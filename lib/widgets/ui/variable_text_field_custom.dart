import 'dart:math';

import 'package:api_craft/providers/config_resolver_provider.dart';
import 'package:api_craft/providers/filter_provider.dart';
import 'package:api_craft/screens/home/sidebar/context_menu.dart';
import 'package:api_craft/widgets/ui/filter.dart';
import 'package:api_craft/widgets/ui/variable_text_builder.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/*
  need listen for consumer variables.

*/
class VariableTextFieldCustom extends ConsumerStatefulWidget {
  final String? initialValue;
  final String id;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final String? placeHolder;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  final bool enableUrlSuggestions;

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
    this.enableUrlSuggestions = false,
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

  late VariableTextBuilder _variableBuilder;

  OverlayEntry? _overlayEntry;
  List<FillOptions> _options = [];
  int _highlightedIndex = 0;

  final double fontSize = 14.0;

  @override
  void initState() {
    super.initState();

    _variableBuilder = VariableTextBuilder(
      builderOnTap: handleVariableTap,
      builderTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
        color: const Color.fromARGB(255, 254, 145, 223),
        backgroundColor: const Color.fromARGB(68, 63, 21, 63),
      ),
    );

    // close on focus lost
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _overlayEntry != null) {
        _hideOverlay();
      }
    });
  }

  void handleVariableTap(dynamic variableName) {
    debugPrint("Variable clicked in UI: $variableName");
    final variableValue = ref
        .read(resolveConfigProvider(widget.id))
        .allVariables?[variableName];
    if (variableValue != null) {
      debugPrint(
        "Variable source ID: ${variableValue.sourceId}, value: ${variableValue.value}",
      );
      showFolderConfigDialog(
        context: context,
        ref: ref,
        id: variableValue.sourceId,
        tabIndex: 3,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('variable: $variableName not found')),
      );
    }
  }

  FilterService get _filterService {
    return ref.read(filterServiceProvider(widget.id));
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
              color: _getTypeColor(option.type).withOpacity(0.1),
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
          style: TextStyle(fontSize: fontSize, height: 1.4),
          autofocus: true,
          onChanged: _onTextChanged,
          onSubmitted: widget.onSubmitted,
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
    _focusNode.dispose();
    super.dispose();
  }
}
