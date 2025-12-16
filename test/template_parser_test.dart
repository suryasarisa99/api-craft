import 'package:test/test.dart';
import 'package:api_craft/template-functions/parsers/parse.dart';

void main() {
  group('TemplateParser – Map based parser', () {
    test('parses simple key value pairs', () {
      final args = TemplateParser.parseTemplate(
        '{{foo(a=1, b=true, c=false, d=null, e="x")}}',
      );

      expect(args, {'a': 1, 'b': true, 'c': false, 'd': null, 'e': 'x'});
    });

    test('parses strings with escapes', () {
      final args = TemplateParser.parseTemplate(r'''{{foo(
          a="line\nbreak",
          b="tab\tchar",
          c="quote\"test",
          d='single\'quote',
          e="slash\\end"
        )}}''');

      expect(args['a'], 'line\nbreak');
      expect(args['b'], 'tab\tchar');
      expect(args['c'], 'quote"test');
      expect(args['d'], "single'quote");
      expect(args['e'], r'slash\end');
    });

    test('parses unicode and emoji strings', () {
      final args = TemplateParser.parseTemplate(
        '{{foo(a="こんにちは", b="🚀🔥", c="áéíóú")}}',
      );

      expect(args['a'], 'こんにちは');
      expect(args['b'], '🚀🔥');
      expect(args['c'], 'áéíóú');
    });

    test('parses negative and float numbers', () {
      final args = TemplateParser.parseTemplate(
        '{{foo(a=-1, b=3.14, c=-0.001, d=1e3)}}',
      );

      expect(args['a'], -1);
      expect(args['b'], 3.14);
      expect(args['c'], -0.001);
      expect(args['d'], 1000);
    });

    test('parses empty argument list', () {
      final args = TemplateParser.parseTemplate('{{foo()}}');
      expect(args, isEmpty);
    });

    test('allows trailing comma', () {
      final args = TemplateParser.parseTemplate('{{foo(a=1, b=2,)}}');

      expect(args.length, 2);
      expect(args['a'], 1);
      expect(args['b'], 2);
    });

    test('parses base64 encoded strings', () {
      final args = TemplateParser.parseTemplate(
        "{{foo(a=b64'SGVsbG8gd29ybGQ=', b=b64'JC50ZXN0LnBhdGg=')}}",
      );

      expect(args['a'], 'Hello world');
      expect(args['b'], r'$.test.path');
    });

    test('parses yaak response.body.path example', () {
      final args = TemplateParser.parseTemplate(
        "{{response.body.path("
        "behavior='ttl', "
        "ttl='194', "
        "result='first', "
        "join=b64'LCA', "
        "request='rq_3kdZLMBncM', "
        "path=b64'JC50ZXN0LmJvb2tkcy5kb25lLm9rLm1hZ2lj'"
        ")}}",
      );

      expect(args['behavior'], 'ttl');
      expect(args['ttl'], '194');
      expect(args['result'], 'first');
      expect(args['join'], ', ');
      expect(args['request'], 'rq_3kdZLMBncM');
      expect(args['path'], r'$.test.bookds.done.ok.magic');
    });

    test('throws on duplicate keys', () {
      expect(
        () => TemplateParser.parseTemplate('{{foo(a=1, a=2)}}'),
        throwsA(isA<TemplateParseException>()),
      );
    });

    test('throws on invalid base64', () {
      expect(
        () => TemplateParser.parseTemplate('{{foo(a=b64"bad")}}'),
        throwsA(isA<TemplateParseException>()),
      );
    });

    test('throws on unterminated string', () {
      expect(
        () => TemplateParser.parseTemplate('{{foo(a="oops)}}'),
        throwsA(isA<TemplateParseException>()),
      );
    });

    test('throws on missing equals', () {
      expect(
        () => TemplateParser.parseTemplate('{{foo(a "bad")}}'),
        throwsA(isA<TemplateParseException>()),
      );
    });

    test('throws on malformed template braces', () {
      expect(
        () => TemplateParser.parseTemplate('{foo(a=1)}}'),
        throwsA(isA<TemplateParseException>()),
      );

      expect(
        () => TemplateParser.parseTemplate('{{foo(a=1)}'),
        throwsA(isA<TemplateParseException>()),
      );
    });

    test('throws on garbage tokens', () {
      expect(
        () => TemplateParser.parseTemplate('{{foo(a=1, ???, b=2)}}'),
        throwsA(isA<TemplateParseException>()),
      );
    });
  });
}
