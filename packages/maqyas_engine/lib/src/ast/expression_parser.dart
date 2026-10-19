import 'ast_nodes.dart';
import 'tokenizer.dart';

class ExpressionParser {
  final List<Token> tokens;
  int _current = 0;

  ExpressionParser(this.tokens);

  static ExpressionNode parse(String expression) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Cannot parse empty expression');
    }
    final tokens = Tokenizer(trimmed).tokenize();
    return ExpressionParser(tokens)._parseExpression();
  }

  ExpressionNode _parseExpression() {
    final expr = _parseOr();
    if (!_isAtEnd()) {
      throw FormatException('Unexpected token "${_peek().text}" at position ${_peek().position}');
    }
    return expr;
  }

  // logical OR: a || b or a or b
  ExpressionNode _parseOr() {
    var expr = _parseAnd();
    while (_match([TokenType.or])) {
      final op = _previous().text;
      final right = _parseAnd();
      expr = BinaryOpNode(operator: op == 'or' ? '||' : op, left: expr, right: right);
    }
    return expr;
  }

  // logical AND: a && b or a and b
  ExpressionNode _parseAnd() {
    var expr = _parseEquality();
    while (_match([TokenType.and])) {
      final op = _previous().text;
      final right = _parseEquality();
      expr = BinaryOpNode(operator: op == 'and' ? '&&' : op, left: expr, right: right);
    }
    return expr;
  }

  // equality: ==, !=
  ExpressionNode _parseEquality() {
    var expr = _parseComparison();
    while (_match([TokenType.equals, TokenType.notEquals])) {
      final op = _previous().text;
      final right = _parseComparison();
      expr = BinaryOpNode(operator: op, left: expr, right: right);
    }
    return expr;
  }

  // comparison: <, <=, >, >=
  ExpressionNode _parseComparison() {
    var expr = _parseAddition();
    while (_match([
      TokenType.lessThan,
      TokenType.lessThanOrEqual,
      TokenType.greaterThan,
      TokenType.greaterThanOrEqual
    ])) {
      final op = _previous().text;
      final right = _parseAddition();
      expr = BinaryOpNode(operator: op, left: expr, right: right);
    }
    return expr;
  }

  // addition / subtraction: +, -
  ExpressionNode _parseAddition() {
    var expr = _parseMultiplication();
    while (_match([TokenType.plus, TokenType.minus])) {
      final op = _previous().text;
      final right = _parseMultiplication();
      expr = BinaryOpNode(operator: op, left: expr, right: right);
    }
    return expr;
  }

  // multiplication / division / modulo: *, /, %
  ExpressionNode _parseMultiplication() {
    var expr = _parseUnary();
    while (_match([TokenType.multiply, TokenType.divide, TokenType.modulo])) {
      final op = _previous().text;
      final right = _parseUnary();
      expr = BinaryOpNode(operator: op, left: expr, right: right);
    }
    return expr;
  }

  // unary: -, !
  ExpressionNode _parseUnary() {
    if (_match([TokenType.minus, TokenType.not])) {
      final op = _previous().text;
      final operand = _parseUnary();
      return UnaryOpNode(operator: op, operand: operand);
    }
    return _parsePrimary();
  }

  // primary: number, string, identifier, function call, parentheses
  ExpressionNode _parsePrimary() {
    if (_match([TokenType.number])) {
      return NumberLiteralNode(_previous().value as num);
    }

    if (_match([TokenType.stringLiteral])) {
      return StringLiteralNode(_previous().value as String);
    }

    if (_match([TokenType.identifier])) {
      final name = _previous().text;
      if (name == 'true') return const BooleanLiteralNode(true);
      if (name == 'false') return const BooleanLiteralNode(false);
      // Check if it's a function call like ceil(x) or max(a, b)
      if (_match([TokenType.lparen])) {
        final args = <ExpressionNode>[];
        if (!_check(TokenType.rparen)) {
          do {
            args.add(_parseOr());
          } while (_matchComma());
        }
        _consume(TokenType.rparen, 'Expected ")" after function arguments');
        return FunctionCallNode(name: name, arguments: args);
      }
      return VariableNode(name);
    }

    if (_match([TokenType.lparen])) {
      final expr = _parseOr();
      _consume(TokenType.rparen, 'Expected ")" after expression');
      return expr;
    }

    throw FormatException(
      'Unexpected token "${_peek().text}" at position ${_peek().position}',
    );
  }

  bool _match(List<TokenType> types) {
    for (final type in types) {
      if (_check(type)) {
        _advance();
        return true;
      }
    }
    return false;
  }

  bool _matchComma() {
    if (!_isAtEnd() && _peek().text == ',') {
      _advance();
      return true;
    }
    return false;
  }

  Token _consume(TokenType type, String message) {
    if (_check(type)) return _advance();
    throw FormatException('$message at position ${_peek().position}');
  }

  bool _check(TokenType type) {
    if (_isAtEnd()) return false;
    return _peek().type == type;
  }

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  bool _isAtEnd() => _peek().type == TokenType.eof;
  Token _peek() => tokens[_current];
  Token _previous() => tokens[_current - 1];
}
