import 'package:flutter/material.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../../../app/theme/app_colors.dart';

class ItemGroupSection extends StatefulWidget {
  final String itemCode;
  final List<BarCuttingPlan> barPlans;
  final bool isDark;

  const ItemGroupSection({
    super.key,
    required this.itemCode,
    required this.barPlans,
    required this.isDark,
  });

  @override
  State<ItemGroupSection> createState() => _ItemGroupSectionState();
}

class _ItemGroupSectionState extends State<ItemGroupSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final nameArabic = widget.barPlans.isNotEmpty &&
            widget.barPlans.first.cuts.isNotEmpty
        ? widget.barPlans.first.cuts.first.nameArabic
        : widget.itemCode;

    final totalCuts = widget.barPlans
        .fold<int>(0, (sum, b) => sum + b.cuts.length);
    final remnantsInGroup =
        widget.barPlans.where((b) => b.isFromRemnant).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: widget.isDark ? AppColors.darkCard : Colors.white,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.amberPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nameArabic,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Row(
                          children: [
                            Text(
                              '${widget.barPlans.length} قضيب · $totalCuts قطعة',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500),
                            ),
                            if (remnantsInGroup > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$remnantsInGroup من فضلة مخزنة',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),

          // Bar plans
          if (_expanded)
            ...widget.barPlans.map((bar) => _BarPlanCard(
                  bar: bar,
                  isDark: widget.isDark,
                )),
        ],
      ),
    );
  }
}

class _BarPlanCard extends StatelessWidget {
  final BarCuttingPlan bar;
  final bool isDark;

  const _BarPlanCard({required this.bar, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isRemnantSource = bar.isFromRemnant;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isRemnantSource
            ? (isDark
                ? AppColors.success.withValues(alpha: 0.06)
                : AppColors.success.withValues(alpha: 0.04))
            : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRemnantSource
              ? AppColors.success.withValues(alpha: 0.35)
              : (isDark ? AppColors.slate600 : AppColors.slate200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bar header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isRemnantSource
                      ? Icons.layers_rounded
                      : Icons.view_column_rounded,
                  size: 16,
                  color: isRemnantSource
                      ? AppColors.success
                      : AppColors.amberPrimary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: isRemnantSource
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'فضلة مخزنة — ${bar.sourceRemnantLengthCm?.toStringAsFixed(1)} سم',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success),
                            ),
                            if (bar.sourceRemnantProjectName != null)
                              Text(
                                'من مشروع: ${bar.sourceRemnantProjectName}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.slate400
                                        : AppColors.slate500),
                              ),
                          ],
                        )
                      : Text(
                          'قضيب جديد رقم ${bar.barNumber} — ${bar.totalBarLengthCm.toStringAsFixed(0)} سم',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                ),
                // Remaining label
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bar.isRemnantUseful
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.slate300.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'متبقي: ${bar.remainingLengthCm.toStringAsFixed(1)} سم'
                    ' ${bar.isRemnantUseful ? "(فضلة)" : "(هدر)"}',
                    style: TextStyle(
                        fontSize: 10,
                        color: bar.isRemnantUseful
                            ? AppColors.warning
                            : AppColors.slate400),
                  ),
                ),
              ],
            ),
          ),

          // Visual bar
          _VisualBar(bar: bar, isDark: isDark),

          // Cut list
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: bar.cuts.asMap().entries.map((e) {
                final idx = e.key + 1;
                final cut = e.value;
                return Chip(
                  label: Text(
                    '#$idx  ${cut.lengthCm.toStringAsFixed(1)}سم'
                    '${cut.unitTag != null ? " · ${cut.unitTag}" : ""}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: cut.isFromRemnant
                      ? AppColors.success.withValues(alpha: 0.12)
                      : (isDark ? AppColors.slate700 : AppColors.slate100),
                  side: BorderSide(
                    color: cut.isFromRemnant
                        ? AppColors.success.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualBar extends StatelessWidget {
  final BarCuttingPlan bar;
  final bool isDark;

  const _VisualBar({required this.bar, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final usable = bar.totalBarLengthCm - bar.trimLossCm;
    if (usable <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: LayoutBuilder(builder: (_, constraints) {
        final totalWidth = constraints.maxWidth;

        return Container(
          height: 28,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: isDark ? AppColors.slate600 : AppColors.slate300),
          ),
          child: Row(
            children: [
              // Cuts
              ...bar.cuts.map((c) {
                final fraction = (c.lengthCm / usable).clamp(0.0, 1.0);
                return Container(
                  width: totalWidth * fraction,
                  color: c.isFromRemnant
                      ? AppColors.success.withValues(alpha: 0.7)
                      : AppColors.amberPrimary.withValues(alpha: 0.7),
                  alignment: Alignment.center,
                  child: fraction > 0.05
                      ? Text(
                          c.lengthCm.toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                );
              }),
              // Kerf losses
              ...List.generate(bar.cuts.length, (_) {
                final kerfFraction =
                    (bar.kerfPerCutCm / usable).clamp(0.0, 1.0);
                return Container(
                  width: totalWidth * kerfFraction,
                  color: AppColors.slate400.withValues(alpha: 0.4),
                );
              }),
              // Remaining
              if (bar.remainingLengthCm > 0)
                Expanded(
                  child: Container(
                    color: bar.isRemnantUseful
                        ? AppColors.warning.withValues(alpha: 0.3)
                        : AppColors.slate200.withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: Text(
                      '${bar.remainingLengthCm.toStringAsFixed(0)}سم',
                      style: TextStyle(
                          fontSize: 9,
                          color: bar.isRemnantUseful
                              ? AppColors.warning
                              : AppColors.slate400),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
