import 'package:api_craft/core/widgets/dialog/input_dialog.dart';
import 'package:api_craft/core/widgets/dialog/multiline_edit.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/widgets/ui/custom_input.dart';
import 'package:api_craft/core/widgets/ui/custom_menu.dart';
import 'package:api_craft/core/widgets/ui/variable_text_field_custom.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_decoration/dotted_decoration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';

enum KeyValueEditorMode {
  headers,
  variables,
  queryParams,
  formData,
  multipart,
  pathParams,
}

class KeyValueEditor extends StatefulWidget {
  final List<KeyValueItem> items;
  final ValueChanged<List<KeyValueItem>> onChanged;
  final bool enableSuggestionsForKey;
  // final Function(int, int) onItemReordered;
  // final Function(int, String, String) onItemChanged;
  // final Function(List<String>, int) onItemAdded;
  final bool isVariable;
  final bool hideValuesGlobal;
  final KeyValueEditorMode mode;
  final String? id;

  const KeyValueEditor({
    required this.items,
    required this.onChanged,
    required this.id,
    this.enableSuggestionsForKey = true,
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
  bool _isCodeEditor = false;

  void _updateItem(int index, KeyValueItem newItem) {
    final newItems = List<KeyValueItem>.from(widget.items);
    newItems[index] = newItem;
    widget.onChanged(newItems);
  }

  void _toggleEditor() {
    setState(() {
      _isCodeEditor = !_isCodeEditor;
    });
  }

  /// value is character we typed in dummy item to add new row
  void _addNew([String? value, bool? isKey]) {
    final v = value ?? "";
    debugPrint("Adding new item with value: $v");
    KeyValueItem newItem;
    if (widget.mode == KeyValueEditorMode.formData ||
        widget.mode == KeyValueEditorMode.multipart) {
      newItem = FormDataItem(
        isEnabled: true,
        key: isKey == true ? v : "",
        value: isKey == true ? "" : v,
        type: 'text',
      );
    } else {
      newItem = KeyValueItem(
        isEnabled: true,
        key: isKey == true ? v : "",
        value: isKey == true ? "" : v,
      );
    }
    final newItems = List<KeyValueItem>.from(widget.items);
    newItems.add(newItem);

    setState(() {
      _focusTargetId = newItem.id;
    });
    widget.onChanged(newItems);
  }

  void _removeItem(int index) {
    final newItems = List<KeyValueItem>.from(widget.items);
    newItems.removeAt(index);
    widget.onChanged(newItems);
  }

  void _onTextChange(String v) {
    final lines = v.split("\n");
    final items = lines.map((line) {
      final idx = line.indexOf(':');

      return KeyValueItem(
        key: idx == -1 ? line.trim() : line.substring(0, idx).trim(),
        value: idx == -1 ? '' : line.substring(idx + 1).trim(),
      );
    }).toList();
    //need to update state.
    widget.onChanged(items);
  }

  String get _toText {
    return widget.items
        .where((e) => e.key.isNotEmpty || e.value.isNotEmpty)
        .map((e) {
          if (e.value.isNotEmpty) {
            return "${e.key}: ${e.value}";
          } else {
            return e.key;
          }
        })
        .join("\n");
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("rebuilding: InputItems");
    const itemHeight = 38.0;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: widget.mode == KeyValueEditorMode.multipart
          ? null
          : FloatingActionButton.small(
              backgroundColor: cs.surfaceContainerHighest,
              onPressed: _toggleEditor,
              //show icon to toggle btn file edit or cell edit
              child: Icon(
                _isCodeEditor ? Icons.code : Icons.grid_view_rounded,
                size: 16,
              ),
            ),
      body: (_isCodeEditor && widget.mode != KeyValueEditorMode.multipart)
          ?
            // CFCodeEditor(
            //     text: _toText,
            //     language: "form-urlencoded",
            //     onChanged: _onTextChange,
            //   )
            VariableTextFieldCustom(
              initialValue: _toText,

              id: widget.id,
              isKeyVal: true,
              onChanged: _onTextChange,
              textStyle: TextStyle(fontSize: 18, height: 1.6),
              decoration: InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            )
          : Padding(
              padding: const .only(left: 8, right: 4),
              child: Column(
                children: [
                  Expanded(
                    child: FocusTraversalGroup(
                      child: ReorderableListView.builder(
                        padding: .only(bottom: 10),
                        itemCount: widget.items.length + 1,
                        itemExtent: itemHeight,
                        buildDefaultDragHandles: false,
                        onReorder: (oldIdx, newIdx) {
                          final fixedNewIdx = newIdx - 1;
                          if (oldIdx >= widget.items.length ||
                              fixedNewIdx > widget.items.length) {
                            return;
                          }
                          if (oldIdx == widget.items.length ||
                              fixedNewIdx == widget.items.length) {
                            return;
                          }
                          final newItems = List<KeyValueItem>.from(
                            widget.items,
                          );
                          if (oldIdx < newIdx) newIdx -= 1;
                          final item = newItems.removeAt(oldIdx);
                          newItems.insert(newIdx, item);
                          widget.onChanged(newItems);
                        },
                        itemBuilder: (context, i) {
                          final isExtra = i == widget.items.length;
                          final item = isExtra ? null : widget.items[i];

                          return _KeyValueRow(
                            key: ValueKey(isExtra ? "extra_row" : item!.id),
                            index: i,
                            item: item,
                            isExtra: isExtra,
                            mode: widget.mode,
                            enableSuggestionsForKey:
                                widget.enableSuggestionsForKey,
                            id: widget.id,
                            focusTargetId: _focusTargetId,
                            focusKeyField: _focusKeyField,
                            itemHeight: itemHeight,
                            onUpdate: (idx, newItem) =>
                                _updateItem(idx, newItem),
                            onRemove: (idx) => _removeItem(idx),
                            onAdd: (val, isKey) {
                              _focusKeyField = isKey ?? true;
                              _addNew(val, isKey);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _KeyValueRow extends StatefulWidget {
  final int index;
  final KeyValueItem? item; // null if extra
  final bool isExtra;
  final KeyValueEditorMode mode;
  final bool enableSuggestionsForKey;
  final String? id;
  final String? focusTargetId;
  final bool focusKeyField;
  final double itemHeight;
  final Function(int, KeyValueItem) onUpdate;
  final Function(int) onRemove;
  final Function(String?, bool?) onAdd;

  const _KeyValueRow({
    super.key,
    required this.index,
    this.item,
    required this.isExtra,
    required this.mode,
    required this.enableSuggestionsForKey,
    required this.id,
    this.focusTargetId,
    required this.focusKeyField,
    required this.itemHeight,
    required this.onUpdate,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  State<_KeyValueRow> createState() => _KeyValueRowState();
}

class _KeyValueRowState extends State<_KeyValueRow> {
  bool _isHovered = false;
  final _menuKey = GlobalKey<CustomPopupState>();
  bool _isDraggingFile = false;

  void _showMultilineEdit() async {
    if (widget.item == null) return;
    final value = await showDialog(
      context: context,
      builder: (ctx) {
        return MultilineEditDialog(initialValue: widget.item!.value);
      },
    );
    if (value != null) {
      widget.onUpdate(widget.index, widget.item!.copyWith(value: value));
    }
  }

  void _showSimpleEditDialog(
    String title,
    String initialValue,
    Function(String) onSave,
  ) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 16)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

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
            if (!widget.isExtra) ...[
              // Checkbox
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
                      value: widget.item!.isEnabled,
                      onChanged: (val) {
                        widget.onUpdate(
                          widget.index,
                          widget.item!.copyWith(isEnabled: val ?? false),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Drag Handle
              AnimatedOpacity(
                opacity: _isHovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: ReorderableDragStartListener(
                  index: widget.index,
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
            ] else
              SizedBox(
                width: widget.mode == KeyValueEditorMode.headers ? 29 : 29,
              ),

            // Key Input
            SizedBox(width: 180, child: _buildInput(true)),
            const SizedBox(width: 12),

            // Removed Type Dropdown

            // Value Input / File Input
            Expanded(child: _buildValueArea()),
            const SizedBox(width: 8),

            // Actions Menu
            if (!widget.isExtra)
              _buildActionsMenu()
            else
              const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildValueArea() {
    if (!widget.isExtra &&
        widget.item is FormDataItem &&
        widget.mode == KeyValueEditorMode.multipart) {
      // Only show file input in multipart mode
      final item = widget.item as FormDataItem;
      if (item.type == 'file') {
        return _buildFileInput(item);
      }
    }
    return _buildInput(false);
  }

  Widget _buildFileInput(FormDataItem item) {
    final path = item.filePath;
    final fileName = path?.split(RegExp(r'[/\\]')).last;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: DottedDecoration(
        shape: Shape.box,
        borderRadius: BorderRadius.circular(4),
        color: _isDraggingFile
            ? colorScheme.primary
            : colorScheme.outlineVariant,
      ),
      child: DropTarget(
        onDragEntered: (_) => setState(() => _isDraggingFile = true),
        onDragExited: (_) => setState(() => _isDraggingFile = false),
        onDragDone: (details) {
          setState(() => _isDraggingFile = false);
          if (details.files.isNotEmpty) {
            widget.onUpdate(
              widget.index,
              item.copyWith(filePath: details.files.first.path),
            );
          }
        },
        child: InkWell(
          onTap: () async {
            final res = await FilePicker.platform.pickFiles();
            if (res != null && res.files.single.path != null) {
              widget.onUpdate(
                widget.index,
                item.copyWith(filePath: res.files.single.path),
              );
            }
          },
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            color: _isDraggingFile
                ? colorScheme.primary.withValues(alpha: 0.1)
                : null,
            child: Row(
              children: [
                Icon(Icons.description, size: 14, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName ?? "Select File",
                    style: TextStyle(
                      fontSize: 12,
                      color: fileName != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fileName != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () {
                      widget.onUpdate(
                        widget.index,
                        item.copyWith(filePath: null),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsMenu() {
    final isMultipart = widget.mode == KeyValueEditorMode.multipart;
    final isFormItem = widget.item is FormDataItem;
    final formItem = isFormItem ? widget.item as FormDataItem : null;
    final notFile = formItem?.type != 'file';
    final disabledClr = const Color.fromARGB(255, 113, 113, 113);
    return MyCustomMenu.contentColumn(
      popupKey: _menuKey,
      useBtn: true,
      items: [
        if (isMultipart && isFormItem) ...[
          CustomMenuIconItem.tick(
            title: const Text('Text'),
            checked: formItem?.type == 'text',
            value: 'type_text',
            onTap: (_) {
              final newItem = formItem!.copyWith(
                type: 'text',
                resetFilename: true,
              );
              widget.onUpdate(widget.index, newItem);
            },
          ),
          CustomMenuIconItem.tick(
            title: const Text('File'),
            checked: formItem?.type == 'file',
            value: 'type_file',
            onTap: (_) {
              final newItem = formItem!.copyWith(type: 'file', value: '');
              widget.onUpdate(widget.index, newItem);
            },
          ),
          menuDivider,
        ],

        if (isMultipart) ...[
          CustomMenuIconItem(
            title: Text(
              'Set Filename',
              style: TextStyle(color: notFile ? disabledClr : null),
            ),
            value: 'filename',
            disabled: notFile,

            onTap: (_) => showInputDialog(
              context: context,
              title: 'Set Filename',
              placeholder: 'Filename',
              initialValue: formItem!.fileName,
              onConfirmed: (v) {
                widget.onUpdate(widget.index, formItem.copyWith(fileName: v));
              },
            ),
          ),
          CustomMenuIconItem(
            title: Text(
              'Content-Type',
              style: TextStyle(color: notFile ? disabledClr : null),
            ),
            value: 'content_type',
            disabled: notFile,
            onTap: (_) => showInputDialog(
              context: context,
              title: 'Set Content-Type',
              placeholder: 'Content-Type',
              initialValue: formItem!.contentType,
              onConfirmed: (v) {
                widget.onUpdate(
                  widget.index,
                  formItem.copyWith(contentType: v),
                );
              },
            ),
          ),
          menuDivider,
        ],
        CustomMenuIconItem(
          title: Text(
            'Edit Multiline',
            style: TextStyle(color: !notFile ? disabledClr : null),
          ),
          value: 'edit',
          disabled: !notFile,
          icon: const Icon(Icons.edit, size: 16),
          onTap: (_) => _showMultilineEdit(),
        ),
        menuDivider,
        CustomMenuIconItem(
          title: const Text('Delete', style: TextStyle(color: Colors.red)),
          value: 'delete',
          icon: const Icon(Icons.delete, size: 16, color: Colors.red),
          onTap: (_) => widget.onRemove(widget.index),
        ),
      ],
      child: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
    );
  }

  Widget _buildInput(bool isKey) {
    if (widget.isExtra) {
      return CustomInput(
        id: widget.id,
        autofocus: false,
        value: '',
        isExtra: true,
        isEnabled: false,
        enableSuggestions: isKey ? widget.enableSuggestionsForKey : true,
        onExtraInputChange: (v) {
          widget.onAdd(v, isKey);
        },
      );
    }

    final item = widget.item!;
    final shouldForceFocus =
        (item.id == widget.focusTargetId) && (isKey == widget.focusKeyField);

    CustomInput buildFn(FocusNode? fn, [TextEditingController? ctrl]) =>
        CustomInput(
          focusNode: fn,
          id: widget.id,
          controller: ctrl,
          value: isKey ? item.key : item.value,
          isExtra: false,
          enableSuggestions: isKey ? widget.enableSuggestionsForKey : true,
          isEnabled: item.isEnabled,
          onUpdate: (val) {
            widget.onUpdate(
              widget.index,
              isKey ? item.copyWith(key: val) : item.copyWith(value: val),
            );
          },
        );

    if (shouldForceFocus) {
      return EnsureFocus(
        value: isKey ? item.key : item.value,
        builder: (fn, ctrl) => buildFn(fn, ctrl),
      );
    }
    return buildFn(null);
  }
}

class EnsureFocus extends StatefulWidget {
  final Widget Function(FocusNode focusNode, TextEditingController controller)
  builder;
  final String value;

  const EnsureFocus({super.key, required this.builder, required this.value});

  @override
  State<EnsureFocus> createState() => _EnsureFocusState();
}

class _EnsureFocusState extends State<EnsureFocus> {
  late FocusNode _focusNode;
  late final TextEditingController controller = TextEditingController(
    text: widget.value,
  );

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        // focusing input which already has text causes text is selected issue
        Future.microtask(() {
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        });
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
    return widget.builder(_focusNode, controller);
  }
}
