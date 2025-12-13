import 'package:api_craft/http/header_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strict duplicate headers appear as multiple lines', () {
    final input = [
      ['set-cookie', 'a=1'],
      ['set-cookie', 'b=2'],
    ];

    final result = HeaderUtils.handleHeaders(input);

    expect(result.length, 2);
    expect(result, anyElement(equals(['set-cookie', 'a=1'])));
    expect(result, anyElement(equals(['set-cookie', 'b=2'])));
  });

  test('cookie is handled as strict duplicate header', () {
    final input = [
      ['cookie', 'a=1'],
      ['cookie', 'b=2'],
    ];

    final result = HeaderUtils.handleHeaders(input);

    expect(result.length, 2);
    expect(result, anyElement(equals(['cookie', 'a=1'])));
    expect(result, anyElement(equals(['cookie', 'b=2'])));
  });

  test('unknown headers allow duplicates', () {
    final input = [
      ['x-custom', 'a'],
      ['x-custom', 'b'],
    ];

    final result = HeaderUtils.handleHeaders(input);

    expect(result.length, 2);
    expect(result, anyElement(equals(['x-custom', 'a'])));
    expect(result, anyElement(equals(['x-custom', 'b'])));
  });

  test('mixed headers behave correctly', () {
    final input = [
      ['accept', 'text/html'],
      ['accept', 'application/xml'],
      ['set-cookie', 'a=1'],
      ['set-cookie', 'b=2'],
      ['content-type', 'json2'],
      ['x-test', 'v1'],
      ['x-test', 'v2'],
    ];

    final result = HeaderUtils.handleHeaders(input);

    expect(
      result,
      anyElement(equals(['accept', 'text/html, application/xml'])),
    );
    expect(result, anyElement(equals(['set-cookie', 'a=1'])));
    expect(result, anyElement(equals(['set-cookie', 'b=2'])));
    expect(result, anyElement(equals(['content-type', 'json2'])));
    expect(result, anyElement(equals(['x-test', 'v1'])));
    expect(result, anyElement(equals(['x-test', 'v2'])));
  });
}
