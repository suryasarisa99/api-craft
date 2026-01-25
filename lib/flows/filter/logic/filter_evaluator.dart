import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/network/header_utils.dart';
import 'package:api_craft/core/utils/parsers.dart';
import 'package:api_craft/flows/filter/models/m.dart';
import 'package:api_craft/flows/models/flow.dart';

class FilterEvaluator {
  static bool evaluate(FilterCondition condition, HttpFlow flow) {
    // 1. Extract value based on field
    dynamic actualValue = extractValue(flow, condition.field);

    // 2. If boolean field, we don't use operator/value (usually)
    if (condition.field.type == FilterFieldType.bool) {
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
          return compareString(fullString, condition.value, condition.operator);
        }
        return compareString(
          item.toString(),
          condition.value,
          condition.operator,
        );
      });
    }

    // Handle Num comparisons
    if (condition.field.type == FilterFieldType.num) {
      final num? numVal = actualValue is num
          ? actualValue
          : num.tryParse(actualValue.toString());
      if (numVal == null) return false;

      // Handle 'between' operator specially as it needs split
      if (condition.operator == FilterOperator.between) {
        final parts = condition.value.split(','); // simple split
        if (parts.length >= 2) {
          final start = num.tryParse(parts[0].trim());
          final end = num.tryParse(parts[1].trim());
          if (start != null && end != null) {
            return numVal >= start && numVal <= end;
          }
        }
        return false;
      }

      // Handle 'inListNum' operator
      if (condition.operator == FilterOperator.inListNum) {
        final parts = condition.value.split(',');
        return parts.any((p) {
          final n = num.tryParse(p.trim());
          return n != null && n == numVal;
        });
      }

      final num? targetNum = num.tryParse(condition.value);
      if (targetNum == null) return false;

      switch (condition.operator) {
        case FilterOperator.numEquals:
          return numVal == targetNum;
        case FilterOperator.lessThan:
          return numVal < targetNum;
        case FilterOperator.lessThanOrEqual:
          return numVal <= targetNum;
        case FilterOperator.greaterThan:
          return numVal > targetNum;
        case FilterOperator.greaterThanOrEqual:
          return numVal >= targetNum;
        default:
          return false;
      }
    }

    // Handle String comparisons
    return compareString(
      actualValue.toString(),
      condition.value,
      condition.operator,
    );
  }

  static bool compareString(String actual, String target, FilterOperator op) {
    switch (op) {
      case FilterOperator.regex:
        try {
          return RegExp(target, caseSensitive: false).hasMatch(actual);
        } catch (e) {
          return false;
        }
      case FilterOperator.equals:
        return actual.toLowerCase() == target.toLowerCase();
      case FilterOperator.contains:
        return actual.toLowerCase().contains(target.toLowerCase());
      case FilterOperator.startsWith:
        return actual.toLowerCase().startsWith(target.toLowerCase());
      case FilterOperator.endsWith:
        return actual.toLowerCase().endsWith(target.toLowerCase());
      case FilterOperator.inListStr:
        final parts = target.split(',');
        return parts.any((p) => p.trim().toLowerCase() == actual.toLowerCase());
      default:
        return false;
    }
  }

  static dynamic extractValue(HttpFlow flow, FilterField field) {
    final req = flow.request;
    final res = flow.response;
    final uri = req != null ? Uri.tryParse(req.url) : null;

    switch (field) {
      case FilterField.all:
        return true;
      case FilterField.contentType:
        return [
          HeaderUtils.getValue(req?.headers ?? [], 'content-type'),
          HeaderUtils.getValue(res?.headers ?? [], 'content-type'),
        ];
      // --- req ---
      case FilterField.url:
        return req?.url;
      case FilterField.method:
        return req?.method;
      case FilterField.domain:
        return uri?.host;
      case FilterField.path:
        return uri?.path;
      case FilterField.query:
        return uri?.query;
      case FilterField.fileExtension:
        if (uri == null) return null;
        final path = uri.path;
        final idx = path.lastIndexOf('.');
        return idx != -1 ? path.substring(idx + 1) : '';
      case FilterField.reqContentType:
        return HeaderUtils.getValue(req?.headers ?? [], 'content-type');

      // --- res ---
      case FilterField.res:
        return res != null;
      case FilterField.statusCode:
        return res?.statusCode;
      case FilterField.asset:
        return false; // Valid TODO
      case FilterField.reqWithNoRes:
        return res == null;
      case FilterField.error:
        return false;
      case FilterField.resContentType:
        return HeaderUtils.getValue(res?.headers ?? [], 'content-type');

      // Headers
      case FilterField.reqHeader:
        return req?.headers; // List<KeyValueItem>
      case FilterField.resHeader:
        return res?.headers; // List<KeyValueItem>
      case FilterField.header:
        // Combine lists
        return [...?req?.headers, ...?res?.headers];

      // Body
      case FilterField.reqBody:
        // body is OngoingBody. Not easily synchronous string.
        // Returning null for now to avoid async complexity in synchronous matches()
        return null;
      case FilterField.resBody:
        // body is CompletedBody? FlowResponse has `CompletedBody? body`.
        // CompletedBody likely has text/bytes.
        return res?.body?.toString(); // dangerous if toString() isn't content
      case FilterField.body:
        return null;

      case FilterField.marked:
        return false;

      // TODO: Implement others properly
      default:
        return null;
    }
  }
}
