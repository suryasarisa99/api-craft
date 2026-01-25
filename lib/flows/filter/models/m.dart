import 'package:api_craft/flows/models/flow.dart';
import 'package:api_craft/flows/filter/logic/filter_evaluator.dart';

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
  url('url'),
  method('method'),
  domain('domain'),
  reqHeader('req-header'),
  reqBody('req-body'),
  reqContentType('req-content-type'),
  reqWithNoRes('no-response', type: .bool),

  // --- res ---
  res('res', type: .bool),
  statusCode('status-code', type: .num),
  asset('asset', type: .bool),
  resHeader('res-header'),
  resBody('res-body'),
  resContentType('res-content-type'),

  // --- Combined ---
  header('header'),
  body('body'),
  contentType('content-type'),

  // --- Connection ---
  sourceAddress('src-addr'),
  destinationAddress('dst-addr'),
  error('error', type: .bool),

  // --- Replay ---
  replayedFlow('replay', type: .bool),
  replayedReq('replay-req', type: .bool),
  replayedRes('replay-res', type: .bool),

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
  queryKey('query-key'),
  queryValue('query-value'),

  // --- Script ---
  script('script', type: .str);

  const FilterField(this.prettyName, {this.type = .str});
  final String prettyName;
  final FilterFieldType type;
}

enum FilterOperator {
  // str and (may also be number)
  regex('~', FilterFieldType.str, 'Regex'),
  equals('=', FilterFieldType.str, 'Equals'),
  contains(':', FilterFieldType.str, 'Contains'),
  startsWith('^', FilterFieldType.str, 'Starts With'),
  endsWith('\$', FilterFieldType.str, 'Ends With'),
  inListStr('in', FilterFieldType.str, 'In List'),

  // num operators
  numEquals('=', FilterFieldType.num, 'Equals'),
  lessThan('<', FilterFieldType.num, 'Less Than'),
  lessThanOrEqual('<=', FilterFieldType.num, 'Less Than Or Equal'),
  greaterThan('>', FilterFieldType.num, 'Greater Than'),
  greaterThanOrEqual('>=', FilterFieldType.num, 'Greater Than Or Equal'),
  between('<>', FilterFieldType.num, 'Between'),
  inListNum('in', FilterFieldType.num, 'In List');

  const FilterOperator(this.symbol, this.supportedType, this.label);
  final String symbol;
  final FilterFieldType supportedType;
  final String label;
}

/// Base class for all nodes in the filter tree.
abstract class FilterNode {
  bool isNegated = false;
  // A unique object for making sure widgets have stable keys during rebuilds.
  final Object key = Object();

  Future<bool> matches(HttpFlow flow, {dynamic jsSession});
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
  Future<bool> matches(HttpFlow flow, {dynamic jsSession}) async {
    // If it's a script field, we need a session
    if (field == FilterField.script && jsSession != null) {
      if (value.trim().isEmpty) return true;
      // We assume jsSession is JsFilterSession (dynamic to avoid circ dep if needed, but imported models usually safe)
      // Actually JsEngine imports m.dart? No. models imports engine? No.
      // We can pass it as dynamic or abstract interface if we want clean arch,
      // but for now dynamic with runtime check is practical.
      try {
        return await (jsSession as dynamic).evaluate(value, flow);
      } catch (e) {
        return false;
      }
    }

    bool result = FilterEvaluator.evaluate(this, flow);
    return isNegated ? !result : result;
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
  Future<bool> matches(HttpFlow flow, {dynamic jsSession}) async {
    if (children.isEmpty) return true;

    // Evaluate first child
    bool result = await children[0].matches(flow, jsSession: jsSession);

    for (int i = 0; i < operators.length; i++) {
      final op = operators[i];
      final nextResult = await children[i + 1].matches(
        flow,
        jsSession: jsSession,
      );

      if (op == LogicalOperator.and) {
        result = result && nextResult;
      } else {
        result = result || nextResult;
      }
    }

    return isNegated ? !result : result;
  }
}
