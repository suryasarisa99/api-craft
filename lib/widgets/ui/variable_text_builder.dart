import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';

class VariableText extends SpecialText {
  static const String startKey = "{{";
  static const String endKey = "}}";

  SpecialTextGestureTapCallback? customOnTap;
  VariableText({
    TextStyle? textStyle,
    this.customOnTap,
    SpecialTextGestureTapCallback? onTap,
  }) : super(startKey, endKey, textStyle, onTap: null);

  @override
  InlineSpan finishText() {
    // remove {{ and }}
    final String variableName = toString().substring(
      startKey.length,
      toString().length - endKey.length,
    );
    debugPrint("detect variable: $variableName");
    // We render a WidgetSpan to make it look like a distinct pill/chip
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,

      child: MouseRegion(
        //cursor
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            debugPrint("tapped a variable: $variableName");
            customOnTap?.call(variableName);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(
              color: const Color.fromARGB(58, 134, 51, 0),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Text(
              variableName,
              style: textStyle?.copyWith(
                backgroundColor: Colors.transparent,
                color: Colors.deepOrange,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // @override
  // InlineSpan finishText() {
  //   /*
  //   replacing with white space causes trim at the end,
  //   so used non-breaking spaces to prevent trim at end.
  //   */
  //   // final variableName = toString()
  //   //     .replaceFirst('{{', '\u00A0\u00A0')
  //   //     .replaceFirst('}}', '\u00A0\u00A0');

  //   /*
  //    to sync characters count,to replace {{ we must use any two characters
  //    but two non-braking spaces takes more space, so we use a zero-width space
  //   */
  //   // final String startReplacement = '\u00A0\u200B';
  //   // final String endReplacement = '\u200B\u00A0';
  //   final String startReplacement = 'xx';
  //   final String endReplacement = 'yy';
  //   final variableName = toString()
  //       .replaceFirst('{{', startReplacement)
  //       .replaceFirst('}}', endReplacement);

  //   // We render a WidgetSpan to make it look like a distinct pill/chip
  //   return TextSpan(
  //     style: textStyle?.copyWith(
  //       backgroundColor: Colors.orange.withValues(alpha: 0.2),
  //       color: Colors.deepOrange,
  //       fontWeight: FontWeight.bold,
  //       fontSize: 14,
  //     ),
  //     recognizer: TapGestureRecognizer()
  //       ..onSecondaryTap = () {
  //         debugPrint("tapped a variable: $variableName");
  //         if (onTap != null) {
  //           onTap!(variableName);
  //         }
  //       },
  //     text: variableName,
  //   );
  // }

  // @override
  // InlineSpan finishText() {
  //   // Extract strictly the name inside
  //   final String variableName = getContent();

  //   // Common style for the background "chip" look

  //   return TextSpan(
  //     recognizer: TapGestureRecognizer()
  //       ..onSecondaryTap = () {
  //         debugPrint("tapped a variable: $variableName");
  //         onTap!(variableName);
  //       },
  //     children: [
  //       // 1.  Opening Braces
  //       TextSpan(
  //         text: startKey,
  //         style: textStyle?.copyWith(color: Colors.blue),
  //       ),

  //       // 2. THE VISIBLE VARIABLE
  //       TextSpan(
  //         text: variableName,
  //         style: textStyle?.copyWith(
  //           color: Colors.deepOrange,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),

  //       // 3. Closing Braces
  //       TextSpan(
  //         text: endKey,
  //         style: textStyle?.copyWith(color: Colors.blue),
  //       ),
  //     ],
  //   );
  // }
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
      return VariableText(
        textStyle: builderTextStyle ?? textStyle,
        customOnTap: builderOnTap,
        onTap: onTap,
      );
    }
    return null;
  }
}
