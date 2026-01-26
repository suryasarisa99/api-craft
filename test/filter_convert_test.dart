import 'package:flutter_test/flutter_test.dart';
import 'package:api_craft/flows/filter/models/m.dart';
import 'package:api_craft/flows/filter/filter_converter.dart';
// import 'package:mockhttp/rules/request_matcher.dart'; // Transitive via filter_converter? Or need direct import for types?

void main() {
  group('FilterConvert', () {
    test('converts simple URL contains condition', () {
      final condition = FilterCondition(
        field: FilterField.url,
        operator: FilterOperator.contains,
        value: 'example.com',
      );

      final matcher = FilterConvert.toRequestMatcher(condition);
      final json = matcher.toJson();

      expect(json['type'], 'url');
      expect(json['pattern']['value'], 'example.com');
      expect(json['pattern']['type'], 'contains');
    });

    test('converts method equals condition', () {
      final condition = FilterCondition(
        field: FilterField.method,
        operator: FilterOperator.equals,
        value: 'GET',
      );
      final matcher = FilterConvert.toRequestMatcher(condition);
      final json = matcher.toJson();

      expect(json['type'], 'method');
      expect(json['method']['value'], 'GET');
      expect(json['method']['type'], 'eq');
    });

    test('converts numeric status code between', () {
      final condition = FilterCondition(
        field: FilterField.statusCode,
        operator: FilterOperator.between,
        value: '200, 300',
      );
      final matcher = FilterConvert.toRequestMatcher(condition);
      final json = matcher.toJson();

      expect(json['type'], 'status');
      expect(json['matcher']['type'], 'between');
      expect(json['matcher']['value']['min'], 200);
      expect(json['matcher']['value']['max'], 300);
    });

    test('converts Group AND', () {
      final c1 = FilterCondition(field: FilterField.url, value: 'a');
      final c2 = FilterCondition(field: FilterField.method, value: 'GET');
      final group = FilterGroup(children: [c1, c2]);

      final matcher = FilterConvert.toRequestMatcher(group);
      final json = matcher.toJson();

      expect(json['type'], 'and');
      expect((json['matchers'] as List).length, 2);
    });
  });
}
