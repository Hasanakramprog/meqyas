import 'package:flutter/material.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../../../app/theme/app_colors.dart';

class CutSummaryCard extends StatelessWidget {
  final OptimizationSummary summary;
  final bool isDark;
  final VoidCallback onRefresh;

  const CutSummaryCard({
    super.key,
    required this.summary,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final usedRemnants = summary.remnantsReused > 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: usedRemnants
              ? [
                  AppColors.success.withValues(alpha: 0.15),
                  AppColors.amberPrimary.withValues(alpha: 0.1),
                ]
              : [
                  AppColors.amberPrimary.withValues(alpha: 0.12),
                  AppColors.amberPrimary.withValues(alpha: 0.06),
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: usedRemnants
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.amberPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(
                usedRemnants
                    ? Icons.recycling_rounded
                    : Icons.cut_rounded,
                color: usedRemnants ? AppColors.success : AppColors.amberPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ملخص خطة القص',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.slate800,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'إعادة الحساب',
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _Stat(
                icon: Icons.view_column_rounded,
                label: 'قضبان جديدة',
                value: '${summary.totalBarsNeeded}',
                color: AppColors.amberPrimary,
                isDark: isDark,
              ),
              if (usedRemnants) ...[
                const SizedBox(width: 8),
                _Stat(
                  icon: Icons.layers_rounded,
                  label: 'فضلات مُعاد استخدامها',
                  value: '${summary.remnantsReused}',
                  color: AppColors.success,
                  isDark: isDark,
                ),
              ],
              const SizedBox(width: 8),
              _Stat(
                icon: Icons.delete_outline_rounded,
                label: 'نسبة الهدر',
                value:
                    '${summary.scrapPercentage.toStringAsFixed(1)}%',
                color: summary.scrapPercentage > 15
                    ? AppColors.error
                    : AppColors.warning,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _Stat(
                icon: Icons.recycling_rounded,
                label: 'فضلات جديدة',
                value:
                    '${summary.totalReusableRemnantsCm.toStringAsFixed(0)} سم',
                color: AppColors.warning,
                isDark: isDark,
              ),
            ],
          ),

          // Savings banner
          if (usedRemnants) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'وُفِّر ≈ ${summary.barsSavedByRemnants.toStringAsFixed(1)} قضيب بفضل الفضلات المخزنة',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: isDark ? AppColors.slate400 : AppColors.slate500)),
          ],
        ),
      ),
    );
  }
}
