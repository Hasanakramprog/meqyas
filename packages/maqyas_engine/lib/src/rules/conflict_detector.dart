import '../ast/evaluator.dart';
import '../models/calculation_rule.dart';
import '../models/unit_specification.dart';

class RuleConflict {
  final CalculationRule candidateRule;
  final CalculationRule existingRule;
  final UnitSpecification exampleCase;
  final String message;

  const RuleConflict({
    required this.candidateRule,
    required this.existingRule,
    required this.exampleCase,
    required this.message,
  });
}

class ConflictDetectionResult {
  final bool hasConflict;
  final List<RuleConflict> conflicts;

  const ConflictDetectionResult({
    required this.hasConflict,
    this.conflicts = const [],
  });
}

class ConflictDetector {
  /// Test matrix dimensions and options specified in section 1 of the implementation plan
  static const List<double> testWidths = [40.0, 90.0, 120.0, 129.0, 180.0, 250.0, 400.0];
  static const List<double> testHeights = [40.0, 90.0, 120.0, 150.0, 220.0, 300.0];
  static const List<String> testUnitTypes = ['window', 'facade'];
  static const List<String> testGlazingModes = ['single', 'double'];
  static const List<int> testSashCounts = [2, 3, 4];
  static const List<bool> testScreenOptions = [true, false];
  static const List<String> testSharhOptions = ['none', 'one_side', 'two_sides'];

  /// Detects whether [candidateRule] clashes with any existing rule in [approvedRules].
  /// A conflict happens if another rule has the same system, same itemCode, same priority,
  /// and both conditions match simultaneously for at least one configuration in the test matrix.
  static ConflictDetectionResult detectConflicts({
    required CalculationRule candidateRule,
    required List<CalculationRule> approvedRules,
  }) {
    final sameItemRules = approvedRules.where((r) {
      return r.id != candidateRule.id &&
          r.profileSystemId == candidateRule.profileSystemId &&
          r.itemCode == candidateRule.itemCode &&
          r.priority == candidateRule.priority &&
          r.isApproved;
    }).toList();

    if (sameItemRules.isEmpty) {
      return const ConflictDetectionResult(hasConflict: false);
    }

    final conflicts = <RuleConflict>[];

    for (final existing in sameItemRules) {
      UnitSpecification? conflictingSpec;

      for (final w in testWidths) {
        if (conflictingSpec != null) break;
        for (final h in testHeights) {
          if (conflictingSpec != null) break;
          for (final ut in testUnitTypes) {
            if (conflictingSpec != null) break;
            for (final gm in testGlazingModes) {
              if (conflictingSpec != null) break;
              for (final sc in testSashCounts) {
                if (conflictingSpec != null) break;
                for (final hasScreen in testScreenOptions) {
                  if (conflictingSpec != null) break;
                  for (final sharh in testSharhOptions) {
                    final spec = UnitSpecification(
                      widthCm: w,
                      heightCm: h,
                      unitType: ut,
                      glazingMode: gm,
                      sashCount: sc,
                      hasScreen: hasScreen,
                      screenCount: hasScreen ? 1 : 0,
                      sharhOption: sharh,
                      profileSystemId: candidateRule.profileSystemId,
                    );

                    final env = spec.toEnvironment();
                    final candidateMatches = _evalConditions(candidateRule.conditions, env);
                    final existingMatches = _evalConditions(existing.conditions, env);

                    if (candidateMatches && existingMatches) {
                      conflictingSpec = spec;
                      break;
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (conflictingSpec != null) {
        final caseDesc = '${conflictingSpec.unitType == "window" ? "شباك" : "واجهة"} '
            '(${conflictingSpec.widthCm.toInt()}×${conflictingSpec.heightCm.toInt()}سم، '
            '${conflictingSpec.glazingMode == "single" ? "مفرد" : "مزدوج"}، '
            '${conflictingSpec.sashCount} درف)';

        conflicts.add(
          RuleConflict(
            candidateRule: candidateRule,
            existingRule: existing,
            exampleCase: conflictingSpec,
            message: 'تضارب مع القاعدة المعتمدة "${existing.nameArabic.isNotEmpty ? existing.nameArabic : existing.itemCode}" '
                '(الإصدار v${existing.version}، أولوية ${existing.priority}) في حالة: $caseDesc. '
                'يجب تغيير الأولوية أو تخصيص الشروط لتجنب التداخل.',
          ),
        );
      }
    }

    return ConflictDetectionResult(
      hasConflict: conflicts.isNotEmpty,
      conflicts: conflicts,
    );
  }

  static bool _evalConditions(List<String> conditions, Map<String, dynamic> env) {
    if (conditions.isEmpty) return true;
    for (final c in conditions) {
      final trimmed = c.trim();
      if (trimmed.isEmpty) continue;
      try {
        final pass = ExpressionEvaluator.evaluateCondition(trimmed, env);
        if (!pass) return false;
      } catch (_) {
        return false;
      }
    }
    return true;
  }
}
