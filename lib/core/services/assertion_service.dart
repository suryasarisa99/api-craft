import 'dart:convert';
import 'package:api_craft/features/request/models/node_config_model.dart';
import 'package:api_craft/features/response/models/http_response_model.dart';
import 'package:flutter/widgets.dart';

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
    final exp = expression.trim();
    if (exp == 'res') {
      return res.toJsMap();
    }
    if (exp == 'res.status' || exp == 'res.statusCode') {
      return res.statusCode;
    } else if (exp == 'res.responseTime') {
      return res.durationMs;
    } else if (exp.startsWith('res.body')) {
      if (exp == 'res.body') return res.body;
      // Handle res.body.token or res.body['token']
      // Simple parsing: remove 'res.body.' and treat rest as key path
      if (jsonBody == null) return null;
      final path = exp.replaceFirst('res.body.', '');
      return _getValueFromPath(jsonBody, path);
    } else if (exp == "res.headers") {
      return res.headers;
    } else if (exp.startsWith('res.headers')) {
      // res.headers['content-type']
      // Simplified: res.headers.content-type
      final path = exp
          .replaceFirst(RegExp(r'^res\.headers[\.\[]'), '')
          .replaceAll(
            RegExp(
              r'[\]"'
              "'"
              '\\s]',
            ),
            '',
          );
      // Headers is List<List<String>>
      // Find header
      final header = res.headers.firstWhere(
        (h) => h[0].toLowerCase() == path.toLowerCase(),
        orElse: () => [],
      );
      return header.isNotEmpty ? header[1] : null;
    }
    return null;
  }

  static dynamic _getValueFromPath(Map<String, dynamic> data, String path) {
    final parts = path.split('.');
    dynamic current = data;
    for (final part in parts) {
      if (current == null) return null;

      // Special properties
      if (part == 'length') {
        if (current is List) return current.length;
        if (current is String) return current.length;
        if (current is Map) return current.length;
      }

      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index != null && index >= 0 && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return current;
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
}
