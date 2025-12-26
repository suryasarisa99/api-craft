import 'dart:io';

import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/surya_theme_icon.dart';
import 'package:api_craft/features/sidebar/context_menu.dart';
import 'package:api_craft/features/sidebar/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:suryaicons/bulk_rounded.dart';

const folderIcon = SuryaThemeIcon(BulkRounded.folder01);
const folderOpenIcon = SuryaThemeIcon(BulkRounded.folder02);

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
  // Layout Constants for perfect alignment
  static const double _kIndentStep = 14.0; // Indentation per depth level

  // Header Item Padding
  static const double _kItemHorizontalPadding = 4.0;

  // Arrow / Icon Layout
  static const double _kArrowBoxWidth =
      16.0; // Width of the expanded/collapsed arrow container
  static const double _kSpacingBetweenArrowAndIcon = 4.0;

  // Calculated: The visual center of the arrow container
  static const double _kArrowCenterOffset = _kArrowBoxWidth / 2;

  // Tweakable: Shift the divider left/right.
  // 0.0 means mathematically centered relative to the Arrow Box geometric center.
  // Use _kDividerNudge to adjust for visual weight of the icon or sub-pixel aliasing.
  static const double _kDividerLeftPadding = _kArrowCenterOffset;
  static const double _kDividerNudge = 0.0; // Adjust this manually if needed.

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
    // request focus to it.
    if (_isExpanded) {
      // delay because while closing folder,focus goes to its children,so after animation completes focus should go to parent
      Future.delayed(
        const Duration(milliseconds: 10),
        () => _focusNode.requestFocus(),
      );
    } else {
      _focusNode.requestFocus();
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
        final hk = HardwareKeyboard.instance;
        final isShift = hk.isShiftPressed;
        final isCtrl = Platform.isMacOS
            ? hk.isMetaPressed
            : hk.isControlPressed;

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
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          final hk = HardwareKeyboard.instance;
          final isShift = hk.isShiftPressed;
          final isCtrl = Platform.isMacOS
              ? hk.isMetaPressed
              : hk.isControlPressed;

          if (isShift) {
            // Range Selection (simulated via Multi-Select add)
            // User requested to unselect if already selected, so we use toggle logic manually if needed
            // But 'toggle' in provider does exactly that: remove if present, add if not.
            ref.read(selectedNodesProvider.notifier).toggle(vNode.id);
          } else if (!isCtrl) {
            // Normal Navigation -> Single Select
            // Unless we want to separate Focus from Selection?
            // Standard file exploers select on focus.
            ref
                .read(selectedNodesProvider.notifier)
                .select(vNode.id, multi: false);

            // Also set as active request?
            // Existing logic in _handleTap:
            // } else {
            //   ref.read(activeReqIdProvider.notifier).setActiveId(vNode.id);
            //   ref.read(selectedNodesProvider.notifier).clear();
            // }
            // Maybe we should just select it visually and let user Enter to open?
            // For now, let's just update selectedNodesProvider.
            // If it's a file, maybe activeReqIdProvider calls logic to open tab?
            // if (vNode.type == NodeType.request) {
            //   ref.read(activeReqIdProvider.notifier).setActiveId(vNode.id);
            // }
          }
        }
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
    final double tileHeight = vNode.type == NodeType.folder ? 30.0 : 28.0;

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
        // ? cs.surfaceBright.withValues(alpha: 1)
        ? const Color.fromARGB(150, 70, 70, 70)
        : isSelected
        ? cs.secondary.withValues(alpha: 0.10)
        : Colors.transparent;

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
              padding: const EdgeInsets.symmetric(
                horizontal: _kItemHorizontalPadding,
              ),
              child: _contextMenuWrapper(
                vNode: vNode,
                isDirectory: isFolder,
                child: focusWrapper(
                  hasFocus: hasFocus,
                  vNode: vNode,
                  child: Builder(
                    builder: (context) {
                      final isFocused = Focus.of(context).hasFocus;
                      return Material(
                        borderRadius: BorderRadius.circular(4),
                        elevation: 0,
                        color: (isActive || !isFocused)
                            ? backgroundColor
                            : theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.6,
                              ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          canRequestFocus: false,
                          autofocus: false,
                          onTap: () => _handleTap(vNode),
                          hoverColor: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: widget.depth * _kIndentStep,
                            ),
                            child: Row(
                              children: [
                                // A. ARROW
                                if (isFolder)
                                  RotationTransition(
                                    turns: _iconTurns,
                                    child: SizedBox(
                                      width: _kArrowBoxWidth,
                                      child: Icon(
                                        Icons.keyboard_arrow_right_rounded,
                                        size:
                                            _kArrowBoxWidth, // Fill the box for consistent alignment center
                                        color: textColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: _kArrowBoxWidth),
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
                        ),
                      );
                    },
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
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 1,
                          color: theme.dividerColor.withValues(alpha: 0.4),
                          margin: EdgeInsets.only(
                            // Mathematical Center: (Depth * Step) + ArrowCenter - (DividerWidth / 2)
                            left:
                                _kItemHorizontalPadding +
                                (widget.depth * _kIndentStep) +
                                _kDividerLeftPadding +
                                _kDividerNudge -
                                1,
                          ),
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
