import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../suppliers/data/suppliers_repository.dart';
import '../data/orders_repository.dart';
import '../data/purchase_order_pdf_generator.dart';
import '../domain/order_model.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isBusy = false;

  // Local editable state for Supplier interactive review & pricing
  String? _initializedForOrderId;
  DateTime? _initializedAt;
  late List<OrderLineItem> _editableItems;
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _priceControllers = {};
  final Map<int, TextEditingController> _supplierNoteControllers = {};
  final TextEditingController _generalSupplierNoteCtrl =
      TextEditingController();

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final c in _supplierNoteControllers.values) {
      c.dispose();
    }
    _generalSupplierNoteCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  void _syncEditableState(OrderModel order) {
    if (_initializedForOrderId == order.id &&
        _initializedAt == order.updatedAt) {
      return;
    }
    _initializedForOrderId = order.id;
    _initializedAt = order.updatedAt;
    _editableItems = List<OrderLineItem>.from(order.items);
    _generalSupplierNoteCtrl.text = order.supplierResponseNote;

    for (var i = 0; i < _editableItems.length; i++) {
      final item = _editableItems[i];
      _qtyControllers[i] ??= TextEditingController();
      _qtyControllers[i]!.text = _fmt(item.qty);

      _priceControllers[i] ??= TextEditingController();
      _priceControllers[i]!.text =
          item.unitPrice > 0 ? _fmt(item.unitPrice) : '';

      _supplierNoteControllers[i] ??= TextEditingController();
      _supplierNoteControllers[i]!.text = item.supplierNote;
    }
  }

  double get _liveComputedTotal =>
      _editableItems.fold<double>(0.0, (acc, i) => acc + i.lineTotal);

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final currentUser = ref.watch(currentUserProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الطلب وعرض السعر'),
        ),
        body: orderAsync.when(
          data: (order) {
            if (order == null) {
              return const Center(child: Text('الطلب غير موجود'));
            }

            _syncEditableState(order);

            final supplier =
                ref.watch(supplierByIdProvider(order.supplierId)).value;
            final whatsappNumbers = supplier?.allWhatsappNumbers ?? const [];

            final isSupplierOrAdmin = currentUser != null &&
                (currentUser.role == UserRole.admin ||
                    currentUser.role == UserRole.supplier);
            final isOwner =
                currentUser != null && currentUser.role == UserRole.owner;
            final canSupplierEditQuote = isSupplierOrAdmin &&
                (order.status == OrderStatus.sent ||
                    order.status == OrderStatus.quoted);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Order Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'طلب رقم: ${order.orderNumber}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'الورشة: ${order.workshopName}  •  المورد: ${order.supplierName}',
                                  style: const TextStyle(
                                    color: AppColors.slate400,
                                    fontSize: 13,
                                  ),
                                ),
                                if (order.projectName.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'المشروع: ${order.projectName}',
                                    style: const TextStyle(
                                      color: AppColors.amberPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if (order.workshopPhone.isNotEmpty ||
                                    order.workshopLocation.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (order.workshopLocation.isNotEmpty)
                                        'الموقع: ${order.workshopLocation}',
                                      if (order.workshopPhone.isNotEmpty)
                                        'هاتف الورشة: ${order.workshopPhone}',
                                    ].join(' • '),
                                    style: const TextStyle(
                                      color: AppColors.slate400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            _buildStatusBadge(order.status),
                          ],
                        ),
                        if (order.notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.glassBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ملاحظة الورشة على الطلب: ${order.notes}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        const Divider(height: 24),

                        // Export PDF & WhatsApp Actions
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                              ),
                              label: const Text('تحميل وطباعة PDF للطلب'),
                              onPressed: () => _exportOrderPdf(context, order),
                            ),
                            if (isOwner && whatsappNumbers.isNotEmpty)
                              for (final phone in whatsappNumbers)
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.chat_rounded,
                                    size: 18,
                                    color: AppColors.success,
                                  ),
                                  label: Text('واتساب المورد ($phone)'),
                                  onPressed: () =>
                                      _launchWhatsApp(context, order, phone),
                                )
                            else if (isSupplierOrAdmin &&
                                order.workshopPhone.isNotEmpty)
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.chat_rounded,
                                  size: 18,
                                  color: AppColors.success,
                                ),
                                label: Text(
                                  'مراسلة الورشة واتساب (${order.workshopPhone})',
                                ),
                                onPressed: () => _launchWhatsApp(
                                  context,
                                  order,
                                  order.workshopPhone,
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.chat_rounded,
                                  size: 18,
                                  color: AppColors.success,
                                ),
                                label: const Text('مشاركة عبر واتساب'),
                                onPressed: () =>
                                    _launchWhatsApp(context, order, ''),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Owner Banner & Action Card (When viewing as Workshop Owner)
                if (isOwner) ...[
                  _buildOwnerDecisionCard(
                    context: context,
                    order: order,
                    actorUid: currentUser.uid,
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Supplier Interactive Review & Pricing Editor OR Read-Only Items View
                if (canSupplierEditQuote)
                  _buildSupplierInteractivePricingCard(
                    context: context,
                    order: order,
                    actorUid: currentUser.uid,
                    isDark: isDark,
                    theme: theme,
                  )
                else ...[
                  if (isSupplierOrAdmin)
                    _buildSupplierPostQuoteActionsCard(
                      context: context,
                      order: order,
                      actorUid: currentUser.uid,
                    ),
                  _buildReadOnlyItemsCard(
                    context: context,
                    order: order,
                    theme: theme,
                    isDark: isDark,
                  ),
                ],

                const SizedBox(height: 16),

                // 4. Status History Timeline
                if (order.statusHistory.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سجل تتبع حالة الطلب',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...order.statusHistory.map(
                            (h) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                    color: AppColors.amberPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${OrderStatus.fromString(h.status).arabicLabel} — ${h.note}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ في تحميل الطلب: $e')),
        ),
      ),
    );
  }

  // ── Owner Decision Card ─────────────────────────────────────────────
  Widget _buildOwnerDecisionCard({
    required BuildContext context,
    required OrderModel order,
    required String actorUid,
  }) {
    if (order.status == OrderStatus.sent) {
      return Card(
        color: AppColors.glassBlue.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                color: AppColors.glassBlueLight,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الطلب مرسل للمورد وبانتظار التسعير والرد',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'سيقوم المورد بتحديد الأصناف المتوفرة لديه وإدخال أسعارها وملاحظاته، وستظهر لك هنا فور إرسالها.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.error,
                  size: 18,
                ),
                label: const Text(
                  'إلغاء الطلب',
                  style: TextStyle(color: AppColors.error),
                ),
                onPressed: _isBusy
                    ? null
                    : () => _handleStatusUpdate(
                          context,
                          order,
                          OrderStatus.cancelled,
                          actorUid: actorUid,
                          note: 'تم إلغاء الطلب من قِبل الورشة',
                        ),
              ),
            ],
          ),
        ),
      );
    }

    if (order.status == OrderStatus.quoted) {
      return Card(
        color: AppColors.amberPrimary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.amberPrimary, width: 1.4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.amberPrimary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'وصل رد وتسعيرة المورد! يرجى مراجعة الأسعار والأصناف المتوفرة أدناه',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              if (order.supplierResponseNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.amberPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ملاحظة المورد العامة: ${order.supplierResponseNote}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      'اعتماد التسعيرة وتأكيد الطلب (${order.computedTotal.toStringAsFixed(2)} ${order.currency})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isBusy
                        ? null
                        : () => _handleApproveByOwner(
                              context,
                              order,
                              actorUid,
                            ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.error,
                      size: 18,
                    ),
                    label: const Text(
                      'رفض / إلغاء الطلب',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onPressed: _isBusy
                        ? null
                        : () => _handleStatusUpdate(
                              context,
                              order,
                              OrderStatus.cancelled,
                              actorUid: actorUid,
                              note: 'تم رفض التسعيرة وإلغاء الطلب من قِبل الورشة',
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Supplier Interactive Pricing & Item Modification Card ───────────
  Widget _buildSupplierInteractivePricingCard({
    required BuildContext context,
    required OrderModel order,
    required String actorUid,
    required bool isDark,
    required ThemeData theme,
  }) {
    final availableCount =
        _editableItems.where((i) => i.isAvailable && i.qty > 0).length;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppColors.amberPrimary.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.amberPrimary,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مراجعة الأصناف وإدخال الأسعار والرد للورشة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'حدد الأصناف المتوفرة لديك، عدّل الكمية إن لزم، وأدخل سعر الوحدة والملاحظات يدوياً',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('تحديد الكل كمتوفر بالكمية المطلوبة'),
                  onPressed: () {
                    setState(() {
                      for (var i = 0; i < _editableItems.length; i++) {
                        final req = _editableItems[i].requestedQty;
                        _editableItems[i] = _editableItems[i].copyWith(
                          isAvailable: true,
                          qty: req,
                        );
                        _qtyControllers[i]?.text = _fmt(req);
                      }
                    });
                  },
                ),
              ],
            ),
            const Divider(height: 24),

            // Editable Item Rows
            ...List.generate(_editableItems.length, (index) {
              final item = _editableItems[index];
              final unitLabel = CatalogUnit.arabicLabel(item.unit);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: !item.isAvailable
                      ? AppColors.error.withValues(alpha: 0.06)
                      : (isDark
                          ? AppColors.slate800.withValues(alpha: 0.4)
                          : AppColors.slate100.withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !item.isAvailable
                        ? AppColors.error.withValues(alpha: 0.4)
                        : AppColors.slate400.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor:
                              AppColors.amberPrimary.withValues(alpha: 0.2),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.amberPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nameArabic,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: !item.isAvailable
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              Text(
                                'الكمية المطلوبة من الورشة: ${_fmt(item.requestedQty)} $unitLabel'
                                '${item.note.isNotEmpty ? " • ملاحظة الورشة: ${item.note}" : ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Available / Unavailable Switch
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.isAvailable ? 'متوفر' : 'غير متوفر',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: item.isAvailable
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                            Switch(
                              value: item.isAvailable,
                              activeThumbColor: AppColors.success,
                              onChanged: (val) {
                                setState(() {
                                  final restoredQty = val
                                      ? (item.qty > 0
                                          ? item.qty
                                          : item.requestedQty)
                                      : 0.0;
                                  _editableItems[index] = item.copyWith(
                                    isAvailable: val,
                                    qty: restoredQty,
                                  );
                                  _qtyControllers[index]?.text =
                                      _fmt(restoredQty);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Editable Fields: Supplied Qty, Unit Price, Supplier Note
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.isAvailable) ...[
                          SizedBox(
                            width: 160,
                            child: TextField(
                              controller: _qtyControllers[index],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'الكمية المتوفرة ($unitLabel)',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final parsed = double.tryParse(v.trim()) ?? 0.0;
                                setState(() {
                                  _editableItems[index] = item.copyWith(
                                    qty: parsed < 0 ? 0.0 : parsed,
                                  );
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: TextField(
                              controller: _priceControllers[index],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    'سعر الوحدة (${order.currency}) *',
                                hintText: '0.00',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final parsed = double.tryParse(v.trim()) ?? 0.0;
                                setState(() {
                                  _editableItems[index] = item.copyWith(
                                    unitPrice: parsed < 0 ? 0.0 : parsed,
                                  );
                                });
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amberPrimary
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'إجمالي البند: ${_editableItems[index].lineTotal.toStringAsFixed(2)} ${order.currency}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.amberPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _supplierNoteControllers[index],
                            decoration: const InputDecoration(
                              labelText: 'ملاحظة المورد على الصنف (اختياري)',
                              hintText: 'مثال: متوفر لون بديل / توريد غداً...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              _editableItems[index] =
                                  _editableItems[index].copyWith(
                                supplierNote: v,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            TextField(
              controller: _generalSupplierNoteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات المورد العامة للورشة (اختياري)',
                hintText:
                    'مثال: الأسعار شاملة التوصيل خلال يومين من اعتماد الطلب...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Summary & Submit Quote Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amberPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.amberPrimary.withValues(alpha: 0.5),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الأصناف المتوفرة: $availableCount من ${_editableItems.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate400,
                        ),
                      ),
                      Text(
                        'الإجمالي الكلي للتسعيرة: ${_liveComputedTotal.toStringAsFixed(2)} ${order.currency}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppColors.amberPrimary,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.error,
                          size: 18,
                        ),
                        label: const Text(
                          'اعتذار / إلغاء الطلب',
                          style: TextStyle(color: AppColors.error),
                        ),
                        onPressed: _isBusy
                            ? null
                            : () => _handleStatusUpdate(
                                  context,
                                  order,
                                  OrderStatus.cancelled,
                                  actorUid: actorUid,
                                  note: 'اعتذر المورد عن توفير الطلب',
                                ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amberPrimary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: _isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          order.status == OrderStatus.quoted
                              ? 'تحديث التسعيرة وإعادة الإرسال للورشة'
                              : 'حفظ وإرسال التسعيرة والرد للورشة',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isBusy
                            ? null
                            : () => _handleSubmitSupplierQuote(
                                  context: context,
                                  order: order,
                                  actorUid: actorUid,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Supplier Post-Quote Fulfillment Actions ─────────────────────────
  Widget _buildSupplierPostQuoteActionsCard({
    required BuildContext context,
    required OrderModel order,
    required String actorUid,
  }) {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: AppColors.success.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_shipping_rounded,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'تحديث حالة تجهيز وتسليم الطلب للورشة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (order.status == OrderStatus.confirmed)
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.precision_manufacturing_rounded,
                        size: 18,
                      ),
                      label: const Text('بدء التجهيز (قيد التجهيز)'),
                      onPressed: _isBusy
                          ? null
                          : () => _handleStatusUpdate(
                                context,
                                order,
                                OrderStatus.preparing,
                                actorUid: actorUid,
                                note: 'بدأ المورد في تجهيز الطلب',
                              ),
                    ),
                  if (order.status == OrderStatus.confirmed ||
                      order.status == OrderStatus.preparing)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.task_alt_rounded, size: 18),
                      label: const Text('إتمام التسليم (مكتمل)'),
                      onPressed: _isBusy
                          ? null
                          : () => _handleStatusUpdate(
                                context,
                                order,
                                OrderStatus.completed,
                                actorUid: actorUid,
                                note: 'تم تسليم الطلب للورشة واكتماله',
                              ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Read-Only Items Card (For Owner & Completed Orders) ─────────────
  Widget _buildReadOnlyItemsCard({
    required BuildContext context,
    required OrderModel order,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'بنود الطلب (${order.items.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'المتوفر: ${order.availableItemsCount} من ${order.items.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...order.items.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              final unitLabel = CatalogUnit.arabicLabel(item.unit);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: !item.isAvailable
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.slate700.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !item.isAvailable
                        ? AppColors.error.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          AppColors.amberPrimary.withValues(alpha: 0.2),
                      child: Text(
                        '$idx',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amberPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                item.nameArabic,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: !item.isAvailable
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (!item.isAvailable)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'غير متوفر لدى المورد',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.error,
                                    ),
                                  ),
                                )
                              else if (item.isQuantityModified)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'الكمية معدلة من المورد (المطلوب: ${_fmt(item.requestedQty)})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الكمية المطلوبة: ${_fmt(item.requestedQty)} $unitLabel'
                            ' • المتوفر للتوريد: ${item.isAvailable ? "${_fmt(item.qty)} $unitLabel" : "0"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate400,
                            ),
                          ),
                          if (item.note.isNotEmpty)
                            Text(
                              'ملاحظة الورشة: ${item.note}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate400,
                              ),
                            ),
                          if (item.supplierNote.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'ملاحظة المورد: ${item.supplierNote}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amberPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.isAvailable
                              ? '${_fmt(item.qty)} $unitLabel'
                              : 'غير متوفر',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: item.isAvailable
                                ? AppColors.amberPrimary
                                : AppColors.error,
                          ),
                        ),
                        if (item.isAvailable && item.unitPrice > 0) ...[
                          Text(
                            'سعر الوحدة: ${item.unitPrice.toStringAsFixed(2)} ${order.currency}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.slate400,
                            ),
                          ),
                          Text(
                            'الإجمالي: ${item.lineTotal.toStringAsFixed(2)} ${order.currency}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),
            if (order.supplierResponseNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amberPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ملاحظات المورد العامة: ${order.supplierResponseNote}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (order.computedTotal > 0) ...[
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'الإجمالي الكلي للتسعيرة: ${order.computedTotal.toStringAsFixed(2)} ${order.currency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.amberPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    final color = switch (status) {
      OrderStatus.draft => AppColors.slate400,
      OrderStatus.sent => AppColors.glassBlueLight,
      OrderStatus.quoted => AppColors.amberPrimary,
      OrderStatus.confirmed => AppColors.success,
      OrderStatus.preparing => AppColors.amberPrimary,
      OrderStatus.completed => AppColors.success,
      OrderStatus.cancelled => AppColors.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.arabicLabel,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  Future<void> _exportOrderPdf(BuildContext context, OrderModel order) async {
    try {
      final pdfBytes =
          await PurchaseOrderPdfGenerator.generatePurchaseOrderPdf(order);
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: '${order.orderNumber}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء ملف PDF: $e')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(
    BuildContext context,
    OrderModel order,
    String phone,
  ) async {
    final uri = order.buildWhatsAppUri(phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleSubmitSupplierQuote({
    required BuildContext context,
    required OrderModel order,
    required String actorUid,
  }) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(ordersRepositoryProvider).submitSupplierQuote(
            orderId: order.id,
            updatedItems: _editableItems,
            supplierResponseNote: _generalSupplierNoteCtrl.text.trim(),
            actorUid: actorUid,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ التعديلات والأسعار وإرسال التسعيرة للورشة بنجاح ✅',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إرسال التسعيرة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleApproveByOwner(
    BuildContext context,
    OrderModel order,
    String actorUid,
  ) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(ordersRepositoryProvider).approveOrder(
            orderId: order.id,
            actorUid: actorUid,
            note: 'اعتمدت الورشة تسعيرة المورد وأكدت الطلب',
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم اعتماد التسعيرة وتأكيد الطلب بنجاح ✅'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تأكيد الطلب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleStatusUpdate(
    BuildContext context,
    OrderModel order,
    OrderStatus newStatus, {
    required String actorUid,
    String note = '',
  }) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(ordersRepositoryProvider).updateOrderStatus(
            orderId: order.id,
            newStatus: newStatus,
            actorUid: actorUid,
            note: note,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة الطلب إلى: ${newStatus.arabicLabel}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث حالة الطلب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
