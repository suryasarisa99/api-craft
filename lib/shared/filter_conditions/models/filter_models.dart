import 'package:api_craft/shared/filter_conditions/models/filter_enums.dart';
import 'package:api_craft/traffic/flows/models/flow.dart';
import 'package:api_craft/traffic/filter/logic/filter_evaluator.dart';

/// Base class for all nodes in the filter tree.
abstract class FilterNode {
  bool isNegated = false;
  // A unique object for making sure widgets have stable keys during rebuilds.
  final Object key = Object();

  Future<bool> matches(HttpFlow flow, {dynamic jsSession});
  FilterNode copy();
  Map<String, dynamic> toJson();
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

  @override
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
  FilterCondition copy() {
    return FilterCondition(field: field, operator: operator, value: value)
      ..isNegated = isNegated;
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

  @override
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
  @override
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
