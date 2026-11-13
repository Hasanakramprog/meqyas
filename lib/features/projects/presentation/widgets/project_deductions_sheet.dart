import 'package:flutter/material.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/rules/domain/locked_formula.dart';

/// Modal bottom sheet for editing or resetting formula deductions ("تعديل التخسيمات / استرجاع الافتراضي")
/// at either the Project level or the Individual Item level.
class ProjectDeductionsSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<CalculationRule> baseRules;
  final Map<String, Map<String, String>> currentOverrides;
  final Future<void> Function(Map<String, Map<String, String>> newOverrides)
      onSave;

  const ProjectDeductionsSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.baseRules,
    required this.currentOverrides,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<CalculationRule> baseRules,
    required Map<String, Map<String, String>> currentOverrides,
    required Future<void> Function(Map<String, Map<String, String>> newOverrides)
        onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProjectDeductionsSheet(
        title: title,
        subtitle: subtitle,
        baseRules: baseRules,
        currentOverrides: currentOverrides,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ProjectDeductionsSheet> createState() => _ProjectDeductionsSheetState();
}

class _ProjectDeductionsSheetState extends State<ProjectDeductionsSheet> {
  late Map<String, Map<String, String>> _workingOverrides;
  final Map<String, List<TextEditingController>> _controllersByRuleKey = {};
  final Map<String, String?> _errorsByRuleKey = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _workingOverrides = {
      for (final e in widget.currentOverrides.entries)
        e.key: Map<String, String>.from(e.value),
    };
    _initControllers();
  }

  void _initControllers() {
    for (final cList in _controllersByRuleKey.values) {
      for (final c in cList) {
        c.dispose();
      }
    }
    _controllersByRuleKey.clear();
    _errorsByRuleKey.clear();

    for (final rule in widget.baseRules) {
      final baseLocked = LockedFormula.parse(rule.lengthFormula);
      final overrideFormula =
          _workingOverrides[rule.ruleKey]?['lengthFormula'] ??
              rule.lengthFormula;
      final currentLocked = LockedFormula.parse(overrideFormula);
      final useCurrent = currentLocked.hasSameStructureAs(baseLocked);
      final activeSegments =
          useCurrent ? currentLocked.numberSegments : baseLocked.numberSegments;

      _controllersByRuleKey[rule.ruleKey] = activeSegments
          .map((seg) => TextEditingController(text: seg.text))
          .toList();
    }
  }

  @override
  void dispose() {
    for (final cList in _controllersByRuleKey.values) {
      for (final c in cList) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _onRuleNumberChanged(CalculationRule rule) {
    final baseLocked = LockedFormula.parse(rule.lengthFormula);
    final ctrls = _controllersByRuleKey[rule.ruleKey] ?? const [];
    final baseNums = baseLocked.numbers;

    String? firstError;
    final values = <String>[];
    for (var i = 0; i < ctrls.length; i++) {
      final text = ctrls[i].text.trim();
      values.add(text);
      if (i < baseNums.length) {
        final bounds = NumberBounds.around(baseNums[i]);
        if (!bounds.isLocked) {
          final err = bounds.validate(text);
          if (err != null && firstError == null) {
            firstError = err;
          }
        }
      }
    }

    setState(() {
      _errorsByRuleKey[rule.ruleKey] = firstError;
      if (firstError == null && values.length == baseLocked.numberCount) {
        final rebuilt = baseLocked.rebuild(values);
        if (rebuilt.replaceAll(' ', '') ==
            rule.lengthFormula.replaceAll(' ', '')) {
          _workingOverrides.remove(rule.ruleKey);
        } else {
          _workingOverrides[rule.ruleKey] = {
            'lengthFormula': rebuilt,
            'quantityFormula': rule.quantityFormula,
          };
        }
      }
    });
  }

  void _resetSingleRule(CalculationRule rule) {
    final baseLocked = LockedFormula.parse(rule.lengthFormula);
    final ctrls = _controllersByRuleKey[rule.ruleKey] ?? const [];
    final baseSegs = baseLocked.numberSegments;
    for (var i = 0; i < ctrls.length && i < baseSegs.length; i++) {
      ctrls[i].text = baseSegs[i].text;
    }
    setState(() {
      _workingOverrides.remove(rule.ruleKey);
      _errorsByRuleKey.remove(rule.ruleKey);
    });
  }

  void _resetAllRules() {
    setState(() {
      _workingOverrides.clear();
      _initControllers();
    });
  }

  Future<void> _handleSave() async {
    final hasError = _errorsByRuleKey.values.any((e) => e != null);
    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تصحيح القيم الخارجة عن النطاق المسموح قبل الحفظ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(_workingOverrides);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final editableRules = widget.baseRules
        .where((r) => LockedFormula.parse(r.lengthFormula).numberCount > 0)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.amberPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_workingOverrides.isNotEmpty)
                  TextButton.icon(
                    onPressed: _isSaving ? null : _resetAllRules,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('استرجاع الكل للافتراضي'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.slate400 : AppColors.slate600,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: editableRules.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rule = editableRules[index];
                  final baseLocked = LockedFormula.parse(rule.lengthFormula);
                  final ctrls =
                      _controllersByRuleKey[rule.ruleKey] ?? const [];
                  final isOverridden =
                      _workingOverrides.containsKey(rule.ruleKey);
                  final errorText = _errorsByRuleKey[rule.ruleKey];
                  var numIdx = 0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOverridden
                            ? AppColors.amberPrimary
                            : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                        width: isOverridden ? 1.4 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rule.nameArabic,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isOverridden
                                    ? AppColors.amberPrimary
                                        .withValues(alpha: 0.15)
                                    : AppColors.slate400
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOverridden ? 'مخصص ✎' : 'افتراضي',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isOverridden
                                      ? AppColors.amberPrimary
                                      : AppColors.slate400,
                                ),
                              ),
                            ),
                            if (isOverridden) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _resetSingleRule(rule),
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.restore_rounded,
                                        size: 14,
                                        color: AppColors.info,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'استرجاع الافتراضي',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.info,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: baseLocked.segments.map((seg) {
                              if (!seg.isNumber) {
                                return Text(
                                  seg.text,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                );
                              }
                              final idx = numIdx++;
                              if (idx >= ctrls.length) {
                                return Text(seg.text);
                              }
                              return SizedBox(
                                width: 68,
                                child: TextField(
                                  controller: ctrls[idx],
                                  textAlign: TextAlign.center,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (_) => _onRuleNumberChanged(rule),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            errorText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('حفظ التخسيمات'),
              onPressed: _isSaving ? null : _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}

