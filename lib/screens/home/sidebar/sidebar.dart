import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/sidebar/context_menu.dart';
import 'package:api_craft/screens/home/sidebar/file_node_tail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

class FileExplorerView extends ConsumerWidget {
  const FileExplorerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the new Tree State
    final treeState = ref.watch(fileTreeProvider);
    final theme = Theme.of(context);

    // 2. Derive Root Nodes (Filter map for items with no parent)
    // Note: No sorting applied as requested.
    final rootNodes = treeState.nodeMap.values
        .where((n) => n.parentId == null)
        .toList();
    debugPrint("roots: (${rootNodes.length}): ${rootNodes.map((e) => e.name)}");
    rootNodes.sort((a, b) {
      // Primary sort: Sort Order index
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) return orderCompare;

      // Fallback sort: Name (if sort orders happen to be equal/zero)
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    // debugPrint(
    //   "build:::file-explorer:::Rendering FileExplorerView with ${rootNodes.length} root nodes",
    // );
    // debugPrint(
    //   "nodes (${treeState.nodeMap.values.length}): ${treeState.nodeMap.values}",
    // );

    return Scaffold(
      body: treeState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ContextMenuWidget(
              menuProvider: (_) async {
                return getMenuProvider(
                  ref: ref,
                  context: context,
                  isRoot: true,
                );
              },
              child: CustomScrollView(
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: FileNodeTile(
                          node: rootNodes[index],
                          isFirstNode: index == 0,
                        ),
                      ),
                      childCount: rootNodes.length,
                    ),
                  ),

                  // The Empty Space Drop Zone (Unchanged)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: DragTarget<Node>(
                      onWillAcceptWithDetails: (details) => true,
                      onAcceptWithDetails: (details) {
                        if (rootNodes.isEmpty) {
                          // Handle drop into empty list if needed
                          return;
                        }
                        // Drop below the last item
                        final lastNode = rootNodes.last;
                        ref
                            .read(fileTreeProvider.notifier)
                            .handleDrop(
                              movedNode: details.data,
                              targetNode: lastNode,
                              slot: DropSlot.bottom,
                            );
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovering = candidateData.isNotEmpty;
                        return Container(
                          color: isHovering
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
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
    );
  }
}

class FileNodeDragWrapper extends ConsumerStatefulWidget {
  final Node node;
  final Widget child;
  final bool isOpen;

  const FileNodeDragWrapper({
    super.key,
    required this.node,
    this.isOpen = false,
    required this.child,
  });

  @override
  ConsumerState<FileNodeDragWrapper> createState() => _FileNodeTileState();
}

class _FileNodeTileState extends ConsumerState<FileNodeDragWrapper> {
  DropSlot? _currentDropSlot;
  bool _isDragging = false;

  // folder tile height
  static const double kTileHeight = 32.0;
  // drag feedback size
  static const double kDragWidthHeight = 26.0;

  @override
  Widget build(BuildContext context) {
    // return widget.child;
    return _buildDragWrapper(widget.child);
  }

  Widget _buildDragWrapper(Widget child) {
    final theme = Theme.of(context);

    // --- DRAGGABLE ---
    Widget draggable = LongPressDraggable<Node>(
      data: widget.node,
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
                widget.node is FolderNode ? Icons.folder : Icons.description,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(widget.node.name, style: theme.textTheme.bodyMedium),
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
        if (details.data.id == widget.node.id) return false;
        // Prevent recursive drops (Parent into Child)
        if (widget.node is FolderNode &&
            widget.node.id.startsWith(details.data.id)) {
          return false;
        }
        return true;
      },
      onMove: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localOffset = box.globalToLocal(details.offset);
        final double dy = localOffset.dy;

        // --- KEY LOGIC CHANGE ---
        // If folder is OPEN, we only interact with the Header (30px).
        // If the cursor is below 30px (over the children), we cancel the
        // parent's drop slot so the children can handle the event.
        if (widget.node is FolderNode && widget.isOpen) {
          if (dy > kTileHeight) {
            debugPrint("Dropping over children, cancel parent drop slot");
            if (_currentDropSlot != null) {
              setState(() => _currentDropSlot = null);
            }
            return;
          }
        }

        // Determine height to use for percentage calculation
        final activeHeight = (widget.node is FolderNode && widget.isOpen)
            ? kTileHeight
            : box.size.height;

        final percent = dy / activeHeight;
        DropSlot newSlot;

        if (widget.node is FolderNode) {
          // Folder Logic
          if (percent < 0.05) {
            newSlot = DropSlot.top;
          } else if (percent > 0.95) {
            newSlot = DropSlot.bottom;
          } else {
            newSlot = DropSlot.center; // Middle 50% is "Drop Inside"
          }
        } else {
          // File Logic (50/50 split)
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
            .handleDrop(
              movedNode: details.data,
              targetNode: widget.node,
              slot: slot,
            );
        setState(() => _currentDropSlot = null);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          // Allows indicators to render slightly outside bounds if needed
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

    // --- INDICATOR POSITIONING ---
    // If Open: Position relative to Header (top 30px).
    // If Closed/File: Position relative to full widget.

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
      // Logic: If open, the "bottom" of the header is at kTileHeight.
      // If closed, "bottom" is at bottom: 0.
      if (widget.node is FolderNode && widget.isOpen) {
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

    // DropSlot.center (Inside Folder)
    // Only highlight the HEADER (30px) if open, otherwise highlight full box
    if (widget.node is FolderNode && widget.isOpen) {
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

    // Default Fill (Closed folder)
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
