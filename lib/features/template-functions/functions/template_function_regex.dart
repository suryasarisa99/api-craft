import 'package:api_craft/core/models/models.dart';
import 'package:flutter/foundation.dart';

// const inputArg: TemplateFunctionArg = {
//   type: 'text',
//   name: 'input',
//   label: 'Input Text',
//   multiLine: true,
// };

// const regexArg: TemplateFunctionArg = {
//   type: 'text',
//   name: 'regex',
//   label: 'Regular Expression',
//   placeholder: '\\w+',
//   defaultValue: '.*',
//   description:
//     'A JavaScript regular expression. Use a capture group to reference parts of the match in the replacement.',
// };

// export const plugin: PluginDefinition = {
//   templateFunctions: [
//     {
//       name: 'regex.match',
//       description: 'Extract text using a regular expression',
//       args: [inputArg, regexArg],
//       previewArgs: [regexArg.name],
//       async onRender(_ctx: Context, args: CallTemplateFunctionArgs): Promise<string | null> {
//         const input = String(args.values.input ?? '');
//         const regex = new RegExp(String(args.values.regex ?? ''));

//         const match = input.match(regex);
//         return match?.groups
//           ? (Object.values(match.groups)[0] ?? '')
//           : (match?.[1] ?? match?.[0] ?? '');
//       },
//     },
//     {
//       name: 'regex.replace',
//       description: 'Replace text using a regular expression',
//       previewArgs: [regexArg.name],
//       args: [
//         inputArg,
//         regexArg,
//         {
//           type: 'text',
//           name: 'replacement',
//           label: 'Replacement Text',
//           placeholder: 'hello $1',
//           description:
//             'The replacement text. Use $1, $2, ... to reference capture groups or $& to reference the entire match.',
//         },
//         {
//           type: 'text',
//           name: 'flags',
//           label: 'Flags',
//           placeholder: 'g',
//           defaultValue: 'g',
//           optional: true,
//           description:
//             'Regular expression flags (g for global, i for case-insensitive, m for multiline, etc.)',
//         },
//       ],
//       async onRender(_ctx: Context, args: CallTemplateFunctionArgs): Promise<string | null> {
//         const input = String(args.values.input ?? '');
//         const replacement = String(args.values.replacement ?? '');
//         const flags = String(args.values.flags || '');
//         const regex = String(args.values.regex);

//         if (!regex) return '';

//         return input.replace(new RegExp(String(args.values.regex), flags), replacement);
//       },
//     },
//   ],
// };

final inputArg = FormInputText(
  name: 'input',
  label: 'Input Text',
  multiLine: true,
);

final regexArg = FormInputText(
  name: 'regex',
  label: 'Regular Expression',
  placeholder: '\\w+',
  defaultValue: '.*',
  description:
      'A JavaScript regular expression. Use a capture group to reference parts of the match in the replacement.',
);

final regexMatchFn = TemplateFunction(
  name: 'regex.match',
  description: 'Extract text using a regular expression',
  args: [inputArg, regexArg],
  onRender: (ref, ctx, args) async {
    final String input = args.values['input'] ?? '';
    final regex = RegExp(args.values['regex'] ?? '');
    debugPrint("input: $input, regex: $regex");
    final match = regex.firstMatch(input);
    if (match == null) return '';

    if (match.groupNames.isNotEmpty) {
      final firstName = match.groupNames.first;
      return match.namedGroup(firstName) ?? '';
    }

    return match.groupCount >= 1
        ? (match.group(1) ?? '')
        : (match.group(0) ?? '');
  },
);
final regexReplaceFn = TemplateFunction(
  name: 'regex.replace',
  description: 'Replace text using a regular expression',
  args: [
    inputArg,
    regexArg,
    FormInputText(
      name: 'replacement',
      label: 'Replacement Text',
      placeholder: 'hello \$1',
      description:
          'The replacement text. Use \$1, \$2, ... to reference capture groups or \$& to reference the entire match.',
    ),
    FormInputText(
      name: 'flags',
      label: 'Flags',
      placeholder: 'g',
      defaultValue: 'g',
      optional: true,
      description:
          'Regular expression flags (g for global, i for case-insensitive, m for multiline, etc.)',
    ),
  ],
  onRender: (ref, ctx, args) async {
    final map = args.values;

    final String input = map['input'] ?? '';
    final pattern = map['regex'] ?? '';
    final replacement = map['replacement'] ?? '';
    final flags = map['flags'] ?? '';

    final regExp = RegExp(
      pattern,
      caseSensitive: !flags.contains('i'),
      multiLine: flags.contains('m'),
      dotAll: flags.contains('s'),
    );

    return input.replaceAll(regExp, replacement);
  },
);
