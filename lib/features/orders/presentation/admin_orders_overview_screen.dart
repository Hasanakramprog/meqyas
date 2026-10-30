import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../data/orders_repository.dart';

class AdminOrdersOverviewScreen extends ConsumerWidget {
  const AdminOrdersOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allAdminOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مراقبة جميع طلبات التوريد (Admin)'),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text('لا توجد طلبات مسجلة في النظام حتى الآن'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => context.push(
                    '/dashboard/owner/orders/${order.id}?workshopId=${order.workshopId}',
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.amberPrimary,
                    child: Icon(Icons.receipt_long_rounded, color: Colors.black),
                  ),
                  title: Text(
                    '${order.orderNumber} — ${order.workshopName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'المورد: ${order.supplierName} • الأصناف: ${order.items.length} • الإجمالي: ${order.computedTotal.toStringAsFixed(2)} ${order.currency}',
                  ),
                  trailing: Chip(
                    label: Text(
                      order.status.arabicLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الطلبات: $e')),
      ),
    );
  }
}
