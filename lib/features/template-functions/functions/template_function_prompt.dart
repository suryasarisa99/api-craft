// {
//       name: 'prompt.text',
//       description: 'Prompt the user for input when sending a request',
//       previewType: 'click',
//       previewArgs: ['label'],
//       args: [
//         {
//           type: 'text',
//           name: 'label',
//           label: 'Label',
//           optional: true,
//           dynamic(_ctx, args) {
//             if (
//               args.values.store === STORE_EXPIRE ||
//               (args.values.store === STORE_FOREVER && !args.values.key)
//             ) {
//               return { optional: false };
//             }
//           },
//         },
//         {
//           type: 'select',
//           name: 'store',
//           label: 'Store Input',
//           defaultValue: STORE_NONE,
//           options: [
//             { label: 'Never', value: STORE_NONE },
//             { label: 'Expire', value: STORE_EXPIRE },
//             { label: 'Forever', value: STORE_FOREVER },
//           ],
//         },
//         {
//           type: 'h_stack',
//           dynamic(_ctx, args) {
//             return { hidden: args.values.store === STORE_NONE };
//           },
//           inputs: [
//             {
//               type: 'text',
//               name: 'namespace',
//               label: 'Namespace',
//               // biome-ignore lint/suspicious/noTemplateCurlyInString: Yaak template syntax
//               defaultValue: '${[ctx.workspace()]}',
//               optional: true,
//             },
//             {
//               type: 'text',
//               name: 'key',
//               label: 'Key (defaults to Label)',
//               optional: true,
//               dynamic(_ctx, args) {
//                 return { placeholder: String(args.values.label || '') };
//               },
//             },
//             {
//               type: 'text',
//               name: 'ttl',
//               label: 'TTL (seconds)',
//               placeholder: '0',
//               defaultValue: '0',
//               optional: true,
//               dynamic(_ctx, args) {
//                 return { hidden: args.values.store !== STORE_EXPIRE };
//               },
//             },
//           ],
//         },
//         {
//           type: 'banner',
//           color: 'info',
//           inputs: [],
//           dynamic(_ctx, args) {
//             let key: string;
//             try {
//               key = buildKey(args);
//             } catch (err) {
//               return { color: 'danger', inputs: [{ type: 'markdown', content: String(err) }] };
//             }
//             return {
//               hidden: args.values.store === STORE_NONE,
//               inputs: [
//                 {
//                   type: 'markdown',
//                   content: [`Value will be saved under: \`${key}\``].join('\n\n'),
//                 },
//               ],
//             };
//           },
//         },
//         {
//           type: 'accordion',
//           label: 'Advanced',
//           inputs: [
//             {
//               type: 'text',
//               name: 'title',
//               label: 'Prompt Title',
//               optional: true,
//               placeholder: 'Enter Value',
//             },
//             { type: 'text', name: 'defaultValue', label: 'Default Value', optional: true },
//             { type: 'text', name: 'placeholder', label: 'Input Placeholder', optional: true },
//             { type: 'checkbox', name: 'password', label: 'Mask Value' },
//           ],
//         },
//       ],
//       async onRender(ctx: Context, args: CallTemplateFunctionArgs): Promise<string | null> {
//         if (args.purpose !== 'send') return null;

//         if (args.values.store !== STORE_NONE && !args.values.namespace) {
//           throw new Error('Namespace is required when storing values');
//         }

//         const existing = await maybeGetValue(ctx, args);
//         if (existing != null) {
//           return existing;
//         }

//         const value = await ctx.prompt.text({
//           id: `prompt-${args.values.label ?? 'none'}`,
//           label: String(args.values.label || 'Value'),
//           title: String(args.values.title ?? 'Enter Value'),
//           defaultValue: String(args.values.defaultValue ?? ''),
//           placeholder: String(args.values.placeholder ?? ''),
//           password: Boolean(args.values.password),
//           required: false,
//         });

//         if (value == null) {
//           throw new Error('Prompt cancelled');
//         }

//         if (args.values.store !== STORE_NONE) {
//           await maybeSetValue(ctx, args, value);
//         }

//         return value;
//       },
//     }

import 'package:api_craft/core/services/app_service.dart';
import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/features/template-functions/models/enums.dart';
import 'package:api_craft/features/template-functions/models/form_input.dart';
import 'package:api_craft/features/template-functions/models/template_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// class K{
//   static const String STORE_NONE = 'none';
//   static const String STORE_EXPIRE = 'expire';
//   static const String STORE_FOREVER = 'forever';
// }
class _Store {
  static const String none = 'none';
  static const String expire = 'expire';
  static const String forever = 'forever';
}

final TemplateFunction promptFn = TemplateFunction(
  name: 'prompt.text',
  description: 'Prompt the user for input when sending a request',
  previewType: "click",
  args: [
    FormInputText(
      name: 'label',
      label: 'Label',
      optional: true,
      dynamicFn: (ctx, args) {},
    ),
    FormInputSelect(
      name: 'store',
      label: 'Store Input',
      defaultValue: _Store.none,
      options: [
        FormInputSelectOption(label: 'Never', value: _Store.none),
        FormInputSelectOption(label: 'Expire', value: _Store.expire),
        FormInputSelectOption(label: 'Forever', value: _Store.forever),
      ],
    ),
    FormInputHStack(
      // name: 'storageOptions',
      dynamicFn: (ctx, args) async {
        debugPrint(
          "should hide hstack: ${args.values['store'] == _Store.none}",
        );
        return {'hidden': args.values['store'] == _Store.none};
      },
      inputs: [
        FormInputText(
          name: 'namespace',
          label: 'Namespace',
          // defaultValue: '{{ctx.workspace()}}',
          defaultValue: 'test',
          optional: true,
        ),
        FormInputText(
          name: 'key',
          label: 'Key (defaults to Label)',
          optional: true,
        ),
        FormInputText(
          name: 'ttl',
          label: 'TTL (seconds)',
          placeholder: '0',
          defaultValue: '0',
          optional: true,
          dynamicFn: (ctx, args) async {
            if (args.values['store'] != _Store.expire) {
              return {'hidden': true};
            }
            return {'hidden': false};
          },
        ),
      ],
    ),

    // FormInputBanner(
    //   name: 'storageBanner',
    //   color: BannerColor.info,
    //   inputs: [],
    //   dynamicFn: (ctx, args) async {
    //     String key;
    //     try {
    //       key = buildKey(args);
    //     } catch (err) {
    //       return {
    //         'color': Colors.red,
    //         'inputs': [
    //           FormInputMarkdown(name: 'errorMarkdown', content: String(err)),
    //         ],
    //       };
    //     }
    //     if (args.values['store'] == STORE_NONE) {
    //       return {'hidden': true};
    //     }
    //     return {
    //       'hidden': false,
    //       'inputs': [
    //         FormInputMarkdown(
    //           name: 'infoMarkdown',
    //           content: 'Value will be saved under: `$key`',
    //         ),
    //       ],
    //     };
    //   },
    // ),
    FormInputAccordion(
      label: 'Advanced',
      inputs: [
        FormInputText(
          name: 'title',
          label: 'Prompt Title',
          optional: true,
          placeholder: 'Enter Value',
        ),
        FormInputText(
          name: 'defaultValue',
          label: 'Default Value',
          optional: true,
        ),
        FormInputText(
          name: 'placeholder',
          label: 'Placeholder',
          optional: true,
        ),
        FormInputCheckbox(
          name: 'password',
          label: 'Mask Password',
          optional: true,
        ),
      ],
    ),
  ],
  onRender: (ref, ctx, args) async {
    debugPrint("args: ${args.values}");
    // if (args.purpose.name != Purpose.send.name) return null;

    if (args.values['store'] != _Store.none &&
        (args.values['namespace'] == null ||
            (args.values['namespace']).isEmpty)) {
      throw Exception('Namespace is required when storing values');
    }
    final key = buildKey(args);
    debugPrint("store: ${args.values['store']}");
    final existing = await maybeGetValue(ref, key, args);
    debugPrint("existing value: $existing");
    if (existing != null) {
      return existing;
    }

    final value = await showCustomDialog(
      ctx,
      id: 'prompt-${args.values['label'] ?? 'none'}',
      label: args.values['label'] ?? 'Value',
      title: args.values['title'] ?? 'Enter Value',
      defaultValue: args.values['defaultValue'] ?? '',
      placeholder: args.values['placeholder'] ?? '',
      password: args.values['password'] ?? false,
    );

    if (value == null) {
      throw Exception('Prompt cancelled');
    }

    if (args.values['store'] != _Store.none &&
        args.values['namespace'] != null) {
      AppService.store.setValue(key, {
        'value': value,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }

    return value;
  },
);

Future<String?> showCustomDialog(
  BuildContext context, {
  required String id,
  required String label,
  required String title,
  required String defaultValue,
  required String placeholder,
  required bool password,
}) async {
  final controller = TextEditingController(text: defaultValue);

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return CustomDialog(
        width: 450,
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 22, fontWeight: .bold)),
            SizedBox(height: 20),
            Text(label, style: TextStyle(fontSize: 14)),
            SizedBox(height: 4),
            TextField(
              autofocus: true,
              controller: controller,
              decoration: InputDecoration(
                // labelText: label,
                hintText: placeholder,
              ),
              obscureText: password,
            ),
            SizedBox(height: 30),
            Row(
              children: [
                Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, controller.text);
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  return result;
}

Future<String?> maybeGetValue(
  Ref ref,
  String key,
  CallTemplateFunctionArgs args,
) async {
  if (args.values['store'] == _Store.none) return null;

  final existing = await AppService.store.getValue(key);
  if (existing == null) {
    return null;
  }

  if (args.values['store'] == _Store.forever) {
    return existing['value'];
  }

  // final ttlSeconds = Number.parseInt(String(args.values['ttl']), 10) || 0;
  final ttlSeconds = int.tryParse(args.values['ttl']) ?? 0;
  final ageSeconds =
      (DateTime.now().millisecondsSinceEpoch - existing['createdAt']) / 1000;
  if (ageSeconds > ttlSeconds) {
    AppService.store.deleteValue(key);
    return null;
  }

  return existing['value'];
}

String buildKey(CallTemplateFunctionArgs args) {
  if (args.values['key'] == null && args.values['label'] == null) {
    throw Exception('A label or key is required when storing values');
  }
  return [args.values['namespace'], args.values['key'] ?? args.values['label']]
      .where((v) => v != null)
      .map((v) => v.toString().toLowerCase().trim())
      .join('.');
}
