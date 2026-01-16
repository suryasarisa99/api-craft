import 'dart:convert';
import 'package:api_craft/features/request/models/node_config_model.dart';
import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';

var fakeReq = {
  "headers": [
    ["content-type", "application/json"],
  ],
  "url": "https://example.com",
  "body": '{"foo": "bar"}',
  "method": "GET",
};
var fakeReqHeaders = [
  ["content-type", "application/json"],
];

class AssertionService {
  static List<TestResult> evaluate(
    List<AssertionDefinition> assertions,
    RawHttpResponse response,
  ) {
    List<TestResult> results = [];

    // Cache body map if needed multiple times
    Map<String, dynamic>? jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {}

    for (final def in assertions) {
      if (!def.isEnabled) continue;
      if (def.expression.trim() == "") continue;

      try {
        final actual = _getActualValue(def.expression, response, jsonBody);
        _evaluateAssertion(def, actual, results);
      } catch (e) {
        results.add(
          TestResult(
            description: "Assert: ${def.expression}",
            status: "failed",
            error: e.toString(),
          ),
        );
      }
    }

    return results;
  }

  static dynamic _getActualValue(
    String expression,
    RawHttpResponse res,
    Map<String, dynamic>? jsonBody,
  ) {
    if (expression.trim() == 'res') {
      return res.toJsMap();
    } else if (expression.trim() == 'req') {
      return fakeReq;
    }

    String exp = expression.trim();

    // 1. Try JSON Path
    try {
      String jsonPath = exp;
      Map<String, dynamic>? contextMap;

      if (exp.startsWith('res.')) {
        jsonPath = exp.replaceFirst('res.', '\$.');
        contextMap = res.toJsMap();
        // Inject parsed body for easier access if body matches string
        if (jsonBody != null && contextMap['body'] is String) {
          contextMap['body'] = jsonBody;
        }
      } else if (exp.startsWith('req.')) {
        jsonPath = exp.replaceFirst('req.', '\$.');
        contextMap = fakeReq;
      }

      if (contextMap != null) {
        final matches = JsonPath(jsonPath).read(contextMap);
        if (matches.isNotEmpty) {
          if (matches.length == 1) return matches.first.value;
          return matches.map((e) => e.value).toList();
        }
      }
    } catch (e) {
      // Ignore JSON Path parsing errors
    }

    // 2. Fallback: Custom Header Logic (Case-insensitive)
    // res.headers.key or res.headers['key']
    if (exp.startsWith('res.headers') || exp.startsWith('req.headers')) {
      final targetHeaders = exp.startsWith('res.headers')
          ? res.headers
          : fakeReqHeaders;

      // Extract key
      String? key;
      // Check dot notation
      final dotPattern = RegExp(r'\.headers\.([a-zA-Z0-9\-_]+)');
      final matchDot = dotPattern.firstMatch(exp);
      if (matchDot != null) {
        key = matchDot.group(1);
      }

      // Check bracket notation
      if (key == null) {
        final bracketPattern = RegExp(r"\.headers\['([^']+)'\]");
        final matchBracket = bracketPattern.firstMatch(exp);
        key = matchBracket?.group(1);
      }
      if (key == null) {
        final bracketPatternDouble = RegExp(r'\.headers\["([^"]+)"\]');
        final matchBracketDouble = bracketPatternDouble.firstMatch(exp);
        key = matchBracketDouble?.group(1);
      }

      if (key != null) {
        // Headers are List<List<String>>
        final header = targetHeaders.firstWhere(
          (h) => h[0].toString().toLowerCase() == key!.toLowerCase(),
          orElse: () => [],
        );
        return header.isNotEmpty ? header[1] : null;
      }
    }

    // 3. Simple Fallbacks
    if (exp == 'res.status' || exp == 'res.statusCode') {
      return res.statusCode;
    } else if (exp == 'res.responseTime') {
      return res.durationMs;
    } else if (exp == "res.headers") {
      return res.headers;
    }

    return null;
  }

  static void _evaluateAssertion(
    AssertionDefinition def,
    dynamic actual,
    List<TestResult> results,
  ) {
    bool passed = false;
    String? error;

    final op = def.operator;
    final expected = def.expectedValue; // Always string initially

    // Type Conversion for comparison (basic)
    dynamic expectedTyped = expected;
    if (actual is int) {
      expectedTyped = int.tryParse(expected) ?? expected;
    } else if (actual is bool) {
      expectedTyped = expected.toLowerCase() == 'true';
    } else if (actual == null && expected == 'null') {
      expectedTyped = null;
    }

    switch (op) {
      case 'equal':
      case 'equals':
      case 'eq':
        passed = actual.toString() == expected.toString();
        if (!passed) error = "Expected '$expected' but got '$actual'";
        break;
      case 'notEqual':
      case 'neq':
        passed = actual.toString() != expected.toString();
        if (!passed) error = "Expected not '$expected' but got '$actual'";
        break;
      case 'contains':
        passed = actual?.toString().contains(expected) ?? false;
        if (!passed) error = "Expected '$actual' to contain '$expected'";
        break;
      case 'toBeNull':
        passed = actual == null;
        if (!passed) error = "Expected null but got '$actual'";
        break;
      case 'toBeNotNull':
        passed = actual != null;
        if (!passed) error = "Expected not null";
        break;
      case 'gt':
        if (actual is num && expectedTyped is num) {
          passed = actual > expectedTyped;
          if (!passed) error = "Expected > $expected but got $actual";
        } else {
          error = "Value is not a number";
        }
        break;
      case 'lt':
        if (actual is num && expectedTyped is num) {
          passed = actual < expectedTyped;
          if (!passed) error = "Expected < $expected but got $actual";
        } else {
          error = "Value is not a number";
        }
        break;
      case 'gte':
        if (actual is num && expectedTyped is num) {
          passed = actual >= expectedTyped;
          if (!passed) error = "Expected >= $expected but got $actual";
        } else {
          error = "Value is not a number";
        }
        break;
      case 'lte':
        if (actual is num && expectedTyped is num) {
          passed = actual <= expectedTyped;
          if (!passed) error = "Expected <= $expected but got $actual";
        } else {
          error = "Value is not a number";
        }
        break;
      case 'exists':
        passed = actual != null;
        if (!passed) error = "Expected to exist (not null)";
        break;
      case 'doesNotExist':
        passed = actual == null;
        if (!passed) error = "Expected to not exist (null)";
        break;
      case 'isTrue':
        passed = actual == true;
        if (!passed) error = "Expected true but got $actual";
        break;
      case 'isFalse':
        passed = actual == false;
        if (!passed) error = "Expected false but got $actual";
        break;
      case 'isEmpty':
        if (actual == null) {
          passed = true;
        } else if (actual is String) {
          passed = actual.isEmpty;
        } else if (actual is List) {
          passed = actual.isEmpty;
        } else if (actual is Map) {
          passed = actual.isEmpty;
        } else {
          passed = false;
        }
        if (!passed) error = "Expected to be empty";
        break;
      case 'isNotEmpty':
        if (actual == null) {
          passed = false;
        } else if (actual is String) {
          passed = actual.isNotEmpty;
        } else if (actual is List) {
          passed = actual.isNotEmpty;
        } else if (actual is Map) {
          passed = actual.isNotEmpty;
        } else {
          passed = true;
        }
        if (!passed) error = "Expected to be not empty";
        break;
      case 'startsWith':
        passed = actual.toString().startsWith(expected);
        if (!passed) error = "Expected starts with '$expected'";
        break;
      case 'endsWith':
        passed = actual.toString().endsWith(expected);
        if (!passed) error = "Expected ends with '$expected'";
        break;
      case 'matches':
        try {
          final reg = RegExp(expected);
          passed = reg.hasMatch(actual.toString());
          if (!passed) error = "Expected to match regex '$expected'";
        } catch (e) {
          error = "Invalid Regex: $e";
        }
        break;
      case 'isString':
        passed = actual is String;
        if (!passed) error = "Expected String type";
        break;
      case 'isNumber':
        passed = actual is num;
        if (!passed) error = "Expected Number type";
        break;
      case 'isBoolean':
        passed = actual is bool;
        if (!passed) error = "Expected Boolean type";
        break;
      case 'isList':
        passed = actual is List;
        if (!passed) error = "Expected List/Array type";
        break;
      case 'isMap':
        passed = actual is Map;
        if (!passed) error = "Expected Map/Object type";
        break;
      case 'hasKey':
        if (actual is Map) {
          passed = actual.containsKey(expected);
          if (!passed) error = "Expected to have key '$expected'";
        } else {
          error = "Actual value is not a Map";
        }
        break;
      case 'doesNotHaveKey':
        if (actual is Map) {
          passed = !actual.containsKey(expected);
          if (!passed) error = "Expected to not have key '$expected'";
        } else {
          error = "Actual value is not a Map";
        }
        break;
      case 'hasValue':
        if (actual is Map) {
          passed = actual.containsValue(expected);
          if (!passed) error = "Expected to have value '$expected'";
        } else {
          error = "Actual value is not a Map";
        }
        break;
      case 'containsAll':
        if (actual is List) {
          try {
            final expectedList = jsonDecode(expected) as List;
            passed = expectedList.every((expItem) {
              return actual.any((actItem) => _deepEquals(actItem, expItem));
            });
            if (!passed) {
              error =
                  "Expected to contain all of $expected but some are missing";
            }
          } catch (e) {
            error = "Invalid JSON array for containsAll: $e";
          }
        } else {
          error = "Actual value is not a List";
        }
        break;
      case 'containsAny':
        if (actual is List) {
          try {
            final expectedList = jsonDecode(expected) as List;
            passed = expectedList.any((expItem) {
              return actual.any((actItem) => _deepEquals(actItem, expItem));
            });
            if (!passed) error = "Expected to contain any of $expected";
          } catch (e) {
            error = "Invalid JSON array for containsAny: $e";
          }
        } else {
          error = "Actual value is not a List";
        }
        break;
      case 'oneOf':
        final list = expected.split(',').map((e) => e.trim()).toList();
        passed = list.contains(actual.toString());
        if (!passed) error = "Expected one of $list but got $actual";
        break;
      case 'closeTo':
        try {
          final parts = expected.split(',');
          if (parts.length == 2 && actual is num) {
            final target = double.parse(parts[0].trim());
            final delta = double.parse(parts[1].trim());
            final diff = (actual - target).abs();
            passed = diff <= delta;
            if (!passed)
              error =
                  "Expected $actual to be close to $target +/- $delta (diff: $diff)";
          } else {
            error = "Invalid format for closeTo (expected 'target,delta')";
          }
        } catch (e) {
          error = "Invalid closeTo arguments: $e";
        }
        break;
      case 'length':
        int? len;
        if (actual is List) len = actual.length;
        if (actual is String) len = actual.length;
        if (actual is Map) len = actual.length;

        if (len != null) {
          passed = len.toString() == expected.toString();
          if (!passed) error = "Expected length $expected but got $len";
        } else {
          error = "Actual value (type: ${actual.runtimeType}) has no length";
        }
        break;
      case 'within':
        try {
          final parts = expected.split(',');
          if (parts.length == 2 && actual is num) {
            final min = double.parse(parts[0].trim());
            final max = double.parse(parts[1].trim());
            passed = actual >= min && actual <= max;
            if (!passed) error = "Expected $actual to be within $min..$max";
          } else {
            error = "Invalid format for within (expected 'min,max')";
          }
        } catch (e) {
          error = "Invalid within arguments: $e";
        }
        break;
      case 'hasKeyValue':
        if (actual is Map) {
          final splitIndex = expected.indexOf(':');
          if (splitIndex != -1) {
            final key = expected.substring(0, splitIndex).trim();
            final valueStr = expected.substring(splitIndex + 1).trim();
            if (actual.containsKey(key)) {
              passed = actual[key].toString() == valueStr;
              if (!passed)
                error =
                    "Expected key '$key' to have value '$valueStr' but got '${actual[key]}'";
            } else {
              error = "Map does not contain key '$key'";
            }
          } else {
            error = "Invalid format for hasKeyValue (expected 'key:value')";
          }
        } else {
          error = "Actual value is not a Map";
        }
        break;

      default:
        error = "Unknown operator: $op";
    }

    results.add(
      TestResult(
        description: "${def.expression} ${def.operator} ${def.expectedValue}",
        status: passed ? 'passed' : 'failed',
        error: error,
      ),
    );
  }

  static bool _deepEquals(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return false;
  }

  static AssertionInspection inspectPath(
    String expression,
    RawHttpResponse res, {
    Map<String, dynamic>? jsonBody,
  }) {
    String exp = expression.trim();
    dynamic value;
    List<String> suggestions = [];
    String validExp = exp;
    String pendingExp = "";

    // 1. Try exact match first
    value = _getActualValue(exp, res, jsonBody);

    // 2. If null, try to find the longest valid parent path
    if (value == null && exp.contains('.')) {
      final parts = exp.split('.');
      for (int i = parts.length - 1; i >= 0; i--) {
        final subPath = parts.sublist(0, i).join('.');
        if (subPath.isEmpty) continue;

        final subVal = _getActualValue(subPath, res, jsonBody);
        if (subVal != null) {
          value = subVal;
          validExp = subPath;
          pendingExp = exp.substring(validExp.length);
          break;
        }
      }
    }

    // 3. If still null (and no parent found), maybe it's just root 'res' or 'req'
    if (value == null) {
      if (exp.startsWith('res')) {
        value = res.toJsMap();
        validExp = 'res';
        pendingExp = exp.substring(3);
      } else if (exp.startsWith('req')) {
        value = fakeReq;
        validExp = 'req';
        pendingExp = exp.substring(3);
      }
    }

    // 4. Generate Suggestions based on the resolved value
    if (value is Map) {
      suggestions = value.keys.map((e) => e.toString()).toList();
    } else if (value is RawHttpResponse) {
      // Should not happen as we convert toJsMap, but safety check
      suggestions = ['statusCode', 'body', 'headers', 'responseTime'];
    }

    // Filter suggestions if there is a pending partial input
    // e.g. valid: res.body (Map), pending: "use" -> suggest "username", "userID"
    // e.g. valid: res.body (Map), pending: "use" -> suggest "username", "userID"
    if (pendingExp.isNotEmpty) {
      String search = pendingExp;
      if (search.startsWith('.')) {
        search = search.substring(1);
      }

      final firstPending = search.split('.').first;
      suggestions = suggestions
          .where((s) => s.toLowerCase().contains(firstPending.toLowerCase()))
          .toList();
    }

    return AssertionInspection(
      value: value,
      validExpression: validExp,
      pendingExpression: pendingExp,
      suggestions: suggestions,
    );
  }
}

class AssertionInspection {
  final dynamic value;
  final String validExpression;
  final String pendingExpression;
  final List<String> suggestions;

  AssertionInspection({
    this.value,
    required this.validExpression,
    required this.pendingExpression,
    this.suggestions = const [],
  });
}
