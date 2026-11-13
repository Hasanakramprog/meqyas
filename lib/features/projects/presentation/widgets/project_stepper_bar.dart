import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meqyas/app/theme/app_colors.dart';

/// 4-step project wizard bar matching the target RTL design:
/// 1 · القياسات  →  2 · القصّ  →  3 · مراجعة البضاعة  →  4 · السلة والطلب
class ProjectStepperBar extends StatelessWidget {
  final String projectId;
  final String workshopId;

  /// Active step (1..4)
  final int activeStep;

  /// Optional callback when a step is tapped (overrides default navigation if provided)
  final ValueChanged<int>? onStepTapped;

  const ProjectStepperBar({
    super.key,
    required this.projectId,
    required this.workshopId,
    required this.activeStep,
    this.onStepTapped,
  });

  static const _steps = [
    (step: 1, label: '1 · القياسات'),
    (step: 2, label: '2 · القصّ'),
    (step: 3, label: '3 · مراجعة البضاعة'),
    (step: 4, label: '4 · السلة والطلب'),
  ];

  void _handleTap(BuildContext context, int step) {
    if (onStepTapped != null) {
      onStepTapped!(step);
      return;
    }
    if (step == activeStep) return;

    switch (step) {
      case 1:
        context.go(
          '/dashboard/owner/projects/$projectId?workshopId=$workshopId',
        );
        break;
      case 2:
        context.push(
          '/dashboard/owner/cut-plan?projectId=$projectId&workshopId=$workshopId',
        );
        break;
      case 3:
        context.push(
          '/dashboard/owner/projects/$projectId/requirements?workshopId=$workshopId&step=3',
        );
        break;
      case 4:
        context.push(
          '/dashboard/owner/projects/$projectId/requirements?workshopId=$workshopId&step=4',
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeAccent = Color(0xFF0E5A7A);
    final activeColor = isDark ? AppColors.amberPrimary : activeAccent;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _StepPill(
                  label: _steps[i].label,
                  isActive: _steps[i].step == activeStep,
                  isCompleted: _steps[i].step < activeStep,
                  isDark: isDark,
                  activeColor: activeColor,
                  onTap: () => _handleTap(context, _steps[i].step),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool isDark;
  final Color activeColor;
  final VoidCallback onTap;

  const _StepPill({
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.isDark,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? (isDark
            ? activeColor.withValues(alpha: 0.14)
            : Colors.white)
        : (isDark ? AppColors.darkCard : Colors.white);

    final borderColor = isActive
        ? activeColor
        : (isCompleted
            ? AppColors.success.withValues(alpha: 0.45)
            : (isDark ? AppColors.darkBorder : const Color(0xFFDCE3EC)));

    final textColor = isActive
        ? activeColor
        : (isCompleted
            ? (isDark ? AppColors.slate200 : AppColors.slate700)
            : (isDark ? AppColors.slate400 : const Color(0xFF475569)));

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: isActive ? 1.6 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

