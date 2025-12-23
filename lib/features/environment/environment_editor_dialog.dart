import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/widgets/dialog/input_dialog.dart';
import 'package:api_craft/features/environment/environment_provider.dart';
import 'package:api_craft/features/collection/selected_collection_provider.dart';
import 'package:api_craft/features/environment/environment_creation_dialog.dart';
import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/core/widgets/ui/key_value_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

class EnvironmentEditorDialog extends ConsumerStatefulWidget {
  final bool globalActive;
  const EnvironmentEditorDialog({super.key, this.globalActive = false});

  @override
  ConsumerState<EnvironmentEditorDialog> createState() =>
      _EnvironmentEditorDialogState();
}

class _EnvironmentEditorDialogState
    extends ConsumerState<EnvironmentEditorDialog> {
  String? _activeEnvId;

  @override
  void initState() {
    super.initState();
    _activeEnvId = widget.globalActive
        ? ref.read(environmentProvider).globalEnvironment?.id
        : ref.read(environmentProvider).selectedEnvironmentId ??
              ref.read(environmentProvider).globalEnvironment?.id;
  }

  void _onSubEnvTap(String id) {
    setState(() {
      _activeEnvId = id;
    });
    ref.read(environmentProvider.notifier).selectEnvironment(id);
  }

  void _onGlobalTap(String id) {
    setState(() {
      _activeEnvId = id;
    });
  }

  void _createNewEnv() {
    final collection = ref.read(selectedCollectionProvider);
    if (collection != null) {
      showDialog(
        context: context,
        builder: (ctx) => EnvironmentCreationDialog(
          onCreate: (name, color, isShared) async {
            ref
                .read(environmentProvider.notifier)
                .createEnvironment(
                  name,
                  collection.id,
                  color: color,
                  isShared: isShared,
                );
            setState(() {
              _activeEnvId = ref
                  .read(environmentProvider)
                  .selectedEnvironmentId;
            });
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final envs = ref.watch(environmentProvider.select((e) => e.environments));
    final selectedEnvId = ref.watch(
      environmentProvider.select((e) => e.selectedEnvironmentId),
    );

    final globalEnv = envs.where((e) => e.isGlobal).firstOrNull;
    final subEnvs = envs.where((e) => !e.isGlobal).toList();

    final activeEnv = envs.where((e) => e.id == _activeEnvId).firstOrNull;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                if (globalEnv != null) ...[
                  _EnvironmentTile(
                    env: globalEnv,
                    isActive: globalEnv.id == _activeEnvId,
                    isSelected: true, // Global is always selected
                    isGlobal: true,
                    onTap: _onGlobalTap,
                    providerRef: ref,
                    showRenameDialog: _showRenameDialog,
                    showColorDialog: _showColorDialog,
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Sub Environments",
                        style: TextStyle(fontSize: 13, fontWeight: .w500),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: _createNewEnv,
                        tooltip: "Create new sub environment",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: subEnvs.length,
                    itemBuilder: (context, index) {
                      final env = subEnvs[index];
                      final isSelected = env.id == selectedEnvId;
                      final isActive = env.id == _activeEnvId;

                      return _EnvironmentTile(
                        env: env,
                        isActive: isActive,
                        isSelected: isSelected,
                        isGlobal: false,
                        onTap: _onSubEnvTap,
                        providerRef: ref,
                        showRenameDialog: _showRenameDialog,
                        showColorDialog: _showColorDialog,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Right Pane (Variables Only)
          if (activeEnv != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const .only(left: 16),
                    child: Text(
                      activeEnv.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: KeyValueEditor(
                      enableSuggestionsForKey: false,
                      key: ValueKey(activeEnv.id),
                      items: activeEnv.variables,
                      onChanged: (items) {
                        ref
                            .read(environmentProvider.notifier)
                            .updateEnvironment(
                              activeEnv.copyWith(variables: items),
                            );
                      },
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
    showDialog(
      context: context,
      builder: (ctx) => InputDialog(
        initialValue: env.name,
        onConfirmed: (text) {
          if (text.isNotEmpty) {
            ref
                .read(environmentProvider.notifier)
                .updateEnvironment(env.copyWith(name: text));
          }
        },
        title: "Rename Environment",
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

        return CustomDialog(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Color",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors
                    .map(
                      (c) => InkWell(
                        onTap: () {
                          ref
                              .read(environmentProvider.notifier)
                              .updateEnvironment(
                                env.copyWith(
                                  color: c == Colors.grey ? null : c,
                                ),
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
            ],
          ),
        );
      },
    );
  }
}

class _EnvironmentTile extends StatelessWidget {
  final Environment env;
  final bool isSelected;
  final bool isActive;
  final bool isGlobal;
  final Function(String) onTap;
  final WidgetRef providerRef;
  final Function(Environment) showRenameDialog;
  final Function(Environment) showColorDialog;

  const _EnvironmentTile({
    required this.env,
    required this.isSelected,
    required this.isActive,
    required this.isGlobal,
    required this.onTap,
    required this.providerRef,
    required this.showRenameDialog,
    required this.showColorDialog,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenuWidget(
      menuProvider: (_) => Menu(
        children: [
          if (!isGlobal) ...[
            MenuAction(title: "Rename", callback: () => showRenameDialog(env)),
            MenuAction(
              title: "Edit Color",
              callback: () => showColorDialog(env),
            ),
            MenuAction(
              title: "Duplicate",
              callback: () {
                providerRef
                    .read(environmentProvider.notifier)
                    .duplicateEnvironment(env);
              },
            ),
          ],
          MenuAction(
            title: env.isShared ? "Make Private" : "Make Shared",
            callback: () {
              providerRef.read(environmentProvider.notifier).toggleShared(env);
            },
          ),
          if (!isGlobal) ...[
            MenuSeparator(),
            MenuAction(
              title: "Delete",
              attributes: const MenuActionAttributes(destructive: true),
              callback: () {
                providerRef
                    .read(environmentProvider.notifier)
                    .deleteEnvironment(env.id);
              },
            ),
          ],
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ListTile(
          onTap: () => onTap(env.id),
          selected: isSelected,
          dense: true,
          minVerticalPadding: 0,
          contentPadding: .only(left: 6, right: 10),
          minTileHeight: 30,
          selectedTileColor: Colors.white10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          // leading:
          title: Row(
            children: [
              // SizedBox(width: 6),
              isActive
                  ? const Icon(Icons.play_arrow, size: 16)
                  : const SizedBox(width: 16, height: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  env.name,
                  overflow: TextOverflow.ellipsis,
                  style: isGlobal
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
              ),
              if (env.color != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.circle, size: 8, color: env.color),
              ],
              if (env.isShared) ...[
                const SizedBox(width: 4),
                const Icon(Icons.people, size: 14, color: Colors.grey),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
