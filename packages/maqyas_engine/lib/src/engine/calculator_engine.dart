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

    // Distinct item codes dynamically loaded from the active rules for this system
    final availableItems = selector.getAvailableItemCodes(profileSystemId: spec.profileSystemId);
    final targetItems = availableItems.isNotEmpty
        ? availableItems
        : [
            'track',
            'u_profile',
            'side',
            'kaab',
            'handle',
            'shankal',
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

        if (rule.outputKind == 'glass_height' ||
            rule.outputKind == 'glass_width' ||
            rule.outputKind == 'intermediate' ||
            itemCode == 'glass_height' ||
            itemCode == 'glass_width') {
          // Glass dimension or intermediate variable, skip adding to cut pieces
        } else {
          var resolvedArabicName = rule.nameArabic.isNotEmpty
              ? rule.nameArabic
              : _arabicNameForItem(itemCode);
          if (spec.glazingMode == 'double' &&
              resolvedArabicName.contains('مفرد')) {
            resolvedArabicName =
                resolvedArabicName.replaceAll('مفرد', 'دبل');
          }
          pieces.add(
            CutPiece(
              itemCode: itemCode,
              nameArabic: resolvedArabicName,
              lengthCm: lengthVal,
              quantity: qtyVal,
              cutAngleLeft: rule.cutAngleLeft,
              cutAngleRight: rule.cutAngleRight,
              profileType: rule.profileType.isNotEmpty ? rule.profileType : _profileTypeForItem(itemCode),
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
        code: spec.glassRollerType.isNotEmpty
            ? 'glass_${spec.glassRollerType}'
            : 'glass_rollers',
        nameArabic: _glassRollerArabic(spec),
        quantity: spec.glassRollerCount > 0
            ? (spec.glassRollerCount.isEven
                ? spec.glassRollerCount
                : spec.glassRollerCount + 1)
            : spec.sashCount * 2, // must be even
        unit: 'piece',
      ),
      if (spec.hasScreen)
        AccessoryItem(
          code: 'screen_rollers_${spec.rollerType}',
          nameArabic: _screenRollerArabic(spec.rollerType),
          quantity: 2 * spec.screenCount,
          unit: 'piece',
        ),
    ];

    if (spec.hasCorners && spec.screenCornerType != 'none') {
      accessories.add(
        const AccessoryItem(
          code: 'corners',
          nameArabic: 'زاوية تجميع المنخل',
          quantity: 4,
          unit: 'piece',
        ),
      );
    }

    if (spec.frameGasketType != 'none') {
      accessories.add(
        const AccessoryItem(
          code: 'gasket',
          nameArabic: 'جوان تجميع الكادر',
          quantity: 4,
          unit: 'piece',
        ),
      );
    }

    if (spec.puttyQtyPerUnit > 0) {
      accessories.add(
        AccessoryItem(
          code: 'putty',
          nameArabic: 'معجونة',
          quantity: spec.puttyQtyPerUnit,
          unit: 'piece',
        ),
      );
    }

    return accessories;
  }

  String _glassRollerArabic(UnitSpecification spec) {
    final resolved = spec.glassRollerType.isNotEmpty
        ? spec.glassRollerType
        : (spec.glazingMode == 'double'
            ? 'roller_2000_double'
            : 'roller_2000_single');
    return resolved == 'roller_2000_double'
        ? 'دولاب 2000 دبل'
        : 'دولاب 2000 مفرد';
  }

  String _screenRollerArabic(String rollerType) {
    switch (rollerType) {
      case 'modified_2000':
        return 'دولاب 2000 معدل (حركة المنخل)';
      case 'milled':
        return 'دولاب تفريز (حركة المنخل)';
      case 'slider':
      default:
        return 'زحّافة (حركة المنخل)';
    }
  }

  String _arabicNameForItem(String itemCode) {
    switch (itemCode) {
      case 'track':
        return 'سكة 2000 بحاجب';
      case 'u_profile':
        return 'يو 2000';
      case 'side':
        return 'جنب 2000 بحاجب';
      case 'kaab':
        return 'كعب 2000 مفرد';
      case 'handle':
        return 'مسكة 2000 مفرد';
      case 'shankal':
        return 'شنكل 2000 مفرد';
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
      case 'side':
        return 'jamb';
      case 'kaab':
      case 'handle':
      case 'shankal':
        return 'sash';
      case 'screen_vertical':
      case 'screen_horizontal':
        return 'screen';
      default:
        return 'profile';
    }
  }
}
