import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String id;
  final String itemId;
  final String engineItemCode;
  final String nameArabic;
  final double qty;
  final String unit;
  final double unitPrice;
  final String category;
  final String sourceProjectId;
  final String sourceProjectName;
  final String sourceUnitId;
  final String note;
  final String suggestedSupplierId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CartItem({
    required this.id,
    required this.itemId,
    this.engineItemCode = '',
    required this.nameArabic,
    required this.qty,
    required this.unit,
    this.unitPrice = 0.0,
    this.category = 'aluminum',
    this.sourceProjectId = '',
    this.sourceProjectName = '',
    this.sourceUnitId = '',
    this.note = '',
    this.suggestedSupplierId = '',
    this.createdAt,
    this.updatedAt,
  });

  CartItem copyWith({
    String? id,
    String? itemId,
    String? engineItemCode,
    String? nameArabic,
    double? qty,
    String? unit,
    double? unitPrice,
    String? category,
    String? sourceProjectId,
    String? sourceProjectName,
    String? sourceUnitId,
    String? note,
    String? suggestedSupplierId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      engineItemCode: engineItemCode ?? this.engineItemCode,
      nameArabic: nameArabic ?? this.nameArabic,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      category: category ?? this.category,
      sourceProjectId: sourceProjectId ?? this.sourceProjectId,
      sourceProjectName: sourceProjectName ?? this.sourceProjectName,
      sourceUnitId: sourceUnitId ?? this.sourceUnitId,
      note: note ?? this.note,
      suggestedSupplierId: suggestedSupplierId ?? this.suggestedSupplierId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'engineItemCode': engineItemCode,
      'nameArabic': nameArabic,
      'qty': qty,
      'unit': unit,
      'unitPrice': unitPrice,
      'category': category,
      'sourceProjectId': sourceProjectId,
      'sourceProjectName': sourceProjectName,
      'sourceUnitId': sourceUnitId,
      'note': note,
      'suggestedSupplierId': suggestedSupplierId,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CartItem(
      id: docId ?? (map['id'] as String? ?? ''),
      itemId: map['itemId'] as String? ?? '',
      engineItemCode: map['engineItemCode'] as String? ?? '',
      nameArabic: map['nameArabic'] as String? ?? '',
      qty: (map['qty'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String? ?? 'piece',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'aluminum',
      sourceProjectId: map['sourceProjectId'] as String? ?? '',
      sourceProjectName: map['sourceProjectName'] as String? ?? '',
      sourceUnitId: map['sourceUnitId'] as String? ?? '',
      note: map['note'] as String? ?? '',
      suggestedSupplierId: map['suggestedSupplierId'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

