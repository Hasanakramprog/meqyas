import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../data/suppliers_repository.dart';

class SuppliersDirectoryScreen extends ConsumerWidget {
  const SuppliersDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل الموردين المعتمدين'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/auth/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(
              child: Text('لا يوجد موردون مسجلون حالياً'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.amberPrimary.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.amberLight,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (supplier.address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.place_outlined,
                                        size: 14,
                                        color: AppColors.slate400,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          supplier.address,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.slate400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final wa in supplier.allWhatsappNumbers)
                            OutlinedButton.icon(
                              icon: const Icon(
                                Icons.chat_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                              label: Text('تواصل واتساب ($wa)'),
                              onPressed: () => _openWhatsApp(wa, supplier.name),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ في تحميل الموردين: $e')),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone, String supplierName) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = Uri.encodeComponent(
      'السلام عليكم $supplierName، أتواصل معكم عبر تطبيق مقياس للاستفسار عن توريد المواد.',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
