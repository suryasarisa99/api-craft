import 'dart:math';

import 'package:api_craft/widgets/ui/filter.dart';
import 'package:api_craft/widgets/ui/variable_text_builder.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';

class VariableTextField extends StatefulWidget {
  final String? initialValue;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  const VariableTextField({
    this.initialValue,
    this.controller,
    this.onChanged,
    super.key,
  });

  @override
  State<VariableTextField> createState() => _VariableTextFieldState();
}

class _VariableTextFieldState extends State<VariableTextField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);
  final FocusNode _focusNode = FocusNode();
  late VariableTextBuilder _variableBuilder;
  int latestCursorPos = 0;
  final fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _variableBuilder = VariableTextBuilder(
      builderOnTap: (dynamic parameter) {
        debugPrint("Variable clicked in UI: $parameter");
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

  String displayStringForOption(FillOptions option) {
    final (text, cursorPos) = FilterService.onOptionPick(
      _controller.text,
      option,
    );
    latestCursorPos = cursorPos;
    return text;
  }

  void moveToCursorPosition() {
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: latestCursorPos),
    );
  }

  Widget optionsViewBuilder(
    BuildContext context,
    AutocompleteOnSelected<FillOptions> onSelected,
    Iterable<FillOptions> options,
  ) {
    final int count = options.length;

    final double height = min(
      (count * 40) + // item height
          ((count - 1).clamp(0, count) * 4) + // separators
          8 + // ListView padding (4 top + 4 bottom)
          2, // ✅ Container border (1 + 1)
      200.0,
    );
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 320,
          height: height,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            border: Border.all(color: const Color.fromARGB(255, 49, 49, 49)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            itemCount: options.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (BuildContext context, int index) {
              final FillOptions option = options.elementAt(index);

              // 1. Get the currently highlighted index from Autocomplete's internal state
              final int highlightedIndex = AutocompleteHighlightedOption.of(
                context,
              );

              // 2. Check if this specific tile is the one selected by keyboard or default
              // Highlighting index 0 by default if highlightedIndex is 0 (standard behavior)
              final bool isHighlighted = highlightedIndex == index;

              return _buildOptionTile(option, onSelected, isHighlighted);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    FillOptions option,
    AutocompleteOnSelected<FillOptions> onSelected,
    bool isHighlighted,
  ) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF242424) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        canRequestFocus: false,
        // onTap: () => onSelected(option),
        onTap: () {
          onSelected(option);
          Future.delayed(Duration(milliseconds: 800), () {
            _focusNode.requestFocus();
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon based on type
              // Container(
              //   width: 26,
              //   height: 26,
              //   decoration: BoxDecoration(
              //     color: _getTypeColor(
              //       option.type,
              //     ).withValues(alpha: isHighlighted ? 0.2 : 0.1),
              //     borderRadius: BorderRadius.circular(6),
              //   ),
              //   child:
              // ),
              Icon(
                _getTypeIcon(option.type),
                size: 18,
                color: _getTypeColor(option.type),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildHighlightedText(option, isHighlighted)),
              // Badge
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
        ),
      ),
    );
  }

  Widget _buildHighlightedText(FillOptions option, bool isHighlighted) {
    final baseColor = isHighlighted ? Colors.white : null;

    if (option.fuzzyMatch == null) {
      return Text(
        option.label,
        style: TextStyle(fontSize: 14, color: baseColor),
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
            // If the row is highlighted, make the non-matched text white, keep matched text blue
            color: isMatched ? const Color(0xFF57ABFF) : baseColor,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
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
  Widget build(BuildContext context) {
    return Autocomplete<FillOptions>(
      focusNode: _focusNode,
      textEditingController: _controller,
      optionsBuilder: FilterService.getOptions,
      displayStringForOption: displayStringForOption,
      optionsViewBuilder: optionsViewBuilder,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return ExtendedTextField(
              controller: textEditingController,
              focusNode: focusNode,
              specialTextSpanBuilder: _variableBuilder,
              style: TextStyle(fontSize: fontSize, height: 1.4),
              autofillHints: const [AutofillHints.url],
              // Ensure onSubmitted calls the autocomplete logic if needed,
              // though Autocomplete handles Enter key internally when an option is highlighted.
              onSubmitted: (value) {
                onFieldSubmitted();
                moveToCursorPosition();
                focusNode.requestFocus();
              },
              onChanged: (v) {
                widget.onChanged?.call(v);
              },
              canRequestFocus: true,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 10.0,
                ),
                hintText: 'Try typing {{baseUrl}}/users or just "base"...',
              ),
            );
          },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
