import 'dart:math';

import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/core/providers/filter_provider.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:api_craft/core/widgets/ui/key_valu_text_builder.dart';
import 'package:api_craft/features/environment/environment_editor_dialog.dart';
import 'package:api_craft/features/sidebar/context_menu.dart';
import 'package:api_craft/features/template-functions/models/template_placeholder_model.dart';
import 'package:api_craft/features/template-functions/parsers/parse.dart';
import 'package:api_craft/features/template-functions/parsers/utils.dart';
import 'package:api_craft/features/template-functions/widget/form_popup_widget.dart';
import 'package:api_craft/core/widgets/ui/filter.dart';
import 'package:api_craft/core/widgets/ui/variable_text_builder.dart';
import 'package:collection/collection.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SwitchTabNotification extends Notification {
  final int index;
  const SwitchTabNotification(this.index);
}

class VariableTextFieldCustom extends ConsumerStatefulWidget {
  final String? initialValue;
  // null id for global variables.
  final String? id;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final String? placeHolder;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  final bool enableUrlSuggestions;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final bool isKeyVal;
  final TextStyle? textStyle;

  const VariableTextFieldCustom({
    super.key,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.focusNode,
    required this.id,
    this.decoration,
    this.placeHolder,
    this.onKeyEvent,
    this.onSubmitted,
    this.enableSuggestions = true,
    this.enableUrlSuggestions = false,
    this.maxLines = 1,
    this.minLines,
    this.isKeyVal = false,
    this.textStyle,
  });

  @override
  ConsumerState<VariableTextFieldCustom> createState() =>
      _VariableTextFieldCustomState();
}

class _VariableTextFieldCustomState
    extends ConsumerState<VariableTextFieldCustom> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);

  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  final LayerLink _layerLink = LayerLink();

  late SpecialTextSpanBuilder _variableBuilder;

  OverlayEntry? _overlayEntry;
  List<FillOptions> _options = [];
  int _highlightedIndex = 0;

  late final double fontSize = widget.textStyle?.fontSize ?? 15;

  @override
  void initState() {
    super.initState();

    if (widget.isKeyVal) {
      _variableBuilder = KeyValueTextBuilder(
        builderOnTap: handleVariableTap,
        builderTextStyle: TextStyle(fontSize: fontSize),
      );
    } else {
      _variableBuilder = VariableTextBuilder(
        builderOnTap: handleVariableTap,
        builderTextStyle: TextStyle(fontSize: fontSize),
      );
    }
    // close on focus lost
    if (!widget.enableSuggestions) return;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _overlayEntry != null) {
        _hideOverlay();
      }
    });
  }

  (String? variable, String? source) getVariable(String name) {
    if (widget.id != null) {
      final node = ref.read(fileTreeProvider).nodeMap[widget.id!];
      VariableValue? x;
      if (node is FolderNode) {
        final v = node.config.variables.firstWhereOrNull((e) => e.key == name);
        if (v != null) {
          x = VariableValue("curr-folder", v.value);
        }
      }
      if (x == null) {
        final inheritedVars = ref
            .read(reqComposeProvider(widget.id!))
            .inheritVariables;
        x = inheritedVars[name];
      }
      return (x?.value, x?.sourceId);
    }
    return (null, null);
  }

  void handleVariableTap({
    required bool isVariable,
    required String name,
    required String rawContent,
    required int from,
    required int to,
  }) {
    debugPrint("Variable clicked in UI: $name");

    if (isVariable) {
      final (variable, source) = getVariable(name);
      final isGlobalEnv = widget.id == null;
      /*
      source null means the variable is global variable
      widget.id null means the text field is from keyvalue editor of global environment
      */

      if (variable != null) {
        debugPrint("Variable source ID: $source, value: $variable");
        if (source == null) {
          if (isGlobalEnv) {
            return;
          }
          showDialog(
            context: context,
            builder: (_) => const EnvironmentEditorDialog(),
          );
        }
        if (source == "global-env") {
          showDialog(
            context: context,
            builder: (_) => const EnvironmentEditorDialog(globalActive: true),
          );
        } else if (source == "sub-env") {
          showDialog(
            context: context,
            builder: (_) => const EnvironmentEditorDialog(),
          );
        } else if (source == "curr-folder") {
          SwitchTabNotification(3).dispatch(context);
        } else {
          showFolderConfigDialog(
            context: context,
            ref: ref,
            id: source!,
            tabIndex: 3,
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('variable: $name not found')));
      }
    } else {
      // function
      debugPrint("Function clicked in UI: $name,from: $from, to: $to");
      final templateFn = getTemplateFunctionByName(name);
      if (templateFn == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('function: $name not found')));
        return;
      }
      final fnPlaceholder =
          TemplateParser.parseContent(rawContent, start: from, end: to)
              as TemplateFnPlaceholder;
      showDialog(
        context: context,
        builder: (context) => FormPopupWidget(
          fnPlaceholder: fnPlaceholder,
          templateFn: templateFn,
          id: widget.id,
          updateField: updateField,
        ),
      );
    }
  }

  FilterService get _filterService {
    return ref.read(filterServiceProvider(widget.id));
  }

  void updateField(String Function(String val) fn) {
    final val = fn(widget.controller?.text ?? '');
    debugPrint("updated-field value: $val");
    _controller.text = val;
    widget.onChanged?.call(val);
  }

  // ─────────────────────────────────────────────────────────────
  // Overlay control
  // ─────────────────────────────────────────────────────────────

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            //  click outside to dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideOverlay,
              ),
            ),

            // actual suggestion box
            Positioned.fill(
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 48),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _buildOverlay(),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ─────────────────────────────────────────────────────────────
  // Text change → compute options
  // ─────────────────────────────────────────────────────────────

  void _onTextChanged(String text) {
    widget.onChanged?.call(text);
    if (!widget.enableSuggestions) return;
    if (!_focusNode.hasFocus) {
      _hideOverlay();
      return;
    }
    final results = _filterService.getOptions(
      _controller.value,
      enableUrlSuggestions: widget.enableUrlSuggestions,
    );
    // TextEditingValue(text: text, selection: _controller.selection),

    if (results.isEmpty) {
      _hideOverlay();
      return;
    }

    _options = results;
    _highlightedIndex = 0;

    _showOverlay();
    _overlayEntry?.markNeedsBuild();
  }

  // ─────────────────────────────────────────────────────────────
  // Option selection
  // ─────────────────────────────────────────────────────────────

  void _selectOption(FillOptions option) {
    final (newText, cursorPos) = FilterService.onOptionPick(
      _controller.text,
      option,
    );

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos),
    );
    widget.onChanged?.call(newText);
    _hideOverlay();
    _focusNode.requestFocus();
  }

  // ─────────────────────────────────────────────────────────────
  // Keyboard navigation
  // ─────────────────────────────────────────────────────────────

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_overlayEntry != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _highlightedIndex = (_highlightedIndex + 1) % _options.length;
        });
        _overlayEntry?.markNeedsBuild();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _highlightedIndex =
              (_highlightedIndex - 1 + _options.length) % _options.length;
        });
        _overlayEntry?.markNeedsBuild();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _selectOption(_options[_highlightedIndex]);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideOverlay();
        return KeyEventResult.handled;
      }
    }
    if (widget.onKeyEvent != null) {
      return widget.onKeyEvent!(node, event);
    }
    return KeyEventResult.ignored;
  }

  // ─────────────────────────────────────────────────────────────
  // Overlay UI
  // ─────────────────────────────────────────────────────────────

  Widget _buildOverlay() {
    final height = min(
      (_options.length * 40) +
          ((_options.length - 1).clamp(0, _options.length) * 4) +
          8,
      200,
    );

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 360,
        height: height.toDouble(),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF313131)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(4),
          itemCount: _options.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final option = _options[index];
            final isHighlighted = index == _highlightedIndex;

            return InkWell(
              onTapDown: (_) => _selectOption(option),
              child: _buildOptionTile(option, isHighlighted),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOptionTile(FillOptions option, bool isHighlighted) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF242424) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            _getTypeIcon(option.type),
            size: 18,
            color: _getTypeColor(option.type),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildHighlightedText(option, isHighlighted)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getTypeColor(option.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              option.type,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getTypeColor(option.type),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(FillOptions option, bool isHighlighted) {
    if (option.fuzzyMatch == null) {
      return Text(
        option.label,
        style: TextStyle(
          fontSize: 14,
          color: isHighlighted ? Colors.white : null,
        ),
      );
    }

    final match = option.fuzzyMatch!;
    final spans = <TextSpan>[];

    for (int i = 0; i < match.text.length; i++) {
      final isMatched = match.matchedIndices.contains(i);
      spans.add(
        TextSpan(
          text: match.text[i],
          style: TextStyle(
            fontSize: 14,
            fontWeight: isMatched ? FontWeight.bold : FontWeight.normal,
            color: isMatched
                ? const Color.fromARGB(255, 251, 134, 233)
                : (isHighlighted ? Colors.white : null),
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        canRequestFocus: false,
        focusNode: FocusNode(),
        onKeyEvent: _handleKey,
        child: ExtendedTextField(
          controller: _controller,
          focusNode: _focusNode,
          specialTextSpanBuilder: _variableBuilder,
          style: widget.textStyle ?? TextStyle(fontSize: fontSize, height: 1.4),
          autofocus: true,

          // textAlignVertical: TextAlignVertical.top,
          onChanged: _onTextChanged,
          onSubmitted: widget.onSubmitted,
          maxLines: widget.isKeyVal ? null : widget.maxLines,
          minLines: widget.isKeyVal ? null : widget.minLines,
          expands: widget.isKeyVal,
          decoration:
              widget.decoration ??
              InputDecoration(
                labelStyle: TextStyle(fontSize: 12),
                hintText: widget.placeHolder,
              ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'url':
        return Icons.link;
      case 'variable':
        return Icons.data_object;
      case 'function':
        return Icons.functions;
      default:
        return Icons.text_fields;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'url':
        return Colors.blue;
      case 'variable':
        return Colors.green;
      case 'function':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }
}
