import 'dart:convert';

class TemplateParseException implements Exception {
  final String message;
  TemplateParseException(this.message);
  @override
  String toString() => 'TemplateParseException: $message';
}

class TemplateParser {
  final String input;
  int pos = 0;

  TemplateParser(this.input);

  bool _eof() => pos >= input.length;
  String get _current => _eof() ? '' : input[pos];

  static Map<String, dynamic> parseTemplate(String raw) {
    String trimmed = raw.trim();
    if (!trimmed.startsWith('{{') || !trimmed.endsWith('}}')) {
      throw TemplateParseException('Invalid template braces');
    }

    trimmed = trimmed.substring(2, trimmed.length - 2).trim();
    final parser = TemplateParser(trimmed);
    return parser._parseFunctionCall();
  }

  Map<String, dynamic> _parseFunctionCall() {
    _skipWhitespace();
    // _parseIdentifier(); // function name (ignored)
    _parseDottedIdentifier();

    _skipWhitespace();
    if (!_consume('(')) {
      throw TemplateParseException("Expected '(' after function name");
    }

    final Map<String, dynamic> args = {};

    _skipWhitespace();
    if (_peek(')')) {
      pos++;
      return args;
    }

    while (true) {
      _skipWhitespace();
      final entry = _parseArgument();

      if (args.containsKey(entry.key)) {
        throw TemplateParseException("Duplicate argument '${entry.key}'");
      }
      args[entry.key] = entry.value;

      _skipWhitespace();
      if (_consume(',')) {
        _skipWhitespace();
        if (_consume(')')) break; // trailing comma
        continue;
      }
      if (_consume(')')) break;

      throw TemplateParseException("Expected ',' or ')'");
    }

    _skipWhitespace();
    if (!_eof()) {
      throw TemplateParseException("Unexpected trailing input");
    }

    return args;
  }

  MapEntry<String, dynamic> _parseArgument() {
    final name = _parseIdentifier();
    _skipWhitespace();
    if (!_consume('=')) {
      throw TemplateParseException("Expected '=' after '$name'");
    }
    _skipWhitespace();
    final value = _parseValue();
    return MapEntry(name, value);
  }

  dynamic _parseValue() {
    _skipWhitespace();

    // b64'...'
    if (_isIdentifierAhead('b64')) {
      pos += 3;
      _skipWhitespace();
      final decoded = _parseBase64String();
      return decoded;
    }

    // normal string
    if (_peek('"') || _peek("'")) {
      return _parseString();
    }

    final literal = _parseLiteral();

    if (literal == 'true') return true;
    if (literal == 'false') return false;
    if (literal == 'null') return null;

    final numVal = num.tryParse(literal);
    if (numVal != null) return numVal;

    return literal; // fallback as string
  }

  String _parseBase64String() {
    if (!_peek("'")) {
      throw TemplateParseException("Expected ' after b64");
    }

    final raw = _parseString();

    try {
      final normalized = _normalizeBase64(raw);
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      throw TemplateParseException("Invalid base64 string");
    }
  }

  String _normalizeBase64(String s) {
    final pad = s.length % 4;
    if (pad == 0) return s;
    return s + '=' * (4 - pad);
  }

  String _parseString() {
    final quote = input[pos++];
    final sb = StringBuffer();

    while (!_eof()) {
      final ch = input[pos];
      if (ch == '\\') {
        if (pos + 1 >= input.length) {
          throw TemplateParseException("Unterminated escape");
        }
        final next = input[pos + 1];
        switch (next) {
          case 'n':
            sb.write('\n');
            break;
          case 't':
            sb.write('\t');
            break;
          case '\\':
          case '"':
          case "'":
            sb.write(next);
            break;
          default:
            throw TemplateParseException("Invalid escape \\$next");
        }
        pos += 2;
      } else if (ch == quote) {
        pos++;
        return sb.toString();
      } else {
        sb.write(ch);
        pos++;
      }
    }
    throw TemplateParseException("Unterminated string");
  }

  String _parseIdentifier() {
    _skipWhitespace();
    if (_eof() || !RegExp(r'[A-Za-z_]').hasMatch(input[pos])) {
      throw TemplateParseException("Expected identifier at $pos");
    }
    final start = pos++;
    while (!_eof() && RegExp(r'[A-Za-z0-9_]').hasMatch(input[pos])) {
      pos++;
    }
    return input.substring(start, pos);
  }

  String _parseDottedIdentifier() {
    _skipWhitespace();
    final start = pos;

    if (_eof() || !RegExp(r'[A-Za-z_]').hasMatch(input[pos])) {
      throw TemplateParseException("Expected identifier at $pos");
    }

    pos++;
    while (!_eof()) {
      final ch = input[pos];
      if (RegExp(r'[A-Za-z0-9_]').hasMatch(ch)) {
        pos++;
      } else if (ch == '.') {
        pos++;
        if (_eof() || !RegExp(r'[A-Za-z_]').hasMatch(input[pos])) {
          throw TemplateParseException("Invalid dotted identifier");
        }
      } else {
        break;
      }
    }

    return input.substring(start, pos);
  }

  String _parseLiteral() {
    final start = pos;
    while (!_eof() && !RegExp(r'[\s,\)]').hasMatch(input[pos])) {
      pos++;
    }
    return input.substring(start, pos);
  }

  bool _isIdentifierAhead(String id) {
    final end = pos + id.length;
    if (end > input.length) return false;
    final slice = input.substring(pos, end);
    return slice == id &&
        (end == input.length || !RegExp(r'[A-Za-z0-9_]').hasMatch(input[end]));
  }

  void _skipWhitespace() {
    while (!_eof() && input[pos].trim().isEmpty) {
      pos++;
    }
  }

  bool _peek(String c) => !_eof() && input[pos] == c;
  bool _consume(String c) => _peek(c) ? (++pos > 0) : false;
}
