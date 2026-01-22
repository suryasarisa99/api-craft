import 'package:api_craft/features/themes/models/theme_model.dart';
import 'package:flutter/material.dart';

final _cs = ColorScheme.fromSeed(
  // seedColor: const Color.fromARGB(255, 251, 13, 255),
  seedColor: const Color.fromARGB(255, 110, 88, 255),
  brightness: Brightness.dark,
);
final _backgroundClr = const Color.fromARGB(255, 28, 32, 47);
final _topBar = const Color.fromARGB(255, 21, 23, 33);
final catppuccinMacchiato = ThemeData(
  visualDensity: VisualDensity.compact,
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  colorScheme: _cs,
  useMaterial3: true,
  scaffoldBackgroundColor: _backgroundClr,
  extensions: [
    AppTheme(
      statusBarBackground: _topBar,
      statusBarText: _cs.onPrimaryContainer,
      // topBarBorder: Colors.transparent,
      topBarBackground: _topBar,
      topBarText: _cs.onPrimaryContainer,
      menuTheme: const Color.fromARGB(255, 40, 47, 66),
    ),
    SidebarTheme(
      background: const Color.fromARGB(244, 35, 38, 55),
      itemActive: const Color.fromARGB(149, 77, 85, 126),
      itemSelected: _cs.secondary.withValues(alpha: 0.1),
      itemHover: _cs.primaryContainer.withValues(alpha: 0.6),
      itemFocused: _cs.primaryContainer.withValues(alpha: 0.6),
      indentLine: const Color.fromARGB(255, 65, 70, 87),
      text: _cs.onPrimaryContainer,
    ),
    BottomPannelTheme(
      background: _backgroundClr,
      headerBackground: Color.fromARGB(255, 40, 47, 66),
      text: _cs.onPrimaryContainer,
      divider: _cs.primaryContainer.withValues(alpha: 0.6),
    ),
    FlowTableTheme(
      selectedRow: const Color.fromARGB(255, 96, 83, 215),
      focusedRow: const Color.fromARGB(255, 141, 88, 255),
      evenRow: const Color.fromARGB(255, 25, 29, 42),
      oddRow: const Color.fromARGB(255, 31, 37, 54),
      rowSeperator: const Color.fromARGB(255, 38, 39, 61),
      header: const Color.fromARGB(255, 38, 45, 66),
      headerBorder: const Color.fromARGB(255, 46, 47, 74),
    ),
    FlowPanelTheme(
      urlBg: Color.fromARGB(255, 20, 23, 34),
      headerBg: Color.fromARGB(255, 29, 34, 47),
    ),
  ],
  dividerColor: const Color.fromARGB(255, 39, 42, 66),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    // backgroundColor: const Color.fromARGB(255, 35, 40, 58),
    backgroundColor: const Color.fromARGB(255, 30, 34, 50),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
      backgroundColor: _cs.secondaryContainer.withValues(alpha: 0.6),
      foregroundColor: _cs.onPrimaryContainer,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
    ),
  ),
  // filledButtonTheme:
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(32, 28),
      maximumSize: const Size(32, 28),
      alignment: Alignment.center,
      padding: .zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
    ),
  ),
  iconTheme: IconThemeData(color: Colors.grey),
  inputDecorationTheme: InputDecorationThemeData(
    isDense: true,
    floatingLabelStyle: TextStyle(height: 1, fontSize: 14, color: Colors.grey),
    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0)),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color.fromARGB(255, 66, 66, 66)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: _cs.primary, width: 1.5),
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
      foregroundColor: WidgetStatePropertyAll<Color>(_cs.primaryContainer),
    ),
  ),
  tabBarTheme: TabBarThemeData(
    tabAlignment: TabAlignment.start,
    dividerColor: Colors.transparent,
    indicator: BoxDecoration(
      color: Colors.transparent,
      border: Border(bottom: BorderSide(color: _cs.primary, width: 2)),
    ),
    labelPadding: .symmetric(horizontal: 10),
    // indicatorSize: TabBarIndicatorSize.tab,
    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    unselectedLabelStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
  ),
);
