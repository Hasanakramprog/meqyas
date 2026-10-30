import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../rules/data/rules_repository.dart';
import '../data/orders_repository.dart';
import '../domain/order_model.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  final String? initialWorkshopId;

  const OrdersListScreen({super.key, this.initialWorkshopId});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final ownerUid = currentUser?.uid ?? '';
    final workshops = ref.watch(ownerWorkshopsProvider(ownerUid)).value ?? [];
    final workshopId = widget.initialWorkshopId?.isNotEmpty == true
        ? widget.initialWorkshopId!
        : (ref.watch(activeWorkshopIdProvider) ??
              (workshops.isNotEmpty
                  ? workshops.first.id
                  : (currentUser?.workshopId ?? '')));

    final ordersAsync = ref.watch(workshopOrdersProvider(workshopId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التوريد وأوامر الشراء'),
        actions: [
          IconButton(
            tooltip: 'سلة الاحتياجات',
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: AppColors.amberPrimary,
            ),
            onPressed: () =>
                context.push('/dashboard/owner/cart?workshopId=$workshopId'),
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final filtered = orders.where((o) {
            if (_selectedStatus == 'all') return true;
            return o.status.name == _selectedStatus;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _statusChip('الكل (${orders.length})', 'all'),
                    const SizedBox(width: 8),
                    for (final st in OrderStatus.values) ...[
                      _statusChip(
                        '${st.arabicLabel} (${orders.where((o) => o.status == st).length})',
                        st.name,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('لا توجد طلبات مطابقة للتصنيف المحدد'),
                  ),
                )
              else
                ...filtered.map(
                  (order) => _buildOrderCard(context, order, workshopId, theme),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الطلبات: $e')),
      ),
    );
  }

  Widget _statusChip(String label, String statusKey) {
    final isSelected = _selectedStatus == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.amberPrimary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.amberPrimary : null,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedStatus = statusKey);
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    OrderModel order,
    String workshopId,
    ThemeData theme,
  ) {
    final statusColor = _colorForStatus(order.status);
    final dateStr = intl.DateFormat('yyyy-MM-dd HH:mm')
        .format(order.createdAt ?? DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/dashboard/owner/orders/${order.id}?workshopId=$workshopId',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          order.orderNumber,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '• ${order.supplierName.isNotEmpty ? order.supplierName : "مورد"}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 0.8),
                    ),
                    child: Text(
                      order.status.arabicLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    'عدد الأصناف: ${order.items.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate400,
                    ),
                  ),
                  if (order.computedTotal > 0)
                    Text(
                      'الإجمالي: ${order.computedTotal.toStringAsFixed(2)} ${order.currency}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amberPrimary,
                      ),
                    ),
                  Text(
                    'التاريخ: $dateStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate400,
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

  Color _colorForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return AppColors.slate400;
      case OrderStatus.sent:
        return AppColors.glassBlueLight;
      case OrderStatus.confirmed:
        return AppColors.success;
      case OrderStatus.preparing:
        return AppColors.amberPrimary;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}
