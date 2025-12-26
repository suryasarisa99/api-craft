import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/key_value_editor.dart';
import 'package:api_craft/features/request/widgets/tabs/binary_body_editor.dart';
import 'package:api_craft/features/request/widgets/tabs/tab_titles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';

class BodyTab extends ConsumerWidget {
  final String id;
  const BodyTab({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reqComposeProvider(id));
    final node = state.node;
    final bodyType = node is RequestNode ? node.config.bodyType : null;
    if (state.isLoading || !node.config.isDetailLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // No Body
    if (bodyType == BodyType.noBody || bodyType == null) {
      return const Center(
        child: Text("No Body Selected", style: TextStyle(color: Colors.grey)),
      );
    }

    // Binary File
    if (bodyType == BodyType.binaryFile) {
      return BinaryBodyEditor(id: id);
    }

    // Form Data & Url Encoded
    if (bodyType == BodyType.formMultipart ||
        bodyType == BodyType.formUrlEncoded) {
      final items =
          (state.bodyData['form'] as List?)
              ?.map((e) => FormDataItem.fromMap(e))
              .toList() ??
          [];
      return KeyValueEditor(
        id: id,
        items: List.from(items),
        mode: bodyType == BodyType.formMultipart
            ? KeyValueEditorMode.multipart
            : KeyValueEditorMode.formData,
        onChanged: (newItems) {
          ref
              .read(reqComposeProvider(id).notifier)
              .updateBodyForm(
                newItems.map((e) {
                  if (e is FormDataItem) return e;
                  return FormDataItem(
                    id: e.id,
                    isEnabled: e.isEnabled,
                    key: e.key,
                    value: e.value,
                    type: 'text',
                  );
                }).toList(),
              );
        },
      );
    }

    // Code Editor (JSON, XML, Text)
    // Note: Form data might need different UI too, but sticking to user request for now which only mentioned no body and binary.
    // Existing code editor likely handles text-based bodies.
    return CFCodeEditor(
      key: ValueKey(bodyType),
      text: (state.bodyData['text'] as String?) ?? '',
      language: bodyType,
      readOnly: false,
      onChanged: (newBody) {
        ref.read(reqComposeProvider(id).notifier).updateBodyText(newBody);
      },
      // You might want to update language definition if bodyType string doesn't match highlighter languages exactly.
      // But assuming it matches 'json', 'xml' etc. from TabTitles.
    );
  }
}
