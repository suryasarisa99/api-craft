import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/environment/environment_provider.dart';
import 'package:api_craft/features/collection/selected_collection_provider.dart';
import 'package:api_craft/features/environment/environment_creation_dialog.dart';
import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/core/widgets/ui/key_value_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

class EnvironmentEditorDialog extends ConsumerStatefulWidget {
  const EnvironmentEditorDialog({super.key});

  @override
  ConsumerState<EnvironmentEditorDialog> createState() =>
      _EnvironmentEditorDialogState();
}

class _EnvironmentEditorDialogState
    extends ConsumerState<EnvironmentEditorDialog> {
  String? _selectedEnvId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(environmentProvider);
      if (state.selectedEnvironmentId != null) {
        setState(() {
          _selectedEnvId = state.selectedEnvironmentId;
        });
      }
    });
  }

  void _onEnvSelected(Environment env) {
    setState(() {
      _selectedEnvId = env.id;
    });
  }

  void _createNewEnv() {
    final collection = ref.read(selectedCollectionProvider);
    if (collection != null) {
      showDialog(
        context: context,
        builder: (ctx) => EnvironmentCreationDialog(
          onCreate: (name, color, isShared) async {
            await ref
                .read(environmentProvider.notifier)
                .createEnvironment(
                  name,
                  collection.id,
                  color: color,
                  isShared: isShared,
                );
            // Auto select logic handled inside createEnvironment call in provider?
            // Actually provider's createEnvironment calls selectEnvironment at the end.
            // But _selectedEnvId local state needs update.
            // final all = ref
            //     .read(environmentProvider)
            //     .environments; // reload happen?
            // Since creating is async, by the time future returns, data is loaded.
            // But watch() in build handles data.
            // We just need to sync _selectedEnvId to the new one.
            final newState = ref.read(environmentProvider);
            if (newState.selectedEnvironmentId != null) {
              setState(() {
                _selectedEnvId = newState.selectedEnvironmentId;
              });
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(environmentProvider);
    final envs = state.environments;
    final selectedEnv = envs.where((e) => e.id == _selectedEnvId).firstOrNull;

    return CustomDialog(
      width: 900,
      height: 600,
      padding: const EdgeInsets.all(0),
      child: Row(
        children: [
          // Left Pane (List)
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Environments",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _createNewEnv,
                        tooltip: "Create new environment",
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: envs.length,
                    itemBuilder: (context, index) {
                      final env = envs[index];
                      final isSelected = env.id == _selectedEnvId;
                      return ContextMenuWidget(
                        menuProvider: (_) => Menu(
                          children: [
                            MenuAction(
                              title: "Rename",
                              callback: () {
                                _showRenameDialog(env);
                              },
                            ),
                            MenuAction(
                              title: "Edit Color", // Simple palette popup?
                              callback: () {
                                _showColorDialog(env);
                              },
                            ),
                            MenuAction(
                              title: "Duplicate",
                              callback: () {
                                ref
                                    .read(environmentProvider.notifier)
                                    .duplicateEnvironment(env);
                              },
                            ),
                            MenuAction(
                              title: env.isShared
                                  ? "Make Private"
                                  : "Make Shared",
                              callback: () {
                                ref
                                    .read(environmentProvider.notifier)
                                    .toggleShared(env);
                              },
                            ),
                            MenuSeparator(),
                            MenuAction(
                              title: "Delete",
                              attributes: const MenuActionAttributes(
                                destructive: true,
                              ),
                              callback: () {
                                ref
                                    .read(environmentProvider.notifier)
                                    .deleteEnvironment(env.id);
                                if (isSelected) {
                                  setState(() => _selectedEnvId = null);
                                }
                              },
                            ),
                          ],
                        ),
                        child: ListTile(
                          onTap: () => _onEnvSelected(env),
                          selected: isSelected,
                          dense: true,
                          minVerticalPadding: 0,
                          minTileHeight: 32,
                          selectedTileColor: Colors.white10,
                          leading: Icon(
                            Icons.circle,
                            color: env.color ?? Colors.grey,
                            size: 12,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  env.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (env.isShared) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.people,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Right Pane (Variables Only)
          if (selectedEnv != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 28),
                  // Removed Header as requested.
                  Expanded(
                    child: KeyValueEditor(
                      key: ValueKey(selectedEnv.id), // Ensure rebuild on switch
                      items: selectedEnv.variables,
                      onChanged: (items) {
                        ref
                            .read(environmentProvider.notifier)
                            .updateEnvironment(
                              selectedEnv.copyWith(variables: items),
                            );
                      },
                      // id: selectedEnv.id,
                      id: null,
                      mode: KeyValueEditorMode.variables,
                      isVariable: true,
                    ),
                  ),
                ],
              ),
            )
          else
            const Expanded(
              child: Center(child: Text("Select an Environment to edit")),
            ),
        ],
      ),
    );
  }

  void _showRenameDialog(Environment env) {
    final controller = TextEditingController(text: env.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Environment"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(environmentProvider.notifier)
                    .updateEnvironment(env.copyWith(name: controller.text));
                Navigator.pop(ctx);
              }
            },
            child: const Text("Refactor"),
          ),
        ],
      ),
    );
  }

  void _showColorDialog(Environment env) {
    // Quick color picker dialog
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = [
          Colors.red,
          Colors.green,
          Colors.blue,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.amber,
          Colors.grey,
        ];

        return AlertDialog(
          title: const Text("Select Color"),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors
                .map(
                  (c) => InkWell(
                    onTap: () {
                      ref
                          .read(environmentProvider.notifier)
                          .updateEnvironment(
                            env.copyWith(color: c == Colors.grey ? null : c),
                          );
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child:
                          (env.color == c ||
                              (env.color == null && c == Colors.grey))
                          ? const Icon(Icons.check, size: 16)
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
