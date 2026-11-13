import 'package:flutter/material.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import '../../domain/models/project.dart';
import 'project_deductions_sheet.dart';

/// General Project Properties section ("الخصائص العامة للمشروع") shown at the top
/// of Step 1 ("1 · القياسات"). Matches the user's reference layout.
class ProjectGeneralPropertiesCard extends StatelessWidget {
  final ProjectDefaults defaults;
  final List<CalculationRule> workshopRules;
  final ValueChanged<ProjectDefaults> onChanged;

  const ProjectGeneralPropertiesCard({
    super.key,
    required this.defaults,
    required this.workshopRules,
    required this.onChanged,
  });

  static const colorOptions = [
    (value: 'white', label: 'أبيض'),
    (value: 'black', label: 'أسود مطفي'),
    (value: 'champagne', label: 'شامبين'),
    (value: 'bronze', label: 'برونز'),
    (value: 'grey', label: 'رمادي (أنتراسيت)'),
    (value: 'wood', label: 'خشبي'),
  ];

  static const glassTypeOptions = [
    (value: 'clear', label: 'شفاف'),
    (value: 'frosted', label: 'مثلج (Frosted)'),
    (value: 'reflective', label: 'عاكس (Reflective)'),
    (value: 'smoked', label: 'مدخن (فيميه)'),
  ];

  static const glassThicknessOptions = [
    (value: 4.0, label: '4 ملم'),
    (value: 6.0, label: '6 ملم'),
    (value: 8.0, label: '8 ملم'),
    (value: 10.0, label: '10 ملم'),
    (value: 18.0, label: '18 ملم (دبل)'),
    (value: 24.0, label: '24 ملم (دبل)'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final labelColor = isDark ? AppColors.slate300 : const Color(0xFF475569);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Card: ألمنيوم الورشة + لون الورشة · الافتراضي للوحدات
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LabeledDropdown<String>(
                    label: 'ألمنيوم الورشة',
                    labelColor: labelColor,
                    value: defaults.glazingMode == 'single' ? 'single' : 'double',
                    items: const [
                      DropdownMenuItem(value: 'double', child: Text('دبل')),
                      DropdownMenuItem(value: 'single', child: Text('عادي (مفرد)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        onChanged(defaults.copyWith(glazingMode: val));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledDropdown<String>(
                    label: 'لون الورشة · الافتراضي للوحدات',
                    labelColor: labelColor,
                    value: colorOptions.any((c) => c.value == defaults.color)
                        ? defaults.color
                        : 'white',
                    items: colorOptions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.value,
                            child: Text(c.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        onChanged(defaults.copyWith(color: val));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Middle Row: تعديل التخسيمات / استرجاع الافتراضي button
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                final systemRules = workshopRules
                    .where((r) => r.profileSystemId == defaults.profileSystemId)
                    .toList();
                final effectiveBase = systemRules.isNotEmpty
                    ? systemRules
                    : SeedRules.getSystem2000BeadedRules();
                ProjectDeductionsSheet.show(
                  context: context,
                  title: 'تعديل التخسيمات / استرجاع الافتراضي (للمشروع)',
                  subtitle:
                      'تطبق هذه التخسيمات تلقائياً على جميع عناصر المشروع ما لم يتم تخصيص عنصر بعينه.',
                  baseRules: effectiveBase,
                  currentOverrides: defaults.ruleOverrides,
                  onSave: (newOverrides) async {
                    onChanged(defaults.copyWith(ruleOverrides: newOverrides));
                  },
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: defaults.hasRuleOverrides
                        ? AppColors.amberPrimary
                        : borderColor,
                    width: defaults.hasRuleOverrides ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'تعديل التخسيمات / استرجاع الافتراضي',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark
                            ? AppColors.slate100
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    if (defaults.hasRuleOverrides) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amberPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'مخصص (${defaults.ruleOverrides.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amberPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Bottom Card: نوع زجاج المشروع · سماكة زجاج المشروع · الزبون يدك كوتشوك الزجاج
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final glassTypeField = _LabeledDropdown<String>(
                  label: 'نوع زجاج المشروع',
                  labelColor: labelColor,
                  value: glassTypeOptions
                          .any((g) => g.value == defaults.glassType)
                      ? defaults.glassType
                      : 'clear',
                  items: glassTypeOptions
                      .map(
                        (g) => DropdownMenuItem(
                          value: g.value,
                          child: Text(g.label),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      onChanged(defaults.copyWith(glassType: val));
                    }
                  },
                );

                final glassThicknessField = _LabeledDropdown<double>(
                  label: 'سماكة زجاج المشروع',
                  labelColor: labelColor,
                  value: glassThicknessOptions
                          .any((t) => t.value == defaults.glassThicknessMm)
                      ? defaults.glassThicknessMm
                      : 6.0,
                  items: glassThicknessOptions
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.value,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      onChanged(defaults.copyWith(glassThicknessMm: val));
                    }
                  },
                );

                final gasketField = _LabeledDropdown<bool>(
                  label: 'الزبون يدك كوتشوك الزجاج',
                  labelColor: labelColor,
                  value: defaults.hasGasket,
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text('لا · لا تضف الكوتشوك للطلبية'),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text('نعم · أضف الكوتشوك للطلبية'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      onChanged(defaults.copyWith(hasGasket: val));
                    }
                  },
                );

                if (constraints.maxWidth >= 560) {
                  return Row(
                    children: [
                      Expanded(child: glassTypeField),
                      const SizedBox(width: 10),
                      Expanded(child: glassThicknessField),
                      const SizedBox(width: 10),
                      Expanded(child: gasketField),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: glassTypeField),
                        const SizedBox(width: 10),
                        Expanded(child: glassThicknessField),
                      ],
                    ),
                    const SizedBox(height: 10),
                    gasketField,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final Color labelColor;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.labelColor,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

