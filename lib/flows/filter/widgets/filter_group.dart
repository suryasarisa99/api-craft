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

  @override
  ConsumerState<FilterGroupWidget> createState() => _FilterGroupWidgetState();
}

class _FilterGroupWidgetState extends ConsumerState<FilterGroupWidget> {
  bool _isHidden = false;
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

        // Children with connectors
        for (int i = 0; i < widget.group.children.length; i++) _buildChild(i),

        SizedBox(height: 8),
        if (widget.isRoot) SizedBox(height: 6),

        // Action Buttons Row
        if (!widget.isRoot) buildActions(),
      ],
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
                // manager.apply(); // Removed apply method from manager
                // Now manager updates state directly.
                // If user wants to "Apply", maybe we just pop? Or do nothing if it's already live.
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

  Widget _buildChild(int index) {
    final node = widget.group.children[index];
    final showConnector = index > 0;
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
      return FilterGroupWidget(
        index: index,
        group: node,
        hasNextChild: hasNextChild,
        managerProvider: widget.managerProvider,
        onRemove: handleRemove,
        showConnector: showConnector,
        connectorOperator: connectorOp,
        onOperatorToggle: handleOperatorToggle,
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
      );
    }

    return Container();
  }
}
