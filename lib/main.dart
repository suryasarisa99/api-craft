import 'package:api_craft/globals.dart';
import 'package:api_craft/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer'; // Use for better logging
import 'package:window_manager/window_manager.dart';

Future<String> getDatabaseFilePath() async {
  // 1. Get the default databases directory for the current platform (macOS in this case)
  String databasesPath = await getDatabasesPath();

  // 2. Join the directory path with your database file name
  String path = join(databasesPath, 'your_database_name.db');

  // 3. Print the full path for debugging
  log('Database Path: $path');

  return path;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData(
        colorScheme: colorSchema,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF272727),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          backgroundColor: const Color(0xFF201F20),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
            backgroundColor: colorSchema.secondaryContainer.withValues(
              alpha: 0.6,
            ),
            foregroundColor: colorSchema.onPrimaryContainer,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
            foregroundColor: colorSchema.primaryContainer,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 28),
            maximumSize: const Size(32, 28),
            padding: .zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: HomeScreen()),
    );
  }
}
