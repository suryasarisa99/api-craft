import 'package:api_craft/features/environment/environment_provider.dart';
import 'package:api_craft/features/environment/cookie_jar_editor_dialog.dart';
import 'package:api_craft/features/environment/environment_editor_dialog.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnvironmentPicker extends ConsumerWidget {
  const EnvironmentPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentProvider);
    final selectedEnv = state.selectedEnvironment;
    final selectedJar = state.selectedCookieJar;

    // "Show 'No Environment' with gray text if no variables in default environment and default env is selected"
    bool isNoEnvironment = false;
    if (selectedEnv != null &&
        selectedEnv.name == 'Default' &&
        selectedEnv.variables.isEmpty) {
      isNoEnvironment = true;
    }

    final displayText = selectedEnv == null
        ? "No Environment"
        : (isNoEnvironment ? "No Environment" : selectedEnv.name);

    final color = selectedEnv?.color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Environment Picker
        MyCustomMenu.contentColumn(
          popupKey: GlobalKey<CustomPopupState>(),
          items: [
            ...state.environments.map(
              (e) => CustomMenuIconItem.tick(
                checked: e.id == state.selectedEnvironmentId,
                title: Text(e.name),
                value: e.id,
                onTap: (val) => ref
                    .read(environmentProvider.notifier)
                    .selectEnvironment(val),
              ),
            ),
            menuDivider,
            CustomMenuIconItem(
              title: const Text("Manage Environments"),
              value: 'manage',
              onTap: (_) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => const EnvironmentEditorDialog(),
                    );
                  }
                });
              },
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                if (color != null) Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Text(
                  displayText,
                  style: TextStyle(color: isNoEnvironment ? Colors.grey : null),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Cookie Jar Picker
        MyCustomMenu.contentColumn(
          popupKey: GlobalKey<CustomPopupState>(),
          items: [
            ...state.cookieJars.map(
              (j) => CustomMenuIconItem.tick(
                checked: j.id == state.selectedCookieJarId,
                title: Text(j.name),
                value: j.id,
                onTap: (val) =>
                    ref.read(environmentProvider.notifier).selectCookieJar(val),
              ),
            ),
            menuDivider,
            CustomMenuIconItem(
              icon: Icon(Icons.cookie_outlined, size: 16),
              title: const Text("Manage Cookies"),
              value: 'manage',
              onTap: (_) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => const CookieJarEditorDialog(),
                    );
                  }
                });
              },
            ),
            CustomMenuIconItem(
              icon: Icon(Icons.edit, size: 16),
              title: const Text("Rename Cookie Jar"),
              value: 'rename',
              onTap: (_) {
                final jar = state.selectedCookieJar;
                if (jar != null) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (context.mounted) {
                      _showRenameDialog(context, ref, jar.id, jar.name);
                    }
                  });
                }
              },
            ),
            if (state.cookieJars.length > 1) ...[
              CustomMenuIconItem(
                icon: Icon(Icons.delete, size: 16, color: Colors.red),
                title: const Text(
                  "Delete Cookie Jar",
                  style: TextStyle(color: Colors.red),
                ),
                value: 'delete',
                onTap: (_) {
                  final jar = state.selectedCookieJar;
                  if (jar != null) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        _showDeleteConfirmation(context, ref, jar.id, jar.name);
                      }
                    });
                  }
                },
              ),
            ],
            menuDivider,
            CustomMenuIconItem(
              icon: Icon(Icons.add, size: 16),
              title: const Text("New Cookie Jar"),
              value: 'new',
              onTap: (_) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) _showNewJarDialog(context, ref);
                });
              },
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                const Icon(Icons.cookie_outlined, size: 18),
                if (selectedJar != null && selectedJar.name != 'Default') ...[
                  const SizedBox(width: 4),
                  Text(selectedJar.name, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showNewJarDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Cookie Jar"),
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
                // Use selectedCollectionProvider instead to be safe?
                // But environmentProvider loads based on selected collection.
                // We can just query environments.first.collectionId as a fallback or inject selectedCollectionProvider.
                // Actually `createCookieJar` needs collectionId.
                // Let's get it from any jar.
                final anyJar = ref
                    .read(environmentProvider)
                    .cookieJars
                    .firstOrNull;
                if (anyJar != null) {
                  ref
                      .read(environmentProvider.notifier)
                      .createCookieJar(controller.text, anyJar.collectionId);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String id,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Cookie Jar"),
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
                    .renameCookieJar(id, controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String id,
    String jarName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Cookie Jar"),
        content: Text("Are you sure you want to delete '$jarName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              ref.read(environmentProvider.notifier).deleteCookieJar(id);
              Navigator.pop(ctx);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
