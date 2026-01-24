import 'package:api_craft/core/widgets/dialog/input_dialog.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/flows/filter/widgets/filter_condition.dart';
import 'package:api_craft/flows/filter/widgets/filter_connector.dart';
import 'package:api_craft/flows/filter/models/m.dart';
import 'package:api_craft/flows/filter/condition_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kBorderClr = Color.fromARGB(255, 138, 138, 138);

class FilterGroupWidget extends ConsumerStatefulWidget {
  const FilterGroupWidget({
    super.key,
    required this.index,
    required this.group,
    required this.managerProvider,
    this.hasNextChild = false,
    this.onRemove,
    this.isRoot = false,
    this.showConnector = false,
    this.connectorOperator,
    this.onOperatorToggle,
    // Drag params
    this.dragData,
    this.dragFeedback,
    this.onDragStarted,
    this.onDragEnd,
  });
  final int index;
  final FilterGroup group;
  final FilterManagerProvider managerProvider;
  final VoidCallback? onRemove;
  final VoidCallback? onOperatorToggle;
  final bool hasNextChild;
  final bool isRoot;
  final bool showConnector;
  final LogicalOperator? connectorOperator;

  // Drag
  final Object? dragData;
  final Widget? dragFeedback;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  @override
  ConsumerState<FilterGroupWidget> createState() => _FilterGroupWidgetState();
}

class _FilterGroupWidgetState extends ConsumerState<FilterGroupWidget> {
  bool _isHidden = false;
  int? _draggingIndex;
  final _groupActionsPickerKey = GlobalKey<CustomPopupState>();

  ConditionManagerNotifier get manager =>
      ref.read(widget.managerProvider.notifier);
  void _addCondition() {
    setState(() {
      manager.addConditionTo(widget.group);
    });
  }

  void _addSubGroup() {
    setState(() {
      manager.addSubgroupTo(widget.group);
    });
  }

  void _negateGroup() {
    setState(() {
      widget.group.isNegated = !widget.group.isNegated;
    });
    manager.notify();
  }

  void _hideGroup() {
    setState(() {
      _isHidden = !_isHidden;
    });
  }

  void collapseGroup() {
    // TODO: implement collapse logic
    // This moves all children to parent and removes this group
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      manager.moveNode(widget.group, oldIndex, newIndex);
    });
  }

  bool _isDescendant(FilterNode target, FilterNode ancestor) {
    if (ancestor == target) return true;
    if (ancestor is FilterGroup) {
      for (final child in ancestor.children) {
        if (_isDescendant(target, child)) return true;
      }
    }
    return false;
  }

  Widget? _buildConnector() {
    if (widget.showConnector) {
      return ConditionConnector(
        operator: widget.connectorOperator!,
        onToggle: widget.onOperatorToggle,
      );
    } else if (widget.hasNextChild) {
      return SizedBox(width: 40);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes to trigger rebuilds
    ref.watch(widget.managerProvider);

    // is Hidden
    if (_isHidden && !widget.isRoot) {
      return Row(
        crossAxisAlignment: .start,
        children: [
          if (_buildConnector() != null) _buildConnector()!,
          Expanded(
            child: Padding(
              padding: const .only(top: 8.0),
              child: _buildGroupHeader(),
            ),
          ),
        ],
      );
    }

    final content = _buildContent();

    // is Root
    if (widget.isRoot) {
      return Column(
        mainAxisSize: .min,
        crossAxisAlignment: .end,
        children: [
          Flexible(child: SingleChildScrollView(child: content)),
          SizedBox(height: 18),
          buildActions(),
        ],
      );
    }

    // is not Root
    final groupColors = <Color>[
      const .fromARGB(255, 44, 32, 46),
      const .fromARGB(255, 38, 36, 31),
      const .fromARGB(255, 25, 33, 25),
      const .fromARGB(255, 42, 52, 51),
      const .fromARGB(255, 37, 39, 46),
      const .fromARGB(255, 46, 37, 37),
    ];
    final color = groupColors[widget.index % groupColors.length];

    return Row(
      crossAxisAlignment: .start,
      children: [
        if (_buildConnector() != null) _buildConnector()!,
        if (!_isHidden)
          Expanded(
            child: Container(
              margin: .only(top: widget.isRoot ? 0 : 8),
              padding: !_isHidden ? .all(widget.isRoot ? 0 : 12) : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: widget.isRoot
                    ? null
                    : Border.all(
                        color: widget.group.isNegated
                            ? Colors.red.withValues(alpha: 0.3)
                            : _kBorderClr.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                color: widget.isRoot
                    ? Colors.transparent
                    : color.withValues(alpha: 0.4),
              ),
              child: content,
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: .end,
      children: [
        // Group Header
        if (!widget.isRoot) _buildGroupHeader(),

        // Children with connectors and DragTarget
        for (int i = 0; i < widget.group.children.length; i++)
          _buildDraggableChild(i),

        _buildFinalDropZone(),

        SizedBox(height: 8),
        if (widget.isRoot) SizedBox(height: 6),

        // Action Buttons Row
        if (!widget.isRoot) buildActions(),
      ],
    );
  }

  Widget _buildDraggableChild(int index) {
    // Data is a record: (Parent Group, Index)
    return DragTarget<(FilterGroup, int)>(
      onWillAcceptWithDetails: (details) {
        // Allow drag from different groups
        // Prevent dropping onto itself (index match)
        if (details.data.$1 == widget.group && details.data.$2 == index) {
          return false;
        }

        // Prevent dropping a group into its own descendant
        final draggedNode = details.data.$1.children[details.data.$2];
        // Target is 'widget.group'. If 'widget.group' is a descendant of 'draggedNode', return false.
        if (_isDescendant(widget.group, draggedNode)) {
          return false;
        }

        return true;
      },
      onAcceptWithDetails: (details) {
        if (details.data.$1 == widget.group) {
          _onReorder(details.data.$2, index);
        } else {
          // Cross-group move
          setState(() {
            manager.moveNodeBetweenGroups(
              details.data.$1, // source group
              details.data.$2, // source index
              widget.group, // target group
              index, // target index
            );
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        final isBeingDragged = _draggingIndex == index;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHovered)
              Container(
                height: 2,
                color: Theme.of(context).colorScheme.primary,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
            Opacity(
              opacity: isBeingDragged ? 0.3 : 1.0,
              child: _buildChild(
                index,
                // Pass drag params down
                dragData: (widget.group, index),
                dragFeedback: SizedBox(
                  width: 300,
                  child: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: 0.7,
                      child: _buildChild(
                        index,
                        forceNoConnector: true,
                        isFeedback: true,
                      ),
                    ),
                  ),
                ),
                onDragStarted: () {
                  setState(() {
                    _draggingIndex = index;
                  });
                },
                onDragEnd: () {
                  setState(() {
                    _draggingIndex = null;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinalDropZone() {
    final len = widget.group.children.length;
    final isEmpty = len == 0;

    return DragTarget<(FilterGroup, int)>(
      onWillAcceptWithDetails: (details) {
        // Prevent dropping a group into its own descendant (even at end)
        final draggedNode = details.data.$1.children[details.data.$2];
        if (_isDescendant(widget.group, draggedNode)) {
          return false;
        }

        if (details.data.$1 == widget.group) {
          // Don't drag if already at end
          return details.data.$2 != len && details.data.$2 != len - 1;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        if (details.data.$1 == widget.group) {
          _onReorder(details.data.$2, len);
        } else {
          setState(() {
            manager.moveNodeBetweenGroups(
              details.data.$1,
              details.data.$2,
              widget.group,
              len,
            );
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          height: (isHovered || isEmpty) ? 20 : 10,
          width: double.infinity,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: isHovered
              ? Container(
                  height: 2, // Standard drop line
                  color: Theme.of(context).colorScheme.primary,
                )
              : (isEmpty
                    ? Container(
                        height: 1.5,
                        width: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      )
                    : null),
        );
      },
    );
  }

  Widget buildActions() {
    return Row(
      children: [
        // Add Condition btn
        SizedBox(
          height: 28,
          child: TextButton.icon(
            onPressed: _addCondition,
            icon: Icon(Icons.add, size: 14),
            label: Text('Condition', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const .symmetric(horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Add Subgroup btn
        SizedBox(
          height: 28,
          child: TextButton.icon(
            onPressed: _addSubGroup,
            icon: Icon(Icons.folder_outlined, size: 14, color: Colors.grey),
            label: Text(
              'Group',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              padding: const .symmetric(horizontal: 12),
            ),
          ),
        ),

        // for root group only
        if (widget.isRoot) ...[
          Spacer(),
          SizedBox(
            height: 26,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (c) {
                    return InputDialog(
                      title: "Save Filter",
                      placeholder: "Filter Name",
                      onConfirmed: (t) {
                        // logic placeholder
                      },
                    );
                  },
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const .symmetric(horizontal: 12),
              ),
              icon: Icon(Icons.refresh, size: 16),
              label: Text('save'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 26,
            child: ElevatedButton.icon(
              onPressed: () {
                manager.reset();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                padding: const .symmetric(horizontal: 12),
              ),
              icon: Icon(Icons.refresh, size: 16),
              label: Text('Reset'),
            ),
          ),
          const SizedBox(width: 8),

          // apply btn
          SizedBox(
            height: 26,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                padding: const .symmetric(horizontal: 12, vertical: 0),
              ),
              icon: Icon(Icons.check, size: 16),
              label: Text('Apply', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupHeader() {
    final childCount = widget.group.children.length;
    final theme = Theme.of(context);
    return Container(
      height: 28,
      padding: const .symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kBorderClr.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          if (widget.dragData != null)
            Draggable(
              data: widget.dragData,
              feedback: widget.dragFeedback ?? SizedBox(),
              childWhenDragging: Opacity(
                opacity: 0.0,
                child: Icon(
                  Icons.drag_indicator,
                  size: 14,
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
              ),
              onDragStarted: widget.onDragStarted,
              onDragEnd: (_) => widget.onDragEnd?.call(),
              child: Icon(
                Icons.drag_indicator,
                size: 14,
                color: Colors.grey.withValues(alpha: 0.4),
              ),
            )
          else
            Icon(
              Icons.drag_indicator,
              size: 14,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
          const SizedBox(width: 6),

          Text(
            widget.group.isNegated ? '! Group' : 'Group',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            // '($childCount condition${childCount != 1 ? 's' : ''})',
            '($childCount)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),

          const Spacer(),

          InkWell(
            onTap: _hideGroup,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const .all(4),
              child: Icon(
                _isHidden ? Icons.expand_more : Icons.expand_less,
                size: 14,
              ),
            ),
          ),

          const SizedBox(width: 4),

          MyCustomMenu.contentColumn(
            popupKey: _groupActionsPickerKey,
            useBtn: false,
            width: 160,
            items: [
              CustomMenuIconItem(
                title: Text(
                  !widget.group.isNegated
                      ? '! Negate Group'
                      : '! Remove Negation',
                  style: TextStyle(fontSize: 13),
                ),
                value: 'negate',
                onTap: (_) {
                  _negateGroup();
                  // Pop implicit
                },
              ),
              CustomMenuIconItem(
                title: Text("Collapse", style: TextStyle(fontSize: 13)),
                value: 'collapse',
                onTap: (_) {
                  collapseGroup();
                  // Pop implicit
                },
              ),
              const Divider(height: 1),
              CustomMenuIconItem(
                title: Text(
                  "Remove Group",
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
                value: 'remove',
                onTap: (_) {
                  widget.onRemove?.call();
                  // Pop implicit
                },
              ),
            ],
            child: InkWell(
              onTap: () {
                _groupActionsPickerKey.currentState?.show();
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const .all(4),
                child: Icon(
                  Icons.more_vert,
                  size: 14,
                  color: Colors.grey.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChild(
    int index, {
    bool forceNoConnector = false,
    bool isFeedback = false,
    // Drag params to pass down
    Object? dragData,
    Widget? dragFeedback,
    VoidCallback? onDragStarted,
    VoidCallback? onDragEnd,
  }) {
    final node = widget.group.children[index];
    final showConnector = !forceNoConnector && index > 0;
    final hasNextChild = index < widget.group.children.length - 1;
    final connectorOp = showConnector
        ? widget.group.operators[index - 1]
        : null;

    void handleRemove() {
      setState(() {
        widget.group.children.removeAt(index);
        if (widget.group.operators.isNotEmpty) {
          widget.group.operators.removeAt(index > 0 ? index - 1 : 0);
        }
      });
      manager.notify();
    }

    void handleWrapInGroup() {
      setState(() {
        final originalNode = widget.group.children[index];
        final newGroup = FilterGroup(children: [originalNode]);
        widget.group.children[index] = newGroup;
      });
      manager.notify();
    }

    void handleOperatorToggle() {
      debugPrint('Toggling operator at index $index');
      setState(() {
        if (connectorOp != null) {
          final currentOp = widget.group.operators[index - 1];
          widget.group.operators[index - 1] = currentOp == LogicalOperator.and
              ? LogicalOperator.or
              : LogicalOperator.and;
        }
      });
      manager.notify();
    }

    if (node is FilterGroup) {
      if (isFeedback) {
        // Avoid recursion in feedback if needed, but for visual it's okay unless deep.
      }
      return FilterGroupWidget(
        index: index,
        group: node,
        hasNextChild: hasNextChild,
        managerProvider: widget.managerProvider,
        onRemove: handleRemove,
        showConnector: showConnector,
        connectorOperator: connectorOp,
        onOperatorToggle: handleOperatorToggle,
        // Pass drag params
        dragData: dragData,
        dragFeedback: dragFeedback,
        onDragStarted: onDragStarted,
        onDragEnd: onDragEnd,
      );
    }

    if (node is FilterCondition) {
      return FilterConditionWidget(
        index: index,
        hasNextChild: hasNextChild,
        condition: node,
        manager: widget.managerProvider,
        onRemove: handleRemove,
        onWrapInGroup: handleWrapInGroup,
        showConnector: showConnector,
        connectorOperator: connectorOp,
        onOperatorToggle: handleOperatorToggle,
        // Pass drag params
        dragData: dragData,
        dragFeedback: dragFeedback,
        onDragStarted: onDragStarted,
        onDragEnd: onDragEnd,
      );
    }

    return Container();
  }
}
