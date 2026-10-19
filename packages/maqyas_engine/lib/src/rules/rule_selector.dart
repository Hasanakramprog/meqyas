import '../ast/evaluator.dart';
import '../models/calculation_result.dart';
import '../models/calculation_rule.dart';
import '../models/unit_specification.dart';

class RuleSelectionResult {
  final CalculationRule? selectedRule;
  final RuleIssue? issue;

  const RuleSelectionResult({this.selectedRule, this.issue});

  bool get hasRule => selectedRule != null;
  bool get hasIssue => issue != null;
}

class RuleSelector {
  final List<CalculationRule> allRules;

  const RuleSelector(this.allRules);

  /// Selects the authoritative rule for a specific itemCode given unit specifications
  RuleSelectionResult selectRule({
    required String itemCode,
    required UnitSpecification spec,
    DateTime? atTime,
  }) {
    final now = atTime ?? DateTime.now();
    final env = spec.toEnvironment();

    // 1. Filter by profile system & itemCode
    final candidateRules = allRules.where((r) {
      return r.profileSystemId == spec.profileSystemId && r.itemCode == itemCode;
    }).toList();

    if (candidateRules.isEmpty) {
      return RuleSelectionResult(
        issue: RuleIssue(
          itemCode: itemCode,
          message: 'No rule defined for item "$itemCode" in system "${spec.profileSystemId}".',
          severity: IssueSeverity.error,
        ),
      );
    }

    // 2. Filter status approved and effectiveAt <= now
    final approvedRules = candidateRules.where((r) {
      return r.status == RuleStatus.approved && r.effectiveAt.isBefore(now.add(const Duration(minutes: 1)));
    }).toList();

    if (approvedRules.isEmpty) {
      return RuleSelectionResult(
        issue: RuleIssue(
          itemCode: itemCode,
          message: 'No approved and active rule available for "$itemCode" (only drafts or archived).',
          severity: IssueSeverity.error,
        ),
      );
    }

    // 3. Filter by unit necessity (e.g. screen rules only if hasScreen is true)
    if (itemCode.startsWith('screen_') && (!spec.hasScreen || spec.screenCount <= 0)) {
      // Item not needed for this unit, return empty without error
      return const RuleSelectionResult();
    }

    // 4. Evaluate conditions for each candidate rule
    final matchingRules = <CalculationRule>[];
    for (final rule in approvedRules) {
      var allConditionsPass = true;
      for (final cond in rule.conditions) {
        try {
          final isTrue = ExpressionEvaluator.evaluateCondition(cond, env);
          if (!isTrue) {
            allConditionsPass = false;
            break;
          }
        } catch (e) {
          allConditionsPass = false;
          break;
        }
      }
      if (allConditionsPass) {
        matchingRules.add(rule);
      }
    }

    if (matchingRules.isEmpty) {
      return RuleSelectionResult(
        issue: RuleIssue(
          itemCode: itemCode,
          message: 'No matching rule conditions satisfied for "$itemCode" (Dimensions: ${spec.widthCm}x${spec.heightCm}, System: ${spec.profileSystemId}). Rule missing - never guess.',
          severity: IssueSeverity.error,
        ),
      );
    }

    // 5. Group by version/priority to select latest / highest priority
    matchingRules.sort((a, b) {
      if (b.priority != a.priority) {
        return b.priority.compareTo(a.priority); // highest priority first
      }
      return b.version.compareTo(a.version); // latest version first
    });

    final topRule = matchingRules.first;

    // Check for equal-priority, equal-version conflict
    final conflicts = matchingRules.where((r) => r.priority == topRule.priority && r.version == topRule.version && r.id != topRule.id).toList();
    if (conflicts.isNotEmpty) {
      return RuleSelectionResult(
        issue: RuleIssue(
          itemCode: itemCode,
          message: 'Conflict: Multiple approved rules have equal priority (${topRule.priority}) and version (${topRule.version}) for item "$itemCode".',
          severity: IssueSeverity.error,
        ),
      );
    }

    return RuleSelectionResult(selectedRule: topRule);
  }
}
