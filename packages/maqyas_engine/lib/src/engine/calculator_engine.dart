import '../ast/evaluator.dart';
import '../graph/dependency_graph.dart';
import '../models/calculation_result.dart';
import '../models/calculation_rule.dart';
import '../models/unit_specification.dart';
import '../rules/rule_selector.dart';
import '../rules/seed_rules.dart';

class CalculatorEngine {
  final List<CalculationRule> rules;

  const CalculatorEngine({List<CalculationRule>? rules})
      : rules = rules ?? const [];

  CalculationResult calculate(UnitSpecification spec) {
    final effectiveRules = rules.isNotEmpty ? rules : SeedRules.getSystem2000BeadedRules();
    final selector = RuleSelector(effectiveRules);
    final env = Map<String, dynamic>.from(spec.toEnvironment());

    final issues = <RuleIssue>[];
    final ruleVersionIdsUsed = <String>[];
    final pieces = <CutPiece>[];

    // Profile item codes to resolve for System 2000
    final targetItems = [
      'track',
      'u_profile',
      'kaab',
      if (spec.hasScreen && spec.screenCount > 0) ...[
        'screen_vertical',
        'screen_horizontal',
      ],
      'glass_height',
      'glass_width',
    ];

    // 1. Select rules for each target item
    final selectedRules = <String, CalculationRule>{};
    for (final itemCode in targetItems) {
      final selection = selector.selectRule(itemCode: itemCode, spec: spec);
      if (selection.hasIssue) {
        issues.add(selection.issue!);
      }
      if (selection.hasRule) {
        selectedRules[itemCode] = selection.selectedRule!;
        ruleVersionIdsUsed.add('${selection.selectedRule!.id}_v${selection.selectedRule!.version}');
      }
    }

    if (issues.any((i) => i.severity == IssueSeverity.error)) {
      // Return early with errors if rules are missing
      return CalculationResult(
        pieces: const [],
        glass: GlassSpecification(
          paneWidthCm: 0,
          paneHeightCm: 0,
          quantity: 0,
          glazingMode: spec.glazingMode,
          glassType: spec.glassType,
          thicknessMm: spec.glassThicknessMm,
        ),
        accessories: const [],
        issues: issues,
        ruleVersionIdsUsed: ruleVersionIdsUsed,
      );
    }

    // 2. Build dependency graph
    final graph = DependencyGraph();
    for (final entry in selectedRules.entries) {
      final itemCode = entry.key;
      final rule = entry.value;
      graph.addNode(itemCode);

      for (final dep in rule.dependsOn) {
        // dep might be an intermediate variable like 'kaab_len' mapped to 'kaab'
        final sourceNode = dep.endsWith('_len') ? dep.replaceAll('_len', '') : dep;
        if (selectedRules.containsKey(sourceNode)) {
          graph.addDependency(node: itemCode, dependsOnNode: sourceNode);
        }
      }
    }

    List<String> evalOrder;
    try {
      evalOrder = graph.topologicalSort();
    } on CircularDependencyException catch (e) {
      issues.add(RuleIssue(itemCode: 'system', message: e.toString()));
      return CalculationResult(
        pieces: const [],
        glass: GlassSpecification(
          paneWidthCm: 0,
          paneHeightCm: 0,
          quantity: 0,
          glazingMode: spec.glazingMode,
          glassType: spec.glassType,
          thicknessMm: spec.glassThicknessMm,
        ),
        accessories: const [],
        issues: issues,
        ruleVersionIdsUsed: ruleVersionIdsUsed,
      );
    }

    // 3. Evaluate lengths and quantities in topological order
    final calculatedLengths = <String, double>{};

    for (final itemCode in evalOrder) {
      final rule = selectedRules[itemCode];
      if (rule == null) continue;

      try {
        final lengthVal = ExpressionEvaluator.evaluateNumeric(rule.lengthFormula, env).toDouble();
        final qtyVal = ExpressionEvaluator.evaluateNumeric(rule.quantityFormula, env).round();

        if (lengthVal <= 0) {
          issues.add(
            RuleIssue(
              itemCode: itemCode,
              message: 'Invalid length ($lengthVal cm) for item "$itemCode". Length must be strictly positive (> 0). Blocks calculation.',
            ),
          );
        }

        if (qtyVal < 0) {
          issues.add(
            RuleIssue(
              itemCode: itemCode,
              message: 'Invalid quantity ($qtyVal) for item "$itemCode". Quantity must be non-negative (>= 0).',
            ),
          );
        }

        calculatedLengths[itemCode] = lengthVal;
        env['${itemCode}_len'] = lengthVal;
        env['${itemCode}_length'] = lengthVal;
        env['${itemCode}_qty'] = qtyVal;

        if (itemCode != 'glass_height' && itemCode != 'glass_width') {
          pieces.add(
            CutPiece(
              itemCode: itemCode,
              nameArabic: _arabicNameForItem(itemCode),
              lengthCm: lengthVal,
              quantity: qtyVal,
              cutAngleLeft: (itemCode == 'kaab' || itemCode.startsWith('screen_')) ? 45.0 : 90.0,
              cutAngleRight: (itemCode == 'kaab' || itemCode.startsWith('screen_')) ? 45.0 : 90.0,
              profileType: _profileTypeForItem(itemCode),
              ruleVersionId: '${rule.id}_v${rule.version}',
            ),
          );
        }
      } catch (e) {
        issues.add(RuleIssue(itemCode: itemCode, message: 'Evaluation error in "$itemCode": $e'));
      }
    }

    // 4. Calculate Glass Specification
    final glassHeight = calculatedLengths['glass_height'] ?? 0.0;
    final glassWidth = calculatedLengths['glass_width'] ?? 0.0;
    final glassSpec = GlassSpecification(
      paneWidthCm: glassWidth,
      paneHeightCm: glassHeight,
      quantity: spec.sashCount,
      glazingMode: spec.glazingMode,
      glassType: spec.glassType,
      thicknessMm: spec.glassThicknessMm,
    );

    // 5. Calculate Accessories (Section 8.6)
    final accessories = _calculateAccessories(spec);

    return CalculationResult(
      pieces: pieces,
      glass: glassSpec,
      accessories: accessories,
      issues: issues,
      ruleVersionIdsUsed: ruleVersionIdsUsed,
    );
  }

  List<AccessoryItem> _calculateAccessories(UnitSpecification spec) {
    final isFacade = spec.unitType == 'facade';
    final handleFaces = isFacade ? 2 : 1;
    final waterPlugCount = isFacade ? 12 : 6;

    final accessories = <AccessoryItem>[
      // Handles
      AccessoryItem(
        code: 'glass_handle',
        nameArabic: 'مسكة زجاج',
        quantity: spec.sashCount * handleFaces,
        unit: 'piece',
      ),
      if (spec.hasScreen)
        AccessoryItem(
          code: 'screen_handle',
          nameArabic: 'مسكة درفة منخل',
          quantity: spec.screenCount * 2,
          unit: 'piece',
        ),

      // Plugs
      const AccessoryItem(
        code: 'shankal_plug',
        nameArabic: 'طبة شنكل',
        quantity: 4,
        unit: 'piece',
      ),
      AccessoryItem(
        code: 'water_plug',
        nameArabic: 'طبة ماء',
        quantity: waterPlugCount,
        unit: 'piece',
      ),
      const AccessoryItem(
        code: 'rakilaj_plug',
        nameArabic: 'طبة مسكة ركلاج',
        quantity: 2,
        unit: 'piece',
      ),
      const AccessoryItem(
        code: 'fixed_plug',
        nameArabic: 'طبة مسكة ثابت',
        quantity: 2,
        unit: 'piece',
      ),

      // Screws
      const AccessoryItem(
        code: 'short_screws',
        nameArabic: 'براغي قصيرة 4mm×1.5cm',
        quantity: 16,
        unit: 'piece',
      ),
      const AccessoryItem(
        code: 'long_screws',
        nameArabic: 'براغي طويلة 4mm×3cm',
        quantity: 8,
        unit: 'piece',
      ),

      // Rollers
      AccessoryItem(
        code: 'glass_rollers',
        nameArabic: 'عجلات درف الزجاج',
        quantity: spec.sashCount * 2, // must be even
        unit: 'pair',
      ),
      if (spec.hasScreen)
        AccessoryItem(
          code: 'screen_rollers_${spec.rollerType}',
          nameArabic: 'عجلات درفة المنخل (${spec.rollerType})',
          quantity: 2,
          unit: 'pair',
        ),
    ];

    if (spec.hasCorners) {
      accessories.add(
        const AccessoryItem(
          code: 'corners',
          nameArabic: 'زوايا تجميع',
          quantity: 4,
          unit: 'piece',
        ),
      );
    }

    if (spec.hasGasket) {
      accessories.add(
        const AccessoryItem(
          code: 'gasket',
          nameArabic: 'جوان إحكام عازل',
          quantity: 4,
          unit: 'piece',
        ),
      );
    }

    return accessories;
  }

  String _arabicNameForItem(String itemCode) {
    switch (itemCode) {
      case 'track':
        return 'سكة 2000 بحاجب';
      case 'u_profile':
        return 'يو 2000';
      case 'kaab':
        return 'كعب 2000 مفرد';
      case 'screen_vertical':
        return 'درفة منخل عامودي';
      case 'screen_horizontal':
        return 'درفة منخل أفقي';
      default:
        return itemCode;
    }
  }

  String _profileTypeForItem(String itemCode) {
    switch (itemCode) {
      case 'track':
        return 'track';
      case 'u_profile':
        return 'jamb';
      case 'kaab':
        return 'sash';
      case 'screen_vertical':
      case 'screen_horizontal':
        return 'screen';
      default:
        return 'profile';
    }
  }
}
