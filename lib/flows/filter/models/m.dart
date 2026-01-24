import 'package:api_craft/flows/models/flow.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:flutter/material.dart';

enum LogicalOperator { and, or }

enum FilterFieldType { num, str, bool }

enum FilterField {
  // --- General ---
  all('all', type: .bool),
  comment('comment'),
  marked('marked', type: .bool),
  marker('marker'),
  metadata('meta'),

  // --- req ---
  url('u'),
  method('m'),
  domain('d'),
  reqHeader('hq'),
  reqBody('bq'),
  reqContentType('tq'),
  reqWithNoRes('q', type: .bool),

  // --- res ---
  res('s', type: .bool),
  statusCode('c', type: .num),
  asset('a', type: .bool),
  resHeader('hs'),
  resBody('bs'),
  resContentType('ts'),

  // --- Combined ---
  header('h'),
  body('b'),
  contentType('t'),

  // --- Connection ---
  sourceAddress('src'),
  destinationAddress('dst'),
  error('e', type: .bool),

  // --- Replay ---
  replayedFlow('replay', type: .bool),
  replayedReq('replayq', type: .bool),
  replayedRes('replays', type: .bool),

  // --- Protocols ---
  http('http', type: .bool),
  tcp('tcp', type: .bool),
  udp('udp', type: .bool),
  dns('dns', type: .bool),
  websocket('websocket', type: .bool),

  // --- Custom Filters on url ---
  fileExtension('ext'),
  path('path'),
  query('query'),
  queryKey('qk'),
  queryValue('qv');

  const FilterField(this.prettyName, {this.type = .str});
  final String prettyName;
  final FilterFieldType type;
}

enum FilterOperator {
  // str and (may also be number)
  regex('~', [.str, .num]),
  equals('=', [.str, .num]),
  contains(':', [.str, .num]),
  startsWith('^', [.str, .num]),
  endsWith('\$', [.str, .num]),

  // num operators
  lessThan('<', [.num]),
  lessThanOrEqual('<=', [.num]),
  greaterThan('>', [.num]),
  greaterThanOrEqual('>=', [.num]);

  const FilterOperator(this.symbol, this.supportedTypes);
  final String symbol;
  final List<FilterFieldType> supportedTypes;
}

/// Base class for all nodes in the filter tree.
abstract class FilterNode {
  bool isNegated = false;
  // A unique object for making sure widgets have stable keys during rebuilds.
  final Object key = Object();

  bool matches(HttpFlow flow);
}

/// A leaf node representing a single filter condition (e.g., "~u example.com").
class FilterCondition extends FilterNode {
  FilterField field;
  FilterOperator operator;
  String value;

  FilterCondition({
    this.field = FilterField.url,
    this.operator = FilterOperator.contains,
    this.value = '',
  });

  FilterCondition.fromJson(Map<String, dynamic> json)
    : field = FilterField.values.firstWhere(
        (k) => k.toString().split('.').last == json['field'] as String,
      ),
      operator = FilterOperator.values.firstWhere(
        (op) => op.toString().split('.').last == json['operator'] as String,
      ),
      value = json['value'] as String {
    isNegated = json['isNegated'] as bool? ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'isNegated': isNegated,
      'field': field.toString().split('.').last,
      'operator': operator.toString().split('.').last,
      'value': value,
      'type': 'condition',
    };
  }

  @override
  bool matches(HttpFlow flow) {
    bool result = _evaluate(flow);
    return isNegated ? !result : result;
  }

  bool _evaluate(HttpFlow flow) {
    // 1. Extract value based on field
    dynamic actualValue = _extractValue(flow, field);

    // 2. If boolean field, we don't use operator/value (usually)
    if (field.type == FilterFieldType.bool) {
      if (actualValue is bool) return actualValue;
      return false;
    }

    // 3. Compare using operator
    if (actualValue == null) return false;

    // Handle List comparisons (e.g. Headers)
    if (actualValue is List) {
      return actualValue.any((item) {
        if (item is KeyValueItem) {
          // Check Key or Value or "Key: Value" string?
          // Simplest helpful logic for generic header search:
          // If value is "json", match "Content-Type: application/json" (contains) or just "application/json".
          // Let's check against formatted string "$key: $value"
          final fullString = '${item.key}: ${item.value}';
          return _compareString(fullString, value, operator);
        }
        return _compareString(item.toString(), value, operator);
      });
    }

    // Handle Num comparisons
    if (field.type == FilterFieldType.num) {
      final num? numVal = actualValue is num
          ? actualValue
          : num.tryParse(actualValue.toString());
      if (numVal == null) return false;

      final num? targetNum = num.tryParse(value);
      // For string ops on numbers (like regex on status code), convert to string
      if (['~', ':', '^', '\$', '='].contains(operator.symbol)) {
        return _compareString(actualValue.toString(), value, operator);
      }

      if (targetNum == null) return false;

      switch (operator) {
        case .equals:
          return numVal == targetNum;
        case .lessThan:
          return numVal < targetNum;
        case .lessThanOrEqual:
          return numVal <= targetNum;
        case .greaterThan:
          return numVal > targetNum;
        case .greaterThanOrEqual:
          return numVal >= targetNum;
        default:
          return false;
      }
    }

    // Handle String comparisons
    return _compareString(actualValue.toString(), value, operator);
  }

  bool _compareString(String actual, String target, FilterOperator op) {
    switch (op) {
      case .regex:
        try {
          return RegExp(target, caseSensitive: false).hasMatch(actual);
        } catch (e) {
          return false;
        }
      case .equals:
        return actual.toLowerCase() == target.toLowerCase();
      case .contains:
        return actual.toLowerCase().contains(target.toLowerCase());
      case .startsWith:
        return actual.toLowerCase().startsWith(target.toLowerCase());
      case .endsWith:
        return actual.toLowerCase().endsWith(target.toLowerCase());
      default:
        return false;
    }
  }

  dynamic _extractValue(HttpFlow flow, FilterField field) {
    final req = flow.request;
    final res = flow.response;
    final uri = req != null ? Uri.tryParse(req.url) : null;

    switch (field) {
      case .all:
        return true;
      // --- req ---
      case .url:
        return req?.url;
      case .method:
        return req?.method;
      case .domain:
        return uri?.host;
      case .path:
        return uri?.path;
      case .query:
        return uri?.query;
      case .fileExtension:
        if (uri == null) return null;
        final path = uri.path;
        final idx = path.lastIndexOf('.');
        return idx != -1 ? path.substring(idx + 1) : '';

      // --- res ---
      case .res:
        return res != null;
      case .statusCode:
        return res?.statusCode;
      case .asset:
        return false; // Valid TODO
      case .reqWithNoRes:
        return res == null;
      case .error:
        return false;

      // Headers
      case .reqHeader:
        return req?.headers; // List<KeyValueItem>
      case .resHeader:
        return res?.headers; // List<KeyValueItem>
      case .header:
        // Combine lists
        return [...?req?.headers, ...?res?.headers];

      // Body
      case .reqBody:
        // body is OngoingBody. Not easily synchronous string.
        // Returning null for now to avoid async complexity in synchronous matches()
        return null;
      case .resBody:
        // body is CompletedBody? FlowResponse has `CompletedBody? body`.
        // CompletedBody likely has text/bytes.
        return res?.body?.toString(); // dangerous if toString() isn't content
      case .body:
        return null;

      case .marked:
        return false;

      // TODO: Implement others properly
      default:
        return null;
    }
  }
}

/// An internal node representing a group of conditions or other groups.
class FilterGroup extends FilterNode {
  List<LogicalOperator> operators;
  List<FilterNode> children;

  FilterGroup({required this.children, List<LogicalOperator>? operators})
    : operators =
          operators ??
          List.filled(
            children.isNotEmpty ? children.length - 1 : 0,
            LogicalOperator.and,
            growable: true,
          );

  Map<String, dynamic> toJson() {
    return {
      'type': 'group',
      'isNegated': isNegated,
      'operators': operators
          .map((op) => op.toString().split('.').last)
          .toList(),
      'children': children.map((child) {
        if (child is FilterCondition) {
          return child.toJson();
        } else if (child is FilterGroup) {
          return child.toJson();
        }
        throw Exception('Unknown FilterNode type');
      }).toList(),
    };
  }

  factory FilterGroup.fromJson(Map<String, dynamic> json) {
    return FilterGroup(
      children: (json['children'] as List<dynamic>).map((childJson) {
        final childMap = Map<String, dynamic>.from(childJson);
        if (childMap['type'] == 'condition') {
          return FilterCondition.fromJson(childMap);
        } else if (childMap['type'] == 'group') {
          return FilterGroup.fromJson(childMap);
        }
        throw Exception('Unknown FilterNode type in JSON');
      }).toList(),
      operators: (json['operators'] as List<dynamic>)
          .map(
            (op) => LogicalOperator.values.firstWhere(
              (o) => o.toString().split('.').last == op as String,
            ),
          )
          .toList(),
    )..isNegated = json['isNegated'] as bool;
  }

  //copy
  FilterGroup copy() {
    return FilterGroup(
      children: children.map((child) {
        if (child is FilterCondition) {
          return FilterCondition(
            field: child.field,
            operator: child.operator,
            value: child.value,
          )..isNegated = child.isNegated;
        } else if (child is FilterGroup) {
          return child.copy();
        }
        throw Exception('Unknown FilterNode type');
      }).toList(),
      operators: List<LogicalOperator>.from(operators),
    )..isNegated = isNegated;
  }

  @override
  bool matches(HttpFlow flow) {
    if (children.isEmpty) return true;

    // Evaluate first child
    bool result = children[0].matches(flow);

    for (int i = 0; i < operators.length; i++) {
      final op = operators[i];
      final nextResult = children[i + 1].matches(flow);

      if (op == .and) {
        result = result && nextResult;
      } else {
        result = result || nextResult;
      }
    }

    return isNegated ? !result : result;
  }
}
