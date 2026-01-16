import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/custom_input.dart';
import 'package:api_craft/features/request/models/node_config_model.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:api_craft/features/request/widgets/expression_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssertionsTab extends ConsumerWidget {
  final String id;
  const AssertionsTab({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = reqComposeProvider(id);
    final assertions = ref.watch(
      provider.select((value) => (value.node).config.assertions),
    );

    return AssertionsEditor(
      items: assertions,
      id: id,
      onChanged: (newItems) {
        ref.read(provider.notifier).updateAssertions(newItems);
      },
    );
  }
}

class AssertionsEditor extends StatefulWidget {
  final List<AssertionDefinition> items;
  final ValueChanged<List<AssertionDefinition>> onChanged;
  final String id;

  const AssertionsEditor({
    super.key,
    required this.items,
    required this.onChanged,
    required this.id,
  });

  @override
  State<AssertionsEditor> createState() => _AssertionsEditorState();
}

class _AssertionsEditorState extends State<AssertionsEditor> {
  String? _focusTargetId;
  int _focusFieldIdx = 0; // 0: Expression, 1: Value

  void _updateItem(int index, AssertionDefinition newItem) {
    final newItems = List<AssertionDefinition>.from(widget.items);
    newItems[index] = newItem;
    widget.onChanged(newItems);
  }

  void _addNew([String? value, int? fieldIdx]) {
    final newItem = AssertionDefinition(
      expression: fieldIdx == 0 ? (value ?? "") : "",
      expectedValue: fieldIdx == 1 ? (value ?? "") : "",
    );
    final newItems = List<AssertionDefinition>.from(widget.items);
    newItems.add(newItem);

    setState(() {
      _focusTargetId = newItem.id;
      _focusFieldIdx = fieldIdx ?? 0;
    });
    widget.onChanged(newItems);
  }

  void _removeItem(int index) {
    final newItems = List<AssertionDefinition>.from(widget.items);
    newItems.removeAt(index);
    widget.onChanged(newItems);
  }

  @override
  Widget build(BuildContext context) {
    const itemHeight = 38.0;
    const style = TextStyle(
      fontSize: 12,
      color: Colors.grey,
      fontWeight: FontWeight.w400,
    );
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: 8, right: 4, top: 12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: const [
                    SizedBox(width: 45), // Checkbox + drag
                    Expanded(
                      flex: 3,
                      child: Text("Expression (e.g. res.status)", style: style),
                    ),
                    SizedBox(width: 8),
                    Expanded(flex: 2, child: Text("Operator", style: style)),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text("Expected Value", style: style),
                    ),
                    SizedBox(width: 32), // Delete
                  ],
                ),
              ),
              SizedBox(height: 4),
              FocusTraversalGroup(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 10),
                  itemCount: widget.items.length,
                  itemExtent: itemHeight,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIdx, newIdx) {
                    if (oldIdx >= widget.items.length ||
                        newIdx > widget.items.length) {
                      return;
                    }
                    if (oldIdx < newIdx) newIdx -= 1;
                    final newItems = List<AssertionDefinition>.from(
                      widget.items,
                    );
                    final item = newItems.removeAt(oldIdx);
                    newItems.insert(newIdx, item);
                    widget.onChanged(newItems);
                  },
                  itemBuilder: (context, i) {
                    final item = widget.items[i];
                    return _AssertionRow(
                      key: ValueKey(item.id),
                      index: i,
                      item: item,
                      id: widget.id,
                      focusTargetId: _focusTargetId,
                      focusFieldIdx: _focusFieldIdx,
                      itemHeight: itemHeight,
                      onUpdate: (idx, newItem) => _updateItem(idx, newItem),
                      onRemove: (idx) => _removeItem(idx),
                    );
                  },
                ),
              ),
              _buildAddRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddRow() {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24, // Matches row padding + icon size area
            height: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => _addNew(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _addNew(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Add Assertion",
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssertionRow extends StatefulWidget {
  final int index;
  final AssertionDefinition item;
  final String id;
  final String? focusTargetId;
  final int focusFieldIdx;
  final double itemHeight;
  final Function(int, AssertionDefinition) onUpdate;
  final Function(int) onRemove;

  const _AssertionRow({
    super.key,
    required this.index,
    required this.item,
    required this.id,
    this.focusTargetId,
    required this.focusFieldIdx,
    required this.itemHeight,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_AssertionRow> createState() => _AssertionRowState();
}

class _AssertionRowState extends State<_AssertionRow> {
  bool _isHovered = false;

  static const operators = [
    {'label': 'Equal', 'value': 'equal'},
    {'label': 'Not Equal', 'value': 'notEqual'},
    {'label': 'Contains', 'value': 'contains'},
    {'label': 'Is Null', 'value': 'toBeNull'},
    {'label': 'Not Null', 'value': 'toBeNotNull'},
    {'label': 'Greater Than', 'value': 'gt'},
    {'label': 'Greater Than Or Equal', 'value': 'gte'},
    {'label': 'Less Than', 'value': 'lt'},
    {'label': 'Less Than Or Equal', 'value': 'lte'},
    {'label': 'Exists', 'value': 'exists'},
    {'label': 'Does Not Exist', 'value': 'doesNotExist'},
    {'label': 'Is True', 'value': 'isTrue'},
    {'label': 'Is False', 'value': 'isFalse'},
    {'label': 'Is Empty', 'value': 'isEmpty'},
    {'label': 'Is Not Empty', 'value': 'isNotEmpty'},
    {'label': 'Starts With', 'value': 'startsWith'},
    {'label': 'Ends With', 'value': 'endsWith'},
    {'label': 'Matches (Regex)', 'value': 'matches'},
    {'label': 'Is String', 'value': 'isString'},
    {'label': 'Is Number', 'value': 'isNumber'},
    {'label': 'Is Boolean', 'value': 'isBoolean'},
    {'label': 'Is List', 'value': 'isList'},
    {'label': 'Is Map', 'value': 'isMap'},
    {'label': 'Has Key', 'value': 'hasKey'},
    {'label': 'Does Not Have Key', 'value': 'doesNotHaveKey'},
    {'label': 'Has Value', 'value': 'hasValue'},
    {'label': 'Has Key:Value (key:value)', 'value': 'hasKeyValue'},
    {'label': 'Contains All (JSON Array)', 'value': 'containsAll'},
    {'label': 'Contains Any (JSON Array)', 'value': 'containsAny'},
    {'label': 'One Of (comma separated)', 'value': 'oneOf'},
    {'label': 'Close To (target,delta)', 'value': 'closeTo'},
    {'label': 'Length', 'value': 'length'},
    {'label': 'Within (min,max)', 'value': 'within'},
  ];

  static const _unaryOperators = {
    'toBeNull',
    'toBeNotNull',
    'exists',
    'doesNotExist',
    'isTrue',
    'isFalse',
    'isEmpty',
    'isNotEmpty',
    'isString',
    'isNumber',
    'isBoolean',
    'isList',
    'isMap',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.itemHeight,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Row(
          children: [
            const SizedBox(width: 4),
            const SizedBox(width: 4),
            // Actions (Checkbox + Drag)
            Transform.scale(
              scale: 0.8,
              child: SizedBox(
                width: 20,
                child: Checkbox(
                  value: widget.item.isEnabled,
                  onChanged: (val) => widget.onUpdate(
                    widget.index,
                    widget.item.copyWith(isEnabled: val ?? true),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: widget.index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: _isHovered ? Colors.grey : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Expression Input
            Expanded(flex: 3, child: _buildInput(0)),
            const SizedBox(width: 8),

            // Operator Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.item.operator,
                  isDense: true,
                  style: Theme.of(context).textTheme.bodySmall,
                  items: operators
                      .map(
                        (op) => DropdownMenuItem(
                          value: op['value'],
                          child: Text(
                            op['label']!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      widget.onUpdate(
                        widget.index,
                        widget.item.copyWith(operator: val),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Expected Value Input
            Expanded(flex: 3, child: _buildInput(1)),
            const SizedBox(width: 8),

            // Delete Action
            SizedBox(
              width: 24,
              child: IconButton(
                icon: Icon(
                  Icons.delete,
                  size: 16,
                  color: _isHovered ? Colors.red : Colors.transparent,
                ),
                onPressed: () => widget.onRemove(widget.index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(int fieldIdx) {
    // fieldIdx: 0 = Expression, 1 = Expected Value

    final item = widget.item;
    final isUnary = _unaryOperators.contains(item.operator);

    // If it is the value field (index 1) and the operator is unary, hide it or disable it
    if (fieldIdx == 1 && isUnary) {
      return SizedBox.shrink();
    }

    final shouldForceFocus =
        (item.id == widget.focusTargetId) && (fieldIdx == widget.focusFieldIdx);

    if (fieldIdx == 0) {
      return ExpressionInput(
        id: widget.id,
        value: item.expression,
        autoFocus: shouldForceFocus,
        hint: 'expr',
        isEnabled: item.isEnabled,
        onUpdate: (val) {
          widget.onUpdate(widget.index, item.copyWith(expression: val));
        },
      );
    }

    return CustomInput(
      id: widget.id,
      value: item.expectedValue,
      isExtra: false,
      isEnabled: item.isEnabled,
      onUpdate: (val) {
        widget.onUpdate(widget.index, item.copyWith(expectedValue: val));
      },
    );
  }
}
