import 'package:api_craft/features/themes/theme.dart';
import 'package:flutter/material.dart';

final _cs = ColorScheme.fromSeed(
  // seedColor: const Color.fromARGB(255, 251, 13, 255),
  seedColor: const Color.fromARGB(255, 252, 151, 255),
  brightness: Brightness.dark,
);
final _backgroundClr = const Color.fromARGB(255, 0, 0, 0);
final _dividerClr = const Color.fromARGB(255, 32, 32, 32);
final theme2 = ThemeData(
  visualDensity: VisualDensity.compact,
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  colorScheme: _cs,
  useMaterial3: true,
  scaffoldBackgroundColor: _backgroundClr,
  extensions: [
    AppTheme(
      menuTheme: const Color.fromARGB(255, 12, 12, 12),
      topBarBackground: Color.fromARGB(255, 13, 13, 13),
      topBarText: _cs.onPrimaryContainer,
      statusBarBackground: Color.fromARGB(255, 0, 0, 0),
      statusBarText: _cs.onPrimaryContainer,
      statusBarBorder: const Color.fromARGB(255, 18, 18, 18),
      divider: const Color.fromARGB(255, 52, 52, 52),
      hoverDivider: const Color.fromARGB(255, 92, 92, 92),
    ),
    SidebarTheme(
      background: _backgroundClr,
      itemActive: const Color.fromARGB(150, 45, 45, 45),
      itemSelected: _cs.secondary.withValues(alpha: 0.1),
      itemHover: _cs.primaryContainer.withValues(alpha: 0.6),
      itemFocused: _cs.primaryContainer.withValues(alpha: 0.6),
      indentLine: const Color.fromARGB(255, 50, 50, 50),
      text: _cs.onPrimaryContainer,
    ),
    BottomPannelTheme(
      background: _backgroundClr,
      headerBackground: Color.fromARGB(255, 8, 8, 8),
      text: _cs.onPrimaryContainer,
      divider: _cs.primaryContainer.withValues(alpha: 0.6),
    ),
  ],
  dividerColor: _dividerClr,
  dividerTheme: DividerThemeData(color: _dividerClr),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    backgroundColor: const Color.fromARGB(255, 6, 6, 6),
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
