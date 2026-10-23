import '../ast/expression_parser.dart';
import '../graph/dependency_graph.dart';
import '../models/calculation_rule.dart';

class RuleValidationResult {
  final bool isValid;
  final Map<String, String> fieldErrors;
  final List<String> errorMessages;

  const RuleValidationResult({
    required this.isValid,
    this.fieldErrors = const {},
    this.errorMessages = const [],
  });

  bool get hasErrors => !isValid;
}

class RuleValidator {
  static const Set<String> standardAllowedVariables = {
    // Dimensions & Quantity
    'W',
    'H',
    'N',
    'quantity',
    // Specifications
    'sashCount',
    'screenCount',
    'hasScreen',
    'glassThicknessMm',
    'hasCorners',
    'hasGasket',
    'unitType',
    'glazingMode',
    'sharhOption',
    'rollerType',
    'glassType',
    'profileSystemId',
    'true',
    'false',
  };

  /// Validates a single CalculationRule for syntax, variable names, and dependency cycles
  static RuleValidationResult validate(
    CalculationRule rule, {
    List<CalculationRule> systemRules = const [],
  }) {
    final fieldErrors = <String, String>{};
    final errorMessages = <String>[];

    void addError(String field, String arabicMessage) {
      fieldErrors[field] = arabicMessage;
      errorMessages.add(arabicMessage);
    }

    // 1. Basic field checks
    if (rule.itemCode.trim().isEmpty) {
      addError('itemCode', 'رمز القطاع (itemCode) مطلوب ولا يمكن تركه فارغاً.');
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(rule.itemCode.trim())) {
      addError('itemCode', 'رمز القطاع يجب أن يحتوي فقط على أحرف إنجليزية وأرقام وعلامة _');
    }

    if (rule.nameArabic.trim().isEmpty && rule.outputKind == 'profile') {
      addError('nameArabic', 'الاسم باللغة العربية مطلوب لقطاعات الألمنيوم.');
    }

    // 2. Validate Length Formula
    final trimmedLength = rule.lengthFormula.trim();
    if (trimmedLength.isEmpty) {
      addError('lengthFormula', 'معادلة حساب الطول مطلوبة.');
    } else {
      try {
        final node = ExpressionParser.parse(trimmedLength);
        final usedVars = node.getVariables();
        for (final v in usedVars) {
          if (!_isVariableAllowed(v, systemRules)) {
            addError('lengthFormula', 'المتغير "$v" غير معرف في معادلة الطول.');
            break;
          }
        }
      } on FormatException catch (e) {
        addError('lengthFormula', 'خطأ في صياغة معادلة الطول: ${e.message}');
      } catch (e) {
        addError('lengthFormula', 'خطأ غير متوقع في معادلة الطول: $e');
      }
    }

    // 3. Validate Quantity Formula
    final trimmedQty = rule.quantityFormula.trim();
    if (trimmedQty.isEmpty) {
      addError('quantityFormula', 'معادلة حساب الكمية مطلوبة.');
    } else {
      try {
        final node = ExpressionParser.parse(trimmedQty);
        final usedVars = node.getVariables();
        for (final v in usedVars) {
          if (!_isVariableAllowed(v, systemRules)) {
            addError('quantityFormula', 'المتغير "$v" غير معرف في معادلة الكمية.');
            break;
          }
        }
      } on FormatException catch (e) {
        addError('quantityFormula', 'خطأ في صياغة معادلة الكمية: ${e.message}');
      } catch (e) {
        addError('quantityFormula', 'خطأ غير متوقع في معادلة الكمية: $e');
      }
    }

    // 4. Validate Conditions
    for (var i = 0; i < rule.conditions.length; i++) {
      final cond = rule.conditions[i].trim();
      if (cond.isEmpty) continue;
      try {
        final node = ExpressionParser.parse(cond);
        final usedVars = node.getVariables();
        for (final v in usedVars) {
          if (!_isVariableAllowed(v, systemRules)) {
            addError('conditions[$i]', 'المتغير "$v" في الشرط غير معرف.');
            break;
          }
        }
      } on FormatException catch (e) {
        addError('conditions[$i]', 'خطأ في صياغة الشرط "$cond": ${e.message}');
      } catch (e) {
        addError('conditions[$i]', 'خطأ غير متوقع في الشرط "$cond": $e');
      }
    }

    // 5. Validate Dependency Cycle across system rules
    if (fieldErrors.isEmpty && systemRules.isNotEmpty) {
      try {
        final graph = DependencyGraph();
        final combinedRules = <CalculationRule>[
          ...systemRules.where((r) => r.id != rule.id && r.itemCode != rule.itemCode),
          rule,
        ];

        for (final r in combinedRules) {
          graph.addNode(r.itemCode);
          for (final dep in r.dependsOn) {
            final sourceNode = dep.endsWith('_len') ? dep.replaceAll('_len', '') : dep;
            graph.addDependency(node: r.itemCode, dependsOnNode: sourceNode);
          }

          // Also scan length formula for referenced *_len variables
          try {
            final ast = ExpressionParser.parse(r.lengthFormula);
            for (final v in ast.getVariables()) {
              if (v.endsWith('_len')) {
                final source = v.replaceAll('_len', '');
                graph.addDependency(node: r.itemCode, dependsOnNode: source);
              }
            }
          } catch (_) {}
        }

        graph.topologicalSort();
      } on CircularDependencyException catch (e) {
        addError('dependsOn', 'تم اكتشاف اعتماد دائري مغلق بين القواعد: ${e.cyclePath.join(" -> ")}');
      }
    }

    return RuleValidationResult(
      isValid: fieldErrors.isEmpty,
      fieldErrors: fieldErrors,
      errorMessages: errorMessages,
    );
  }

  static bool _isVariableAllowed(String name, List<CalculationRule> systemRules) {
    if (standardAllowedVariables.contains(name)) return true;
    if (name.endsWith('_len') || name.endsWith('_length') || name.endsWith('_qty')) {
      final prefix = name.replaceAll('_len', '').replaceAll('_length', '').replaceAll('_qty', '');
      if (prefix.isNotEmpty) return true;
    }
    // Check if it corresponds to an existing rule's itemCode
    return systemRules.any((r) => r.itemCode == name || name.startsWith('${r.itemCode}_'));
  }
}
