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

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final currentUser = ref.watch(currentUserProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل أمر الشراء والتوريد'),
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          final supplier =
              ref.watch(supplierByIdProvider(order.supplierId)).value;
          final whatsappNumbers = supplier?.allWhatsappNumbers ?? const [];
          final canConfirm = currentUser != null &&
              (currentUser.role == UserRole.admin ||
                  (currentUser.role == UserRole.supplier &&
                      currentUser.supplierId == order.supplierId));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Order Header Card
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
                                'أمر شراء رقم: ${order.orderNumber}',
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
                            ],
                          ),
                          _buildStatusBadge(order.status),
                        ],
                      ),
                      const Divider(height: 24),

                      // Export & WhatsApp Actions (Spec §11: NEVER deducts stock)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                            label: const Text('تصدير وطباعة أمر الشراء PDF'),
                            onPressed: () => _exportOrderPdf(context, order),
                          ),
                          if (whatsappNumbers.isNotEmpty)
                            for (final phone in whatsappNumbers)
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.chat_rounded,
                                  size: 18,
                                  color: AppColors.success,
                                ),
                                label: Text('إرسال عبر واتساب ($phone)'),
                                onPressed: () =>
                                    _launchWhatsApp(context, order, phone),
                              )
                          else
                            OutlinedButton.icon(
                              icon: const Icon(
                                Icons.chat_rounded,
                                size: 18,
                                color: AppColors.success,
                              ),
                              label: const Text('مشاركة النص عبر واتساب'),
                              onPressed: () =>
                                  _launchWhatsApp(context, order, ''),
                            ),
                          if (order.status == OrderStatus.draft)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text('اعتماد المسودة كطلب مرسل'),
                              onPressed: _isBusy
                                  ? null
                                  : () async {
                                      setState(() => _isBusy = true);
                                      try {
                                        await ref
                                            .read(ordersRepositoryProvider)
                                            .sendDraftOrder(
                                              order.id,
                                              actorUid: currentUser?.uid,
                                            );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isBusy = false);
                                        }
                                      }
                                    },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Authorized Confirmation & Status Transition Card (Supplier / Admin)
              if (canConfirm) ...[
                Card(
                  color: AppColors.success.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'إجراءات المورد / الإدارة (التأكيد الرسمي وخصم المخزون)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'تأكيد الطلب ينفذ عملية ذرية (Transaction) تتحقق من كفاية رصيد جميع الأصناف وتخصمها مرة واحدة فقط مع تسجيل حركة المخزون.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (order.status == OrderStatus.sent ||
                                order.status == OrderStatus.draft)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                ),
                                icon: const Icon(Icons.check_circle_rounded),
                                label: const Text(
                                  'تأكيد الطلب وخصم المخزون (confirmOrder)',
                                ),
                                onPressed: _isBusy
                                    ? null
                                    : () => _handleConfirmOrder(context, order),
                              ),
                            if (order.status == OrderStatus.confirmed)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.precision_manufacturing_rounded),
                                label: const Text('بدء التجهيز (قيد التجهيز)'),
                                onPressed: _isBusy
                                    ? null
                                    : () => _handleStatusUpdate(
                                          context,
                                          order,
                                          OrderStatus.preparing,
                                        ),
                              ),
                            if (order.status == OrderStatus.confirmed ||
                                order.status == OrderStatus.preparing)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                ),
                                icon: const Icon(Icons.task_alt_rounded),
                                label: const Text('إتمام التسليم (مكتمل)'),
                                onPressed: _isBusy
                                    ? null
                                    : () => _handleStatusUpdate(
                                          context,
                                          order,
                                          OrderStatus.completed,
                                        ),
                              ),
                            if (order.status != OrderStatus.completed &&
                                order.status != OrderStatus.cancelled)
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: AppColors.error,
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
                                        ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Line Items Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بنود الطلب (${order.items.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...order.items.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        final qtyStr = item.qty == item.qty.roundToDouble()
                            ? item.qty.toInt().toString()
                            : item.qty.toStringAsFixed(2);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.slate700.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    AppColors.amberPrimary.withValues(
                                  alpha: 0.2,
                                ),
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
                                    Text(
                                      item.nameArabic,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (item.projectName.isNotEmpty ||
                                        item.note.isNotEmpty)
                                      Text(
                                        [
                                          if (item.projectName.isNotEmpty)
                                            'المشروع: ${item.projectName}',
                                          if (item.note.isNotEmpty) item.note,
                                        ].join(' • '),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate400,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$qtyStr ${CatalogUnit.arabicLabel(item.unit)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.amberPrimary,
                                    ),
                                  ),
                                  if (item.unitPrice > 0)
                                    Text(
                                      '${item.lineTotal.toStringAsFixed(2)} ${order.currency}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.success,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      if (order.computedTotal > 0) ...[
                        const Divider(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'الإجمالي الكلي: ${order.computedTotal.toStringAsFixed(2)} ${order.currency}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.amberPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status History
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
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    final color = switch (status) {
      OrderStatus.draft => AppColors.slate400,
      OrderStatus.sent => AppColors.glassBlueLight,
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

  Future<void> _handleConfirmOrder(
    BuildContext context,
    OrderModel order,
  ) async {
    setState(() => _isBusy = true);
    try {
      final res = await ref.read(ordersRepositoryProvider).confirmOrder(
            orderId: order.id,
            idempotencyKey: order.idempotencyKey,
          );
      if (context.mounted) {
        final already = res['alreadyConfirmed'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              already
                  ? 'تم تأكيد هذا الطلب مسبقاً (لم يتم خصم المخزون مرتين)'
                  : 'تم تأكيد الطلب وخصم الكميات من مخزون المورد بنجاح!',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.error),
                SizedBox(width: 8),
                Expanded(child: Text('تعذر تأكيد الطلب (لم يتم خصم أي كمية)')),
              ],
            ),
            content: Text('$e'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleStatusUpdate(
    BuildContext context,
    OrderModel order,
    OrderStatus newStatus,
  ) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(ordersRepositoryProvider).updateOrderStatus(
            orderId: order.id,
            newStatus: newStatus,
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

