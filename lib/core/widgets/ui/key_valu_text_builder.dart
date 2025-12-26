import 'package:api_craft/core/widgets/ui/variable_text_builder.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';

class KeyValueTextBuilder extends SpecialTextSpanBuilder {
  final TemplateTap? builderOnTap;
  final TextStyle? builderTextStyle;

  KeyValueTextBuilder({this.builderOnTap, this.builderTextStyle});

  @override
  TextSpan build(
    String data, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    List<InlineSpan> children = [];
    int lineStart = 0;

    // Split logic handling newlines manually to track indices correctly
    while (lineStart < data.length) {
      int lineEnd = data.indexOf('\n', lineStart);
      if (lineEnd == -1) lineEnd = data.length;

      String lineText = data.substring(lineStart, lineEnd);
      _processLine(lineText, lineStart, children, textStyle);

      if (lineEnd < data.length) {
        children.add(const TextSpan(text: '\n'));
        lineStart = lineEnd + 1;
      } else {
        lineStart = lineEnd;
      }
    }

    // Handle empty string or trailing newline case implicit in loop logic:
    // If data ends with \n, the loop finishes.

    return TextSpan(children: children, style: textStyle);
  }

  void _processLine(
    String line,
    int lineStartIndex,
    List<InlineSpan> spans,
    TextStyle? baseStyle,
  ) {
    int colonIndex = line.indexOf(':');

    String keySection;
    String valSection;
    String? sep;

    if (colonIndex == -1) {
      keySection = line;
      valSection = "";
      sep = null;
    } else {
      keySection = line.substring(0, colonIndex);
      sep = ":";
      valSection = line.substring(colonIndex + 1);
    }

    // Color Styles
    final keyStyle =
        baseStyle?.copyWith(color: Colors.orange) ??
        const TextStyle(color: Colors.orange);
    final valStyle =
        baseStyle?.copyWith(color: Colors.green) ??
        const TextStyle(color: Colors.green);
    final sepStyle = baseStyle;

    // Process Key Section
    _appendWithVars(keySection, lineStartIndex, keyStyle, spans);

    // Process Separator
    if (sep != null) {
      spans.add(TextSpan(text: sep, style: sepStyle));
    }

    // Process Value Section
    if (valSection.isNotEmpty) {
      // The absolute start index of value is:
      // lineStartIndex + length_of_key + length_of_sep (1)
      int valStartIndex =
          lineStartIndex + keySection.length + (sep != null ? 1 : 0);
      _appendWithVars(valSection, valStartIndex, valStyle, spans);
    }
  }

  void _appendWithVars(
    String text,
    int startIndex,
    TextStyle style,
    List<InlineSpan> spans,
  ) {
    // Regex for {{...}}
    final pattern = RegExp(r'\{\{.*?\}\}');

    int cursor = 0;
    for (final match in pattern.allMatches(text)) {
      // Text before match
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: style),
        );
      }

      // The Variable
      String inner = text.substring(match.start + 2, match.end - 2);

      // We reuse VariableText to generate the span
      var vt = VariableText(
        start: startIndex + match.start,
        textStyle: builderTextStyle ?? style,
        customOnTap: builderOnTap,
      );
      vt.appendContent(
        inner,
      ); // Append content so VariableText knows what parsing

      // finishText returns the formatted span
      spans.add(vt.finishText());

      cursor = match.end;
    }

    // Remaining text
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }
  }

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    required int index,
  }) {
    // Not used because we override build
    return null;
  }
}
