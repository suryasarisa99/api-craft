import 'package:api_craft/shared/ui/custom_menu.dart';
import 'package:api_craft/shared/ui/cf_code_editor.dart';
import 'package:api_craft/shared/filter_conditions/models/filter_enums.dart';
import 'package:api_craft/shared/filter_conditions/widgets/filter_connector.dart';
import 'package:api_craft/shared/filter_conditions/models/filter_models.dart';
import 'package:api_craft/traffic/filter/condition_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_popup/flutter_popup.dart';

const _kBorderClr = Color.fromARGB(255, 138, 138, 138);

class FilterConditionWidget extends ConsumerStatefulWidget {
  const FilterConditionWidget({
    super.key,
    required this.index,
    required this.condition,
    required this.manager,
    required this.onRemove,
    required this.onWrapInGroup,
    required this.hasNextChild,
    required this.onOperatorToggle,
    this.showConnector = false,
    this.connectorOperator,
    // Drag params
    this.dragData,
    this.dragFeedback,
    this.onDragStarted,
    this.onDragEnd,
  });

  final bool hasNextChild;
  final int index;
  final FilterCondition condition;
  final FilterManagerProvider manager;
  final VoidCallback onRemove;
  final VoidCallback onWrapInGroup;
  final VoidCallback? onOperatorToggle;
  final bool showConnector;
  final LogicalOperator? connectorOperator;

  // Drag
  final Object? dragData;
  final Widget? dragFeedback;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  @override
  ConsumerState<FilterConditionWidget> createState() =>
      _FilterConditionWidgetState();
}

class _FilterConditionWidgetState extends ConsumerState<FilterConditionWidget> {
  late final TextEditingController _valueController;
  final _keyPickerKey = GlobalKey<CustomPopupState>();
  final _operatorPickerKey = GlobalKey<CustomPopupState>();
  final _menuKey = GlobalKey<CustomPopupState>();
  final focusNode = FocusNode();
  final GlobalKey _containerKey = GlobalKey();
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.condition.value);
  }

  @override
  void didUpdateWidget(covariant FilterConditionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.condition.value != _valueController.text) {
      _valueController.text = widget.condition.value;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  ConditionManagerNotifier get manager => ref.read(widget.manager.notifier);

  @override
  Widget build(BuildContext context) {
    final operatorText =
        (widget.condition.isNegated ? '!' : '') +
        widget.condition.operator.symbol;
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: .max,
      mainAxisAlignment: .start,
      crossAxisAlignment: .center,
      children: [
        if (widget.showConnector)
          ConditionConnector(
            operator: widget.connectorOperator!,
            onToggle: widget.onOperatorToggle,
          )
        else if (widget.hasNextChild)
          SizedBox(width: 40),
        Flexible(
          fit: FlexFit.tight,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                key: _containerKey,
                height: 32,
                margin: const .only(top: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isHovered
                        ? _kBorderClr.withValues(alpha: 0.6)
                        : _kBorderClr.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    SizedBox(
                      width: 32,
                      child: widget.dragData != null
                          ? Draggable(
                              data: widget.dragData,
                              feedback: widget.dragFeedback ?? SizedBox(),
                              childWhenDragging: Opacity(
                                opacity: 0.0,
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 16,
                                  color: Colors.grey.withValues(alpha: 0.4),
                                ),
                              ),
                              onDragStarted: widget.onDragStarted,
                              onDragEnd: (_) => widget.onDragEnd?.call(),
                              child: Icon(
                                Icons.drag_indicator,
                                size: 16,
                                color: Colors.grey.withValues(alpha: 0.4),
                              ),
                            )
                          : Icon(
                              Icons.drag_indicator,
                              size: 16,
                              color: Colors.grey.withValues(alpha: 0.4),
                            ),
                    ),

                    MyCustomMenu(
                      popupKey: _keyPickerKey,
                      useBtn: false,
                      content: _KeyPickerContent(
                        onSelected: (field) {
                          final oldType = widget.condition.field.type;
                          final newType = field.type;

                          if (oldType != newType) {
                            // If switching to Number
                            if (newType == FilterFieldType.num) {
                              _valueController.text =
                                  ''; // Clear potentially invalid text
                              widget.condition.value = '';

                              if (widget.condition.operator ==
                                  FilterOperator.inListStr) {
                                widget.condition.operator =
                                    FilterOperator.inListNum;
                              } else {
                                widget.condition.operator =
                                    FilterOperator.numEquals;
                              }
                            }
                            // If switching to String
                            else if (newType == FilterFieldType.str) {
                              // Num -> Str (keep value usually strictly string is permissive)
                              if (widget.condition.operator ==
                                  FilterOperator.inListNum) {
                                widget.condition.operator =
                                    FilterOperator.inListStr;
                              } else {
                                widget.condition.operator =
                                    FilterOperator.equals;
                              }
                            }
                          }

                          setState(() => widget.condition.field = field);
                          manager.notify(); // Notifying change
                          focusNode.requestFocus();
                        },
                      ),
                      child: InkWell(
                        onTap: () => _keyPickerKey.currentState?.show(),
                        child: Container(
                          padding: const .symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: _kBorderClr.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 110),
                                child: Text(
                                  widget.condition.field.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (widget.condition.field == FilterField.script) ...[
                      // Script button
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => _ScriptEditorDialog(
                                  initialValue: widget.condition.value,
                                  onSave: (val) {
                                    setState(() {
                                      widget.condition.value = val;
                                    });
                                    manager.notify();
                                  },
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: theme.colorScheme.onSurface,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              maximumSize: const Size.fromHeight(28),
                              minimumSize: const Size.fromHeight(28),
                            ),
                            icon: const Icon(Icons.code, size: 14),
                            label: const Text(
                              'Edit Script',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      if (widget.condition.field.type !=
                          FilterFieldType.bool) ...[
                        MyCustomMenu.contentColumn(
                          popupKey: _operatorPickerKey,
                          useBtn: false,
                          width: 200,
                          items: [
                            Padding(
                              padding: const .symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Operators',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            ...FilterOperator.values
                                .where(
                                  (op) =>
                                      op.supportedType ==
                                      widget.condition.field.type,
                                )
                                .map(
                                  (op) => CustomMenuIconItem(
                                    title: Row(
                                      children: [
                                        SizedBox(
                                          width: 25,
                                          child: Text(
                                            op.symbol,
                                            textAlign: .center,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          op.label,
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    value: op.name,
                                    onTap: (_) {
                                      setState(() {
                                        widget.condition.operator = op;
                                        widget.condition.isNegated = false;
                                      });
                                      manager.notify(); // Corrected usage
                                    },
                                  ),
                                ),
                            const Divider(height: 1),
                            CustomMenuIconItem(
                              title: Text(
                                widget.condition.isNegated
                                    ? '!  Remove Negation'
                                    : '!  Negate',
                                style: TextStyle(fontSize: 13),
                              ),
                              value: 'negate',
                              onTap: (_) {
                                setState(() {
                                  widget.condition.isNegated =
                                      !widget.condition.isNegated;
                                });
                                manager.notify();
                                // Automatic pop via CustomMenuIconItem
                              },
                            ),
                          ],
                          child: InkWell(
                            onTap: () =>
                                _operatorPickerKey.currentState?.show(),
                            child: Container(
                              width: 50,
                              padding: const .symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: _kBorderClr.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                operatorText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: TextField(
                            controller: _valueController,
                            focusNode: focusNode,
                            inputFormatters: [
                              if (widget.condition.field.type ==
                                  FilterFieldType.num) ...[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9, ]'),
                                ),
                              ],
                            ],
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Enter value...',
                              hintStyle: TextStyle(
                                color: Colors.grey.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              contentPadding: const .symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (value) {
                              widget.condition.value = value;
                              manager.notify();
                            },
                          ),
                        ),
                      ],
                    ], // End if script else

                    _buildMoreMenu(),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.condition.field.type == FilterFieldType.bool) ...[
          const SizedBox(width: 8),
          if (widget.condition.isNegated)
            Text(
              '(!)',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          Spacer(),
          _buildMoreMenu(),
        ],
      ],
    );
  }

  Widget _buildMoreMenu() {
    return MyCustomMenu.contentColumn(
      popupKey: _menuKey,
      width: 180,
      useBtn: false,
      items: [
        CustomMenuIconItem(
          title: Text('Wrap in Group', style: TextStyle(fontSize: 13)),
          value: 'wrap',
          onTap: (_) {
            widget.onWrapInGroup();
            // Pop handled by CustomMenuIconItem
          },
        ),
        CustomMenuIconItem(
          title: Text(
            widget.condition.isNegated ? '!  Remove Negation' : '!  Negate',
            style: TextStyle(fontSize: 13),
          ),
          value: 'negate',
          onTap: (_) {
            setState(() {
              widget.condition.isNegated = !widget.condition.isNegated;
            });
            manager.notify();
          },
        ),
        const Divider(height: 1),
        CustomMenuIconItem(
          title: Text(
            'Remove Condition',
            style: TextStyle(color: Colors.red, fontSize: 13),
          ),
          value: 'remove',
          onTap: (_) {
            widget.onRemove();
          },
        ),
      ],
      child: InkWell(
        onTap: () => _menuKey.currentState?.show(),
        child: SizedBox(
          width: 32,
          child: Icon(
            Icons.more_vert,
            size: 16,
            color: Colors.grey.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _KeyPickerContent extends StatefulWidget {
  const _KeyPickerContent({required this.onSelected});
  final ValueChanged<FilterField> onSelected;

  @override
  State<_KeyPickerContent> createState() => _KeyPickerContentState();
}

class _KeyPickerContentState extends State<_KeyPickerContent> {
  String _searchTerm = '';
  List<FilterField> get _filteredKeys {
    if (_searchTerm.isEmpty) return FilterField.values;
    return FilterField.values
        .where(
          (key) =>
              key.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
              key.prettyName.toLowerCase().contains(_searchTerm.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          width: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  autofocus: true,
                  onChanged: (val) => setState(() => _searchTerm = val),
                  style: TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search key...',
                    hintStyle: TextStyle(fontSize: 13),
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceBright,
                    prefixIcon: Padding(
                      padding: const .only(left: 8.0),
                      child: Icon(Icons.search, size: 16),
                    ),
                    prefixIconConstraints: BoxConstraints.loose(Size(32, 32)),
                    contentPadding: .symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredKeys.length,
                  itemBuilder: (context, index) {
                    final key = _filteredKeys[index];
                    return CustomMenuIconItem(
                      title: Text(key.name, style: TextStyle(fontSize: 13)),
                      value: key.name,
                      onTap: (_) => widget.onSelected(key),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScriptEditorDialog extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onSave;
  const _ScriptEditorDialog({required this.initialValue, required this.onSave});

  @override
  State<_ScriptEditorDialog> createState() => _ScriptEditorDialogState();
}

class _ScriptEditorDialogState extends State<_ScriptEditorDialog> {
  late String _value;
  static const _defaultScript = '''
function filter(req, res) {
  return res.statusCode == 200;
}
''';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue.trim().isEmpty) {
      _value = _defaultScript;
    } else {
      _value = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        height: 480,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Script', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Define function filter(req, res) { ... } returning boolean.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CFCodeEditor(
                    text: _value,
                    language: 'javascript',
                    onChanged: (v) => _value = v,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    widget.onSave(_value);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
