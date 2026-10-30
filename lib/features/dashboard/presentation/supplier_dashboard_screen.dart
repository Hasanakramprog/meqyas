import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';

class SupplierDashboardScreen extends StatelessWidget {
  const SupplierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بوابة المورد'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.glassBlue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: AppColors.glassBlueLight, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'شركة التوريدات الوطنية للألمنيوم والملحقات',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الطلبات الواردة • تسعير الأصناف • إدارة المخزون والأرصدة',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.slate400 : AppColors.slate600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('إدارة التوريد والمبيعات', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _buildSupplierGrid(context, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierGrid(BuildContext context, bool isDark) {
    final items = [
      {
        'title': 'الطلبات الواردة',
        'desc': 'مراجعة طلبات الورش وتأكيد الاستلام وخصم المخزون',
        'icon': Icons.inbox_rounded,
        'color': AppColors.glassBlue,
        'route': '/dashboard/supplier/orders',
      },
      {
        'title': 'قائمة الأسعار',
        'desc': 'تعديل أسعار المقاطع والزجاج والإكسسوارات وسجل الأسعار',
        'icon': Icons.price_change_outlined,
        'color': AppColors.amberPrimary,
        'route': '/dashboard/supplier/prices',
      },
      {
        'title': 'المستودع والمخزون',
        'desc': 'أرصدة القضبان واللفات وتغذية المخزون وسجل الحركات',
        'icon': Icons.inventory_2_outlined,
        'color': AppColors.success,
        'route': '/dashboard/supplier/stock',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 440,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final color = item['color'] as Color;
        final route = item['route'] as String;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(route),
            child: Padding(
              padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item['icon'] as IconData, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['title'] as String,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['desc'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.slate400 : AppColors.slate600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
