import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/utils/parsers.dart';
import 'package:api_craft/shared/filter_conditions/models/filter_enums.dart';
import 'package:api_craft/shared/filter_conditions/models/filter_models.dart';
import 'package:api_craft/traffic/flows/models/flow.dart';

class FilterEvaluator {
  static bool evaluate(FilterCondition condition, HttpFlow flow) {
    // 1. Extract value based on field
    dynamic actualValue = extractValue(flow, condition.field);

    // 2. If boolean field, we don't use operator/value (usually)
    if (condition.field.type == .bool) {
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
    if (condition.field.type == .num) {
      final num? numVal = actualValue is num
          ? actualValue
          : num.tryParse(actualValue.toString());
      if (numVal == null) return false;

      // Handle 'between' operator specially as it needs split
      if (condition.operator == .between) {
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
      if (condition.operator == .inListNum) {
        final parts = condition.value.split(',');
        return parts.any((p) {
          final n = num.tryParse(p.trim());
          return n != null && n == numVal;
        });
      }

      final num? targetNum = num.tryParse(condition.value);
      if (targetNum == null) return false;

      switch (condition.operator) {
        case .numEquals:
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
    return compareString(
      actualValue.toString(),
      condition.value,
      condition.operator,
    );
  }

  static bool compareString(String actual, String target, FilterOperator op) {
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
      case .inListStr:
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
      case .all:
        return true;
      case .contentType:
        return [
          HeaderUtils.getValue(req?.headers ?? [], 'content-type'),
          HeaderUtils.getValue(res?.headers ?? [], 'content-type'),
        ];
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
      case .reqContentType:
        return HeaderUtils.getValue(req?.headers ?? [], 'content-type');

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
      case .resContentType:
        return HeaderUtils.getValue(res?.headers ?? [], 'content-type');

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
