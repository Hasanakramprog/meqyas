import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/stock_item.dart';

class InventoryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  InventoryRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Streams stock balances for a given supplier mapped by `itemId`.
  Stream<Map<String, StockItem>> watchSupplierStock(String supplierId) {
    if (supplierId.isEmpty) return Stream.value(const {});
    return _firestore
        .collection('suppliers')
        .doc(supplierId)
        .collection('stock')
        .snapshots()
        .map((snap) {
      final map = <String, StockItem>{};
      for (final doc in snap.docs) {
        map[doc.id] = StockItem.fromMap(
          doc.data(),
          itemId: doc.id,
          supplierId: supplierId,
        );
      }
      return map;
    });
  }

  /// Streams inventory movements for a supplier.
  Stream<List<InventoryMovement>> watchSupplierMovements(String supplierId) {
    if (supplierId.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('inventoryMovements')
        .where('supplierId', isEqualTo: supplierId)
        .limit(50)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => InventoryMovement.fromMap(d.data(), docId: d.id))
          .toList();
      list.sort(
        (a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)),
      );
      return list;
    });
  }

  /// Restocks or adjusts inventory via the server-side `adjustStock` Cloud Function (Spec §0.4: never write stock from client).
  Future<void> adjustStock({
    required String supplierId,
    required String itemId,
    required String nameArabic,
    required double qty,
    required String unit,
    String movementType = 'restock',
    String reason = '',
  }) async {
    final callable = _functions.httpsCallable('adjustStock');
    await callable.call({
      'supplierId': supplierId,
      'itemId': itemId,
      'nameArabic': nameArabic,
      'qty': qty,
      'unit': unit,
      'movementType': movementType,
      'reason': reason,
    });
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository();
});

final supplierStockProvider = StreamProvider.autoDispose
    .family<Map<String, StockItem>, String>((ref, supplierId) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchSupplierStock(supplierId);
});

final supplierMovementsProvider = StreamProvider.autoDispose
    .family<List<InventoryMovement>, String>((ref, supplierId) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchSupplierMovements(supplierId);
});

