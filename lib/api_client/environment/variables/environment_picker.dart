import 'package:api_craft/api_client/environment/environment_provider.dart';
import 'package:api_craft/api_client/environment/variables/environment_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnvironmentButton extends ConsumerWidget {
  const EnvironmentButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEnv = ref.watch(
      environmentProvider.select((e) => e.selectedEnvironment),
    );
    final globalEnv = ref.watch(
      environmentProvider.select((e) => e.globalEnvironment),
    );

    String displayText = "Global";
    Color? color;

    if (selectedEnv != null) {
      displayText = selectedEnv.name;
      if (!selectedEnv.isGlobal) {
        color = selectedEnv.color;
      }
    } else if (globalEnv != null) {
      displayText = globalEnv.name;
    }

    final isGlobalOrNull = selectedEnv == null || selectedEnv.isGlobal;

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => const EnvironmentEditorDialog(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 8),
            ],
            Text(
              displayText,
              style: TextStyle(color: isGlobalOrNull ? Colors.grey : null),
            ),
          ],
        ),
      ),
    );
  }
}
