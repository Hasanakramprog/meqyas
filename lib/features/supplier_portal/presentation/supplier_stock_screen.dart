import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../suppliers/data/suppliers_repository.dart';

class SupplierStockScreen extends ConsumerWidget {
  const SupplierStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final suppliers = ref.watch(suppliersListProvider).value ?? [];
    final supplierId = (currentUser?.supplierId?.isNotEmpty == true)
        ? currentUser!.supplierId!
        : (suppliers.isNotEmpty ? suppliers.first.id : '');

    final catalogAsync = ref.watch(activeCatalogItemsProvider);
    final stockMap = ref.watch(supplierStockProvider(supplierId)).value ?? {};
    final movements =
        ref.watch(supplierMovementsProvider(supplierId)).value ?? [];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المستودع والأرصدة وحركات المخزون'),
          bottom: const TabBar(
            indicatorColor: AppColors.amberPrimary,
            labelColor: AppColors.amberPrimary,
            tabs: [
              Tab(text: 'الأرصدة الحالية وتغذية المخزون'),
              Tab(text: 'سجل الحركات (Inventory Movements)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Current Balances
            catalogAsync.when(
              data: (items) {
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final stock = stockMap[item.id];
                    final balance = stock?.balance ?? 0.0;
                    final isLow = balance <= 10.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLow
                              ? AppColors.error.withValues(alpha: 0.14)
                              : AppColors.success.withValues(alpha: 0.14),
                          child: Icon(
                            isLow
                                ? Icons.warning_amber_rounded
                                : Icons.inventory_2_outlined,
                            color: isLow ? AppColors.error : AppColors.success,
                          ),
                        ),
                        title: Text(
                          item.arabicName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'الكود: ${item.code} • الرصيد المتوفر: ${balance.toInt()} ${CatalogUnit.arabicLabel(item.unit)}',
                        ),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.add_box_outlined, size: 16),
                          label: const Text('تغذية / تسوية'),
                          onPressed: () => _showAdjustStockDialog(
                            context,
                            ref,
                            supplierId,
                            item,
                            balance,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),

            // Tab 2: Inventory Movements
            movements.isEmpty
                ? const Center(
                    child: Text('لا توجد حركات مخزون مسجلة حتى الآن'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: movements.length,
                    itemBuilder: (context, index) {
                      final m = movements[index];
                      final isDeduction = m.movementType == 'deduction';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(
                            isDeduction
                                ? Icons.remove_circle_outline_rounded
                                : Icons.add_circle_outline_rounded,
                            color: isDeduction
                                ? AppColors.error
                                : AppColors.success,
                          ),
                          title: Text(
                            '${m.nameArabic.isNotEmpty ? m.nameArabic : m.itemId} (${m.movementTypeArabic})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'الكمية: ${m.qty} ${CatalogUnit.arabicLabel(m.unit)}'
                            '${m.balanceBefore != null && m.balanceAfter != null ? " • الرصيد: ${m.balanceBefore!.toInt()} ← ${m.balanceAfter!.toInt()}" : ""}'
                            '${m.orderId != null ? " • طلب: ${m.orderId}" : ""}',
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdjustStockDialog(
    BuildContext context,
    WidgetRef ref,
    String supplierId,
    CatalogItem item,
    double currentBalance,
  ) async {
    final qtyCtrl = TextEditingController(text: '50');
    final reasonCtrl = TextEditingController(text: 'توريد دفعة جديدة للمستودع');
    var movementType = 'restock';
    var isSaving = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('تعديل مخزون: ${item.arabicName}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الرصيد الحالي: ${currentBalance.toInt()} ${CatalogUnit.arabicLabel(item.unit)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: movementType,
                  decoration: const InputDecoration(
                    labelText: 'نوع العملية',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'restock',
                      child: Text('تغذية مستودع (إضافة رصيد +)'),
                    ),
                    DropdownMenuItem(
                      value: 'adjustment',
                      child: Text('تسوية جردية (+ أو -)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => movementType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        'الكمية (${CatalogUnit.arabicLabel(item.unit)}) *',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'السبب / البيان',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMsg!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final qty = double.tryParse(qtyCtrl.text.trim());
                      if (qty == null || qty == 0) {
                        setDialogState(
                          () => errorMsg = 'يرجى إدخال كمية غير صفرية',
                        );
                        return;
                      }
                      setDialogState(() {
                        isSaving = true;
                        errorMsg = null;
                      });
                      try {
                        await ref
                            .read(inventoryRepositoryProvider)
                            .adjustStock(
                              supplierId: supplierId,
                              itemId: item.id,
                              nameArabic: item.arabicName,
                              qty: qty,
                              unit: item.unit,
                              movementType: movementType,
                              reason: reasonCtrl.text.trim(),
                            );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم تحديث الرصيد عبر الخادم وتسجيل الحركة بنجاح',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          errorMsg = '$e';
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تنفيذ عبر الخادم'),
            ),
          ],
        ),
      ),
    );
  }
}

