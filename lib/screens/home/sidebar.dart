import 'package:api_craft/dialog/input_dialog.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileExplorerView extends ConsumerWidget {
  const FileExplorerView({super.key});

  void createFolder(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return InputDialog(
          title: "New Folder",
          placeholder: "Folder Name",
          onConfirmed: (folderName) {
            final folder = ref.read(activeReqProvider.notifier);
            final path = folder.getDirectory();
            ref.read(fileTreeProvider.notifier).createFolder(path, folderName);
            // ref.read(fileTreeProvider.notifier).createFolder(folderName);
          },
        );
      },
    );
  }

  void createFile(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return InputDialog(
          title: "New Request File",
          placeholder: "File Name",
          onConfirmed: (fileName) {
            final folder = ref.read(activeReqProvider.notifier).getDirectory();
            ref.read(fileTreeProvider.notifier).createRequest(folder, fileName);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(fileTreeProvider);

    return Scaffold(
      body: treeAsync.when(
        data: (nodes) => ListView(
          children: nodes
              .map((node) => FileNodeTile(node: node, isRoot: true))
              .toList(),
        ),
        // Fallback to your custom list for recursion support
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'create_folder',
            onPressed: () => createFolder(context, ref),
            tooltip: 'Create Folder',
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'create_file',
            onPressed: () => createFile(context, ref),
            tooltip: 'Create Request File',
            child: const Icon(Icons.note_add),
          ),
        ],
      ),
    );
  }
}

class FileNodeTile extends ConsumerStatefulWidget {
  final FileNode node;
  final bool isRoot;
  final int indentLevel;

  const FileNodeTile({
    super.key,
    required this.node,
    this.isRoot = false,
    this.indentLevel = 0,
  });

  @override
  ConsumerState<FileNodeTile> createState() => _FileNodeTileState();
}

class _FileNodeTileState extends ConsumerState<FileNodeTile> {
  DropSlot? _currentDropSlot;
  bool _isDragging = false;

  bool _isExpanded = false; // Track expansion for folder icon

  @override
  Widget build(BuildContext context) {
    final activeNode = ref.watch(activeReqProvider);
    final isActive = activeNode?.path == widget.node.path;
    final theme = Theme.of(context);

    // --- CONFIGURATION ---
    const double arrowSize = 18.0;
    const double folderIconSize = 18.0;
    // Adjust root padding slightly if needed
    final double tileLeftPadding = widget.isRoot ? 4.0 : 8.0;

    // --- MATH FOR EXACT LINE ALIGNMENT ---
    // The line should start exactly at the center of the arrow.
    // Formula: Padding + (ArrowSize / 2) - (LineWidth / 2)
    final double lineMargin = tileLeftPadding + (arrowSize / 2) - 0.5;
    Widget header;
    if (widget.node.isDirectory) {
      header = Theme(
        // Remove default borders
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: SizedBox(
          child: ExpansionTile(
            key: PageStorageKey(widget.node.path),
            maintainState: true,
            initiallyExpanded: ref
                .read(activeReqProvider.notifier)
                .isDirectoryOpen(widget.node.path),

            // 1. CONTROL PADDING & SIZING
            tilePadding: EdgeInsets.only(left: tileLeftPadding, right: 8),
            childrenPadding: EdgeInsets.zero,
            dense: true,
            minTileHeight: 30,

            visualDensity: const VisualDensity(vertical: -4, horizontal: -4),

            // 2. DISABLE DEFAULT EXPANSION ICON
            trailing: const SizedBox.shrink(),

            // 3. CUSTOM ANIMATED ARROW (LEADING)
            leading: SizedBox(
              width: arrowSize,
              height: arrowSize,
              child: AnimatedRotation(
                // 0.0 = Right (0 deg), 0.25 = Bottom (90 deg)
                turns: _isExpanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Icon(
                  Icons.keyboard_arrow_right, // Standard tree arrow
                  size: arrowSize,
                  color: isActive
                      ? theme.colorScheme.primary
                      : const Color(0xA49E9E9E),
                ),
              ),
            ),

            // 4. TITLE: FOLDER ICON + TEXT
            title: Transform.translate(
              offset: Offset(-12, 0), // Adjust this value as needed
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.folder_open : Icons.folder,
                    color: isActive
                        ? theme.colorScheme.primary
                        : Colors.amber[700],
                    size: folderIconSize,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.node.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            onExpansionChanged: (expanded) =>
                setState(() => _isExpanded = expanded),

            // 5. CHILDREN WITH ALIGNED BORDER
            children: [
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Color(0xCB5C5C5C),
                      width: 0.5, // Line width
                    ),
                  ),
                ),
                // Apply the calculated margin to align line with arrow center
                margin: EdgeInsets.only(left: lineMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      widget.node.children?.map((child) {
                        return FileNodeTile(
                          node: child,
                          isRoot:
                              false, // Ensure children calculate padding correctly
                          indentLevel: widget.indentLevel + 1,
                        );
                      }).toList() ??
                      [],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // FILE TILE logic (Keep your existing logic, just align padding)
      // To align file icon with folder text, we need to offset it by arrow size + gap
      final double fileIndent =
          tileLeftPadding +
          arrowSize +
          0; // Adjust '0' to match gap in Row above

      header = Padding(
        padding: .only(left: fileIndent - 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () =>
              ref.read(activeReqProvider.notifier).setActiveNode(widget.node),
          child: Ink(
            padding: .symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.data_object,
                  size: folderIconSize, // Match folder icon size
                  color: isActive
                      ? theme.colorScheme.primary
                      : Colors.blueGrey[300],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.node.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- 2. DRAGGABLE WRAPPER ---
    // We wrap the header in Draggable.
    // Using LongPressDraggable prevents accidental drags when clicking to expand.
    Widget draggable = LongPressDraggable<FileNode>(
      data: widget.node,
      delay: const Duration(milliseconds: 150), // Short delay for better UX
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(widget.node.name, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
      onDragStarted: () => setState(() => _isDragging = true),
      onDragEnd: (_) => setState(() => _isDragging = false),
      child: Opacity(opacity: _isDragging ? 0.4 : 1.0, child: header),
    );

    // --- 3. DROP TARGET WITH IMPROVED LOGIC ---
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

        // --- NEW LOGIC START ---
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
        // --- NEW LOGIC END ---

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

  // --- 4. BEAUTIFUL DROP INDICATORS ---
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
