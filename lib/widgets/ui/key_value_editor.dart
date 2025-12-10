import 'package:api_craft/dialog/multiline_edit.dart';
import 'package:api_craft/models/models.dart';
import 'package:api_craft/widgets/ui/custom_input.dart';
import 'package:flutter/material.dart';

enum KeyValueEditorMode {
  headers,
  variables,
  queryParams,
  formData,
  pathParams,
}

class KeyValueEditor extends StatefulWidget {
  final List<KeyValueItem> items;
  final ValueChanged<List<KeyValueItem>> onChanged;
  // final Function(int, int) onItemReordered;
  // final Function(int, String, String) onItemChanged;
  // final Function(List<String>, int) onItemAdded;
  final bool isVariable;
  final bool hideValuesGlobal;
  final KeyValueEditorMode mode;

  const KeyValueEditor({
    required this.items,
    required this.onChanged,
    // required this.onItemReordered,
    // required this.onItemChanged,
    // required this.onItemAdded,
    required this.mode,
    this.isVariable = false,
    this.hideValuesGlobal = false,
    super.key,
  });

  @override
  State<KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<KeyValueEditor> {
  bool _focusKeyField = true;
  String? _focusTargetId;

  void _dispatchUpdate() {
    widget.onChanged(widget.items);
  }

  void _updateItem(int index, KeyValueItem newItem) {
    setState(() {
      widget.items[index] = newItem;
    });
    _dispatchUpdate();
  }

  /// value is character we typed in dummy item to add new row
  void _addNew([String? value, bool? isKey]) {
    final v = value ?? "";
    debugPrint("Adding new item with value: $v");
    final newItem = KeyValueItem(
      isEnabled: true,
      key: isKey == true ? v : "",
      value: isKey == true ? "" : v,
    );
    setState(() {
      widget.items.add(newItem);
    });
    debugPrint("last added id: ${newItem.id}");
    _focusTargetId = newItem.id;
    _dispatchUpdate();
  }

  void _removeItem(int index) {
    setState(() {
      widget.items.removeAt(index);
    });
    _dispatchUpdate();
  }

  void _showMultilineEdit(int index, KeyValueItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return MultilineEditDialog(initialValue: item.value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("rebuilding: InputItems");
    const itemHeight = 38.0;
    // 15+10+4
    return Padding(
      padding: const .only(left: 8, right: 4),
      child: FocusTraversalGroup(
        child: ReorderableListView.builder(
          padding: .only(bottom: 10),
          // +1 for the extra dummy row
          itemCount: widget.items.length + 1,
          itemExtent: itemHeight,
          buildDefaultDragHandles: false,
          onReorder: (oldIdx, newIdx) {
            final fixedNewIdx = newIdx - 1;
            debugPrint("Reordering from $oldIdx to $fixedNewIdx");
            if (oldIdx >= widget.items.length ||
                fixedNewIdx > widget.items.length) {
              // to prevent reordering the extra row
              return;
            }
            // Don't allow reordering the last empty row
            if (oldIdx == widget.items.length ||
                fixedNewIdx == widget.items.length) {
              return;
            }
            setState(() {
              if (oldIdx < newIdx) newIdx -= 1;
              final item = widget.items.removeAt(oldIdx);
              widget.items.insert(newIdx, item);
            });
          },
          itemBuilder: (context, i) {
            final isExtra = i == widget.items.length;

            return SizedBox(
              key: ValueKey(isExtra ? "extra_row" : widget.items[i].id),
              height: itemHeight,
              child: Builder(
                builder: (context) {
                  bool isHovered = false;
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return MouseRegion(
                        onEnter: (_) => setState(() => isHovered = true),
                        onExit: (_) => setState(() => isHovered = false),
                        child: Row(
                          children: [
                            SizedBox(width: 4),
                            // 1. Checkbox
                            if (!isExtra) ...[
                              Transform.scale(
                                scale: 0.8,
                                child: SizedBox(
                                  height: 15,
                                  width: 15,
                                  child: Focus(
                                    autofocus: false,
                                    canRequestFocus: false,
                                    descendantsAreFocusable: false,
                                    child: Checkbox(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      side: BorderSide(
                                        style: BorderStyle.solid,
                                        color: Colors.grey[600]!,
                                        width: 1,
                                      ),
                                      fillColor: WidgetStateColor.resolveWith((
                                        states,
                                      ) {
                                        return widget.items[i].key.isNotEmpty
                                            ? Colors.greenAccent.shade700
                                            : Colors.grey.shade600;
                                      }),
                                      value: widget.items[i].isEnabled,
                                      onChanged: (value) {
                                        _updateItem(
                                          i,
                                          widget.items[i].copyWith(
                                            isEnabled: value ?? false,
                                          ),
                                        );
                                      },
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              ),

                              // 2. Drag Handle
                              if (!isExtra)
                                AnimatedOpacity(
                                  opacity: isHovered ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: ReorderableDragStartListener(
                                    index: i,
                                    child: Container(
                                      width: 10,
                                      padding: const .all(0),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: Colors.grey[400],
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 4),

                              // 3. Optional Info icon
                              // if (widget.mode == KeyValueEditorMode.headers) ...[
                              //   const SizedBox(width: 8),
                              //   Tooltip(
                              //     message: "dummy",
                              //     // message: getHeaderDocs(items[i][0])?.summary ?? '',
                              //     child: Icon(
                              //       Icons.info_outline,
                              //       color: Colors.grey,
                              //       size: 16,
                              //     ),
                              //   ),
                              //   const SizedBox(width: 12),
                              // ],
                            ] else
                              SizedBox(
                                width: widget.mode == KeyValueEditorMode.headers
                                    ? 29 //65
                                    : 29,
                              ),

                            // 4. Key input field
                            SizedBox(width: 150, child: buildInput(i, true)),
                            const SizedBox(width: 12),

                            // 5. Value input field
                            Expanded(child: buildInput(i, false)),
                            const SizedBox(width: 8),

                            // 6. Actions Menu
                            if (!isExtra)
                              ExcludeFocus(
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.arrow_drop_down),
                                  onSelected: (val) {
                                    if (val == 'delete') {
                                      _removeItem(i);
                                    } else if (val == 'edit') {
                                      _showMultilineEdit(i, widget.items[i]);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text("Edit Multiline"),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text("Delete"),
                                    ),
                                  ],
                                ),
                              )
                            else
                              SizedBox(width: 38),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildInput(int i, bool isKey) {
    final extra = i == widget.items.length;

    if (extra) {
      return CustomInput(
        autofocus: false,
        value: '',
        isExtra: extra,
        isEnabled: false,
        onExtraInputChange: (v) {
          _addNew(v, isKey);
        },
      );
    }

    final item = extra ? null : widget.items[i];
    final bool shouldForceFocus =
        (item!.id == _focusTargetId) && (isKey == _focusKeyField);

    CustomInput buildFn(focusNode) => CustomInput(
      focusNode: focusNode,
      value: isKey ? item.key : item.value,
      isExtra: extra,
      isEnabled: item.isEnabled,
      onUpdate: (value) {
        if (isKey && value.trim().isEmpty) return;
        _updateItem(
          i,
          isKey ? item.copyWith(key: value) : item.copyWith(value: value),
        );
      },
    );

    if (shouldForceFocus) {
      return EnsureFocus(builder: (focusNode) => buildFn(focusNode));
    }
    return buildFn(null);
  }
}

class EnsureFocus extends StatefulWidget {
  final Widget Function(FocusNode focusNode) builder;

  const EnsureFocus({super.key, required this.builder});

  @override
  State<EnsureFocus> createState() => _EnsureFocusState();
}

class _EnsureFocusState extends State<EnsureFocus> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_focusNode);
  }
}
