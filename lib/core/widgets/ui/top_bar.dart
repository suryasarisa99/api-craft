import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key, required this.left, required this.right});
  final List<Widget> left;
  final List<Widget> right;
  static const topBarHeight = 36.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const topBarColor = Color.fromARGB(255, 27, 27, 27);

    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      //// it causes slow down the buttons on topbar
      // onDoubleTap: () async {
      //   if (await windowManager.isMaximized()) {
      //     await windowManager.unmaximize();
      //   } else {
      //     await windowManager.maximize();
      //   }
      // },
      child: Ink(
        height: topBarHeight,
        decoration: BoxDecoration(
          color: topBarColor,
          border: Border(bottom: BorderSide(color: const Color(0xFF3D3D3D))),
        ),
        child: Row(
          children: [
            if (Platform.isMacOS) SizedBox(width: 70),
            ...left,
            Expanded(
              child: GestureDetector(
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
              ),
            ),
            ...right,
          ],
        ),
      ),
    );
    // return WindowTitleBarBox(
    //   child: Container(
    //     height: topBarHeight,
    //     decoration: BoxDecoration(
    //       color: topBarColor,
    //       border: Border(bottom: BorderSide(color: const Color(0xFF3D3D3D))),
    //     ),
    //     child: Row(
    //       children: [
    //         if (Platform.isMacOS) SizedBox(width: 70),
    //         ...left,
    //         Expanded(child: MoveWindow(onDoubleTap: null)),
    //         ...right,
    //       ],
    //     ),
    //   ),
    // );
  }
}

class WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const WindowButton({super.key, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon, size: 16), onPressed: onPressed);
  }
}
