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
              color: const Color.fromARGB(255, 120, 119, 119),
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
    final popupClr = const Color.fromARGB(255, 41, 41, 42);
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
      child: child,
    );
  }
}

// SizedBox(
//       width: 180,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(4),
//         onTap: () {
//           ref
//               .read(resolveConfigProvider(widget.id).notifier)
//               .updateAuth(
//                 ref
//                     .read(resolveConfigProvider(widget.id))
//                     .node
//                     .config
//                     .auth
//                     .copyWith(type: type),
//               );
//           Navigator.of(context).pop();
//         },
//         child: Ink(
//           padding: const .symmetric(vertical: 3, horizontal: 4),
//           // alignment: Alignment.centerLeft,
//           width: 140,
//           child: Row(
//             children: [
//               if (checked)
//                 Icon(
//                   Icons.check,
//                   color: const Color.fromARGB(255, 120, 120, 120),
//                   size: 16,
//                 )
//               else
//                 SizedBox(width: 16),
//               SizedBox(width: 8),
//               Text(n),
//             ],
//           ),
//         ),
//       )

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
               Icons.check,
               color: Color.fromARGB(255, 120, 120, 120),
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
          onTap?.call(value);
          Navigator.of(context).pop(value);
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
