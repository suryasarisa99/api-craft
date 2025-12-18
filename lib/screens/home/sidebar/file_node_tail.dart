import 'dart:io';

import 'package:api_craft/models/models.dart';
import 'package:api_craft/providers/providers.dart';
import 'package:api_craft/screens/home/sidebar/context_menu.dart';
import 'package:api_craft/screens/home/sidebar/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:suryaicons/bulk_rounded.dart';
import 'package:suryaicons/suryaicons.dart';

final _folderClr = const Color(0xFFC4742D);
final _folderSize = 18.0;

final folderIcon = SuryaIcon(
  icon: BulkRounded.folder01,
  color: Colors.transparent,
  color2: _folderClr,
  opacity: 0.8,
  size: _folderSize,
  strokeWidth: 1,
);
final folderOpenIcon = SuryaIcon(
  icon: BulkRounded.folder02,
  color: _folderClr,
  color2: const Color(0xFFFFA726),
  opacity: 1,
  size: _folderSize,
);

class FileNodeTile extends ConsumerStatefulWidget {
  final String nodeId; // Accepts ID only
  final int depth;
  final bool isFirstNode;

  const FileNodeTile({
    super.key,
    required this.nodeId,
    this.depth = 0,
    this.isFirstNode = false,
  });

  @override
  ConsumerState<FileNodeTile> createState() => _FileTreeTileState();
}

class _FileTreeTileState extends ConsumerState<FileNodeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;
  late bool _isExpanded = false;
  late final FocusNode _focusNode = FocusNode();

  // Your Constants (Unchanged)
  // We cannot access 'widget.node.type' in initializer anymore, handled in build/initState logic
  static const double _kIndentation = 6.0;
  static const double _kIconSize = 14.0;
  // static const double _kFolderIconSize = 17.0;
  static const double _kSpacingBetweenArrowAndIcon = 2.0;

  late final activeNode = ref.read(activeReqProvider);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _iconTurns = Tween<double>(
      begin: 0.0,
      end: 0.25,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _heightFactor = _controller.view;

    // Expansion Logic
    // Access node via ref.read inside initState is safe
    final node = ref.read(fileTreeProvider).nodeMap[widget.nodeId];
    if (node != null && node.type == NodeType.folder) {
      // Assuming your ancestor check works with ID or Node
      final initiallyExpanded = _isAncestor();
      if (initiallyExpanded) {
        _isExpanded = true;
        _controller.value = 1.0;
      }
    }
  }

  bool _isAncestor() {
    var ptr = getParent(activeNode);
    while (ptr != null) {
      if (ptr.id == widget.nodeId) {
        return true;
      }
      ptr = getParent(ptr);
    }
    return false;
  }

  Node? getParent(Node? node) {
    final tree = ref.read(fileTreeProvider);
    return tree.nodeMap[node?.parentId];
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTap(VisualNode vNode) {
    final hk = HardwareKeyboard.instance;
    final isCtrl = Platform.isMacOS ? hk.isMetaPressed : hk.isControlPressed;
    if (isCtrl) {
      ref.read(selectedNodesProvider.notifier).toggle(vNode.id);
      return;
    }

    if (vNode.type == NodeType.folder) {
      setState(() {
        _isExpanded = !_isExpanded;
        if (_isExpanded) {
          _controller.forward();
        } else {
          _controller.reverse().then((_) {
            if (!mounted) return;
            setState(() {});
          });
        }
      });
    } else {
      ref.read(activeReqIdProvider.notifier).setActiveId(vNode.id);
      ref.read(selectedNodesProvider.notifier).clear();
    }
  }

  void handleToggleExpand(VisualNode vNode) {
    if (vNode.type == NodeType.folder) {
      setState(() {
        _isExpanded = !_isExpanded;
        if (_isExpanded) {
          _controller.forward();
        } else {
          _controller.reverse().then((_) {
            if (!mounted) return;
            setState(() {});
          });
        }
      });
    }
  }

  Widget focusWrapper({
    required Widget child,
    required bool hasFocus,
    required VisualNode vNode,
  }) {
    return Focus(
      focusNode: _focusNode,
      autofocus: hasFocus,
      descendantsAreFocusable: _isExpanded,
      descendantsAreTraversable: _isExpanded,
      canRequestFocus: true,
      onKeyEvent: (FocusNode node, KeyEvent keyEvent) {
        if (keyEvent is KeyUpEvent) return KeyEventResult.ignored;
        final k = keyEvent.logicalKey;

        if (k == LogicalKeyboardKey.arrowDown) {
          FocusScope.of(context).nextFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowUp) {
          FocusScope.of(context).previousFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          if (vNode.type == NodeType.folder && !_isExpanded) {
            handleToggleExpand(vNode);
          } else {
            FocusScope.of(context).nextFocus();
          }
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (vNode.type == NodeType.folder && _isExpanded) {
            handleToggleExpand(vNode);
            Future.delayed(const Duration(milliseconds: 10), () {
              _focusNode.requestFocus();
            });
          } else {
            FocusScope.of(context).previousFocus();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. WATCH THE OPTIMIZED PROVIDER
    // If URL/Content changes, 'vNode' is IDENTICAL to previous, so build STOPS here.
    final vNode = ref.watch(visualNodeProvider(widget.nodeId));

    if (vNode == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final double tileHeight = vNode.type == NodeType.folder ? 32.0 : 28.0;

    // --- WATCH REQUIRED PROVIDERS ---
    final activeNode = ref.watch(activeReqProvider);
    final selected = ref.watch(selectedNodesProvider);

    final isSelected = selected.contains(vNode.id);
    final isActive = activeNode?.id == vNode.id;
    final hasFocus = (activeNode == null && widget.isFirstNode) || isActive;
    final isFolder = vNode.type == NodeType.folder;

    final Color textColor = isActive
        ? cs.primary
        : theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final Color? backgroundColor = isActive
        ? cs.secondaryContainer.withValues(alpha: 0.6)
        : isSelected
        ? cs.secondary.withValues(alpha: 0.10)
        : null;

    return FileNodeDragWrapper(
      id: vNode.id,
      isOpen: _isExpanded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. THE HEADER ---
          SizedBox(
            height: tileHeight,
            child: Padding(
              padding: .only(right: 4, left: 4),
              child: Material(
                borderRadius: BorderRadius.circular(4),
                color: backgroundColor ?? Colors.transparent,
                // color: Colors.transparent,
                child: _contextMenuWrapper(
                  vNode: vNode,
                  isDirectory: isFolder,
                  child: focusWrapper(
                    hasFocus: hasFocus,
                    vNode: vNode,
                    child: Builder(
                      builder: (context) {
                        // final isFocused = Fd
                        // focus.of(context).hasFocus;
                        return InkWell(
                          borderRadius: BorderRadius.circular(4),
                          canRequestFocus: false,
                          autofocus: false,
                          onTap: () => _handleTap(vNode),
                          hoverColor: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                          child: Ink(
                            padding: .only(
                              left: (widget.depth == 0
                                  ? 0
                                  : (widget.depth * (_kIndentation + 6))),
                            ),
                            child: Row(
                              children: [
                                // SizedBox(width: _kIndentation),
                                // A. ARROW
                                if (isFolder)
                                  RotationTransition(
                                    turns: _iconTurns,
                                    child: SizedBox(
                                      width: _kIconSize + 2,
                                      child: Icon(
                                        Icons.keyboard_arrow_right,
                                        size: _kIconSize + 2,
                                        color: textColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: _kIconSize + 2),
                                const SizedBox(
                                  width: _kSpacingBetweenArrowAndIcon,
                                ),

                                // B. ICON
                                if (isFolder)
                                  _isExpanded
                                      ? folderOpenIcon
                                      : folderIcon // (Ensure these are accessible)
                                else
                                  Text(
                                    vNode.method ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w300,
                                      color: const Color.fromARGB(
                                        255,
                                        156,
                                        192,
                                        250,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),

                                // C. LABEL
                                Expanded(
                                  child: Text(
                                    vNode.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                      fontWeight: FontWeight.normal,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                if (vNode.statusCode != null)
                                  Text(
                                    vNode.statusCode.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                SizedBox(width: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- 2. THE CHILDREN ---
          if (isFolder)
            ExcludeFocus(
              excluding: !_isExpanded,
              child: SizeTransition(
                sizeFactor: _heightFactor,
                axisAlignment: -1.0,
                child: Stack(
                  children: [
                    // vertical divider at left for children
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(
                            left: widget.depth == 0
                                ? 2 + (_kIconSize / 2) + 2
                                : (widget.depth * (_kIndentation + 6.5)) +
                                      (_kIconSize / 2) +
                                      2,
                          ),
                          width: 1,
                          color: theme.dividerColor.withValues(alpha: 0.25),
                        ),
                      ),
                    ),

                    Builder(
                      builder: (context) {
                        final childIds = vNode.children;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: childIds.map((childId) {
                            return FileNodeTile(
                              key: ValueKey(childId),
                              nodeId: childId,
                              depth: widget.depth + 1,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _contextMenuWrapper({
    required Widget child,
    required VisualNode vNode,
    bool isDirectory = true,
  }) {
    return ContextMenuWidget(
      menuProvider: (_) {
        final node = ref.read(fileTreeProvider).nodeMap[vNode.id];
        return getMenuProvider(
          ref: ref,
          context: context,
          node: node,
          isDirectory: isDirectory,
        );
      },
      child: child,
    );
  }
}
