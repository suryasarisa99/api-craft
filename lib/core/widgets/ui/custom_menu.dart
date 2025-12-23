import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';

const menuDivider = Padding(
  padding: EdgeInsets.symmetric(vertical: 4),
  child: Divider(height: 1),
);

class LabeledDivider extends StatelessWidget {
  final String text;
  const LabeledDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: .center,
        children: [
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(255, 138, 138, 138),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(child: const Divider(height: 1)),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class MyCustomMenu extends StatelessWidget {
  final Widget child;
  final Widget content;
  final double? width;
  final EdgeInsets childPadding;
  final GlobalKey<CustomPopupState>? popupKey;
  final bool useBtn;
  const MyCustomMenu({
    super.key,
    required this.popupKey,
    required this.child,
    required this.content,
    this.childPadding = const EdgeInsets.symmetric(
      horizontal: 8.0,
      vertical: 2.0,
    ),
    this.width,
    this.useBtn = true,
  });

  MyCustomMenu.contentColumn({
    super.key,
    required this.child,
    required this.popupKey,
    this.width,
    this.childPadding = const EdgeInsets.symmetric(
      horizontal: 8.0,
      vertical: 2.0,
    ),
    this.useBtn = true,
    required List<Widget> items,
  }) : content = Material(
         color: Colors.transparent,
         //  surfaceTintColor: Colors.red,
         //  elevation: 4,
         child: Padding(
           padding: const EdgeInsets.symmetric(vertical: 4),
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
    final popupClr = const Color.fromARGB(255, 38, 38, 38);
    return CustomPopup(
      key: popupKey,
      barrierColor: Colors.transparent,
      // barrierColor: const Color.fromARGB(103, 0, 0, 0),
      showArrow: true,
      // arrowColor: popupClr,
      arrowColor: const Color.fromARGB(255, 69, 64, 69),
      contentPadding: .zero,
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
      child: !useBtn
          ? child
          : InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                debugPrint("CustomMenuBtn Pressed");
                popupKey?.currentState?.show();
              },
              child: Padding(padding: childPadding, child: child),
            ),
    );
  }
}

class CustomMenuIconItem extends StatelessWidget {
  final Widget title;
  final String value;
  final void Function(String value)? onTap;
  final Widget? icon;

  const CustomMenuIconItem({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
    this.icon,
  });

  const CustomMenuIconItem.tick({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
    bool checked = false,
  }) : icon = checked == true
           ? const Icon(
               Icons.check_rounded,
               color: Color.fromARGB(255, 162, 162, 162),
               size: 16,
             )
           : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          Navigator.of(context).pop(value);
          onTap?.call(value);
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          width: double.infinity,
          child: Row(
            children: [
              if (icon != null) icon! else SizedBox(width: 16),
              SizedBox(width: 8),
              title,
            ],
          ),
        ),
      ),
    );
  }
}
