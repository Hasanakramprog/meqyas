abstract class ExpressionNode {
  const ExpressionNode();

  dynamic evaluate(Map<String, dynamic> environment);

  Set<String> getVariables();
}

class NumberLiteralNode extends ExpressionNode {
  final num value;

  const NumberLiteralNode(this.value);

  @override
  dynamic evaluate(Map<String, dynamic> environment) => value;

  @override
  Set<String> getVariables() => {};

  @override
  String toString() => value.toString();
}

class StringLiteralNode extends ExpressionNode {
  final String value;

  const StringLiteralNode(this.value);

  @override
  dynamic evaluate(Map<String, dynamic> environment) => value;

  @override
  Set<String> getVariables() => {};

  @override
  String toString() => "'$value'";
}

class BooleanLiteralNode extends ExpressionNode {
  final bool value;

  const BooleanLiteralNode(this.value);

  @override
  dynamic evaluate(Map<String, dynamic> environment) => value;

  @override
  Set<String> getVariables() => {};

  @override
  String toString() => value.toString();
}

class VariableNode extends ExpressionNode {
  final String name;

  const VariableNode(this.name);

  @override
  dynamic evaluate(Map<String, dynamic> environment) {
    if (!environment.containsKey(name)) {
      throw FormatException('Missing required variable in formula evaluation: "$name"');
    }
    return environment[name];
  }

  @override
  Set<String> getVariables() => {name};

  @override
  String toString() => name;
}

class BinaryOpNode extends ExpressionNode {
  final String operator;
  final ExpressionNode left;
  final ExpressionNode right;

  const BinaryOpNode({
    required this.operator,
    required this.left,
    required this.right,
  });

  @override
  dynamic evaluate(Map<String, dynamic> environment) {
    final leftVal = left.evaluate(environment);
    final rightVal = right.evaluate(environment);

    switch (operator) {
      // Arithmetic
      case '+':
        if (leftVal is num && rightVal is num) return leftVal + rightVal;
        return '$leftVal$rightVal';
      case '-':
        _ensureNumeric(leftVal, rightVal, '-');
        return (leftVal as num) - (rightVal as num);
      case '*':
        _ensureNumeric(leftVal, rightVal, '*');
        return (leftVal as num) * (rightVal as num);
      case '/':
        _ensureNumeric(leftVal, rightVal, '/');
        if ((rightVal as num) == 0) throw UnsupportedError('Division by zero');
        return (leftVal as num) / rightVal;
      case '%':
        _ensureNumeric(leftVal, rightVal, '%');
        return (leftVal as num) % (rightVal as num);

      // Comparisons
      case '==':
        return leftVal.toString() == rightVal.toString();
      case '!=':
        return leftVal.toString() != rightVal.toString();
      case '>':
        _ensureNumeric(leftVal, rightVal, '>');
        return (leftVal as num) > (rightVal as num);
      case '>=':
        _ensureNumeric(leftVal, rightVal, '>=');
        return (leftVal as num) >= (rightVal as num);
      case '<':
        _ensureNumeric(leftVal, rightVal, '<');
        return (leftVal as num) < (rightVal as num);
      case '<=':
        _ensureNumeric(leftVal, rightVal, '<=');
        return (leftVal as num) <= (rightVal as num);

      // Logical
      case '&&':
        return _isTruthy(leftVal) && _isTruthy(rightVal);
      case '||':
        return _isTruthy(leftVal) || _isTruthy(rightVal);

      default:
        throw UnsupportedError('Unsupported operator: $operator');
    }
  }

  void _ensureNumeric(dynamic a, dynamic b, String op) {
    if (a is! num || b is! num) {
      throw FormatException('Operator "$op" requires numeric operands, got: $a ($op) $b');
    }
  }

  bool _isTruthy(dynamic val) {
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) return val.isNotEmpty && val != 'false';
    return val != null;
  }

  @override
  Set<String> getVariables() => left.getVariables().union(right.getVariables());

  @override
  String toString() => '($left $operator $right)';
}

class UnaryOpNode extends ExpressionNode {
  final String operator;
  final ExpressionNode operand;

  const UnaryOpNode({
    required this.operator,
    required this.operand,
  });

  @override
  dynamic evaluate(Map<String, dynamic> environment) {
    final val = operand.evaluate(environment);
    if (operator == '-') {
      if (val is! num) throw FormatException('Unary "-" requires numeric operand, got: $val');
      return -val;
    }
    if (operator == '!') {
      return val is bool ? !val : (val == null || val == false || val == 0);
    }
    throw UnsupportedError('Unsupported unary operator: $operator');
  }

  @override
  Set<String> getVariables() => operand.getVariables();

  @override
  String toString() => '$operator($operand)';
}

class FunctionCallNode extends ExpressionNode {
  final String name;
  final List<ExpressionNode> arguments;

  const FunctionCallNode({
    required this.name,
    required this.arguments,
  });

  @override
  dynamic evaluate(Map<String, dynamic> environment) {
    final evaluatedArgs = arguments.map((a) => a.evaluate(environment)).toList();
    switch (name.toLowerCase()) {
      case 'ceil':
        if (evaluatedArgs.isEmpty || evaluatedArgs.first is! num) throw FormatException('ceil requires a number');
        return (evaluatedArgs.first as num).ceilToDouble();
      case 'floor':
        if (evaluatedArgs.isEmpty || evaluatedArgs.first is! num) throw FormatException('floor requires a number');
        return (evaluatedArgs.first as num).floorToDouble();
      case 'round':
        if (evaluatedArgs.isEmpty || evaluatedArgs.first is! num) throw FormatException('round requires a number');
        return (evaluatedArgs.first as num).roundToDouble();
      case 'max':
        if (evaluatedArgs.length < 2) throw FormatException('max requires at least 2 numbers');
        return (evaluatedArgs.first as num) > (evaluatedArgs[1] as num) ? evaluatedArgs.first : evaluatedArgs[1];
      case 'min':
        if (evaluatedArgs.length < 2) throw FormatException('min requires at least 2 numbers');
        return (evaluatedArgs.first as num) < (evaluatedArgs[1] as num) ? evaluatedArgs.first : evaluatedArgs[1];
      default:
        throw UnsupportedError('Unknown function call: $name');
    }
  }

  @override
  Set<String> getVariables() {
    final vars = <String>{};
    for (final a in arguments) {
      vars.addAll(a.getVariables());
    }
    return vars;
  }

  @override
  String toString() => '$name(${arguments.join(', ')})';
}
