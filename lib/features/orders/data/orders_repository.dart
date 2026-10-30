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
  /// CRITICAL (Spec §0.4, §11, §15): Never deducts stock here!
  Future<String> createOrder({
    required String workshopId,
    required String workshopName,
    required String workshopPhone,
    required String workshopLocation,
    required String supplierId,
    required String supplierName,
    required List<OrderLineItem> items,
    String notes = '',
    OrderStatus initialStatus = OrderStatus.sent,
    String? actorUid,
  }) async {
    if (initialStatus == OrderStatus.confirmed) {
      throw ArgumentError(
        'لا يمكن إنشاء طلب بحالة مؤكد مباشرة؛ التأكيد يتم حصرياً عبر الدالة السحابية confirmOrder',
      );
    }

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
              ? 'تم إنشاء الطلب وإرساله للمورد'
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

  /// Updates a `draft` order or sends it (`draft` -> `sent`). Never touches stock.
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

  /// Calls the transactional `confirmOrder` Cloud Function (Core Phase 6 DoD).
  /// - Deducts stock atomically once.
  /// - Retrying with the same `idempotencyKey` never double-deducts.
  /// - Insufficient stock aborts completely without partial deductions.
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

  /// Transitions order status via the server-side `updateOrderStatus` Cloud Function.
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String note = '',
  }) async {
    final callable = _functions.httpsCallable('updateOrderStatus');
    await callable.call({
      'orderId': orderId,
      'newStatus': newStatus.name,
      'note': note,
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

