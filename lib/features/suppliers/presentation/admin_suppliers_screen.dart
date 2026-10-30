import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../data/suppliers_repository.dart';
import '../domain/supplier.dart';

class AdminSuppliersScreen extends ConsumerWidget {
  const AdminSuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموردين المعتمدين'),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text(
                    'الموردون المسجلون (${suppliers.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_download_outlined, size: 16),
                        label: const Text('تثبيت الموردين الافتراضيين'),
                        onPressed: () async {
                          final added = await ref
                              .read(suppliersRepositoryProvider)
                              .seedDefaultSuppliersToFirestore();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added > 0
                                      ? 'تم تثبيت $added مورد افتراضي بنجاح'
                                      : 'الموردون الافتراضيون مثبتون مسبقاً',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('إنشاء حساب مورد جديد'),
                        onPressed: () =>
                            _showCreateSupplierAccountDialog(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (suppliers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('لا يوجد موردون مسجلون حالياً'),
                  ),
                )
              else
                ...suppliers.map(
                  (supplier) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.glassBlue.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: AppColors.glassBlueLight,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      supplier.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (supplier.address.isNotEmpty)
                                      Text(
                                        supplier.address,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate400,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'تعديل بيانات المورد',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _showEditSupplierDialog(
                                  context,
                                  ref,
                                  supplier,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              if (supplier.phone.isNotEmpty)
                                Chip(
                                  avatar: const Icon(Icons.phone_rounded, size: 16),
                                  label: Text('هاتف: ${supplier.phone}'),
                                ),
                              for (final wa in supplier.whatsappPhones)
                                Chip(
                                  avatar: const Icon(
                                    Icons.chat_rounded,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  label: Text('واتساب: $wa'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الموردين: $e')),
      ),
    );
  }

  Future<void> _showCreateSupplierAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final whatsappCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    var isSaving = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إنشاء مورد جديد مع حساب دخول'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الشركة / المورد *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني للدخول *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور المبدئية *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف الرئيسي',
                      hintText: '9665XXXXXXXX',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: whatsappCtrl,
                    decoration: const InputDecoration(
                      labelText: 'أرقام واتساب (افصل بينها بفاصلة)',
                      hintText: '966500000001, 966500000002',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'العنوان / المدينة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
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
                      if (nameCtrl.text.trim().isEmpty) {
                        setDialogState(
                          () => errorMsg = 'يرجى إدخال اسم المورد',
                        );
                        return;
                      }
                      setDialogState(() {
                        isSaving = true;
                        errorMsg = null;
                      });
                      final waList = whatsappCtrl.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      try {
                        if (emailCtrl.text.trim().isNotEmpty &&
                            passwordCtrl.text.isNotEmpty) {
                          await ref
                              .read(suppliersRepositoryProvider)
                              .createSupplierAccount(
                                email: emailCtrl.text,
                                password: passwordCtrl.text,
                                name: nameCtrl.text,
                                phone: phoneCtrl.text,
                                whatsappPhones: waList,
                                address: addressCtrl.text,
                              );
                        } else {
                          await ref
                              .read(suppliersRepositoryProvider)
                              .saveSupplier(
                                Supplier(
                                  id: '',
                                  name: nameCtrl.text,
                                  phone: phoneCtrl.text,
                                  whatsappPhones: waList,
                                  address: addressCtrl.text,
                                ),
                              );
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تسجيل المورد بنجاح'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          errorMsg = 'تعذر إنشاء الحساب: $e';
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إنشاء وحفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSupplierDialog(
    BuildContext context,
    WidgetRef ref,
    Supplier supplier,
  ) async {
    final nameCtrl = TextEditingController(text: supplier.name);
    final phoneCtrl = TextEditingController(text: supplier.phone);
    final whatsappCtrl = TextEditingController(
      text: supplier.whatsappPhones.join(', '),
    );
    final addressCtrl = TextEditingController(text: supplier.address);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات المورد'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المورد',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: whatsappCtrl,
                  decoration: const InputDecoration(
                    labelText: 'أرقام واتساب (مفصولة بفاصلة)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final waList = whatsappCtrl.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              await ref.read(suppliersRepositoryProvider).saveSupplier(
                    supplier.copyWith(
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      whatsappPhones: waList,
                      address: addressCtrl.text,
                    ),
                  );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }
}

