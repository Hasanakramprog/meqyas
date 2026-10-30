import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_model.dart';
import '../../pricing/data/pricing_repository.dart';
import '../../rules/data/rules_repository.dart';
import '../../suppliers/data/suppliers_repository.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/cart_repository.dart';
import '../domain/cart_item.dart';

class CartScreen extends ConsumerStatefulWidget {
  final String? initialWorkshopId;

  const CartScreen({super.key, this.initialWorkshopId});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  String? _selectedSupplierId;
  final TextEditingController _orderNotesCtrl = TextEditingController();
  bool _isCreatingOrder = false;

  @override
  void dispose() {
    _orderNotesCtrl.dispose();
    super.dispose();
  }

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

    final activeWorkshop = workshops.firstWhere(
      (w) => w.id == workshopId,
      orElse: () => WorkshopInfo(
        id: workshopId,
        name: 'ورشة العمل',
        location: '',
        phone: currentUser?.phone ?? '',
      ),
    );

    final cartAsync = ref.watch(workshopCartProvider(workshopId));
    final suppliers = ref.watch(suppliersListProvider).value ?? [];
    final catalogItems = ref.watch(activeCatalogItemsProvider).value ?? [];

    final effectiveSupplierId = (_selectedSupplierId != null &&
            suppliers.any((s) => s.id == _selectedSupplierId))
        ? _selectedSupplierId!
        : (suppliers.isNotEmpty ? suppliers.first.id : '');

    final selectedSupplier = suppliers.firstWhere(
      (s) => s.id == effectiveSupplierId,
      orElse: () => const Supplier(id: '', name: 'مورد غير محدد'),
    );

    final supplierPrices =
        ref.watch(supplierPricesProvider(effectiveSupplierId)).value ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة احتياجات المواد والتوريد'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('طلباتي'),
            onPressed: () => context.push(
              '/dashboard/owner/orders?workshopId=$workshopId',
            ),
          ),
          IconButton(
            tooltip: 'إضافة صنف للسلة يدوياً',
            icon: const Icon(
              Icons.add_shopping_cart_rounded,
              color: AppColors.amberPrimary,
            ),
            onPressed: () => _showAddManualItemDialog(
              context,
              workshopId,
              catalogItems,
              effectiveSupplierId,
            ),
          ),
        ],
      ),
      body: cartAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: AppColors.slate400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'سلة الاحتياجات فارغة حالياً',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يمكنك تجميع قضبان الألمنيوم والزجاج والإكسسوارات تلقائياً من صفحة المشروع أو خطة التقطيع، أو إضافة أصناف يدوياً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.slate400),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إضافة صنف من الكتالوج'),
                          onPressed: () => _showAddManualItemDialog(
                            context,
                            workshopId,
                            catalogItems,
                            effectiveSupplierId,
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('عرض الطلبات السابقة'),
                          onPressed: () => context.push(
                            '/dashboard/owner/orders?workshopId=$workshopId',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          var estimatedTotal = 0.0;
          for (final item in items) {
            final price =
                supplierPrices[item.itemId]?.price ?? item.unitPrice;
            estimatedTotal += item.qty * price;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Non-deduction policy banner (Spec §11 & §15)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.glassBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.glassBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.glassBlueLight,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ملاحظة: معاينة السلة أو حفظ مسودة أو تصدير PDF أو الإرسال عبر واتساب لا يخصم من مخزون المورد إطلاقاً. الخصم يتم فقط عند تأكيد الطلب الرسمي.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Supplier Selector Card
              if (suppliers.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'المورد المستهدف لإصدار أمر الشراء:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: effectiveSupplierId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                            isDense: true,
                          ),
                          items: suppliers
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSupplierId = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // Cart Items Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    'البنود المجمعة في السلة (${items.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: AppColors.error,
                      size: 18,
                    ),
                    label: const Text(
                      'إفراغ السلة',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onPressed: () async {
                      await ref
                          .read(cartRepositoryProvider)
                          .clearCartItems(workshopId);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items List
              ...items.map((item) {
                final priceObj = supplierPrices[item.itemId];
                final effectivePrice = priceObj?.price ?? item.unitPrice;
                final lineTotal = effectivePrice * item.qty;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nameArabic,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'الوحدة: ${CatalogUnit.arabicLabel(item.unit)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate400,
                                        ),
                                      ),
                                      if (item.sourceProjectName.isNotEmpty)
                                        Text(
                                          '• المشروع: ${item.sourceProjectName}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.amberPrimary,
                                          ),
                                        ),
                                      if (effectivePrice > 0)
                                        Text(
                                          '• السعر: ${effectivePrice.toStringAsFixed(2)} SAR (الإجمالي: ${lineTotal.toStringAsFixed(2)} SAR)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.success,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (item.note.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'ملاحظة: ${item.note}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.slate400,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'تعديل الكمية أو الملاحظة',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showEditCartItemDialog(
                                context,
                                workshopId,
                                item,
                              ),
                            ),
                            IconButton(
                              tooltip: 'حذف من السلة',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              onPressed: () => ref
                                  .read(cartRepositoryProvider)
                                  .deleteCartItem(workshopId, item.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: item.qty > 1
                                  ? () => ref
                                      .read(cartRepositoryProvider)
                                      .saveCartItem(
                                        workshopId,
                                        item.copyWith(qty: item.qty - 1),
                                      )
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amberPrimary.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.qty == item.qty.roundToDouble()
                                    ? '${item.qty.toInt()} ${CatalogUnit.arabicLabel(item.unit)}'
                                    : '${item.qty.toStringAsFixed(2)} ${CatalogUnit.arabicLabel(item.unit)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => ref
                                  .read(cartRepositoryProvider)
                                  .saveCartItem(
                                    workshopId,
                                    item.copyWith(qty: item.qty + 1),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              TextField(
                controller: _orderNotesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات عامة على الطلب للمورد (اختياري)',
                  hintText: 'مثال: يرجى التوريد صباح الغد مع مراعاة التغليف...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Summary & Checkout Buttons
              Card(
                color: AppColors.amberPrimary.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (estimatedTotal > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'الإجمالي التقديري حسب أسعار المورد: ${estimatedTotal.toStringAsFixed(2)} SAR',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.amberPrimary,
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('حفظ كمسودة طلب (Draft)'),
                            onPressed: _isCreatingOrder
                                ? null
                                : () => _submitOrder(
                                      context: context,
                                      workshop: activeWorkshop,
                                      supplier: selectedSupplier,
                                      cartItems: items,
                                      supplierPrices: supplierPrices,
                                      initialStatus: OrderStatus.draft,
                                      actorUid: ownerUid,
                                    ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.send_rounded),
                            label: const Text(
                              'إصدار أمر التوريد للمورد (متابعة للواتساب / PDF)',
                            ),
                            onPressed: _isCreatingOrder
                                ? null
                                : () => _submitOrder(
                                      context: context,
                                      workshop: activeWorkshop,
                                      supplier: selectedSupplier,
                                      cartItems: items,
                                      supplierPrices: supplierPrices,
                                      initialStatus: OrderStatus.sent,
                                      actorUid: ownerUid,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل السلة: $e')),
      ),
    );
  }

  Future<void> _submitOrder({
    required BuildContext context,
    required WorkshopInfo workshop,
    required Supplier supplier,
    required List<CartItem> cartItems,
    required Map<String, dynamic> supplierPrices,
    required OrderStatus initialStatus,
    required String actorUid,
  }) async {
    if (supplier.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مورد أولاً')),
      );
      return;
    }

    setState(() => _isCreatingOrder = true);
    try {
      final orderItems = cartItems.map((c) {
        final priceObj = supplierPrices[c.itemId];
        final frozenPrice =
            priceObj != null ? (priceObj.price as double) : c.unitPrice;
        return OrderLineItem(
          itemId: c.itemId,
          nameArabic: c.nameArabic,
          qty: c.qty,
          unit: c.unit,
          unitPrice: frozenPrice,
          projectId: c.sourceProjectId,
          projectName: c.sourceProjectName,
          unitId: c.sourceUnitId,
          note: c.note,
        );
      }).toList();

      final orderId = await ref.read(ordersRepositoryProvider).createOrder(
            workshopId: workshop.id,
            workshopName: workshop.name,
            workshopPhone: workshop.phone,
            workshopLocation: workshop.location,
            supplierId: supplier.id,
            supplierName: supplier.name,
            items: orderItems,
            notes: _orderNotesCtrl.text.trim(),
            initialStatus: initialStatus,
            actorUid: actorUid,
          );

      // Clear ordered items from cart
      await ref.read(cartRepositoryProvider).clearCartItems(
            workshop.id,
            itemIdsToDelete: cartItems.map((e) => e.id).toList(),
          );

      if (context.mounted) {
        context.push(
          '/dashboard/owner/orders/$orderId?workshopId=${workshop.id}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء الطلب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }

  Future<void> _showEditCartItemDialog(
    BuildContext context,
    String workshopId,
    CartItem item,
  ) async {
    final qtyCtrl = TextEditingController(text: item.qty.toString());
    final noteCtrl = TextEditingController(text: item.note);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل: ${item.nameArabic}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'الكمية (${CatalogUnit.arabicLabel(item.unit)})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظة على السطر',
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
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? item.qty;
              if (qty <= 0) return;
              await ref.read(cartRepositoryProvider).saveCartItem(
                    workshopId,
                    item.copyWith(qty: qty, note: noteCtrl.text.trim()),
                  );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddManualItemDialog(
    BuildContext context,
    String workshopId,
    List<CatalogItem> catalogItems,
    String defaultSupplierId,
  ) async {
    if (catalogItems.isEmpty) return;
    var selectedItem = catalogItems.first;
    final qtyCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة صنف للسلة من الكتالوج'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedItem.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الصنف',
                    border: OutlineInputBorder(),
                  ),
                  items: catalogItems
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.arabicName} (${c.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedItem =
                            catalogItems.firstWhere((c) => c.id == val);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        'الكمية (${CatalogUnit.arabicLabel(selectedItem.unit)})',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                if (qty <= 0) return;
                await ref.read(cartRepositoryProvider).saveCartItem(
                      workshopId,
                      CartItem(
                        id: '',
                        itemId: selectedItem.id,
                        engineItemCode: selectedItem.engineItemCode,
                        nameArabic: selectedItem.arabicName,
                        qty: qty,
                        unit: selectedItem.unit,
                        category: selectedItem.categoryId,
                        note: noteCtrl.text.trim(),
                        suggestedSupplierId: defaultSupplierId,
                      ),
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('إضافة للسلة'),
            ),
          ],
        ),
      ),
    );
  }
}

