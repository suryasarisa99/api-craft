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
    final treeAsync = ref.watch(fileTreeProvider);

    return Scaffold(
      body: treeAsync.when(
        data: (nodes) => ContextMenuWidget(
          menuProvider: (_) async {
            return getMenuProvider(ref: ref, context: context, isRoot: true);
          },
          child: ListView(
            children: nodes
                .map((node) => FileNodeDragWrapper(node: node, isRoot: true))
                .toList(),
          ),
        ),
        // Fallback to your custom list for recursion support
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class FileNodeDragWrapper extends ConsumerStatefulWidget {
  final FileNode node;
  final bool isRoot;
  final int indentLevel;

  const FileNodeDragWrapper({
    super.key,
    required this.node,
    this.isRoot = false,
    this.indentLevel = 0,
  });

  @override
  ConsumerState<FileNodeDragWrapper> createState() => _FileNodeTileState();
}

class _FileNodeTileState extends ConsumerState<FileNodeDragWrapper> {
  DropSlot? _currentDropSlot;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final content = FileNodeTile(node: widget.node);
    return _buildDragWrapper(content);
  }

  Widget _buildDragWrapper(Widget child) {
    final theme = Theme.of(context);
    Widget draggable = LongPressDraggable<FileNode>(
      data: widget.node,
      delay: const Duration(milliseconds: 150), // Short delay for better UX
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                widget.node.isDirectory ? Icons.folder : Icons.description,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(widget.node.name, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      onDragStarted: () => setState(() => _isDragging = true),
      onDragEnd: (_) => setState(() => _isDragging = false),
      child: Opacity(opacity: _isDragging ? 0.4 : 1.0, child: child),
    );

    // --- DROP TARGET ---
    return DragTarget<FileNode>(
      onWillAcceptWithDetails: (details) {
        if (details.data.path == widget.node.path) return false;
        if (widget.node.isDirectory &&
            widget.node.path.startsWith(details.data.path)) {
          return false;
        }
        return true;
      },
      onMove: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localOffset = box.globalToLocal(details.offset);
        final height = box.size.height;
        final percent = localOffset.dy / height;

        DropSlot newSlot;

        if (widget.node.isDirectory) {
          // For Folders: Huge "Center" target to make dropping inside easy
          if (percent < 0.10) {
            newSlot = DropSlot.top;
          } else if (percent > 0.90) {
            newSlot = DropSlot.bottom;
          } else {
            newSlot = DropSlot.center; // Middle 60% is for "Inside"
          }
        } else {
          // For Files: No center slot. 50/50 Split.
          // This makes hitting "Bottom" (Last item) much easier.
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
          children: [
            draggable,
            if (_currentDropSlot != null)
              Positioned.fill(child: _buildDropIndicator(theme)),
          ],
        );
      },
    );
  }

  // --- DROP INDICATORS ---
  Widget _buildDropIndicator(ThemeData theme) {
    Color indicatorColor = theme.colorScheme.primary;

    if (_currentDropSlot == DropSlot.top) {
      return Align(
        alignment: Alignment.topCenter,
        child: Container(height: 2, color: indicatorColor),
      );
    }

    if (_currentDropSlot == DropSlot.bottom) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(height: 2, color: indicatorColor),
      );
    }

    // DropSlot.center (Inside Folder)
    return Container(
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.1),
        border: Border.all(color: indicatorColor, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
