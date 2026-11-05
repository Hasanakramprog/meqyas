import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/order_model.dart';

class OrdersRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  OrdersRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('orders');

  Stream<List<OrderModel>> watchWorkshopOrders(String workshopId) {
    if (workshopId.isEmpty) return Stream.value(const []);
    return _col
        .where('workshopId', isEqualTo: workshopId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => OrderModel.fromMap(d.data(), docId: d.id))
          .toList();
      list.sort(
        (a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)),
      );
      return list;
    });
  }

  Stream<List<OrderModel>> watchSupplierOrders(String supplierId) {
    if (supplierId.isEmpty) return Stream.value(const []);
    return _col
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => OrderModel.fromMap(d.data(), docId: d.id))
          .toList();
      list.sort(
        (a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)),
      );
      return list;
    });
  }

  Stream<List<OrderModel>> watchAllOrders() {
    return _col.limit(100).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => OrderModel.fromMap(d.data(), docId: d.id))
          .toList();
      list.sort(
        (a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)),
      );
      return list;
    });
  }

  Stream<OrderModel?> watchOrderById(String orderId) {
    if (orderId.isEmpty) return Stream.value(null);
    return _col.doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OrderModel.fromMap(doc.data()!, docId: doc.id);
    });
  }

  /// Creates an order in `draft` or `sent` status.
  Future<String> createOrder({
    required String workshopId,
    required String workshopName,
    required String workshopPhone,
    required String workshopLocation,
    required String supplierId,
    required String supplierName,
    required List<OrderLineItem> items,
    String projectId = '',
    String projectName = '',
    String notes = '',
    OrderStatus initialStatus = OrderStatus.sent,
    String? actorUid,
  }) async {
    final docRef = _col.doc();
    final now = FieldValue.serverTimestamp();
    final nowIso = DateTime.now().toIso8601String();
    final shortCode = docRef.id.substring(0, 6).toUpperCase();
    final orderNumber = 'PO-${DateTime.now().year}-$shortCode';
    final idempotencyKey = 'idem_${docRef.id}';

    final order = OrderModel(
      id: docRef.id,
      orderNumber: orderNumber,
      workshopId: workshopId,
      workshopName: workshopName,
      workshopPhone: workshopPhone,
      workshopLocation: workshopLocation,
      supplierId: supplierId,
      supplierName: supplierName,
      projectId: projectId,
      projectName: projectName,
      status: initialStatus,
      items: items,
      notes: notes,
      idempotencyKey: idempotencyKey,
      statusHistory: [
        OrderStatusHistoryEntry(
          status: initialStatus.name,
          changedBy: actorUid ?? '',
          changedAt: nowIso,
          note: initialStatus == OrderStatus.sent
              ? 'تم إرسال طلب التوريد والتسعير من الورشة إلى المورد'
              : 'تم حفظ الطلب كمسودة',
        ),
      ],
    );

    await docRef.set({
      ...order.toMap(),
      'createdAt': now,
      'updatedAt': now,
    });

    return docRef.id;
  }

  /// Updates a `draft` order or sends it (`draft` -> `sent`).
  Future<void> sendDraftOrder(String orderId, {String? actorUid}) async {
    final docRef = _col.doc(orderId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final order = OrderModel.fromMap(snap.data()!, docId: snap.id);
    final updatedHistory = [
      ...order.statusHistory.map((h) => h.toMap()),
      OrderStatusHistoryEntry(
        status: OrderStatus.sent.name,
        changedBy: actorUid ?? '',
        changedAt: DateTime.now().toIso8601String(),
        note: 'تم اعتماد المسودة وإرسالها للمورد',
      ).toMap(),
    ];

    await docRef.update({
      'status': OrderStatus.sent.name,
      'statusHistory': updatedHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supplier submits modified items (availability, supplied quantities, manual unit prices, item notes)
  /// and general response note back to the workshop owner (`status` -> `quoted`).
  Future<void> submitSupplierQuote({
    required String orderId,
    required List<OrderLineItem> updatedItems,
    required String supplierResponseNote,
    String? actorUid,
  }) async {
    final docRef = _col.doc(orderId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final order = OrderModel.fromMap(snap.data()!, docId: snap.id);
    final total = updatedItems.fold<double>(
      0.0,
      (acc, item) => acc + item.lineTotal,
    );
    final availableCount =
        updatedItems.where((i) => i.isAvailable && i.qty > 0).length;
    final unavailableCount = updatedItems.length - availableCount;

    final summaryNote = unavailableCount > 0
        ? 'رد المورد بالتسعيرة ($availableCount صنف متوفر، $unavailableCount غير متوفر) — الإجمالي: ${total.toStringAsFixed(2)} ${order.currency}'
        : 'رد المورد بقبول وتسعير جميع الأصناف ($availableCount صنف) — الإجمالي: ${total.toStringAsFixed(2)} ${order.currency}';

    final updatedHistory = [
      ...order.statusHistory.map((h) => h.toMap()),
      OrderStatusHistoryEntry(
        status: OrderStatus.quoted.name,
        changedBy: actorUid ?? '',
        changedAt: DateTime.now().toIso8601String(),
        note: summaryNote,
      ).toMap(),
    ];

    await docRef.update({
      'items': updatedItems.map((i) => i.toMap()).toList(),
      'totalAmount': total,
      'supplierResponseNote': supplierResponseNote.trim(),
      'status': OrderStatus.quoted.name,
      'statusHistory': updatedHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Workshop Owner (or Supplier) approves/confirms the order.
  Future<void> approveOrder({
    required String orderId,
    String? actorUid,
    String note = 'تم اعتماد التسعيرة وتأكيد الطلب',
  }) async {
    final docRef = _col.doc(orderId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final order = OrderModel.fromMap(snap.data()!, docId: snap.id);
    final updatedHistory = [
      ...order.statusHistory.map((h) => h.toMap()),
      OrderStatusHistoryEntry(
        status: OrderStatus.confirmed.name,
        changedBy: actorUid ?? '',
        changedAt: DateTime.now().toIso8601String(),
        note: note,
      ).toMap(),
    ];

    await docRef.update({
      'status': OrderStatus.confirmed.name,
      'confirmedBy': actorUid ?? '',
      'confirmedAt': FieldValue.serverTimestamp(),
      'statusHistory': updatedHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Calls the transactional `confirmOrder` Cloud Function if needed.
  Future<Map<String, dynamic>> confirmOrder({
    required String orderId,
    required String idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('confirmOrder');
    final response = await callable.call({
      'orderId': orderId,
      'idempotencyKey': idempotencyKey.isNotEmpty
          ? idempotencyKey
          : 'idem_$orderId',
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Updates order status (`preparing`, `completed`, `cancelled`, etc.).
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String note = '',
    String? actorUid,
  }) async {
    final docRef = _col.doc(orderId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final order = OrderModel.fromMap(snap.data()!, docId: snap.id);
    final updatedHistory = [
      ...order.statusHistory.map((h) => h.toMap()),
      OrderStatusHistoryEntry(
        status: newStatus.name,
        changedBy: actorUid ?? '',
        changedAt: DateTime.now().toIso8601String(),
        note: note.isNotEmpty
            ? note
            : 'تحديث الحالة إلى: ${newStatus.arabicLabel}',
      ).toMap(),
    ];

    await docRef.update({
      'status': newStatus.name,
      'statusHistory': updatedHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository();
});

final workshopOrdersProvider = StreamProvider.autoDispose
    .family<List<OrderModel>, String>((ref, workshopId) {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.watchWorkshopOrders(workshopId);
});

final supplierOrdersProvider = StreamProvider.autoDispose
    .family<List<OrderModel>, String>((ref, supplierId) {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.watchSupplierOrders(supplierId);
});

final allAdminOrdersProvider =
    StreamProvider.autoDispose<List<OrderModel>>((ref) {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.watchAllOrders();
});

final orderDetailProvider =
    StreamProvider.autoDispose.family<OrderModel?, String>((ref, orderId) {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.watchOrderById(orderId);
});
