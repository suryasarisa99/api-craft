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
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Text(
              variableName,
              style: textStyle?.copyWith(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w400,
                fontSize: 15,
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

class VariableTextField extends StatefulWidget {
  const VariableTextField({super.key});

  @override
  State<VariableTextField> createState() => _VariableTextFieldState();
}

class _VariableTextFieldState extends State<VariableTextField> {
  final TextEditingController _controller = TextEditingController();
  late VariableTextBuilder _variableBuilder; // change to late

  final fontSize = 16.0;

  @override
  void initState() {
    super.initState();

    // Initialize the builder with your specific logic
    _variableBuilder = VariableTextBuilder(
      // 1. Handle Clicks Here
      builderOnTap: (dynamic parameter) {
        // 'parameter' is the variable name (e.g., "baseUrl")
        debugPrint("Variable clicked in UI: $parameter");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Edit variable: $parameter')));
      },

      // 2. Define Specific Variable Style Here
      builderTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
        backgroundColor: const Color(0x5F763417),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        child: ExtendedTextField(
          controller: _controller,
          specialTextSpanBuilder: _variableBuilder,
          style: TextStyle(fontSize: fontSize, height: 1.4),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: .symmetric(horizontal: 8.0, vertical: 10.0),
            hintText: 'Try typing {{baseUrl}}/users...',
          ),
        ),
      ),
    );
  }
}
