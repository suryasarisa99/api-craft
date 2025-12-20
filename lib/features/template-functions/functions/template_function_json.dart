import 'dart:convert';

import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/template-functions/functions/template_common_args.dart';
import 'package:flutter/widgets.dart';
import 'package:json_path/json_path.dart';
// export const plugin: PluginDefinition = {
//   templateFunctions: [
//     {
//       name: 'json.jsonpath',
//       description: 'Filter JSON-formatted text using JSONPath syntax',
//       previewArgs: ['query'],
//       args: [
//         {
//           type: 'editor',
//           name: 'input',
//           label: 'Input',
//           language: 'json',
//           placeholder: '{ "foo": "bar" }',
//         },
//         {
//           type: 'h_stack',
//           inputs: [
//             {
//               type: 'select',
//               name: 'result',
//               label: 'Return Format',
//               defaultValue: RETURN_FIRST,
//               options: [
//                 { label: 'First result', value: RETURN_FIRST },
//                 { label: 'All results', value: RETURN_ALL },
//                 { label: 'Join with separator', value: RETURN_JOIN },
//               ],
//             },
//             {
//               name: 'join',
//               type: 'text',
//               label: 'Separator',
//               optional: true,
//               defaultValue: ', ',
//               dynamic(_ctx, args) {
//                 return { hidden: args.values.result !== RETURN_JOIN };
//               },
//             },
//           ],
//         },
//         {
//           type: 'checkbox',
//           name: 'formatted',
//           label: 'Pretty Print',
//           description: 'Format the output as JSON',
//           dynamic(_ctx, args) {
//             return { hidden: args.values.result === RETURN_JOIN };
//           },
//         },
//         { type: 'text', name: 'query', label: 'Query', placeholder: '$..foo' },
//       ],
//       async onRender(_ctx: Context, args: CallTemplateFunctionArgs): Promise<string | null> {
//         try {
//           return filterJSONPath(
//             String(args.values.input),
//             String(args.values.query),
//             (args.values.result || RETURN_FIRST) as XPathResult,
//             args.values.join == null ? null : String(args.values.join),
//             Boolean(args.values.formatted),
//           );
//         } catch {
//           return null;
//         }
//       },
//     },
//     {
//       name: 'json.escape',
//       description: 'Escape a JSON string, useful when using the output in JSON values',
//       args: [
//         {
//           type: 'text',
//           name: 'input',
//           label: 'Input',
//           multiLine: true,
//           placeholder: 'Hello "World"',
//         },
//       ],
//       async onRender(_ctx: Context, args: CallTemplateFunctionArgs): Promise<string | null> {
//         const input = String(args.values.input ?? '');
//         return input.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
//       },
//     },
//     {
//       name: 'json.minify',
//       description: 'Remove unnecessary whitespace from a valid JSON string.',
//       args: [
//         {
//           type: 'editor',
//           language: 'json',
//           name: 'input',
//           label: 'Input',
//           placeholder: '{ "foo": "bar" }',
//         },
//       ],
//       async onRender(_ctx: Context, args: CallTemplateFunctionArgs): Promise<string | null> {
//         const input = String(args.values.input ?? '');
//         try {
//           return JSON.stringify(JSON.parse(input));
//         } catch {
//           return input;
//         }
//       },
//     },
//   ],
// };

final jsonPathFn = TemplateFunction(
  name: "json.path",
  description: "Extract text using a json path expression",
  args: [
    FormInputText(
      name: "input",
      label: "Input",
      placeholder: '{ "foo": "bar" }',
    ),
    returnFormatHstak,
    FormInputCheckbox(
      name: 'formatted',
      label: 'Pretty Print',
      description: 'Format the output as JSON',
    ),
    FormInputText(name: 'query', label: 'Query', placeholder: '\$..foo'),
  ],
  onRender: (ref, ctx, args) async {
    try {
      return filterJsonPath(
        args.values['input'],
        args.values['query'],
        args.values['result'] ?? Return.first.name,
        join: args.values['join'] ?? ', ',
      );
    } catch (e) {
      debugPrint("err: $e ");
      return null;
    }
  },
);

String? filterJsonPath(
  String body,
  String path,
  String returnFormat, {
  String join = ', ',
}) {
  final parsed = jsonDecode(body);
  debugPrint("Parsed body: $parsed");
  var items = JsonPath(path).read(parsed);
  if (returnFormat == Return.first.name) {
    if (items.isNotEmpty) {
      return objToString(items.first.value);
    }
    return null;
  } else if (returnFormat == Return.last.name) {
    if (items.isNotEmpty) {
      return objToString(items.last.value);
    }
    return null;
  } else {
    final values = items.map((e) => objToString(e.value)).toList();
    return values.join(join);
  }
}

String objToString(dynamic obj) {
  if (obj == null) return 'null';
  if (obj is String) return obj;
  if (obj is num || obj is bool) return obj.toString();
  try {
    return jsonEncode(obj);
  } catch (e) {
    return obj.toString();
  }
}
