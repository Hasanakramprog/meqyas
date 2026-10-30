import 'package:cloud_firestore/cloud_firestore.dart';

class ItemPrice {
  final String itemId;
  final String supplierId;
  final double price;
  final String currency;
  final DateTime? validFrom;
  final DateTime? updatedAt;

  const ItemPrice({
    required this.itemId,
    required this.supplierId,
    required this.price,
    this.currency = 'SAR',
    this.validFrom,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'supplierId': supplierId,
      'price': price,
      'currency': currency,
      'validFrom': validFrom != null ? Timestamp.fromDate(validFrom!) : FieldValue.serverTimestamp(),
    };
  }

  factory ItemPrice.fromMap(
    Map<String, dynamic> map, {
    required String itemId,
    required String supplierId,
  }) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ItemPrice(
      itemId: map['itemId'] as String? ?? itemId,
      supplierId: map['supplierId'] as String? ?? supplierId,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'SAR',
      validFrom: parseDate(map['validFrom']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class PriceHistoryEntry {
  final String id;
  final String itemId;
  final double price;
  final String currency;
  final String? updatedBy;
  final DateTime? recordedAt;

  const PriceHistoryEntry({
    required this.id,
    required this.itemId,
    required this.price,
    this.currency = 'SAR',
    this.updatedBy,
    this.recordedAt,
  });

  factory PriceHistoryEntry.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return PriceHistoryEntry(
      id: docId ?? (map['id'] as String? ?? ''),
      itemId: map['itemId'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'SAR',
      updatedBy: map['updatedBy'] as String?,
      recordedAt: parseDate(map['recordedAt']),
    );
  }
}

