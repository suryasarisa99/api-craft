import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/screens/home_screen.dart';
import 'package:api_craft/core/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonner_toast/sonner_toast.dart';

import 'package:window_manager/window_manager.dart'; // Use for better logging

const kTopBarClr = Color(0xFF1B1B1B);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // doWhenWindowReady(() {
  //   final win = appWindow;
  //   // const initialSize = Size(600, 450);
  //   // win.minSize = initialSize;
  //   // win.size = initialSize;
  //   // win.alignment = Alignment.center;
  //   win.show();
  // });
  // final path = await getDatabaseFilePath();
  await windowManager.ensureInitialized();
  const WindowOptions windowOptions = WindowOptions(
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(child: const MainApp()));
}

final colorSchema = ColorScheme.fromSeed(
  seedColor: const Color.fromARGB(255, 251, 13, 255),
  brightness: Brightness.dark,
);

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeServiceProvider);

    return MaterialApp(
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child!,
          SonnerOverlay(
            config: SonnerConfig(
              width: 350,
              alignment: Alignment.bottomRight,
              innerPadding: EdgeInsets.all(12),
            ),
            key: Sonner.overlayKey,
          ),
        ],
      ),

      theme: themeState
          .themeData, // Use theme based on selection (supports both light and dark effectively via the provider)
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: HomeScreen()),
    );
  }
}
