import 'package:api_craft/core/services/app_service.dart';
import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/features/template-functions/models/form_input.dart';
import 'package:api_craft/features/template-functions/models/template_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          defaultValue: '{{ctx.workspace.id()}}',
          // defaultValue: 'test',
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
    if (!ctx.mounted) return null;
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
