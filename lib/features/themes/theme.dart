import 'package:flutter/material.dart';

// app theme: status bar, top bar,
class AppTheme extends ThemeExtension<AppTheme> {
  final Color topBarBackground;
  final Color topBarText;
  final Color? topBarBorder;
  final Color statusBarBackground;
  final Color statusBarText;
  final Color? statusBarBorder;
  final Color menuTheme;
  final Color? divider;
  final Color? hoverDivider;

  const AppTheme({
    required this.statusBarBackground,
    required this.statusBarText,
    required this.topBarBackground,
    required this.topBarText,
    this.topBarBorder,
    this.statusBarBorder,
    required this.menuTheme,
    this.divider,
    this.hoverDivider,
  });

  @override
  AppTheme copyWith({
    Color? statusBarBackground,
    Color? statusBarText,
    Color? topBarBackground,
    Color? topBarText,
    Color? topBarBorder,
    Color? statusBarBorder,
    Color? menuTheme,
  }) => AppTheme(
    statusBarBackground: statusBarBackground ?? this.statusBarBackground,
    statusBarText: statusBarText ?? this.statusBarText,
    topBarBackground: topBarBackground ?? this.topBarBackground,
    topBarText: topBarText ?? this.topBarText,
    topBarBorder: topBarBorder ?? this.topBarBorder,
    statusBarBorder: statusBarBorder ?? this.statusBarBorder,
    menuTheme: menuTheme ?? this.menuTheme,
  );

  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) => AppTheme(
    statusBarBackground: statusBarBackground,
    statusBarText: statusBarText,
    topBarBackground: topBarBackground,
    topBarText: topBarText,
    topBarBorder: topBarBorder,
    statusBarBorder: statusBarBorder,
    menuTheme: menuTheme,
  );
}

class SidebarTheme extends ThemeExtension<SidebarTheme> {
  final Color background;
  final Color itemActive;
  final Color itemHover;
  final Color itemSelected;
  final Color itemFocused;
  final Color indentLine;
  final Color text;

  const SidebarTheme({
    required this.background,
    required this.itemActive,
    required this.itemHover,
    required this.itemSelected,
    required this.itemFocused,
    required this.indentLine,
    required this.text,
  });

  @override
  SidebarTheme copyWith({
    Color? background,
    Color? itemActive,
    Color? itemHover,
    Color? itemSelected,
    Color? itemFocused,
    Color? indentLine,
    Color? text,
  }) => SidebarTheme(
    background: background ?? this.background,
    itemActive: itemActive ?? this.itemActive,
    itemHover: itemHover ?? this.itemHover,
    itemSelected: itemSelected ?? this.itemSelected,
    itemFocused: itemFocused ?? this.itemFocused,
    indentLine: indentLine ?? this.indentLine,
    text: text ?? this.text,
  );

  @override
  SidebarTheme lerp(ThemeExtension<SidebarTheme>? other, double t) =>
      SidebarTheme(
        background: background,
        itemActive: itemActive,
        itemHover: itemHover,
        itemSelected: itemSelected,
        itemFocused: itemFocused,
        indentLine: indentLine,
        text: text,
      );
}

class BottomPannelTheme extends ThemeExtension<BottomPannelTheme> {
  final Color background;
  final Color headerBackground;
  final Color text;
  final Color divider;

  const BottomPannelTheme({
    required this.background,
    required this.headerBackground,
    required this.text,
    required this.divider,
  });

  @override
  BottomPannelTheme copyWith({
    Color? background,
    Color? headerBackground,
    Color? text,
    Color? divider,
  }) => BottomPannelTheme(
    background: background ?? this.background,
    headerBackground: headerBackground ?? this.headerBackground,
    divider: divider ?? this.divider,
    text: text ?? this.text,
  );

  @override
  BottomPannelTheme lerp(ThemeExtension<BottomPannelTheme>? other, double t) =>
      BottomPannelTheme(
        background: background,
        headerBackground: headerBackground,
        text: text,
        divider: divider,
      );
}
