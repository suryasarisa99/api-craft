import 'package:flutter/material.dart';

class ThemeInfo {
  final String id;
  final String name;
  final bool isDark;
  final bool supportCustomColor;
  final ThemeData? fixedTheme;
  final ThemeData Function(Color? seedColor)? themeBuilder;

  const ThemeInfo({
    required this.id,
    required this.name,
    required this.isDark,
    this.supportCustomColor = false,
    this.fixedTheme,
    this.themeBuilder,
  }) : assert(
         fixedTheme != null || themeBuilder != null,
         'Either fixedTheme or themeBuilder must be provided',
       );

  ThemeData getThemeData([Color? seedColor]) {
    if (fixedTheme != null) {
      return fixedTheme!;
    }
    return themeBuilder!(seedColor);
  }
}
