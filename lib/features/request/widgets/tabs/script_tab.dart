import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/js_engine.dart';
import 'package:api_craft/core/widgets/ui/cf_code_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

class ScriptTab extends ConsumerStatefulWidget {
  final String id;
  const ScriptTab({super.key, required this.id});

  @override
  ConsumerState<ScriptTab> createState() => _ScriptTabState();
}

class _ScriptTabState extends ConsumerState<ScriptTab> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reqComposeProvider(widget.id));
    final node = state.node;

    if (!node.config.isDetailLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final preScript = node.config.preRequestScript;
    final postScript = node.config.postRequestScript;
    final testScript = node.config.testScript;
    final notifier = ref.read(reqComposeProvider(widget.id).notifier);

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TabBar(
                          isScrollable: true,
                          onTap: (index) {
                            setState(() {
                              _index = index;
                            });
                          },
                          tabs: [
                            Tab(text: "Pre Request"),
                            Tab(text: "Post Request"),
                            Tab(text: "Tests"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final index = _index;
                        String? script = [
                          preScript,
                          postScript,
                          testScript,
                        ][index];

                        if (script != null && script.isNotEmpty) {
                          ref
                              .read(jsEngineProvider)
                              .executeScript(
                                script,
                                context: context,
                                isPreview: true,
                              );
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      tooltip: "Run Script",
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Expanded(
                child: LazyLoadIndexedStack(
                  index: _index,
                  // controller: DefaultTabController.of(context),
                  children: [
                    CFCodeEditor(
                      text: preScript ?? '',
                      language: 'javascript',
                      onChanged: (val) => notifier.updatePreRequestScript(val),
                    ),
                    CFCodeEditor(
                      text: postScript ?? '',
                      language: 'javascript',
                      onChanged: (val) => notifier.updatePostRequestScript(val),
                    ),
                    CFCodeEditor(
                      text: testScript ?? '',
                      language: 'javascript',
                      onChanged: (val) => notifier.updateTestScript(val),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
