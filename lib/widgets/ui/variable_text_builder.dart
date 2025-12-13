import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class VariableText extends SpecialText {
  static const String startKey = "{{";
  static const String endKey = "}}";
  final int start; // <--- 2. Add this property

  SpecialTextGestureTapCallback? customOnTap;

  VariableText({
    TextStyle? textStyle,
    this.customOnTap,
    SpecialTextGestureTapCallback? onTap,
    required this.start, // <--- 1. Add this parameter
  }) : super(startKey, endKey, textStyle, onTap: onTap);

  @override
  InlineSpan finishText() {
    final String variableName = getContent();

    // finad open and close brackets: ( and ), ignore any content inbetween
    final regex = RegExp(r'\([^)]*\)');
    final didReplace = regex.hasMatch(variableName);
    late final String result;
    if (didReplace) {
      debugPrint("Variable name with parameters detected: $variableName");
      result = variableName.replaceAll(regex, '(...)');
    } else {
      result = variableName;
    }

    return SpecialTextSpan(
      actualText: toString(),
      text: result,
      deleteAll: true,
      start: start,
      style: textStyle?.copyWith(
        backgroundColor: Colors.orange.withOpacity(
          0.2,
        ), // fixed withValues for compatibility
        color: Colors.deepOrange,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          debugPrint("tapped a variable: $variableName");
          customOnTap?.call(variableName);
        },
    );
  }
}

class VariableTextBuilder extends SpecialTextSpanBuilder {
  // Define your custom properties here
  final SpecialTextGestureTapCallback? builderOnTap;
  final TextStyle? builderTextStyle;

  VariableTextBuilder({this.builderOnTap, this.builderTextStyle});

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    required int index,
  }) {
    if (flag == '') return null;

    if (isStart(flag, VariableText.startKey)) {
      final start = index - (VariableText.startKey.length - 1);
      debugPrint('flag: $flag (${flag.length})at index: $index');
      debugPrint("Creating VariableText at position: $start");
      return VariableText(
        start: start,
        textStyle: builderTextStyle ?? textStyle,
        customOnTap: builderOnTap,
        onTap: onTap,
      );
    }
    return null;
  }
}
