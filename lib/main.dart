import 'package:api_craft/globals.dart';
import 'package:api_craft/screens/home/home_screen.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer'; // Use for better logging

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
  doWhenWindowReady(() {
    final win = appWindow;
    // const initialSize = Size(600, 450);
    // win.minSize = initialSize;
    // win.size = initialSize;
    // win.alignment = Alignment.center;
    win.show();
  });
  // final path = await getDatabaseFilePath();
  // await windowManager.ensureInitialized();
  // const WindowOptions windowOptions = WindowOptions(
  //   center: true,
  //   backgroundColor: Colors.transparent,
  //   skipTaskbar: false,
  // );
  // await windowManager.waitUntilReadyToShow(windowOptions, () async {
  //   await windowManager.show();
  //   await windowManager.focus();
  // });
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
        scaffoldBackgroundColor: const Color.fromARGB(255, 33, 33, 33),
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
            minimumSize: const Size(38, 28),
            maximumSize: const Size(38, 28),
            alignment: Alignment.center,
            padding: .zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationThemeData(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color.fromARGB(255, 66, 66, 66)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color.fromARGB(255, 185, 116, 177),
              width: 1.5,
            ),
          ),
          prefixIconConstraints: BoxConstraints.tight(Size(36, 28)),
          suffixIconConstraints: BoxConstraints.tight(Size(36, 28)),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: HomeScreen()),
    );
  }
}
