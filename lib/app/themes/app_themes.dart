import 'package:api_craft/app/themes/models/theme_info.dart';
import 'package:api_craft/app/themes/catppuccin_macchiato.dart';
import 'package:api_craft/app/themes/theme1.dart';
import 'package:api_craft/app/themes/theme2.dart';
import 'package:api_craft/app/themes/theme3.dart';
import 'package:api_craft/app/themes/theme4.dart';
import 'package:flutter/material.dart';

class AppThemes {
  static final List<ThemeInfo> themes = [
    ThemeInfo(
      id: 'custom_dark',
      name: 'Custom Dark',
      isDark: true,
      supportCustomColor: true,
      themeBuilder: (seedColor) => buildTheme1(
        brightness: Brightness.dark,
        seedColor: seedColor ?? Colors.blue,
      ),
    ),
    ThemeInfo(
      id: 'theme2',
      name: 'Black',
      isDark: true,
      supportCustomColor: true,
      themeBuilder: (seedColor) => buildBlackTheme(
        brightness: Brightness.dark,
        color: seedColor ?? const Color.fromARGB(255, 255, 114, 38),
      ),
    ),
    ThemeInfo(
      id: 'theme3',
      name: 'Dark Blue',
      isDark: true,
      supportCustomColor: true,
      themeBuilder: (seedColor) => buildTheme3(
        brightness: Brightness.dark,
        color: seedColor ?? Colors.blue,
      ),
    ),
    ThemeInfo(
      id: 'theme4',
      name: 'Dark Blue',
      isDark: true,
      supportCustomColor: true,
      themeBuilder: (seedColor) => buildTheme4(
        brightness: Brightness.dark,
        color: seedColor ?? Colors.orange,
      ),
    ),
    ThemeInfo(
      id: 'catppuccin_macchiato',
      name: 'Catppuccin Macchiato',
      isDark: true,
      fixedTheme: catppuccinMacchiato,
    ),
  ];
}
