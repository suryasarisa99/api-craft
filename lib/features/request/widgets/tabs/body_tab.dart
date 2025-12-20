import 'package:api_craft/core/providers/providers.dart';
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
    return CFCodeEditor(
      key: ValueKey(bodyType),
      text: state.body ?? '',
      language: bodyType,
      readOnly: false,
      onChanged: (newBody) {
        ref.read(reqComposeProvider(id).notifier).updateBody(newBody);
      },
    );
  }
}
