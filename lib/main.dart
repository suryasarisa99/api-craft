import 'package:api_craft/globals.dart';
import 'package:api_craft/screens/home/home_screen.dart';
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
  prefs = await SharedPreferences.getInstance();
  final path = await getDatabaseFilePath();
  debugPrint("Database will be initialized at: $path");
  runApp(ProviderScope(child: const MainApp()));
}

final colorSchema = ColorScheme.fromSeed(
  seedColor: const Color.fromARGB(255, 13, 138, 255),
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
        scaffoldBackgroundColor: const Color(0xFF1A1C1D),
        dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1A1C1D)),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: HomeScreen()),
    );
  }
}
