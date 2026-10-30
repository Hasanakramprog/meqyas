import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/item_price.dart';

class PricingRepository {
  final FirebaseFirestore _firestore;

  PricingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Streams prices for a given supplier mapped by `itemId`.
  Stream<Map<String, ItemPrice>> watchSupplierPrices(String supplierId) {
    if (supplierId.isEmpty) return Stream.value(const {});
    return _firestore
        .collection('suppliers')
        .doc(supplierId)
        .collection('prices')
        .snapshots()
        .map((snap) {
          final map = <String, ItemPrice>{};
          for (final doc in snap.docs) {
            map[doc.id] = ItemPrice.fromMap(
              doc.data(),
              itemId: doc.id,
              supplierId: supplierId,
            );
          }
          return map;
        });
  }

  /// Updates an item price and appends an entry to `suppliers/{supplierId}/prices/{itemId}/history` (Spec §6 & §10).
  Future<void> saveItemPrice({
    required String supplierId,
    required String itemId,
    required double price,
    String currency = 'SAR',
    String? actorUid,
  }) async {
    if (price < 0) {
      throw ArgumentError('السعر لا يمكن أن يكون سالباً');
    }

    final priceRef = _firestore
        .collection('suppliers')
        .doc(supplierId)
        .collection('prices')
        .doc(itemId);
    final historyRef = priceRef.collection('history').doc();
    final now = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(priceRef, {
      'itemId': itemId,
      'supplierId': supplierId,
      'price': price,
      'currency': currency,
      'validFrom': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    batch.set(historyRef, {
      'itemId': itemId,
      'price': price,
      'currency': currency,
      'updatedBy': actorUid,
      'recordedAt': now,
    });

    await batch.commit();
  }

  Stream<List<PriceHistoryEntry>> watchPriceHistory({
    required String supplierId,
    required String itemId,
  }) {
    if (supplierId.isEmpty || itemId.isEmpty) {
      return Stream.value(const []);
    }
    return _firestore
        .collection('suppliers')
        .doc(supplierId)
        .collection('prices')
        .doc(itemId)
        .collection('history')
        .orderBy('recordedAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PriceHistoryEntry.fromMap(d.data(), docId: d.id))
              .toList(),
        );
  }
}

final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  return PricingRepository();
});

final supplierPricesProvider = StreamProvider.autoDispose
    .family<Map<String, ItemPrice>, String>((ref, supplierId) {
      final repo = ref.watch(pricingRepositoryProvider);
      return repo.watchSupplierPrices(supplierId);
    });
