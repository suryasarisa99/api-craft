import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/features/sidebar/context_menu.dart';
import 'package:api_craft/features/sidebar/file_node_tail.dart';
import 'package:api_craft/features/sidebar/providers/clipboard_provider.dart';
import 'package:api_craft/features/sidebar/providers/sidebar_search_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

class FileExplorerView extends ConsumerWidget {
  const FileExplorerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootList = ref.watch(rootIdsProvider);
    final isLoading = ref.watch(fileTreeProvider.select((s) => s.isLoading));

    if (isLoading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyC, meta: true): () {
            final selected = ref.read(selectedNodesProvider);
            if (selected.isNotEmpty) {
              ref.read(clipboardProvider.notifier).copy(selected);
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyX, meta: true): () {
            debugPrint('Cut');
            final selected = ref.read(selectedNodesProvider);
            if (selected.isNotEmpty) {
              ref.read(clipboardProvider.notifier).cut(selected);
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () {
            final clipboard = ref.read(clipboardProvider);
            if (clipboard.isNotEmpty) {
              // Determine target from selection
              final selected = ref.read(selectedNodesProvider);
              final targetId = selected.isNotEmpty ? selected.last : null;
              ref
                  .read(fileTreeProvider.notifier)
                  .paste(clipboard, targetId: targetId);
            }
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            ref.read(selectedNodesProvider.notifier).clear();
          },
          const SingleActivator(LogicalKeyboardKey.delete): () {
            final selected = ref.read(selectedNodesProvider);
            if (selected.isNotEmpty) {
              ref
                  .read(fileTreeProvider.notifier)
                  .deleteNodes(selected.toList());
            }
          },
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Consumer(
                builder: (context, ref, child) {
                  final searchState = ref.watch(sidebarSearchProvider);
                  return SizedBox(
                    // height: 36,
                    child: TextField(
                      onChanged: (val) => ref
                          .read(sidebarSearchProvider.notifier)
                          .setQuery(val),
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search files...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ), // Vertical center
                        prefixIcon: Icon(
                          Icons.search,
                          size: 16,
                          color: theme.iconTheme.color?.withValues(alpha: 0.7),
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          maxWidth: 120,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (searchState.query.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  ref
                                      .read(sidebarSearchProvider.notifier)
                                      .setQuery('');
                                },
                                child: const Icon(Icons.close, size: 16),
                              ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: "Search Folders",
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => ref
                                    .read(sidebarSearchProvider.notifier)
                                    .toggleSearchFolders(),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: searchState.searchFolders
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.2,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.folder_open,
                                    size: 16,
                                    color: searchState.searchFolders
                                        ? theme.colorScheme.primary
                                        : theme.iconTheme.color?.withValues(
                                            alpha: 0.5,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 0),
                child: ContextMenuWidget(
                  menuProvider: (_) async {
                    return getMenuProvider(
                      ref: ref,
                      context: context,
                      isRoot: true,
                    );
                  },
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: CustomScrollView(
                      slivers: [
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final id = rootList.ids[index];
                            return FileNodeTile(
                              key: ValueKey(id), // Important for performance
                              nodeId: id, // Pass ID only
                              isFirstNode: index == 0,
                            );
                          }, childCount: rootList.ids.length),
                        ),

                        // --- Drop Zone ---
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: DragTarget<Node>(
                            onWillAcceptWithDetails: (details) => true,
                            onAcceptWithDetails: (details) {
                              if (rootList.ids.isEmpty) return;

                              final lastId = rootList.ids.last;
                              final lastNode = ref
                                  .read(fileTreeProvider)
                                  .nodeMap[lastId];

                              if (lastNode != null) {
                                ref
                                    .read(fileTreeProvider.notifier)
                                    .handleDrop(
                                      movedNode: details.data,
                                      targetNode: lastNode,
                                      slot: DropSlot.bottom,
                                    );
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              final isHovering = candidateData.isNotEmpty;
                              return Container(
                                color: isHovering
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      )
                                    : Colors.transparent,
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 2),
                                child: isHovering
                                    ? Container(
                                        height: 2,
                                        color: theme.colorScheme.primary,
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FileNodeDragWrapper extends ConsumerStatefulWidget {
  final String id;
  final Widget child;
  final bool isOpen;

  const FileNodeDragWrapper({
    super.key,
    this.isOpen = false,
    required this.child,
    required this.id,
  });

  @override
  ConsumerState<FileNodeDragWrapper> createState() => _FileNodeTileState();
}

class _FileNodeTileState extends ConsumerState<FileNodeDragWrapper> {
  DropSlot? _currentDropSlot;
  bool _isDragging = false;
  late final node = ref.read(fileTreeProvider).nodeMap[widget.id]!;

  // folder tile height
  static const double kTileHeight = 32.0;
  // drag feedback size
  static const double kDragWidthHeight = 26.0;

  @override
  Widget build(BuildContext context) {
    return _buildDragWrapper(widget.child);
  }

  Widget _buildDragWrapper(Widget child) {
    final theme = Theme.of(context);

    // --- DRAGGABLE ---
    Widget draggable = LongPressDraggable(
      data: node,
      delay: const Duration(milliseconds: 150),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          height: kDragWidthHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withValues(alpha: 0.2),
              ),
            ],
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                node is FolderNode ? Icons.folder : Icons.description,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(node.name, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
      onDragStarted: () => setState(() => _isDragging = true),
      onDragEnd: (_) => setState(() => _isDragging = false),
      child: Opacity(opacity: _isDragging ? 0.4 : 1.0, child: child),
    );

    // --- DROP TARGET ---
    return DragTarget<Node>(
      onWillAcceptWithDetails: (details) {
        final movedNode = details.data;
        final targetNode = node;

        // 1. Cannot drop onto self
        if (movedNode.id == targetNode.id) return false;

        // 2. Cycle Detection
        final treeMap = ref.read(fileTreeProvider).nodeMap;
        Node? ptr = targetNode;
        while (ptr != null) {
          if (ptr.id == movedNode.id) return false;
          if (ptr.parentId == null) break;
          ptr = treeMap[ptr.parentId];
        }

        return true;
      },
      onMove: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localOffset = box.globalToLocal(details.offset);
        final double dy = localOffset.dy;

        // If folder is OPEN, only interact with Header (30px)
        if (node is FolderNode && widget.isOpen) {
          if (dy > kTileHeight) {
            if (_currentDropSlot != null) {
              setState(() => _currentDropSlot = null);
            }
            return;
          }
        }

        final activeHeight = (node is FolderNode && widget.isOpen)
            ? kTileHeight
            : box.size.height;

        final percent = dy / activeHeight;
        DropSlot newSlot;

        if (node is FolderNode) {
          if (percent < 0.05) {
            newSlot = DropSlot.top;
          } else if (percent > 0.95) {
            newSlot = DropSlot.bottom;
          } else {
            newSlot = DropSlot.center;
          }
        } else {
          if (percent < 0.5) {
            newSlot = DropSlot.top;
          } else {
            newSlot = DropSlot.bottom;
          }
        }

        if (_currentDropSlot != newSlot) {
          setState(() => _currentDropSlot = newSlot);
        }
      },
      onLeave: (_) => setState(() => _currentDropSlot = null),
      onAcceptWithDetails: (details) {
        final slot = _currentDropSlot ?? DropSlot.center;
        ref
            .read(fileTreeProvider.notifier)
            .handleDrop(movedNode: details.data, targetNode: node, slot: slot);
        setState(() => _currentDropSlot = null);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            draggable,
            if (_currentDropSlot != null) _buildDropIndicator(theme),
          ],
        );
      },
    );
  }

  Widget _buildDropIndicator(ThemeData theme) {
    final color = theme.colorScheme.primary;
    const double borderThick = 2.0;

    if (_currentDropSlot == DropSlot.top) {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: borderThick,
        child: Container(color: color),
      );
    }

    if (_currentDropSlot == DropSlot.bottom) {
      if (node is FolderNode && widget.isOpen) {
        return Positioned(
          top: kTileHeight - borderThick,
          left: 0,
          right: 0,
          height: borderThick,
          child: Container(color: color),
        );
      } else {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: borderThick,
          child: Container(color: color),
        );
      }
    }

    // DropSlot.center
    if (node is FolderNode && widget.isOpen) {
      return Positioned(
        top: 0,
        height: kTileHeight,
        left: 0,
        right: 0,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: borderThick),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: borderThick),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
