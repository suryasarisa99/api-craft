import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/js_engine.dart';
import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/widgets/sonner/sonner.dart';
import 'package:api_craft/core/services/toast_service.dart';

class ScriptTab extends ConsumerWidget {
  final String id;
  const ScriptTab({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reqComposeProvider(id));
    final node = state.node;
    final scripts = node is RequestNode ? node.reqConfig.scripts : null;

    if (!node.config.isDetailLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text(
                "Post-Response Script",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Sonner.toast(
                    builder: (context, _) => Container(
                      padding: const EdgeInsets.all(12),
                      width: 300,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 72, 72, 72),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "I am custom!",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
                child: const Text("Custom Toast"),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ToastService.success(
                    'Message sent',
                    description:
                        'Your message has been delivered\ntesting\nok\n1\n2',
                    duration: Duration(seconds: 10),
                  );
                  if (scripts != null && scripts.isNotEmpty) {
                    ref
                        .read(jsEngineProvider)
                        .executeScript(scripts, context: context);
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text("Run Now"),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: CFCodeEditor(
            text: scripts ?? '',
            language: 'javascript',
            onChanged: (val) {
              ref.read(reqComposeProvider(id).notifier).updateScripts(val);
            },
          ),
        ),
      ],
    );
  }
}
