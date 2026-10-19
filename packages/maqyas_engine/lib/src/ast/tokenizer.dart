enum TokenType {
  number,
  identifier,
  stringLiteral,
  plus,
  minus,
  multiply,
  divide,
  modulo,
  lparen,
  rparen,
  equals,
  notEquals,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  and,
  or,
  not,
  eof,
}

class Token {
  final TokenType type;
  final String text;
  final dynamic value;
  final int position;

  const Token({
    required this.type,
    required this.text,
    this.value,
    required this.position,
  });

  @override
  String toString() => 'Token($type, "$text", pos: $position)';
}

class Tokenizer {
  final String source;
  int _pos = 0;

  Tokenizer(this.source);

  List<Token> tokenize() {
    final tokens = <Token>[];
    while (_pos < source.length) {
      final ch = source[_pos];

      if (_isWhitespace(ch)) {
        _pos++;
        continue;
      }

      final startPos = _pos;

      // Numbers (integers and decimals)
      if (_isDigit(ch) || (ch == '.' && _pos + 1 < source.length && _isDigit(source[_pos + 1]))) {
        tokens.add(_readNumber());
        continue;
      }

      // Strings (single or double quotes)
      if (ch == '\'' || ch == '"') {
        tokens.add(_readString(ch));
        continue;
      }

      // Identifiers & keywords (W, H, sashCount, etc.)
      if (_isIdentStart(ch)) {
        tokens.add(_readIdentifier());
        continue;
      }

      // Operators and punctuation
      switch (ch) {
        case '+':
          tokens.add(Token(type: TokenType.plus, text: '+', position: startPos));
          _pos++;
          break;
        case '-':
          tokens.add(Token(type: TokenType.minus, text: '-', position: startPos));
          _pos++;
          break;
        case '*':
          tokens.add(Token(type: TokenType.multiply, text: '*', position: startPos));
          _pos++;
          break;
        case '/':
          tokens.add(Token(type: TokenType.divide, text: '/', position: startPos));
          _pos++;
          break;
        case '%':
          tokens.add(Token(type: TokenType.modulo, text: '%', position: startPos));
          _pos++;
          break;
        case '(':
          tokens.add(Token(type: TokenType.lparen, text: '(', position: startPos));
          _pos++;
          break;
        case ')':
          tokens.add(Token(type: TokenType.rparen, text: ')', position: startPos));
          _pos++;
          break;
        case '=':
          if (_pos + 1 < source.length && source[_pos + 1] == '=') {
            tokens.add(Token(type: TokenType.equals, text: '==', position: startPos));
            _pos += 2;
          } else {
            tokens.add(Token(type: TokenType.equals, text: '=', position: startPos));
            _pos++;
          }
          break;
        case '!':
          if (_pos + 1 < source.length && source[_pos + 1] == '=') {
            tokens.add(Token(type: TokenType.notEquals, text: '!=', position: startPos));
            _pos += 2;
          } else {
            tokens.add(Token(type: TokenType.not, text: '!', position: startPos));
            _pos++;
          }
          break;
        case '>':
          if (_pos + 1 < source.length && source[_pos + 1] == '=') {
            tokens.add(Token(type: TokenType.greaterThanOrEqual, text: '>=', position: startPos));
            _pos += 2;
          } else {
            tokens.add(Token(type: TokenType.greaterThan, text: '>', position: startPos));
            _pos++;
          }
          break;
        case '<':
          if (_pos + 1 < source.length && source[_pos + 1] == '=') {
            tokens.add(Token(type: TokenType.lessThanOrEqual, text: '<=', position: startPos));
            _pos += 2;
          } else {
            tokens.add(Token(type: TokenType.lessThan, text: '<', position: startPos));
            _pos++;
          }
          break;
        case '&':
          if (_pos + 1 < source.length && source[_pos + 1] == '&') {
            tokens.add(Token(type: TokenType.and, text: '&&', position: startPos));
            _pos += 2;
          } else {
            throw FormatException('Unexpected character "&" at position $startPos');
          }
          break;
        case '|':
          if (_pos + 1 < source.length && source[_pos + 1] == '|') {
            tokens.add(Token(type: TokenType.or, text: '||', position: startPos));
            _pos += 2;
          } else {
            throw FormatException('Unexpected character "|" at position $startPos');
          }
          break;
        default:
          throw FormatException('Unexpected character "$ch" at position $startPos in "$source"');
      }
    }

    tokens.add(Token(type: TokenType.eof, text: '', position: _pos));
    return tokens;
  }

  Token _readNumber() {
    final start = _pos;
    while (_pos < source.length && _isDigit(source[_pos])) {
      _pos++;
    }
    if (_pos < source.length && source[_pos] == '.') {
      _pos++;
      while (_pos < source.length && _isDigit(source[_pos])) {
        _pos++;
      }
    }
    final raw = source.substring(start, _pos);
    final val = num.parse(raw);
    return Token(type: TokenType.number, text: raw, value: val, position: start);
  }

  Token _readString(String quote) {
    final start = _pos;
    _pos++; // skip open quote
    final buf = StringBuffer();
    while (_pos < source.length && source[_pos] != quote) {
      if (source[_pos] == '\\' && _pos + 1 < source.length) {
        _pos++;
        buf.write(source[_pos]);
      } else {
        buf.write(source[_pos]);
      }
      _pos++;
    }
    if (_pos >= source.length) {
      throw FormatException('Unterminated string starting at position $start');
    }
    _pos++; // skip close quote
    return Token(type: TokenType.stringLiteral, text: buf.toString(), value: buf.toString(), position: start);
  }

  Token _readIdentifier() {
    final start = _pos;
    while (_pos < source.length && _isIdentPart(source[_pos])) {
      _pos++;
    }
    final text = source.substring(start, _pos);
    if (text == 'and') return Token(type: TokenType.and, text: text, position: start);
    if (text == 'or') return Token(type: TokenType.or, text: text, position: start);
    if (text == 'not') return Token(type: TokenType.not, text: text, position: start);
    return Token(type: TokenType.identifier, text: text, value: text, position: start);
  }

  bool _isWhitespace(String ch) => ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
  bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
  bool _isIdentStart(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || ch == '_' || (c >= 0x0600 && c <= 0x06FF); // Arabic letters allowed
  }
  bool _isIdentPart(String ch) => _isIdentStart(ch) || _isDigit(ch);
}
