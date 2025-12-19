// import 'package:extended_text_field/extended_text_field.dart';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';

// class AtText extends SpecialText {
//   static const String flag = "@";
//   final int start;

//   /// whether show background for @somebody
//   final bool showAtBackground;

//   AtText(
//     TextStyle? textStyle,
//     SpecialTextGestureTapCallback? onTap, {
//     this.showAtBackground = false,
//     required this.start,
//   }) : super(flag, " ", textStyle);

//   @override
//   InlineSpan finishText() {
//     TextStyle? textStyle = this.textStyle?.copyWith(
//       color: Colors.blue,
//       fontSize: 16.0,
//     );

//     final String atText = toString();
//     debugPrint("AtText detected: $atText");

//     return SpecialTextSpan(
//       text: atText,
//       actualText: atText,
//       start: start,
//       style: textStyle,
//       recognizer: (TapGestureRecognizer()
//         ..onTap = () {
//           if (onTap != null) onTap!(atText);
//         }),
//     );
//   }
// }

// class MySpecialTextSpanBuilder extends SpecialTextSpanBuilder {
//   /// whether show background for @somebody
//   final bool showAtBackground;
//   // final BuilderType type;
//   MySpecialTextSpanBuilder({
//     this.showAtBackground = false,
//     // this.type = BuilderType.extendedText,
//   });

//   // @override
//   // TextSpan build(
//   //   String data, {
//   //   required TextStyle textStyle,
//   //   required SpecialTextGestureTapCallback onTap,
//   // }) {
//   //   var textSpan = super.build(data, textStyle: textStyle, onTap: onTap);
//   //   return textSpan;
//   // }

//   @override
//   SpecialText? createSpecialText(
//     String flag, {
//     TextStyle? textStyle,
//     SpecialTextGestureTapCallback? customOnTap,
//     required int index,
//   }) {
//     if (flag == null || flag == "") return null;

//     ///index is end index of start flag, so text start index should be index-(flag.length-1)
//     if (isStart(flag, AtText.flag)) {
//       return AtText(
//         textStyle!,
//         customOnTap,
//         start: index - (AtText.flag.length - 1),
//         showAtBackground: showAtBackground,
//       );
//     }
//     // else if (isStart(flag, EmojiText.flag)) {
//     //   return EmojiText(textStyle, start: index - (EmojiText.flag.length - 1));
//     // } else if (isStart(flag, DollarText.flag)) {
//     //   return DollarText(
//     //     textStyle,
//     //     onTap,
//     //     start: index - (DollarText.flag.length - 1),
//     //     type: type,
//     //   );
//     // }
//     return null;
//   }
// }
