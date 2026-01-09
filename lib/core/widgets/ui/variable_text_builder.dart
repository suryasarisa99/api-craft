import 'package:api_craft/features/template-functions/parsers/utils.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';

typedef TemplateTap =
    void Function({
      required bool isVariable,
      required String name,
      required String rawContent,
      required int from,
      required int to,
    });
final _variableRegex = RegExp(r'\([^)]*\)');

class VariableText extends SpecialText {
  static const String startKey = "{{";
  static const String endKey = "}}";
  final int start; // <--- 2. Add this property

  TemplateTap? customOnTap;

  VariableText({
    TextStyle? textStyle,
    this.customOnTap,
    required this.start, // <--- 1. Add this parameter
  }) : super(startKey, endKey, textStyle);

  @override
  InlineSpan finishText() {
    final String variableName = getContent();

    // find open and close brackets: ( and ), ignore any content in between
    final isFn = _variableRegex.hasMatch(variableName);
    late final String result;
    bool isExist = true;
    if (isFn) {
      // debugPrint("Variable name with parameters detected: $variableName");
      // result = variableName.replaceAll(_variableRegex, '(...)');
      final name = variableName.replaceAll(_variableRegex, '');
      isExist = templateFunctionRegistry[name] != null;
      result = "$name(...)";
    } else {
      result = variableName;
    }

    const verticalPadding = 1.5;
    return ExtendedWidgetSpan(
      alignment: PlaceholderAlignment.middle,
      actualText: toString(),
      start: start,
      baseline: TextBaseline.alphabetic,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: (textStyle?.fontSize ?? 14) + (verticalPadding * 2),
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            // color: textStyle?.backgroundColor,
            color: isFn
                ? const Color.fromARGB(154, 111, 27, 111)
                : const Color.fromARGB(159, 42, 80, 127),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x66857383), width: 1),
          ),
          child: GestureDetector(
            // onTap: () {
            //   customOnTap?.call(variableName);
            // },
            onTap: () {
              final content = getContent().trim();

              final name = isFn
                  ? content.substring(0, content.indexOf('(')).trim()
                  : content;

              customOnTap?.call(
                isVariable: !isFn,
                name: name,
                rawContent: content,
                from: start,
                to: start + toString().length,
              );
            },
            child: Row(
              mainAxisSize: .min,
              children: [
                if (!isExist)
                  Text(
                    "! ",
                    style: TextStyle(
                      color: const Color.fromARGB(255, 255, 117, 105),
                      fontWeight: FontWeight.w500,
                      fontSize: (textStyle?.fontSize ?? 14),
                      backgroundColor: Colors.transparent,
                      letterSpacing: 0.9,
                      height: 0.8,
                    ),
                  ),
                Text(
                  result,
                  strutStyle: StrutStyle(height: 0.5),
                  style: textStyle?.copyWith(
                    color: isFn
                        ? const Color.fromARGB(255, 255, 151, 226)
                        : const Color.fromARGB(255, 149, 204, 255),
                    fontWeight: FontWeight.w300,
                    fontSize: (textStyle?.fontSize ?? 14),
                    backgroundColor: Colors.transparent,
                    letterSpacing: 0.9,
                    height: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VariableTextBuilder extends SpecialTextSpanBuilder {
  // Define your custom properties here
  final TemplateTap? builderOnTap;
  final TextStyle? builderTextStyle;

  VariableTextBuilder({this.builderOnTap, this.builderTextStyle});

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap, // not using
    required int index,
  }) {
    if (flag == '') return null;

    if (isStart(flag, VariableText.startKey)) {
      final start = index - (VariableText.startKey.length - 1);
      return VariableText(
        start: start,
        textStyle: builderTextStyle ?? textStyle,
        customOnTap: builderOnTap,
        // onTap: onTap,
      );
    }
    return null;
  }
}
