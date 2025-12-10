import 'package:api_craft/globals.dart';
import 'package:api_craft/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
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
        dialogTheme: DialogThemeData(
          backgroundColor: const Color.fromARGB(255, 19, 19, 19),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: HomeScreen()),
    );
  }
}
