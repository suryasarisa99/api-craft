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

class FileNodeTile extends ConsumerStatefulWidget {
  final FileNode node; // Your Node class
  final int depth; // Current indentation level (0 for root)
  final VoidCallback? onRefresh; // Optional callback
  final bool isFirstNode;
  const FileNodeTile({
    super.key,
    required this.node,
    this.depth = 0,
    this.onRefresh,
    this.isFirstNode = false,
  });

  @override
  ConsumerState<FileNodeTile> createState() => _FileTreeTileState();
}

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

class _FileTreeTileState extends ConsumerState<FileNodeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;
  // expand is about for active and all its parent directories
  late bool _isExpanded = false;
  late final FocusNode _focusNode = FocusNode();
  // selected for to select multiple files

  // Configuration Constants
  late final double _kTileHeight = widget.node.isDirectory ? 32.0 : 28.0;
  static const double _kIndentation = 6.0;
  static const double _kIconSize = 14.0;
  static const double _kFolderIconSize = 17.0;
  static const double _kSpacingBetweenArrowAndIcon = 2.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Rotate 90 degrees (0.25 turns) when expanded
    _iconTurns = Tween<double>(
      begin: 0.0,
      end: 0.25,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _heightFactor = _controller.view;

    // Check if initially expanded via your Provider
    final initiallyExpanded = widget.node.isDirectory
        ? ref.read(activeReqProvider.notifier).isAncestor(widget.node)
        : false;
    // final _isSelected = ref
    //     .read(selectedNodesProvider.notifier)
    //     .isSelected(widget.node.path);
    if (initiallyExpanded) {
      _isExpanded = true;
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 1. Handle Selection Logic (Multi-select or Single)
    final hk = HardwareKeyboard.instance;
    final isCtrl = Platform.isMacOS ? hk.isMetaPressed : hk.isControlPressed;
    if (isCtrl) {
      // setState(() {
      //   _isSelected = !_isSelected;
      // });
      ref.read(selectedNodesProvider.notifier).toggle(widget.node.id);
      return;
    }

    // 2. Handle Expansion if directory
    if (widget.node.isDirectory) {
      setState(() {
        _isExpanded = !_isExpanded;
        if (_isExpanded) {
          _controller.forward();
          // ref.read(activeReqProvider.notifier).setDirectoryOpen(widget.node.path, true);
        } else {
          _controller.reverse().then((_) {
            if (!mounted) return;
            setState(() {}); // Rebuild to ensure offstage cleaning if needed
          });
          // ref.read(activeReqProvider.notifier).setDirectoryOpen(widget.node.path, false);
        }
      });
    } else {
      // set file is selected
      ref.read(activeReqProvider.notifier).setActiveNode(widget.node);
      ref.read(selectedNodesProvider.notifier).clear();
    }
  }

  void handleToggleExpand() {
    if (widget.node.isDirectory) {
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

  Widget focusWrapper({required Widget child, required bool hasFocus}) {
    return Focus(
      focusNode: _focusNode,
      autofocus: hasFocus,
      descendantsAreFocusable: _isExpanded,
      descendantsAreTraversable: _isExpanded,
      canRequestFocus: true,
      onKeyEvent: (FocusNode node, KeyEvent keyEvent) {
        if (keyEvent is KeyUpEvent) return KeyEventResult.ignored;
        // only allows keyDown and keyRepeat events.
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
          if (widget.node.isDirectory && !_isExpanded) {
            handleToggleExpand();
          } else {
            FocusScope.of(context).nextFocus();
          }
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (widget.node.isDirectory && _isExpanded) {
            handleToggleExpand();
            // when folder closes rebuild happens it causes focus to next child
            // here the next child is folder children at that time the animation is not yet completed
            // so focus goes to children and folder colapses.
            // so to get back the focus to folder after a small delay
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // --- SELECTION LOGIC ---
    // Change this to check against a Set/List for multi-selection
    // bool isSelected = ref.watch(selectedNodesProvider).contains(widget.node.path);
    // For now, using your existing logic pattern:
    final activeNode = ref.watch(activeReqProvider);
    final selected = ref.watch(selectedNodesProvider);
    final isSelected = selected.contains(widget.node.id);
    final isActive = activeNode?.id == widget.node.id;
    final hasFocus = (activeNode == null && widget.isFirstNode) || isActive;

    final Color textColor = isActive
        ? cs.primary
        : theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final Color? backgroundColor = isActive
        ? cs.secondary.withValues(alpha: 0.15)
        : isSelected
        ? cs.secondary.withValues(alpha: 0.10)
        : null; // Add Hover logic here using InkWell's hoverColor
    return FileNodeDragWrapper(
      node: widget.node,
      isOpen: _isExpanded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. THE HEADER (Full Width Background) ---
          SizedBox(
            height: _kTileHeight,
            child: Material(
              color:
                  backgroundColor ??
                  Colors.transparent, // Background spans full width
              child: _contextMenuWrapper(
                isDirectory: widget.node.isDirectory,
                child: focusWrapper(
                  hasFocus: hasFocus,
                  child: Builder(
                    builder: (context) {
                      final isFocused = Focus.of(context).hasFocus;
                      return Ink(
                        color: isFocused
                            ? cs.primary.withValues(alpha: 0.08)
                            : null,
                        child: InkWell(
                          // autofocus: hasFocus,
                          // focusNode: _focusNode,
                          canRequestFocus: false,
                          autofocus: false,
                          onTap: _handleTap,
                          onFocusChange: (f) {
                            debugPrint(
                              "InkWell Focus changed: $f,node: ${widget.node.name}",
                            );
                          },
                          hoverColor: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: _kIndentation),
                              // A. ARROW (Only for directories)
                              if (widget.node.isDirectory)
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
                                const SizedBox(
                                  width: _kIconSize + 2,
                                ), // Spacing for files
                              const SizedBox(
                                width: _kSpacingBetweenArrowAndIcon,
                              ),

                              // B. FOLDER/FILE ICON
                              if (widget.node.isDirectory)
                                _isExpanded ? folderOpenIcon : folderIcon
                              else
                                Icon(
                                  Icons.data_object,
                                  size: _kFolderIconSize,
                                  color: widget.node.isDirectory
                                      ? Colors.amber[700]
                                      : Colors.blueGrey,
                                ),
                              const SizedBox(width: 8),

                              // C. LABEL
                              Expanded(
                                child: Text(
                                  widget.node.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight: FontWeight.normal,
                                    height: 1.0, // Tight text height
                                  ),
                                ),
                              ),
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

          // --- 2. THE CHILDREN (Animated Expansion) ---
          // Only build children tree if expanded to save resources (optional optimization)
          if (widget.node.isDirectory)
            ExcludeFocus(
              excluding: !_isExpanded,
              child: SizeTransition(
                sizeFactor: _heightFactor,
                axisAlignment: -1.0, // Expands from top down
                child: Container(
                  // The Vertical Guide Line Logic
                  decoration: BoxDecoration(
                    // color: Colors.red,
                    border: Border(
                      left: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                        width: 1.0,
                      ),
                    ),
                  ),
                  margin: EdgeInsets.only(
                    left: (_kIndentation) + (_kIconSize / 2),
                  ),
                  child: Column(
                    mainAxisSize: .min,
                    children:
                        widget.node.children?.map((child) {
                          return FileNodeTile(
                            node: child,
                            depth:
                                widget.depth +
                                1, // Don't rely on 'indent' padding, pass depth
                          );
                        }).toList() ??
                        [],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _contextMenuWrapper({required Widget child, bool isDirectory = true}) {
    return ContextMenuWidget(
      menuProvider: (_) {
        return getMenuProvider(
          ref: ref,
          context: context,
          node: widget.node,
          isDirectory: isDirectory,
        );
      },
      child: child,
    );
  }
}
