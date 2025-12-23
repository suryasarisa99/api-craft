import 'package:flutter/material.dart';

class CustomDialog extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  final EdgeInsets padding;
  final bool showCloseButton;
  const CustomDialog({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3D3D3D)),
      ),
      child: child,
    );
    return Dialog(
      child: showCloseButton
          ? Stack(
              children: [
                container,
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            )
          : container,
    );
  }
}
