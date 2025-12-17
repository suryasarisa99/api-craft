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
        child: Row(children: [SizedBox(width: 70), ...items]),
      ),
    );
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
