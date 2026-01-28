import 'package:api_craft/shared/filter_conditions/models/filter_enums.dart';
import 'package:api_craft/traffic/interception_rules/interception_script_service.dart';
import 'package:api_craft/shared/filter_conditions/models/filter_models.dart';
import 'package:mockhttp/rules/request_matcher.dart';

class FilterConvert {
  static RequestMatcher toRequestMatcher(FilterNode node) {
    if (node is FilterGroup) {
      if (node.children.isEmpty) {
        return RequestMatcher.all(
          [],
        ); // Matches everything usually? Or nothing? Empty AND is true.
      }

      // FilterGroup mixes AND/OR based on 'operators' list.
      // RequestMatcher logic typically groups all-AND or all-OR.
      // If the group has mixed operators, strictly speaking we need to respect precedence.
      // But FilterGroup logic in m.dart evaluates sequentially: result = result OP next.
      // Valid mapping:
      // A AND B OR C -> ((A AND B) OR C)
      // This is left-associative.

      RequestMatcher current = toRequestMatcher(node.children[0]);

      for (int i = 0; i < node.operators.length; i++) {
        final op = node.operators[i];
        final nextMatcher = toRequestMatcher(node.children[i + 1]);

        if (op == LogicalOperator.and) {
          current = current.and(nextMatcher);
        } else {
          current = current.or(nextMatcher);
        }
      }

      if (node.isNegated) {
        current = current.not();
      }

      return current;
    } else if (node is FilterCondition) {
      RequestMatcher matcher = _conditionToMatcher(node);
      if (node.isNegated) {
        matcher = matcher.not();
      }
      return matcher;
    }

    throw UnimplementedError("Unknown FilterNode type");
  }

  static RequestMatcher _conditionToMatcher(FilterCondition condition) {
    // 1. Convert Operator + Value to Expr
    final expr = _toExpr(
      condition.operator,
      condition.value,
      condition.field.type,
    );

    // 2. Map Field to RequestMatcher factory
    switch (condition.field) {
      // --- Request ---
      case .url:
        // Expr<String> required
        return RequestMatcher.url(expr as Expr<String>);

      case .method:
        return RequestMatcher.method(expr as Expr<String>);

      case .domain:
        return RequestMatcher.domain(expr as Expr<String>);

      case .path:
        return RequestMatcher.path(expr as Expr<String>);

      case .query:
        // We only support checking the raw query string with this mapping?
        // RequestMatcher.query(key, value) requires a key.
        // .query matches the entire query string.
        // We might need a custom function matcher for full query string match,
        // OR strict parsing if condition value is "key=value".
        // Let's use custom function for full query string match.
        return _customQueryStringMatcher(expr as Expr<String>);

      case .queryKey:
        // Matches if ANY query param key matches?
        // RequestMatcher.query(key) can check existence.
        // But condition.value is the key to check?
        // "queryKey equals 'id'" -> check if query param 'id' exists.
        // The 'expr' is built from 'value'. So we check if query key matches 'expr'?
        // That implies iterating all keys.
        return _customQueryKeyMatcher(expr as Expr<String>);

      case .reqHeader:
        // Expect "Key: Value" or just "Key" or just "Value"?
        // If generic text search, assume "Key: Value" or fallback to custom searches.
        // Let's try to split by first colon.
        final parts = condition.value.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final valStr = parts.sublist(1).join(':').trim();
          // Re-create expression for the value part if operator allows?
          // Complex. If op is 'contains', we check if header value contains valStr.
          // Let's try to target the header 'key' and apply operator to 'valStr'.
          // But wait, the `expr` created above used the FULL string.
          // We should regenerate expr for the value part.
          final valueExpr =
              _toExpr(condition.operator, valStr, FilterFieldType.str)
                  as Expr<String>;
          return RequestMatcher.header(key, valueExpr);
        } else {
          // Treating as checking if ANY header line matches...
          // e.g. "application/json" contains...
          return _customHeaderLineMatcher(
            expr as Expr<String>,
            isResponse: false,
          );
        }

      case .reqBody:
        return RequestMatcher.body(expr as Expr<String>);

      // --- Response ---
      case .statusCode:
        return RequestMatcher.status(expr as Expr<num>);

      case .resHeader:
        final parts = condition.value.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final valStr = parts.sublist(1).join(':').trim();
          final valueExpr =
              _toExpr(condition.operator, valStr, FilterFieldType.str)
                  as Expr<String>;
          return RequestMatcher.resHeader(key, valueExpr);
        } else {
          return _customHeaderLineMatcher(
            expr as Expr<String>,
            isResponse: true,
          );
        }

      case .resBody:
        return RequestMatcher.resBody(expr as Expr<String>);

      // --- Script ---
      case .script:
        final script = condition.value;
        if (script.trim().isEmpty) {
          return RequestMatcher.fn((_, _) => true);
        }

        return RequestMatcher.fn((req, [res]) async {
          return InterceptionScriptService.instance.evaluate(script, req, res);
        });

      // --- Fallbacks / Not Supported on Server ---
      default:
        // E.g. sourceAddress, destinationAddress, time...
        // might not be supported by basic RequestMatcher builders yet.
        // Return a fallback that always matches (or never)?
        // Better to warn or error?
        return RequestMatcher.fn(
          (_, _) => true,
        ); // Default to true for unsupported fields
    }
  }

  static Expr _toExpr(FilterOperator op, String value, FilterFieldType type) {
    // Handle Numeric
    if (type == FilterFieldType.num) {
      // numEquals, lessThan...
      if (op == FilterOperator.between) {
        final parts = value.split(',');
        final min = num.tryParse(parts[0].trim()) ?? 0;
        final max =
            num.tryParse(
              parts.length > 1 ? parts[1].trim() : parts[0].trim(),
            ) ??
            0;
        return Expr.between(min, max);
      }
      if (op == FilterOperator.inListNum) {
        final list = value
            .split(',')
            .map((e) => num.tryParse(e.trim()) ?? 0)
            .toList();
        return Expr.oneOf<num>(list);
      }

      final numVal = num.tryParse(value) ?? 0;
      switch (op) {
        case .numEquals:
          return Expr.eq<num>(numVal);
        case .lessThan:
          return Expr.lt(numVal);
        case .lessThanOrEqual:
          return Expr.lte(numVal);
        case .greaterThan:
          return Expr.gt(numVal);
        case .greaterThanOrEqual:
          return Expr.gte(numVal);
        default:
          return Expr.eq<num>(numVal);
      }
    }

    // Handle String
    switch (op) {
      case .equals:
        return Expr.eq<String>(value);
      case .contains:
        return Expr.contains(value);
      case .startsWith:
        return Expr.startsWith(value);
      case .endsWith:
        return Expr.endsWith(value);
      case .regex:
        return Expr.regexp(value);
      case .inListStr:
        return Expr.oneOf<String>(
          value.split(',').map((e) => e.trim()).toList(),
        );
      default:
        return Expr.contains(value);
    }
  }

  static RequestMatcher _customQueryStringMatcher(Expr<String> expr) {
    return RequestMatcher.fn((req, _) {
      final uri = Uri.parse(
        req.url,
      ); // Parsing might be redundant if req object handles it, but OngoingRequest has url string.
      // or req.url contains query? Yes.
      // But wait, RequestMatcher.url matches full URL.
      // FilterField.query matches ONLY the query string part.
      return expr.matches(uri.query);
    });
  }

  static RequestMatcher _customQueryKeyMatcher(Expr<String> expr) {
    return RequestMatcher.fn((req, _) {
      final uri = Uri.parse(req.url);
      return uri.queryParameters.keys.any((k) => expr.matches(k));
    });
  }

  static RequestMatcher _customHeaderLineMatcher(
    Expr<String> expr, {
    required bool isResponse,
  }) {
    if (!isResponse) {
      return RequestMatcher.fn((req, _) {
        // req.headers is List<List<String>> e.g. [[key, val], ...]
        return req.headers.any((h) => expr.matches('${h[0]}: ${h[1]}'));
      });
    } else {
      // response matching
      return RequestMatcher.fn((res, _) {
        return res.headers.any((h) => expr.matches('${h[0]}: ${h[1]}'));
      });
    }
  }
}
