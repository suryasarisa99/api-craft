import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:suryaicons/bulk_rounded.dart';

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
            icon: const SuryaThemeIcon(BulkRounded.linkBackward),
            title: const Text("Clear History"),
            value: 'clear_history',
            onTap: (_) {
              ref.read(repositoryProvider).clearHistoryForCollection();
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
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Collection"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Collection Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(collectionsProvider.notifier)
                    .createCollection(name, type: CollectionType.database);
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
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
