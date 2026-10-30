import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/catalog_item.dart';

class CatalogRepository {
  final FirebaseFirestore _firestore;

  CatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('catalogItems');

  /// Streams all catalog items. Falls back to built-in [SeedCatalog] if the database is empty.
  Stream<List<CatalogItem>> watchAllCatalogItems() {
    return _col.snapshots().map((snap) {
      if (snap.docs.isEmpty) {
        return SeedCatalog.getDefaultCatalogItems();
      }
      final list = snap.docs
          .map((doc) => CatalogItem.fromMap(doc.data(), docId: doc.id))
          .toList();
      list.sort((a, b) => a.code.compareTo(b.code));
      return list;
    });
  }

  /// Streams only active catalog items.
  Stream<List<CatalogItem>> watchActiveCatalogItems() {
    return watchAllCatalogItems().map(
      (items) => items.where((item) => item.isActive).toList(),
    );
  }

  /// Ensures default catalog items are persisted in Firestore if the collection is empty.
  Future<int> seedDefaultCatalogToFirestore() async {
    final existingSnap = await _col.get();
    final existingCodes = existingSnap.docs
        .map((d) => (d.data()['code'] as String? ?? '').toUpperCase())
        .toSet();

    final defaults = SeedCatalog.getDefaultCatalogItems();
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    var added = 0;

    for (final item in defaults) {
      if (existingCodes.contains(item.code.toUpperCase())) continue;
      final docRef = _col.doc(item.id);
      batch.set(docRef, {
        ...item.toMap(),
        'createdAt': now,
        'updatedAt': now,
      });
      added++;
    }

    if (added > 0) {
      await batch.commit();
    }
    return added;
  }

  /// Creates or updates a catalog item, enforcing unique `code` and Spec §8.7 roll validation.
  Future<String> saveCatalogItem(CatalogItem item) async {
    final error = item.validate();
    if (error != null) {
      throw ArgumentError(error);
    }

    final normalizedCode = item.code.trim().toUpperCase();

    // Check for duplicate code across other documents
    final dupQuery = await _col.where('code', isEqualTo: normalizedCode).get();
    for (final doc in dupQuery.docs) {
      if (doc.id != item.id) {
        throw StateError('كود الصنف ($normalizedCode) مستخدم بالفعل لصنف آخر');
      }
    }

    final docRef = item.id.isNotEmpty ? _col.doc(item.id) : _col.doc();
    final now = FieldValue.serverTimestamp();

    final data = item.copyWith(id: docRef.id, code: normalizedCode).toMap();
    data['updatedAt'] = now;
    if (item.id.isEmpty) {
      data['createdAt'] = now;
    }

    await docRef.set(data, SetOptions(merge: true));
    return docRef.id;
  }

  /// Batch imports validated catalog items into Firestore.
  Future<int> importCatalogItemsBatch(List<CatalogItem> items) async {
    if (items.isEmpty) return 0;

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final item in items) {
      final docId = item.id.isNotEmpty
          ? item.id
          : 'cat_${item.code.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final ref = _col.doc(docId);
      batch.set(
        ref,
        {
          ...item.toMap(),
          'createdAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    return items.length;
  }

  Future<void> deleteCatalogItem(String itemId) async {
    await _col.doc(itemId).delete();
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository();
});

final allCatalogItemsProvider =
    StreamProvider.autoDispose<List<CatalogItem>>((ref) {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.watchAllCatalogItems();
});

final activeCatalogItemsProvider =
    StreamProvider.autoDispose<List<CatalogItem>>((ref) {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.watchActiveCatalogItems();
});

