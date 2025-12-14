import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key, required this.items});
  final List<Widget> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const topBarColor = Color.fromARGB(255, 27, 27, 27);
    const topBarHeight = 35.0;
    if (Platform.isMacOS) {
      return Container(
        height: topBarHeight,
        decoration: BoxDecoration(
          color: topBarColor,
          border: Border(bottom: BorderSide(color: const Color(0xFF3D3D3D))),
        ),
        child: Row(children: [SizedBox(width: 70), ...items, const Spacer()]),
      );
    } else {
      return GestureDetector(
        onPanStart: (details) {
          windowManager.startDragging();
        },
        onDoubleTap: () async {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
        child: Container(
          height: topBarHeight,
          color: topBarColor,
          child: Row(children: items),
        ),
      );
    }
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
