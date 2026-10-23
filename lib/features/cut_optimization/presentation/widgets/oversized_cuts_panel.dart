import 'package:flutter/material.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../../../app/theme/app_colors.dart';

class OversizedCutsPanel extends StatelessWidget {
  final List<PlannedCut> cuts;
  final bool isDark;

  const OversizedCutsPanel({
    super.key,
    required this.cuts,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text(
                'قطع تتجاوز طول القضيب (${cuts.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...cuts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${c.nameArabic} — ${c.lengthCm.toStringAsFixed(1)} سم'
                      '${c.unitTag != null ? " (${c.unitTag})" : ""}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'يجب مراجعة هذه القطع مع المورد أو تعديل المقاسات.',
            style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.slate400 : AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
