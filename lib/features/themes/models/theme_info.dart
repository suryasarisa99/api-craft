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

class MyColors {
  final Color $1;
  final Color $2;
  final Color $3;
  final Color $4;
  final Color $5;
  final Color $6;
  final Color $7;
  final Color $8;
  final Color $9;
  final Color $10;
  final Color $11;
  final Color $12;

  const MyColors({
    required this.$1,
    required this.$2,
    required this.$3,
    required this.$4,
    required this.$5,
    required this.$6,
    required this.$7,
    required this.$8,
    required this.$9,
    required this.$10,
    required this.$11,
    required this.$12,
  });
}
