import 'dart:math';

import 'package:api_craft/widgets/ui/filter.dart';
import 'package:api_craft/widgets/ui/variable_text_builder.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VariableTextFieldCustom extends StatefulWidget {
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const VariableTextFieldCustom({
    super.key,
    this.initialValue,
    this.controller,
    this.onChanged,
  });

  @override
  State<VariableTextFieldCustom> createState() =>
      _VariableTextFieldCustomState();
}

class _VariableTextFieldCustomState extends State<VariableTextFieldCustom> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);

  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  late VariableTextBuilder _variableBuilder;

  OverlayEntry? _overlayEntry;
  List<FillOptions> _options = [];
  int _highlightedIndex = 0;

  final double fontSize = 16.0;

  @override
  void initState() {
    super.initState();

    _variableBuilder = VariableTextBuilder(
      builderOnTap: (dynamic parameter) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Edit variable: $parameter')));
      },
      builderTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
        backgroundColor: const Color(0x5F763417),
      ),
    );
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

    final results = FilterService.getOptions(
      TextEditingValue(text: text, selection: _controller.selection),
    );

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

    _hideOverlay();
    _focusNode.requestFocus();
  }

  // ─────────────────────────────────────────────────────────────
  // Keyboard navigation
  // ─────────────────────────────────────────────────────────────

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_overlayEntry == null) return KeyEventResult.ignored;
    if (event is KeyUpEvent) return KeyEventResult.ignored;

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
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final option = _options[index];
            final isHighlighted = index == _highlightedIndex;

            return InkWell(
              onTap: () => _selectOption(option),
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
                ? const Color(0xFF57ABFF)
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
        focusNode: FocusNode(),
        onKeyEvent: _handleKey,
        child: ExtendedTextField(
          controller: _controller,
          focusNode: _focusNode,
          specialTextSpanBuilder: _variableBuilder,
          style: TextStyle(fontSize: fontSize, height: 1.4),
          autofocus: true,
          onChanged: _onTextChanged,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            hintText: 'Try typing {{baseUrl}}/users or just "base"...',
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
