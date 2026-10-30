import 'package:cloud_firestore/cloud_firestore.dart';

class StockItem {
  final String itemId;
  final String nameArabic;
  final String supplierId;
  final double balance;
  final String unit;
  final double reservedQty;
  final double lowStockThreshold;
  final DateTime? updatedAt;

  const StockItem({
    required this.itemId,
    this.nameArabic = '',
    required this.supplierId,
    required this.balance,
    required this.unit,
    this.reservedQty = 0.0,
    this.lowStockThreshold = 10.0,
    this.updatedAt,
  });

  bool get isLowStock => balance <= lowStockThreshold;

  factory StockItem.fromMap(
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

    return StockItem(
      itemId: map['itemId'] as String? ?? itemId,
      nameArabic: map['nameArabic'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? supplierId,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'piece',
      reservedQty: (map['reservedQty'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toDouble() ?? 10.0,
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class InventoryMovement {
  final String movementId;
  final String itemId;
  final String nameArabic;
  final String supplierId;
  final double qty;
  final double? balanceBefore;
  final double? balanceAfter;
  final String unit;
  final String movementType; // 'deduction' | 'restock' | 'adjustment'
  final String? orderId;
  final String? idempotencyKey;
  final String? reason;
  final String? actorUid;
  final DateTime? createdAt;

  const InventoryMovement({
    required this.movementId,
    required this.itemId,
    this.nameArabic = '',
    required this.supplierId,
    required this.qty,
    this.balanceBefore,
    this.balanceAfter,
    required this.unit,
    required this.movementType,
    this.orderId,
    this.idempotencyKey,
    this.reason,
    this.actorUid,
    this.createdAt,
  });

  String get movementTypeArabic {
    switch (movementType) {
      case 'deduction':
        return 'خصم طلب مؤكد';
      case 'restock':
        return 'تغذية مستودع (توريد)';
      case 'adjustment':
        return 'تسوية جردية';
      default:
        return movementType;
    }
  }

  factory InventoryMovement.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return InventoryMovement(
      movementId: docId ?? (map['movementId'] as String? ?? ''),
      itemId: map['itemId'] as String? ?? '',
      nameArabic: map['nameArabic'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      qty: (map['qty'] as num?)?.toDouble() ?? 0.0,
      balanceBefore: (map['balanceBefore'] as num?)?.toDouble(),
      balanceAfter: (map['balanceAfter'] as num?)?.toDouble(),
      unit: map['unit'] as String? ?? 'piece',
      movementType: map['movementType'] as String? ?? 'deduction',
      orderId: map['orderId'] as String?,
      idempotencyKey: map['idempotencyKey'] as String?,
      reason: map['reason'] as String?,
      actorUid: map['actorUid'] as String?,
      createdAt: parseDate(map['createdAt']),
    );
  }
}

