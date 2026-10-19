import 'package:flutter/material.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';

class BarLayoutView extends StatelessWidget {
  final List<CutPiece> pieces;

  const BarLayoutView({super.key, required this.pieces});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const optimizer = CutOptimizer();
    final optResult = optimizer.optimize(pieces: pieces);

    if (optResult.barPlans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('لا توجد قطع قطاعات لحساب مخطط القضبان', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary KPI Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildKpi(
                    context,
                    title: 'القضبان المطلوبة (660 سم)',
                    value: '${optResult.summary.totalBarsNeeded} قضبان',
                    color: AppColors.amberPrimary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpi(
                    context,
                    title: 'نسبة الهدر الكلي',
                    value: '${optResult.summary.scrapPercentage.toStringAsFixed(1)}%',
                    color: optResult.summary.scrapPercentage < 5 ? AppColors.success : AppColors.error,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpi(
                    context,
                    title: 'فضلات صالحة (≥50سم)',
                    value: '${optResult.summary.totalReusableRemnantsCm.toStringAsFixed(0)} سم',
                    color: AppColors.remnant,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Visual Bars List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: optResult.barPlans.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final bar = optResult.barPlans[index];
            return _buildBarCard(context, bar, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildKpi(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: isDark ? AppColors.slate400 : AppColors.slate600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarCard(BuildContext context, BarCuttingPlan bar, bool isDark) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bar Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.amberPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'قضيب رقم #${bar.barNumber}',
                        style: const TextStyle(
                          color: AppColors.amberLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'قطاع: ${bar.itemCode}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  'المتبقي: ${bar.remainingLengthCm.toStringAsFixed(1)} سم ${bar.isRemnantUseful ? "(فضلة صالحة)" : "(سكراب)"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bar.isRemnantUseful ? AppColors.success : AppColors.slate400,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Visual Bar Diagram
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Row(
                  children: [
                    // Cut pieces
                    ...bar.cuts.map((cut) {
                      final flex = (cut.lengthCm * 10).toInt();
                      return Expanded(
                        flex: flex > 0 ? flex : 1,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          color: AppColors.glassBlue.withValues(alpha: isDark ? 0.7 : 0.8),
                          alignment: Alignment.center,
                          child: Text(
                            '${cut.lengthCm.toInt()} سم',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),

                    // Leftover Remnant / Waste
                    if (bar.remainingLengthCm > 0)
                      Expanded(
                        flex: (bar.remainingLengthCm * 10).toInt(),
                        child: Container(
                          color: bar.isRemnantUseful
                              ? AppColors.success.withValues(alpha: 0.35)
                              : Colors.red.withValues(alpha: 0.2),
                          alignment: Alignment.center,
                          child: Text(
                            '${bar.remainingLengthCm.toInt()} سم',
                            style: TextStyle(
                              color: bar.isRemnantUseful ? AppColors.success : AppColors.slate400,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
