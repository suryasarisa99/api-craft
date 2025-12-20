import 'dart:convert';

import 'package:api_craft/features/template-functions/models/template_placeholder_model.dart';
import 'package:flutter/foundation.dart';

class TemplateParseException implements Exception {
  final String message;
  TemplateParseException(this.message);
  @override
  String toString() => message;
}

class TemplateParser {
  /// ============================================================
  /// 1️⃣ FULL STRING PARSE (final request)
  /// ============================================================
  static List<TemplatePlaceholder> parseAll(String input) {
    final result = <TemplatePlaceholder>[];
    int i = 0;

    while (true) {
      final start = input.indexOf('{{', i);
      if (start == -1) break;

      final end = input.indexOf('}}', start);
      if (end == -1) {
        throw TemplateParseException('Unterminated {{');
      }

      final content = input.substring(start + 2, end).trim();

      result.add(_parseContent(content: content, start: start, end: end + 2));

      i = end + 2;
    }

    return result;
  }

  /// ============================================================
  /// 2️⃣ SINGLE PLACEHOLDER PARSE (click / edit)
  /// ============================================================
  static TemplatePlaceholder parseContent(
    String content, {
    required int start,
    required int end,
  }) {
    debugPrint("Parsing content: $content");
    return _parseContent(content: content, start: start, end: end);
  }

  /// ============================================================
  /// Internal dispatcher
  /// ============================================================
  static TemplatePlaceholder _parseContent({
    required String content,
    required int start,
    required int end,
  }) {
    if (_looksLikeFunction(content)) {
      final fn = _FnParser(content).parse();
      return TemplateFnPlaceholder(
        name: fn.name,
        args: fn.args,
        start: start,
        end: end,
      );
    }
    return TemplateVariablePlaceholder(name: content, start: start, end: end);
  }

  static bool _looksLikeFunction(String s) =>
      s.contains('(') && s.endsWith(')');
}

class _FnParser {
  final String input;
  int pos = 0;

  _FnParser(this.input);

  _ParsedFn parse() {
    final name = _parseDottedIdentifier();
    _consume('(');

    final args = <String, dynamic>{};
    _skipWs();

    if (_peek(')')) {
      pos++;
      return _ParsedFn(name, args);
    }

    while (true) {
      _skipWs();
      final key = _parseIdentifier();
      _consume('=');
      final value = _parseValue();

      if (args.containsKey(key)) {
        throw TemplateParseException('Duplicate arg $key');
      }
      args[key] = value;

      _skipWs();
      if (_peek(',')) {
        pos++;
        continue;
      }
      if (_peek(')')) {
        pos++;
        break;
      }
      throw TemplateParseException('Expected , or )');
    }

    return _ParsedFn(name, args);
  }

  dynamic _parseValue() {
    _skipWs();

    if (_match("b64'")) {
      final raw = _parseUntil("'");
      return utf8.decode(base64.decode(_padBase64(raw)));
    }

    if (_peek("'") || _peek('"')) {
      return _parseString();
    }

    final literal = _parseLiteral();
    if (literal == 'true') return true;
    if (literal == 'false') return false;
    if (literal == 'null') return null;

    final n = num.tryParse(literal);
    if (n != null) return n;

    return literal;
  }

  String _parseString() {
    final quote = input[pos++];
    final sb = StringBuffer();

    while (pos < input.length) {
      final c = input[pos++];
      if (c == quote) return sb.toString();
      if (c == '\\') {
        sb.write(input[pos++]);
      } else {
        sb.write(c);
      }
    }
    throw TemplateParseException('Unterminated string');
  }

  String _parseLiteral() {
    final start = pos;
    while (pos < input.length && !',)'.contains(input[pos])) {
      pos++;
    }
    return input.substring(start, pos).trim();
  }

  String _parseIdentifier() {
    final start = pos;
    while (pos < input.length && RegExp(r'[A-Za-z0-9_]').hasMatch(input[pos])) {
      pos++;
    }
    return input.substring(start, pos);
  }

  String _parseDottedIdentifier() {
    final start = pos;
    while (pos < input.length &&
        RegExp(r'[A-Za-z0-9_.]').hasMatch(input[pos])) {
      pos++;
    }
    return input.substring(start, pos);
  }

  void _consume(String s) {
    _skipWs();
    if (!input.startsWith(s, pos)) {
      throw TemplateParseException('Expected $s');
    }
    pos += s.length;
  }

  bool _peek(String c) => pos < input.length && input[pos] == c;

  bool _match(String s) {
    if (input.startsWith(s, pos)) {
      pos += s.length;
      return true;
    }
    return false;
  }

  void _skipWs() {
    while (pos < input.length && input[pos].trim().isEmpty) {
      pos++;
    }
  }

  String _parseUntil(String end) {
    final start = pos;
    final idx = input.indexOf(end, pos);
    if (idx == -1) {
      throw TemplateParseException('Unterminated');
    }
    pos = idx + 1;
    return input.substring(start, idx);
  }

  String _padBase64(String s) => s + '=' * ((4 - s.length % 4) % 4);
}

class _ParsedFn {
  final String name;
  final Map<String, dynamic> args;
  _ParsedFn(this.name, this.args);
}

String serializePlaceholder(TemplatePlaceholder p) {
  if (p is TemplateVariablePlaceholder) {
    return p.name;
  }

  final fn = p as TemplateFnPlaceholder;
  final sb = StringBuffer();
  sb.write(fn.name);
  sb.write('(');

  var first = true;
  fn.args?.forEach((k, v) {
    if (!first) sb.write(', ');
    first = false;
    sb.write('$k=${_serializeValue(v)}');
  });

  sb.write(')');
  return sb.toString();
}

String _serializeValue(dynamic v) {
  if (v == null) return 'null';
  if (v is bool || v is num) return v.toString();

  if (_needsBase64(v)) {
    final b64 = base64.encode(utf8.encode(v));
    return "b64'$b64'";
  }
  return "'${v.replaceAll("'", "\\'")}'";
}

// \n, { }, ( ), $, comma (,)
bool _needsBase64(String s) {
  // chars that break parser / grammar
  return RegExp(r'[\n,\{\}\(\)\$]').hasMatch(s);
}
