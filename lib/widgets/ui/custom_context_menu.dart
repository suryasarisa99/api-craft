import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';

class MyCustomMenu extends StatelessWidget {
  final Widget child;
  final Widget content;
  final double? width;
  final GlobalKey<CustomPopupState>? popupKey;
  const MyCustomMenu({
    super.key,
    required this.popupKey,
    required this.child,
    required this.content,
    this.width,
  });

  MyCustomMenu.contentColumn({
    super.key,
    required this.child,
    required this.popupKey,
    this.width,
    required List<Widget> items,
  }) : content = Material(
         color: Colors.transparent,
         //  surfaceTintColor: Colors.red,
         //  elevation: 4,
         child: Padding(
           padding: const EdgeInsets.all(0.0),
           child: IntrinsicWidth(
             stepWidth: width,
             child: Column(
               crossAxisAlignment: .stretch,
               mainAxisSize: MainAxisSize.min,
               children: items,
             ),
           ),
         ),
       );

  @override
  Widget build(BuildContext context) {
    final popupClr = const Color.fromARGB(255, 41, 41, 42);
    return CustomPopup(
      key: popupKey,
      barrierColor: Colors.transparent,
      // barrierColor: const Color.fromARGB(103, 0, 0, 0),
      showArrow: true,
      // arrowColor: popupClr,
      arrowColor: const Color.fromARGB(255, 69, 64, 69),

      backgroundColor: popupClr,
      animationDuration: const Duration(milliseconds: 0),
      content: content,
      contentDecoration: BoxDecoration(
        color: popupClr,
        border: Border.all(
          color: const Color.fromARGB(255, 60, 60, 61),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
