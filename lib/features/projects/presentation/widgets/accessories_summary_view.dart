import 'package:flutter/material.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';

class AccessoriesSummaryView extends StatelessWidget {
  final List<AccessoryItem> accessories;

  const AccessoriesSummaryView({super.key, required this.accessories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (accessories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('لا توجد ملحقات مسجلة لهذا العنصر', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handyman_rounded, color: AppColors.amberPrimary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'قائمة الإكسسوارات والملحقات المطلوبة',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accessories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final a = accessories[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.amberPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.amberLight),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          a.nameArabic,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Text(
                          '${a.quantity} ${a.unit == "piece" ? "قطعة" : a.unit == "pair" ? "زوج" : a.unit}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.amberPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
