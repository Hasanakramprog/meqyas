import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../projects/domain/models/project_unit.dart';
import '../domain/cart_item.dart';

class CartRepository {
  final FirebaseFirestore _firestore;

  CartRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cartCol(String workshopId) =>
      _firestore.collection('workshops').doc(workshopId).collection('cart');

  Stream<List<CartItem>> watchCartItems(String workshopId) {
    if (workshopId.isEmpty) return Stream.value(const []);
    return _cartCol(workshopId).snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => CartItem.fromMap(doc.data(), docId: doc.id))
          .toList();
      list.sort((a, b) => a.category.compareTo(b.category));
      return list;
    });
  }

  Future<void> saveCartItem(String workshopId, CartItem item) async {
    if (workshopId.isEmpty) return;
    final col = _cartCol(workshopId);
    final docRef = item.id.isNotEmpty ? col.doc(item.id) : col.doc();
    final now = FieldValue.serverTimestamp();
    final data = item.copyWith(id: docRef.id).toMap();
    data['updatedAt'] = now;
    if (item.id.isEmpty) {
      data['createdAt'] = now;
    }
    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> deleteCartItem(String workshopId, String cartItemId) async {
    if (workshopId.isEmpty || cartItemId.isEmpty) return;
    await _cartCol(workshopId).doc(cartItemId).delete();
  }

  Future<void> clearCartItems(
    String workshopId, {
    List<String>? itemIdsToDelete,
  }) async {
    if (workshopId.isEmpty) return;
    final col = _cartCol(workshopId);
    final snap = await col.get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      if (itemIdsToDelete == null || itemIdsToDelete.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  /// Adds or updates aggregated project materials in the workshop cart.
  /// Stock is NEVER modified here (Spec §0.4 & §11).
  Future<int> upsertProjectCartItems({
    required String workshopId,
    required List<CartItem> items,
  }) async {
    if (workshopId.isEmpty || items.isEmpty) return 0;

    final col = _cartCol(workshopId);
    final existingSnap = await col.get();
    final existingByKey = <String, DocumentSnapshot<Map<String, dynamic>>>{};

    for (final doc in existingSnap.docs) {
      final d = doc.data();
      final key = '${d['itemId']}_${d['sourceProjectId']}';
      existingByKey[key] = doc;
    }

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final item in items) {
      final key = '${item.itemId}_${item.sourceProjectId}';
      final existingDoc = existingByKey[key];
      if (existingDoc != null) {
        batch.update(existingDoc.reference, {
          ...item.toMap(),
          'updatedAt': now,
        });
      } else {
        final docRef = col.doc();
        batch.set(docRef, {
          ...item.toMap(),
          'createdAt': now,
          'updatedAt': now,
        });
      }
    }

    await batch.commit();
    return items.length;
  }

  /// Aggregates required Aluminum Bars, Glass, Accessories, and Mesh/Brush Rolls from a project's units.
  static List<CartItem> aggregateFromProject({
    required String projectId,
    required String projectName,
    required List<ProjectUnit> units,
    required CalculatorEngine engine,
    required CutOptimizer optimizer,
    required List<CatalogItem> catalogItems,
    Map<String, int>? precomputedBarsByItemCode,
    String defaultSupplierId = '',
  }) {
    if (units.isEmpty) return const [];

    CatalogItem? findCatalogByEngineCode(String engineCode) {
      for (final c in catalogItems) {
        if (c.engineItemCode == engineCode) return c;
      }
      if (engineCode.startsWith('screen_rollers')) {
        for (final c in catalogItems) {
          if (c.engineItemCode == 'screen_rollers') return c;
        }
      }
      return null;
    }

    final resultCartItems = <CartItem>[];
    final allCutPieces = <CutPiece>[];
    final pieceCountByItemCode = <String, int>{};
    final itemArabicNames = <String, String>{};
    final accessoryTotals = <String, int>{};
    final accessoryNames = <String, String>{};
    final accessoryUnits = <String, String>{};
    var totalGlassAreaM2 = 0.0;
    var totalGlassPanes = 0;
    var hasAnyScreens = false;

    for (final unit in units) {
      final calc = engine.calculate(unit.toEngineSpec());
      if (unit.hasScreen && unit.screenCount > 0) {
        hasAnyScreens = true;
      }

      // 1. Collect profile pieces for bar count calculation
      for (final piece in calc.pieces) {
        final totalPieceQty = piece.quantity * unit.quantity;
        if (totalPieceQty <= 0) continue;

        itemArabicNames[piece.itemCode] = piece.nameArabic;
        pieceCountByItemCode[piece.itemCode] =
            (pieceCountByItemCode[piece.itemCode] ?? 0) + totalPieceQty;

        allCutPieces.add(
          CutPiece(
            itemCode: piece.itemCode,
            nameArabic: piece.nameArabic,
            lengthCm: piece.lengthCm,
            quantity: totalPieceQty,
            cutAngleLeft: piece.cutAngleLeft,
            cutAngleRight: piece.cutAngleRight,
            profileType: piece.profileType,
            ruleVersionId: piece.ruleVersionId,
            unitTag: unit.name,
          ),
        );
      }

      // 2. Collect glass area & pane counts
      if (calc.glass.quantity > 0 &&
          calc.glass.paneWidthCm > 0 &&
          calc.glass.paneHeightCm > 0) {
        final panes = calc.glass.quantity * unit.quantity;
        final areaM2 = calc.glass.singlePaneAreaM2 * panes;
        totalGlassPanes += panes;
        totalGlassAreaM2 += areaM2;
      }

      // 3. Collect accessories
      for (final acc in calc.accessories) {
        final count = acc.quantity * unit.quantity;
        if (count <= 0) continue;
        accessoryTotals[acc.code] = (accessoryTotals[acc.code] ?? 0) + count;
        accessoryNames[acc.code] = acc.nameArabic;
        accessoryUnits[acc.code] = acc.unit;
      }
    }

    // Compute bars needed per itemCode
    final Map<String, int> barsByItemCode;
    if (precomputedBarsByItemCode != null) {
      barsByItemCode = precomputedBarsByItemCode;
    } else {
      final optResult = optimizer.optimize(pieces: allCutPieces);
      barsByItemCode = <String, int>{};
      for (final bar in optResult.barPlans) {
        if (!bar.isFromRemnant) {
          barsByItemCode[bar.itemCode] =
              (barsByItemCode[bar.itemCode] ?? 0) + 1;
        }
      }
    }

    // Emit Aluminum Bar CartItems
    for (final entry in barsByItemCode.entries) {
      final itemCode = entry.key;
      final barsNeeded = entry.value;
      if (barsNeeded <= 0) continue;

      final cat = findCatalogByEngineCode(itemCode);
      final pieceCount = pieceCountByItemCode[itemCode] ?? 0;

      resultCartItems.add(
        CartItem(
          id: '',
          itemId: cat?.id ?? 'cat_al_$itemCode',
          engineItemCode: itemCode,
          nameArabic: cat?.arabicName ??
              '${itemArabicNames[itemCode] ?? itemCode} (قضيب 6.6م)',
          qty: barsNeeded.toDouble(),
          unit: 'bar',
          category: 'aluminum',
          sourceProjectId: projectId,
          sourceProjectName: projectName,
          note: pieceCount > 0 ? 'إجمالي $pieceCount قطعة مقصوصة' : '',
          suggestedSupplierId: defaultSupplierId,
        ),
      );
    }

    // Emit Glass CartItem
    if (totalGlassAreaM2 > 0) {
      final glassCat = findCatalogByEngineCode('glass_pane');
      final roundedArea =
          double.parse(totalGlassAreaM2.toStringAsFixed(2));
      resultCartItems.add(
        CartItem(
          id: '',
          itemId: glassCat?.id ?? 'cat_gl_clear_6mm',
          engineItemCode: 'glass_pane',
          nameArabic: glassCat?.arabicName ?? 'زجاج شفاف 6 ملم',
          qty: roundedArea > 0 ? roundedArea : 1.0,
          unit: 'm2',
          category: 'glass',
          sourceProjectId: projectId,
          sourceProjectName: projectName,
          note: 'عدد الألواح: $totalGlassPanes لوح',
          suggestedSupplierId: defaultSupplierId,
        ),
      );
    }

    // Emit Accessory CartItems
    for (final entry in accessoryTotals.entries) {
      final code = entry.key;
      final totalQty = entry.value;
      final cat = findCatalogByEngineCode(code);

      resultCartItems.add(
        CartItem(
          id: '',
          itemId: cat?.id ?? 'cat_acc_$code',
          engineItemCode: code,
          nameArabic: cat?.arabicName ?? (accessoryNames[code] ?? code),
          qty: totalQty.toDouble(),
          unit: cat?.unit ?? (accessoryUnits[code] ?? 'piece'),
          category: cat?.categoryId ?? 'accessories',
          sourceProjectId: projectId,
          sourceProjectName: projectName,
          suggestedSupplierId: defaultSupplierId,
        ),
      );
    }

    // Emit Fiber Mesh & Brush Rolls when screens are present (Spec §8.7: strictly ROLL unit)
    if (hasAnyScreens) {
      final meshCat = findCatalogByEngineCode('fiber_mesh_roll');
      resultCartItems.add(
        CartItem(
          id: '',
          itemId: meshCat?.id ?? 'cat_fb_mesh_120',
          engineItemCode: 'fiber_mesh_roll',
          nameArabic:
              meshCat?.arabicName ?? 'لفة شبك منخل فيبر عرض 120 سم × 20 م',
          qty: 1,
          unit: 'roll',
          category: 'fiber',
          sourceProjectId: projectId,
          sourceProjectName: projectName,
          note: 'يباع ويسعر باللفة فقط (Spec §8.7)',
          suggestedSupplierId: defaultSupplierId,
        ),
      );

      final brushCat = findCatalogByEngineCode('brush_450_roll');
      resultCartItems.add(
        CartItem(
          id: '',
          itemId: brushCat?.id ?? 'cat_fb_brush_450',
          engineItemCode: 'brush_450_roll',
          nameArabic: brushCat?.arabicName ?? 'لفة فراشة منخل 450',
          qty: 1,
          unit: 'roll',
          category: 'fiber',
          sourceProjectId: projectId,
          sourceProjectName: projectName,
          note: 'يباع ويسعر باللفة فقط (Spec §8.7)',
          suggestedSupplierId: defaultSupplierId,
        ),
      );
    }

    return resultCartItems;
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository();
});

final workshopCartProvider =
    StreamProvider.autoDispose.family<List<CartItem>, String>((ref, workshopId) {
  final repo = ref.watch(cartRepositoryProvider);
  return repo.watchCartItems(workshopId);
});
