import 'package:api_craft/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/widgets/ui/key_value_editor.dart';
import 'package:flutter/material.dart';

class QueryParamsTab extends ConsumerWidget {
  final String id;
  const QueryParamsTab({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryParams = ref.watch(
      resolveConfigProvider(
        id,
      ).select((value) => (value.node as RequestNode).config.queryParameters),
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: KeyValueEditor(
              id: id,
              mode: KeyValueEditorMode.variables,
              items: List.from(
                queryParams,
              ), // Pass copy to allow local reordering
              onChanged: (newItems) => ref
                  .read(resolveConfigProvider(id).notifier)
                  .updateQueryParameters(newItems),
            ),
          ),
        ],
      ),
    );
  }
}
