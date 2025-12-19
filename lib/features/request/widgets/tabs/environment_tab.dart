import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/widgets/ui/key_value_editor.dart';
import 'package:flutter/material.dart';

class EnvironmentTab extends ConsumerWidget {
  final String id;
  const EnvironmentTab({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variables = ref.watch(
      reqComposeProvider(
        id,
      ).select((value) => (value.node as FolderNode).config.variables),
    );
    return Column(
      children: [
        Expanded(
          child: KeyValueEditor(
            enableSuggestionsForKey: false,
            id: id,
            mode: KeyValueEditorMode.variables,
            items: List.from(variables), // Pass copy to allow local reordering
            onChanged: (newItems) => ref
                .read(reqComposeProvider(id).notifier)
                .updateVariables(newItems),
          ),
        ),
      ],
    );
  }
}
