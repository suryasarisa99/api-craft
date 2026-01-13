import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/services/toast_service.dart';

import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:suryaicons/bulk_rounded.dart';
import 'package:api_craft/features/collection/collection_config_dialog.dart';
import 'package:file_picker/file_picker.dart';

class CollectionPicker extends ConsumerStatefulWidget {
  const CollectionPicker({super.key});

  @override
  ConsumerState<CollectionPicker> createState() => _CollectionPickerState();
}

class _CollectionPickerState extends ConsumerState<CollectionPicker> {
  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();

  @override
  Widget build(BuildContext context) {
    final selectedCollection = ref.watch(selectedCollectionProvider);
    final collections = ref.watch(collectionsProvider).asData?.value ?? [];

    return MyCustomMenu.contentColumn(
      popupKey: _popupKey,
      width: 200,
      items: [
        ...collections.map((c) {
          final isSelected = c.id == selectedCollection?.id;
          return CustomMenuIconItem.tick(
            title: Text(c.name),
            value: c.id,
            checked: isSelected,
            onTap: (_) {
              ref.read(selectedCollectionProvider.notifier).select(c);
              // change active request
              // ref.read(activeReqIdProvider.notifier).setActiveId(null);
            },
          );
        }),
        menuDivider,
        CustomMenuIconItem(
          icon: const SuryaThemeIcon(BulkRounded.plusSign),
          title: const Text("Create New..."),
          value: 'create',
          onTap: (_) => _showCreateDialog(context),
        ),

        if (selectedCollection != null) ...[
          menuDivider,
          CustomMenuIconItem(
            icon: const SuryaThemeIcon(BulkRounded.settings01),
            title: const Text("Configure Collection"),
            value: 'configure',
            onTap: (_) {
              showDialog(
                context: context,
                builder: (_) =>
                    CollectionConfigDialog(collectionId: selectedCollection.id),
              );
            },
          ),
          menuDivider,
          CustomMenuIconItem(
            icon: const SuryaThemeIcon(BulkRounded.linkBackward),
            title: const Text("Clear History"),
            value: 'clear_history',
            onTap: (_) {
              ref.read(dataRepositoryProvider).clearHistoryForCollection();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("History cleared")));
            },
          ),
        ],
        if (selectedCollection != null &&
            selectedCollection.id != kDefaultCollection.id)
          CustomMenuIconItem(
            // icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            icon: const SuryaThemeIcon(BulkRounded.delete01),
            title: const Text(
              "Delete Collection",
              style: TextStyle(color: Colors.red),
            ),
            value: 'delete',
            onTap: (_) => _showDeleteDialog(context, selectedCollection),
          ),
      ],
      child: Text(
        selectedCollection != null
            ? selectedCollection.name
            : 'Select Collection',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateCollectionDialog(),
    );
  }

  void _showDeleteDialog(BuildContext context, CollectionModel collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete '${collection.name}'?"),
        content: const Text(
          "This will permanently delete this collection and all its requests, history, and environments.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(collectionsProvider.notifier)
                  .deleteCollection(collection.id);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

class _CreateCollectionDialog extends ConsumerStatefulWidget {
  const _CreateCollectionDialog();

  @override
  ConsumerState<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState
    extends ConsumerState<_CreateCollectionDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedPath;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _selectedPath = result;
      });
    }
  }

  Future<void> _create() async {
    try {
      final name = _nameController.text.trim();
      if (name.isEmpty) return;

      final type = _selectedPath != null
          ? CollectionType.filesystem
          : CollectionType.database;

      final newCollection = await ref
          .read(collectionsProvider.notifier)
          .createCollection(name, type: type, path: _selectedPath);

      if (mounted) {
        ref.read(selectedCollectionProvider.notifier).select(newCollection);
        Navigator.pop(context);
      }
    } catch (e) {
      ToastService.error(
        "Collection creation failed",
        description: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text("New Collection"),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Collection Name",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 16),
            const Text(
              "Storage Loaction",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                dense: true,
                onTap: _pickFolder,
                leading: const Icon(Icons.folder, size: 20),
                title: Text(
                  _selectedPath ?? "Database (Default)",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _selectedPath == null
                        ? theme.disabledColor
                        : theme.textTheme.bodyMedium?.color,
                    fontStyle: _selectedPath == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                trailing: _selectedPath != null
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            _selectedPath = null;
                          });
                        },
                      )
                    : const Icon(Icons.edit, size: 16),
              ),
            ),
            if (_selectedPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Files will be stored in this directory.",
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(onPressed: _create, child: const Text("Create")),
      ],
    );
  }
}
