import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../pricing/data/pricing_repository.dart';
import '../../pricing/domain/item_price.dart';
import '../../suppliers/data/suppliers_repository.dart';

class SupplierPricesScreen extends ConsumerStatefulWidget {
  const SupplierPricesScreen({super.key});

  @override
  ConsumerState<SupplierPricesScreen> createState() =>
      _SupplierPricesScreenState();
}

class _SupplierPricesScreenState extends ConsumerState<SupplierPricesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final suppliers = ref.watch(suppliersListProvider).value ?? [];
    final supplierId = (currentUser?.supplierId?.isNotEmpty == true)
        ? currentUser!.supplierId!
        : (suppliers.isNotEmpty ? suppliers.first.id : '');

    final catalogAsync = ref.watch(activeCatalogItemsProvider);
    final pricesMap = ref.watch(supplierPricesProvider(supplierId)).value ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('قائمة أسعار المورد وسجل الأسعار')),
      body: catalogAsync.when(
        data: (items) {
          final filtered = items.where((item) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return item.arabicName.toLowerCase().contains(q) ||
                item.code.toLowerCase().contains(q);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث عن صنف لتعديل سعره...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
              const SizedBox(height: 16),
              ...filtered.map((item) {
                final priceObj = pricesMap[item.id];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      item.arabicName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'الكود: ${item.code} • الوحدة: ${CatalogUnit.arabicLabel(item.unit)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priceObj != null
                                ? AppColors.success.withValues(alpha: 0.14)
                                : AppColors.slate700.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            priceObj != null
                                ? '${priceObj.price.toStringAsFixed(2)} ${priceObj.currency}'
                                : 'غير مسعّر',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: priceObj != null
                                  ? AppColors.success
                                  : AppColors.slate400,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'سجل تاريخ الأسعار',
                          icon: const Icon(Icons.history_rounded, size: 18),
                          onPressed: () => _showPriceHistoryDialog(
                            context,
                            supplierId,
                            item,
                          ),
                        ),
                        IconButton(
                          tooltip: 'تعديل السعر',
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.amberPrimary,
                          ),
                          onPressed: () => _showEditPriceDialog(
                            context,
                            supplierId,
                            item,
                            priceObj,
                            currentUser?.uid,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الكتالوج: $e')),
      ),
    );
  }

  Future<void> _showEditPriceDialog(
    BuildContext context,
    String supplierId,
    CatalogItem item,
    ItemPrice? currentPrice,
    String? actorUid,
  ) async {
    final priceCtrl = TextEditingController(
      text: currentPrice != null ? currentPrice.price.toString() : '',
    );
    final currencyCtrl = TextEditingController(
      text: currentPrice?.currency ?? 'SAR',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسعير: ${item.arabicName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'وحدة البيع المعتمدة: ${CatalogUnit.arabicLabel(item.unit)}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate400),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'السعر للوحدة *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currencyCtrl,
              decoration: const InputDecoration(
                labelText: 'العملة',
                hintText: 'SAR',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final priceVal = double.tryParse(priceCtrl.text.trim());
              if (priceVal == null || priceVal < 0) return;

              await ref
                  .read(pricingRepositoryProvider)
                  .saveItemPrice(
                    supplierId: supplierId,
                    itemId: item.id,
                    price: priceVal,
                    currency: currencyCtrl.text.trim().isNotEmpty
                        ? currencyCtrl.text.trim()
                        : 'SAR',
                    actorUid: actorUid,
                  );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('حفظ السعر'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPriceHistoryDialog(
    BuildContext context,
    String supplierId,
    CatalogItem item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سجل أسعار: ${item.arabicName}'),
        content: SizedBox(
          width: 420,
          child: StreamBuilder<List<PriceHistoryEntry>>(
            stream: ref
                .read(pricingRepositoryProvider)
                .watchPriceHistory(supplierId: supplierId, itemId: item.id),
            builder: (context, snap) {
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('لا يوجد سجل تغييرات سابق لهذا الصنف'),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: list.map((h) {
                    final dt = h.recordedAt != null
                        ? intl.DateFormat('yyyy-MM-dd HH:mm')
                              .format(h.recordedAt!)
                        : '';
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.price_change_outlined,
                        color: AppColors.amberPrimary,
                      ),
                      title: Text(
                        '${h.price.toStringAsFixed(2)} ${h.currency}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('التاريخ: $dt'),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
