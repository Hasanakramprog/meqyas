import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:test/test.dart';

void main() {
  group('RuleValidator Tests', () {
    test('Valid rule passes validation without errors', () {
      final rule = CalculationRule(
        id: 'rule_test_1',
        itemCode: 'track',
        profileSystemId: 'system_2000_beaded',
        effectiveAt: DateTime(2026, 1, 1),
        nameArabic: 'سكة 2000 بحاجب',
        quantityFormula: '2',
        lengthFormula: 'W - 3',
        conditions: ["unitType == 'window' || unitType == 'facade'"],
      );

      final result = RuleValidator.validate(rule);
      expect(result.isValid, isTrue);
      expect(result.hasErrors, isFalse);
      expect(result.fieldErrors, isEmpty);
    });

    test('Syntax error in formula is caught and reported in Arabic', () {
      final rule = CalculationRule(
        id: 'rule_bad_syntax',
        itemCode: 'track',
        profileSystemId: 'system_2000_beaded',
        effectiveAt: DateTime(2026, 1, 1),
        nameArabic: 'سكة',
        quantityFormula: '2',
        lengthFormula: 'W - * 3', // syntax error
      );

      final result = RuleValidator.validate(rule);
      expect(result.isValid, isFalse);
      expect(result.fieldErrors.containsKey('lengthFormula'), isTrue);
      expect(result.fieldErrors['lengthFormula'], contains('خطأ في صياغة معادلة الطول'));
    });

    test('Unknown variable in formula is caught and reported in Arabic', () {
      final rule = CalculationRule(
        id: 'rule_unknown_var',
        itemCode: 'track',
        profileSystemId: 'system_2000_beaded',
        effectiveAt: DateTime(2026, 1, 1),
        nameArabic: 'سكة',
        quantityFormula: '2',
        lengthFormula: 'W - randomUnknownVar',
      );

      final result = RuleValidator.validate(rule);
      expect(result.isValid, isFalse);
      expect(result.fieldErrors['lengthFormula'], contains('المتغير "randomUnknownVar" غير معرف'));
    });

    test('Circular dependency across system rules is caught', () {
      final ruleA = CalculationRule(
        id: 'rule_A',
        itemCode: 'item_a',
        profileSystemId: 'system_2000_beaded',
        effectiveAt: DateTime(2026, 1, 1),
        nameArabic: 'قطعة أ',
        quantityFormula: '1',
        lengthFormula: 'item_b_len + 5',
        dependsOn: const ['item_b_len'],
      );

      final ruleB = CalculationRule(
        id: 'rule_B',
        itemCode: 'item_b',
        profileSystemId: 'system_2000_beaded',
        effectiveAt: DateTime(2026, 1, 1),
        nameArabic: 'قطعة ب',
        quantityFormula: '1',
        lengthFormula: 'item_a_len + 5',
        dependsOn: const ['item_a_len'],
      );

      final result = RuleValidator.validate(ruleA, systemRules: [ruleB]);
      expect(result.isValid, isFalse);
      expect(result.fieldErrors.containsKey('dependsOn'), isTrue);
      expect(result.fieldErrors['dependsOn'], contains('اعتماد دائري'));
    });
  });

  group('ConflictDetector Tests', () {
    test('Non-conflicting rules pass without conflict', () {
      final ruleWindow = CalculationRule(
        id: 'rule_win',
        itemCode: 'track',
        profileSystemId: 'system_2000_beaded',
        priority: 10,
        effectiveAt: DateTime(2026, 1, 1),
        conditions: ["unitType == 'window'"],
        quantityFormula: '2',
        lengthFormula: 'W - 3',
      );

      final ruleFacade = CalculationRule(
        id: 'rule_fac',
        itemCode: 'track',
        profileSystemId: 'system_2000_beaded',
        priority: 10,
        effectiveAt: DateTime(2026, 1, 1),
        conditions: ["unitType == 'facade'"],
        quantityFormula: '2',
        lengthFormula: 'W - 3.5',
      );

      final result = ConflictDetector.detectConflicts(
        candidateRule: ruleFacade,
        approvedRules: [ruleWindow],
      );

      expect(result.hasConflict, isFalse);
    });

    test('Conflicting rules with same priority and overlapping condition are detected', () {
      final existingRule = CalculationRule(
        id: 'rule_existing',
        itemCode: 'track',
        profileSystemId: 'system_2000_beaded',
        priority: 10,
        effectiveAt: DateTime(2026, 1, 1),
        conditions: ["glazingMode == 'single'"],
        quantityFormula: '2',
        lengthFormula: 'W - 3',
        nameArabic: 'سكة قديمة',
      );

      final candidateRule = CalculationRule(
        id: 'rule_candidate',
        itemCode: 'track',
        profileSystemId: 'system_2000_beaded',
        priority: 10, // same priority!
        effectiveAt: DateTime(2026, 1, 1),
        conditions: ["unitType == 'window'"], // overlaps when unitType=window and glazingMode=single!
        quantityFormula: '2',
        lengthFormula: 'W - 3.5',
        nameArabic: 'سكة جديدة',
      );

      final result = ConflictDetector.detectConflicts(
        candidateRule: candidateRule,
        approvedRules: [existingRule],
      );

      expect(result.hasConflict, isTrue);
      expect(result.conflicts.length, 1);
      expect(result.conflicts.first.message, contains('تضارب مع القاعدة المعتمدة'));
    });
  });

  group('RuleSandbox Tests', () {
    test('Diffs draft rule against baseline accurately', () {
      final approvedRules = SeedRules.getSystem2000BeadedRules();
      const testSpec = UnitSpecification(
        widthCm: 120.0,
        heightCm: 150.0,
        profileSystemId: 'system_2000_beaded',
      );

      // Candidate rule modifies track length from W - 3 (117.0) to W - 3.5 (116.5)
      final draftTrackRule = CalculationRule(
        id: 'rule_2000_track_v2',
        itemCode: 'track',
        profileSystemId: 'system_2000_beaded',
        priority: 10,
        status: RuleStatus.draft,
        version: 2,
        effectiveAt: DateTime(2026, 1, 1),
        conditions: ["unitType == 'window' || unitType == 'facade'"],
        quantityFormula: '2',
        lengthFormula: 'W - 3.5',
        nameArabic: 'سكة 2000 بحاجب (معدلة)',
      );

      final sandboxResult = RuleSandbox.testDraftRule(
        candidateRule: draftTrackRule,
        approvedRules: approvedRules,
        testSpec: testSpec,
      );

      expect(sandboxResult.hasDiff, isTrue);
      expect(sandboxResult.baselinePiece?.lengthCm, 117.0);
      expect(sandboxResult.sandboxPiece?.lengthCm, 116.5);
      expect(sandboxResult.lengthDiffCm, closeTo(-0.5, 0.001));
      expect(sandboxResult.summaryMessage, contains('117.0'));
      expect(sandboxResult.summaryMessage, contains('116.5'));
    });
  });

  group('Dynamic Rules in CalculatorEngine (DoD Requirement)', () {
    test('New item added in rules appears in cutting list and bar layout dynamically', () {
      final baseRules = SeedRules.getSystem2000BeadedRules();

      // Brand new item: interlock / سكينة تراكب
      final newInterlockRule = CalculationRule(
        id: 'rule_2000_interlock_v1',
        itemCode: 'interlock',
        profileSystemId: 'system_2000_beaded',
        status: RuleStatus.approved,
        priority: 10,
        version: 1,
        effectiveAt: DateTime(2026, 1, 1),
        conditions: ["unitType == 'window'"],
        quantityFormula: '2',
        lengthFormula: 'H - 6.0',
        nameArabic: 'سكينة تراكب 2000',
        profileType: 'jamb',
        cutAngleLeft: 90.0,
        cutAngleRight: 90.0,
      );

      final engine = CalculatorEngine(rules: [...baseRules, newInterlockRule]);
      const spec = UnitSpecification(
        widthCm: 120.0,
        heightCm: 150.0,
        profileSystemId: 'system_2000_beaded',
      );

      final result = engine.calculate(spec);
      expect(result.isValid, isTrue);

      final interlockPiece = result.pieces.where((p) => p.itemCode == 'interlock').firstOrNull;
      expect(interlockPiece, isNotNull);
      expect(interlockPiece!.nameArabic, 'سكينة تراكب 2000');
      expect(interlockPiece.lengthCm, 144.0); // 150 - 6
      expect(interlockPiece.quantity, 2);
    });
  });
}
