import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/utils/debouncer.dart';
import 'package:api_craft/core/widgets/ui/custom_dialog.dart';
import 'package:api_craft/core/widgets/ui/variable_text_field_custom.dart';
import 'package:api_craft/features/auth/auth_tab.dart';
import 'package:api_craft/features/collection/collection_model.dart';
import 'package:api_craft/features/request/widgets/tabs/headers_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

class CollectionConfigDialog extends ConsumerStatefulWidget {
  final String collectionId;
  const CollectionConfigDialog({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionConfigDialog> createState() =>
      _CollectionConfigDialogState();
}

class _CollectionConfigDialogState
    extends ConsumerState<CollectionConfigDialog> {
  int tabIndex = 0;
  bool hasChanges = false;
  static const useLazyMode = true;
  late final ProviderSubscription<FolderNode> subscription;
  final debouncer = Debouncer(Duration(milliseconds: 1000));

  @override
  void initState() {
    super.initState();
    // Listen for changes in the node
    subscription = ref.listenManual(
      fileTreeProvider.select(
        (s) => s.nodeMap[widget.collectionId] as CollectionNode,
      ),
      (previous, next) {
        if (useLazyMode) {
          /// note: hasChanges is always becomes true, when folder config dialog is opened
          hasChanges = true;
          subscription.close();
        } else {
          debouncer.run(() {
            ref.read(repositoryProvider).updateNode(next);
          });
        }
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    subscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (pop, result) async {
        // Trigger inheritance update
        ref
            .read(nodeUpdateTriggerProvider.notifier)
            .setLastUpdatedFolder(widget.collectionId);

        // Lazy Persistence
        if (hasChanges) {
          final node =
              ref.read(fileTreeProvider).nodeMap[widget.collectionId]
                  as CollectionNode;
          await ref.read(repositoryProvider).updateNode(node);
        }
      },
      child: CustomDialog(
        width: 900,
        height: 600,
        child: NotificationListener<SwitchTabNotification>(
          onNotification: (notification) {
            setState(() {
              tabIndex = notification.index;
            });
            return true;
          },
          child: _buildDialog(),
        ),
      ),
    );
  }

  Widget _buildDialog() {
    final tabs = ["General", "Storage", "Headers", "Auth"];
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          // Header
          Consumer(
            builder: (context, ref, child) {
              final title = ref.watch(
                collectionsProvider.select(
                  (value) =>
                      value.value
                          ?.firstWhere((e) => e.id == widget.collectionId)
                          .name ??
                      "",
                ),
              );
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 28,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: Column(
                    children: [
                      for (final (index, tab) in tabs.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              setState(() {
                                tabIndex = index;
                              });
                            },
                            child: Container(
                              width: 150,
                              decoration: BoxDecoration(
                                color: tabIndex == index
                                    ? const Color(
                                        0xFFEC21F3,
                                      ).withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: index == 3 ? 0 : 6,
                                horizontal: 8,
                              ),
                              child: index == 3
                                  ? SizedBox(
                                      height: 32,
                                      child: AuthTabHeader(
                                        color: tabIndex == index
                                            ? const Color(0xFFE17FF0)
                                            : Colors.grey,
                                        widget.collectionId,
                                        isTabActive: tabIndex == index,
                                        handleSetTab: () {
                                          setState(() {
                                            tabIndex = index;
                                          });
                                        },
                                      ),
                                    )
                                  : Text(
                                      tab,
                                      style: TextStyle(
                                        color: tabIndex == index
                                            ? const Color(0xFFE17FF0)
                                            : Colors.grey,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LazyLoadIndexedStack(
                    index: tabIndex,
                    children: [
                      // 1. General Tab
                      _GeneralTab(id: widget.collectionId),
                      // 2. Storage Tab
                      _StorageTab(id: widget.collectionId),
                      // 3. Headers Tab
                      HeadersTab(id: widget.collectionId),
                      // 4. Auth Tab
                      AuthTab(id: widget.collectionId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralTab extends ConsumerStatefulWidget {
  final String id;
  const _GeneralTab({required this.id});

  @override
  ConsumerState<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends ConsumerState<_GeneralTab> {
  late final TextEditingController nameController;
  late final ReqComposeNotifier notifier;

  @override
  void initState() {
    super.initState();
    final collection = ref
        .read(collectionsProvider)
        .value!
        .firstWhere((e) => e.id == widget.id);
    nameController = TextEditingController(text: collection.name);
    // Assuming root node ID is same as collection ID for description/config updates?
    // If not, we need a way to get root node from collection ID.
    // Usually collection ID == Root Node ID in fileTree structure if it's the root.
    // Let's assume widget.id is valid for ReqComposeNotifier (which works on Nodes).
    notifier = ref.read(reqComposeProvider(widget.id).notifier);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to collection name changes
    ref.listen(
      collectionsProvider.select(
        (v) => v.value?.firstWhere((e) => e.id == widget.id).name,
      ),
      (_, n) {
        if (n != null && n != nameController.text) {
          nameController.text = n;
        }
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: "Collection Name",
              border: OutlineInputBorder(),
              labelText: "Name",
            ),
            onChanged: (val) {
              if (val.trim().isEmpty) return;

              ref
                  .read(collectionsProvider.notifier)
                  .updateCollection(
                    ref
                        .read(collectionsProvider)
                        .value!
                        .firstWhere((e) => e.id == widget.id)
                        .copyWith(name: val),
                  );
            },
          ),
          const SizedBox(height: 24),
          // Description likely stored in NodeConfig of the root node
          TextFormField(
            initialValue: ref.watch(
              reqComposeProvider(
                widget.id,
              ).select((v) => v.node.config.description),
            ),
            decoration: const InputDecoration(
              hintText: "Description",
              border: OutlineInputBorder(),
              labelText: "Description",
            ),
            maxLines: 5,
            onChanged: notifier.updateDescription,
          ),
        ],
      ),
    );
  }
}

class _StorageTab extends ConsumerWidget {
  final String id;
  const _StorageTab({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(
      collectionsProvider.select(
        (value) => value.value!.firstWhere((e) => e.id == id),
      ),
    );

    if (collection.type == CollectionType.database) {
      return const Center(child: Text("Database Storage (Managed internally)"));
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Storage Path", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(collection.path ?? "Unknown path"),
          const SizedBox(height: 16),
          const Text(
            "To change path, please re-import the collection from the new location (Implementation of move pending).",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
