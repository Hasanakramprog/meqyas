import '../engine/calculator_engine.dart';
import '../models/calculation_result.dart';
import '../models/calculation_rule.dart';
import '../models/unit_specification.dart';

class RuleSandboxResult {
  final CalculationResult baselineResult;
  final CalculationResult sandboxResult;
  final CutPiece? baselinePiece;
  final CutPiece? sandboxPiece;
  final double? lengthDiffCm;
  final int? quantityDiff;
  final bool hasDiff;
  final String summaryMessage;

  const RuleSandboxResult({
    required this.baselineResult,
    required this.sandboxResult,
    this.baselinePiece,
    this.sandboxPiece,
    this.lengthDiffCm,
    this.quantityDiff,
    required this.hasDiff,
    required this.summaryMessage,
  });
}

class RuleSandbox {
  /// Evaluates a candidate rule against approved rules for a test unit and produces a full diff
  static RuleSandboxResult testDraftRule({
    required CalculationRule candidateRule,
    required List<CalculationRule> approvedRules,
    required UnitSpecification testSpec,
  }) {
    // 1. Calculate baseline using approved rules
    final baselineEngine = CalculatorEngine(rules: approvedRules);
    final baselineResult = baselineEngine.calculate(testSpec);

    // 2. Swapping in candidate rule
    // Force candidate rule to be approved status during sandbox execution
    final candidateAsActive = candidateRule.copyWith(status: RuleStatus.approved);
    final sandboxRules = <CalculationRule>[
      ...approvedRules.where((r) => r.id != candidateRule.id && !(r.itemCode == candidateRule.itemCode && r.priority == candidateRule.priority)),
      candidateAsActive,
    ];

    final sandboxEngine = CalculatorEngine(rules: sandboxRules);
    final sandboxResult = sandboxEngine.calculate(testSpec);

    // 3. Find the target piece
    final bPiece = baselineResult.pieces.where((p) => p.itemCode == candidateRule.itemCode).firstOrNull;
    final sPiece = sandboxResult.pieces.where((p) => p.itemCode == candidateRule.itemCode).firstOrNull;

    double? lenDiff;
    int? qtyDiff;
    var hasDiff = false;
    var summary = '';

    if (bPiece != null && sPiece != null) {
      lenDiff = sPiece.lengthCm - bPiece.lengthCm;
      qtyDiff = sPiece.quantity - bPiece.quantity;
      hasDiff = lenDiff.abs() > 0.001 || qtyDiff != 0;

      if (hasDiff) {
        summary = 'تغير طول القطاع من ${bPiece.lengthCm.toStringAsFixed(1)} سم إلى ${sPiece.lengthCm.toStringAsFixed(1)} سم '
            '(${lenDiff >= 0 ? "+" : ""}${lenDiff.toStringAsFixed(1)} سم)';
        if (qtyDiff != 0) {
          summary += '، وتغيرت الكمية من ${bPiece.quantity} إلى ${sPiece.quantity}';
        }
      } else {
        summary = 'لا يوجد اختلاف في قياسات القطاع (${sPiece.lengthCm.toStringAsFixed(1)} سم)';
      }
    } else if (bPiece == null && sPiece != null) {
      hasDiff = true;
      summary = 'تمت إضافة قطاع جديد "${sPiece.nameArabic}" بطول ${sPiece.lengthCm.toStringAsFixed(1)} سم وعدد ${sPiece.quantity}';
    } else if (bPiece != null && sPiece == null) {
      hasDiff = true;
      summary = 'لم يعد القطاع يُحسب في هذه الحالة (الشروط لم تتحقق)';
    } else {
      summary = 'القطاع غير مطلوب في هذه المواصفات';
    }

    return RuleSandboxResult(
      baselineResult: baselineResult,
      sandboxResult: sandboxResult,
      baselinePiece: bPiece,
      sandboxPiece: sPiece,
      lengthDiffCm: lenDiff,
      quantityDiff: qtyDiff,
      hasDiff: hasDiff,
      summaryMessage: summary,
    );
  }
}
