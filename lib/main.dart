import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/app/screens/home_screen.dart';
import 'package:api_craft/core/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonner_toast/sonner_toast.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

      theme: themeState.themeData,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: HomeScreen()),
    );
  }
}
