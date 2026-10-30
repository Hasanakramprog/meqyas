import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_model.dart';
import '../../suppliers/data/suppliers_repository.dart';

class SupplierOrdersScreen extends ConsumerStatefulWidget {
  const SupplierOrdersScreen({super.key});

  @override
  ConsumerState<SupplierOrdersScreen> createState() =>
      _SupplierOrdersScreenState();
}

class _SupplierOrdersScreenState extends ConsumerState<SupplierOrdersScreen> {
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final suppliers = ref.watch(suppliersListProvider).value ?? [];
    final supplierId = (currentUser?.supplierId?.isNotEmpty == true)
        ? currentUser!.supplierId!
        : (suppliers.isNotEmpty ? suppliers.first.id : '');

    final ordersAsync = ref.watch(supplierOrdersProvider(supplierId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات الواردة من الورش'),
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
                    _chip('الكل (${orders.length})', 'all'),
                    const SizedBox(width: 8),
                    for (final st in OrderStatus.values) ...[
                      _chip(
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
                    child: Text('لا توجد طلبات واردة في هذا التصنيف حالياً'),
                  ),
                )
              else
                ...filtered.map(
                  (order) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => context.push(
                        '/dashboard/supplier/orders/${order.id}',
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.glassBlue,
                        child: Icon(Icons.inbox_rounded, color: Colors.white),
                      ),
                      title: Text(
                        '${order.orderNumber} — ${order.workshopName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'الأصناف: ${order.items.length} • الإجمالي: ${order.computedTotal.toStringAsFixed(2)} ${order.currency}',
                      ),
                      trailing: Chip(
                        label: Text(
                          order.status.arabicLabel,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الطلبات: $e')),
      ),
    );
  }

  Widget _chip(String label, String statusKey) {
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
}

