import 'expression_parser.dart';

class ExpressionEvaluator {
  const ExpressionEvaluator();

  static dynamic evaluate(String expression, Map<String, dynamic> environment) {
    final ast = ExpressionParser.parse(expression);
    return ast.evaluate(environment);
  }

  static num evaluateNumeric(String expression, Map<String, dynamic> environment) {
    final result = evaluate(expression, environment);
    if (result is num) return result;
    throw FormatException(
      'Expression "$expression" did not evaluate to a number. Got: $result (${result.runtimeType})',
    );
  }

  static bool evaluateCondition(String condition, Map<String, dynamic> environment) {
    final result = evaluate(condition, environment);
    if (result is bool) return result;
    if (result is num) return result != 0;
    if (result is String) return result.isNotEmpty && result != 'false';
    return result != null;
  }

  static Set<String> extractVariables(String expression) {
    final ast = ExpressionParser.parse(expression);
    return ast.getVariables();
  }
}
