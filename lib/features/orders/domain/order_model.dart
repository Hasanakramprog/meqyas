import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  draft,
  sent,
  confirmed,
  preparing,
  completed,
  cancelled;

  String get arabicLabel {
    switch (this) {
      case OrderStatus.draft:
        return 'مسودة';
      case OrderStatus.sent:
        return 'مُرسل للمورد';
      case OrderStatus.confirmed:
        return 'مؤكد (تم خصم المخزون)';
      case OrderStatus.preparing:
        return 'قيد التجهيز';
      case OrderStatus.completed:
        return 'مكتمل ومُسلّم';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  static OrderStatus fromString(String? value) {
    for (final s in OrderStatus.values) {
      if (s.name == value) return s;
    }
    return OrderStatus.draft;
  }
}

class OrderLineItem {
  final String itemId;
  final String nameArabic;
  final double qty;
  final String unit;
  final double unitPrice;
  final String projectId;
  final String projectName;
  final String unitId;
  final String note;

  const OrderLineItem({
    required this.itemId,
    required this.nameArabic,
    required this.qty,
    required this.unit,
    this.unitPrice = 0.0,
    this.projectId = '',
    this.projectName = '',
    this.unitId = '',
    this.note = '',
  });

  double get lineTotal => qty * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'nameArabic': nameArabic,
      'name': nameArabic,
      'qty': qty,
      'unit': unit,
      'unitPrice': unitPrice,
      'projectId': projectId,
      'projectName': projectName,
      'unitId': unitId,
      'note': note,
    };
  }

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    return OrderLineItem(
      itemId: map['itemId'] as String? ?? '',
      nameArabic:
          map['nameArabic'] as String? ?? (map['name'] as String? ?? ''),
      qty: (map['qty'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String? ?? 'piece',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      projectId: map['projectId'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      unitId: map['unitId'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }
}

class OrderStatusHistoryEntry {
  final String status;
  final String changedBy;
  final String changedAt;
  final String note;

  const OrderStatusHistoryEntry({
    required this.status,
    required this.changedBy,
    required this.changedAt,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'changedBy': changedBy,
      'changedAt': changedAt,
      'note': note,
    };
  }

  factory OrderStatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return OrderStatusHistoryEntry(
      status: map['status'] as String? ?? '',
      changedBy: map['changedBy'] as String? ?? '',
      changedAt: map['changedAt']?.toString() ?? '',
      note: map['note'] as String? ?? '',
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String workshopId;
  final String workshopName;
  final String workshopPhone;
  final String workshopLocation;
  final String supplierId;
  final String supplierName;
  final OrderStatus status;
  final List<OrderLineItem> items;
  final String notes;
  final String idempotencyKey;
  final double totalAmount;
  final String currency;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderStatusHistoryEntry> statusHistory;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.workshopId,
    this.workshopName = '',
    this.workshopPhone = '',
    this.workshopLocation = '',
    required this.supplierId,
    this.supplierName = '',
    this.status = OrderStatus.draft,
    required this.items,
    this.notes = '',
    required this.idempotencyKey,
    this.totalAmount = 0.0,
    this.currency = 'SAR',
    this.confirmedBy,
    this.confirmedAt,
    this.createdAt,
    this.updatedAt,
    this.statusHistory = const [],
  });

  bool get isConfirmed =>
      status == OrderStatus.confirmed ||
      status == OrderStatus.preparing ||
      status == OrderStatus.completed;

  double get computedTotal =>
      items.fold<double>(0.0, (acc, item) => acc + item.lineTotal);

  /// Formats an Arabic WhatsApp order summary (Spec §11).
  String buildWhatsAppMessage() {
    final buffer = StringBuffer();
    buffer.writeln(
      '*طلب توريد مواد — ${workshopName.isNotEmpty ? workshopName : "ورشة ألمنيوم"}*',
    );
    buffer.writeln('رقم الطلب: $orderNumber');
    if (supplierName.isNotEmpty) {
      buffer.writeln('المورد: $supplierName');
    }
    buffer.writeln('-------------------------');
    for (final item in items) {
      final qtyStr = item.qty == item.qty.roundToDouble()
          ? item.qty.toInt().toString()
          : item.qty.toStringAsFixed(2);
      final noteSuffix = item.note.isNotEmpty ? ' (${item.note})' : '';
      buffer.writeln('• $qtyStr ${item.unit} — ${item.nameArabic}$noteSuffix');
    }
    buffer.writeln('-------------------------');
    if (computedTotal > 0) {
      buffer.writeln(
        'الإجمالي التقديري: ${computedTotal.toStringAsFixed(2)} $currency',
      );
    }
    if (notes.isNotEmpty) {
      buffer.writeln('ملاحظات: $notes');
    }
    if (workshopLocation.isNotEmpty) {
      buffer.writeln('الموقع: $workshopLocation');
    }
    if (workshopPhone.isNotEmpty) {
      buffer.writeln('هاتف الورشة: $workshopPhone');
    }
    return buffer.toString().trim();
  }

  Uri buildWhatsAppUri(String rawPhone) {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = Uri.encodeComponent(buildWhatsAppMessage());
    return Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
  }

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'workshopId': workshopId,
      'workshopName': workshopName,
      'workshopPhone': workshopPhone,
      'workshopLocation': workshopLocation,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'status': status.name,
      'items': items.map((i) => i.toMap()).toList(),
      'notes': notes,
      'idempotencyKey': idempotencyKey,
      'totalAmount': computedTotal,
      'currency': currency,
      'statusHistory': statusHistory.map((h) => h.toMap()).toList(),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawItems = map['items'];
    final itemsList = rawItems is Iterable
        ? rawItems
            .whereType<Map>()
            .map((m) => OrderLineItem.fromMap(Map<String, dynamic>.from(m)))
            .toList()
        : <OrderLineItem>[];

    final rawHistory = map['statusHistory'];
    final historyList = rawHistory is Iterable
        ? rawHistory
            .whereType<Map>()
            .map(
              (m) =>
                  OrderStatusHistoryEntry.fromMap(Map<String, dynamic>.from(m)),
            )
            .toList()
        : <OrderStatusHistoryEntry>[];

    return OrderModel(
      id: docId ?? (map['id'] as String? ?? ''),
      orderNumber: map['orderNumber'] as String? ?? 'PO-0000',
      workshopId: map['workshopId'] as String? ?? '',
      workshopName: map['workshopName'] as String? ?? '',
      workshopPhone: map['workshopPhone'] as String? ?? '',
      workshopLocation: map['workshopLocation'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String? ?? '',
      status: OrderStatus.fromString(map['status'] as String?),
      items: itemsList,
      notes: map['notes'] as String? ?? '',
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'SAR',
      confirmedBy: map['confirmedBy'] as String?,
      confirmedAt: parseDate(map['confirmedAt']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      statusHistory: historyList,
    );
  }
}


