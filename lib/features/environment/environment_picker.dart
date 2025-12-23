import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/widgets/dialog/input_dialog.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/environment/environment_provider.dart';
import 'package:api_craft/features/environment/cookie_jar_editor_dialog.dart';
import 'package:api_craft/features/environment/environment_editor_dialog.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suryaicons/bulk_rounded.dart';

class CookiesJarPicker extends ConsumerWidget {
  const CookiesJarPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jar = ref.watch(
      environmentProvider.select((state) => state.selectedCookieJar),
    );

    return MyCustomMenu.contentColumn(
      popupKey: GlobalKey<CustomPopupState>(),
      items: menuItems(ref, context, jar),
      child: Row(
        children: [
          const SuryaThemeIcon(BulkRounded.cookie),
          if (jar != null && jar.name != 'Default') ...[
            const SizedBox(width: 6),
            Text(
              jar.name,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> menuItems(
    WidgetRef ref,
    BuildContext context,
    CookieJarModel? jar,
  ) {
    final cookieJars = ref.read(environmentProvider).cookieJars;
    return [
      /// cookies Jar List
      ...cookieJars.map(
        (j) => CustomMenuIconItem.tick(
          checked: j.id == jar?.id,
          title: Text(j.name),
          value: j.id,
          onTap: (val) =>
              ref.read(environmentProvider.notifier).selectCookieJar(val),
        ),
      ),

      /// manage cookies
      LabeledDivider(text: jar?.name ?? "No Cookie Jar"),
      CustomMenuIconItem(
        icon: const SuryaThemeIcon(BulkRounded.cookie),
        title: const Text("Manage Cookies"),
        value: 'manage',
        onTap: (_) {
          showDialog(
            context: context,
            builder: (_) => const CookieJarEditorDialog(),
          );
        },
      ),
      CustomMenuIconItem(
        // icon: Icon(Icons.edit, size: 16),
        icon: const SuryaThemeIcon(BulkRounded.edit03),
        title: const Text("Rename Cookie Jar"),
        value: 'rename',
        onTap: (_) {
          if (jar != null) {
            _showRenameDialog(context, ref, jar.id, jar.name);
          }
        },
      ),
      if (cookieJars.length > 1) ...[
        CustomMenuIconItem(
          icon: const SuryaThemeIcon(BulkRounded.delete01),
          title: const Text(
            "Delete Cookie Jar",
            style: TextStyle(color: Colors.red),
          ),
          value: 'delete',
          onTap: (_) {
            if (jar != null) {
              _showDeleteConfirmation(context, ref, jar.id, jar.name);
            }
          },
        ),
      ],
      menuDivider,
      CustomMenuIconItem(
        icon: const SuryaThemeIcon(BulkRounded.add01),
        title: const Text("New Cookie Jar"),
        value: 'new',
        onTap: (_) => _showNewJarDialog(context, ref),
      ),
    ];
  }

  void _showNewJarDialog(BuildContext context, WidgetRef ref) {
    // final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => InputDialog(
        onConfirmed: (text) {
          if (text.isNotEmpty) {
            // Use selectedCollectionProvider instead to be safe?
            // But environmentProvider loads based on selected collection.
            // We can just query environments.first.collectionId as a fallback or inject selectedCollectionProvider.
            // Actually `createCookieJar` needs collectionId.
            // Let's get it from any jar.
            final anyJar = ref.read(environmentProvider).cookieJars.firstOrNull;
            if (anyJar != null) {
              ref
                  .read(environmentProvider.notifier)
                  .createCookieJar(text, anyJar.collectionId);
            }
          }
        },
        title: "New Cookie Jar",
        placeholder: "Enter jar name",
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String id,
    String currentName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => InputDialog(
        onConfirmed: (text) {
          if (text.isNotEmpty) {
            ref.read(environmentProvider.notifier).renameCookieJar(id, text);
          }
        },
        initialValue: currentName,
        title: "Rename Cookie Jar",
        placeholder: "Enter jar name",
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
