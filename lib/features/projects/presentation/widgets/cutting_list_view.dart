import 'package:flutter/material.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';

class CuttingListView extends StatelessWidget {
  final CalculationResult result;

  const CuttingListView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!result.isValid) {
      return Card(
        color: AppColors.error.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.error),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    'تعذر حساب القياسات لوجود أخطاء أو قواعد ناقصة:',
                    style: theme.textTheme.titleSmall?.copyWith(color: AppColors.error, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...result.issues.map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• ${i.message}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
                  )),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Glass Fabrication Ticket Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.crop_square_rounded, color: AppColors.glassBlueLight, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'تذكرة تقطيع الزجاج (للمعمل)',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.glassBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        result.glass.glazingMode == 'double' ? 'دبل غلاس (مزدوج)' : 'زجاج مفرد',
                        style: const TextStyle(
                          color: AppColors.glassBlueLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        title: 'أبعاد اللوح الواحد',
                        value: '${result.glass.paneWidthCm.toStringAsFixed(1)} × ${result.glass.paneHeightCm.toStringAsFixed(1)} سم',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        title: 'عدد الألواح',
                        value: '${result.glass.quantity} ألواح',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        title: 'المساحة الإجمالية',
                        value: '${result.glass.totalAreaM2.toStringAsFixed(3)} م²',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        title: 'الوزن التقريبي',
                        value: '${result.glass.weightKg.toStringAsFixed(1)} كغ',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Profiles Table Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten_rounded, color: AppColors.amberPrimary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'جدول قص قطاعات الألمنيوم',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      '${result.pieces.length} قطاعات',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Table
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: result.pieces.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = result.pieces[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nameArabic,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'الرمز: ${p.itemCode} • الزوايا: ${p.cutAngleLeft.toInt()}° / ${p.cutAngleRight.toInt()}°',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${p.lengthCm.toStringAsFixed(2)} سم',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.amberPrimary,
                                ),
                              ),
                              Text(
                                'الكمية: ${p.quantity} قطع',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.slate400 : AppColors.slate600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
