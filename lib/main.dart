import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/core/screens/home_screen.dart';
import 'package:api_craft/objectbox.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:window_manager/window_manager.dart'; // Use for better logging

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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        colorScheme: colorSchema,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color.fromARGB(255, 33, 33, 33),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          backgroundColor: const Color.fromARGB(255, 33, 33, 33),
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
          // style: TextButton.styleFrom(
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(6.0),
          //   ),
          //   foregroundColor: colorSchema.primaryContainer,
          // ),
          style: ButtonStyle(
            shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
            ),
            foregroundColor: WidgetStatePropertyAll<Color>(
              colorSchema.primaryContainer,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
            foregroundColor: colorSchema.primaryContainer,
          ),
        ),
        // filledButtonTheme:
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 28),
            maximumSize: const Size(32, 28),
            alignment: Alignment.center,
            padding: .zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey),
        inputDecorationTheme: InputDecorationThemeData(
          isDense: true,
          // labelStyle: TextStyle(color: Colors.grey, fontSize: 14),
          floatingLabelStyle: TextStyle(
            height: 1,
            fontSize: 14,
            color: Colors.grey,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
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
          prefixIconConstraints: BoxConstraints.tight(Size(32, 28)),
          suffixIconConstraints: BoxConstraints.tight(Size(32, 28)),
        ),

        /// Dropdown Button Style
        dropdownMenuTheme: DropdownMenuThemeData(),
        menuButtonTheme: MenuButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
            ),
            foregroundColor: WidgetStatePropertyAll<Color>(
              colorSchema.primaryContainer,
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: HomeScreen()),
    );
  }
}
