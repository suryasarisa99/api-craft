import 'package:api_craft/app/themes/models/theme_model.dart';
import 'package:flutter/material.dart';

ThemeData buildBlackTheme({
  required Brightness brightness,
  required Color color,
}) {
  final cs = ColorScheme.fromSeed(seedColor: color, brightness: brightness);
  final backgroundClr = const Color.fromARGB(255, 0, 0, 0);
  final dividerClr = const Color.fromARGB(255, 32, 32, 32);
  return ThemeData(
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundClr,
    extensions: [
      AppTheme(
        menuTheme: const Color.fromARGB(255, 12, 12, 12),
        topBarBackground: Color.fromARGB(255, 13, 13, 13),
        topBarText: cs.onPrimaryContainer,
        statusBarBackground: Color.fromARGB(255, 0, 0, 0),
        statusBarText: cs.onPrimaryContainer,
        statusBarBorder: const Color.fromARGB(255, 18, 18, 18),
        divider: const Color.fromARGB(255, 52, 52, 52),
        hoverDivider: const Color.fromARGB(255, 92, 92, 92),
      ),
      SidebarTheme(
        background: backgroundClr,
        itemActive: const Color.fromARGB(150, 45, 45, 45),
        itemSelected: cs.secondary.withValues(alpha: 0.1),
        itemHover: cs.primaryContainer.withValues(alpha: 0.6),
        itemFocused: cs.primaryContainer.withValues(alpha: 0.6),
        indentLine: const Color.fromARGB(255, 50, 50, 50),
        text: cs.onPrimaryContainer,
      ),
      BottomPannelTheme(
        background: backgroundClr,
        headerBackground: Color.fromARGB(255, 8, 8, 8),
        text: cs.onPrimaryContainer,
        divider: cs.primaryContainer.withValues(alpha: 0.6),
      ),
      FlowTableTheme(
        selectedRow: cs.primary,
        focusedRow: cs.primaryContainer,
        evenRow: const Color.fromARGB(255, 10, 10, 10),
        oddRow: const Color.fromARGB(255, 14, 14, 14),
        rowSeperator: const Color.fromARGB(255, 20, 20, 20),
        header: const Color.fromARGB(255, 20, 20, 20),
        headerBorder: const Color.fromARGB(255, 42, 42, 42),
      ),
      FlowPanelTheme(
        urlBg: Color.fromARGB(255, 8, 8, 8),
        headerBg: Color.fromARGB(255, 8, 8, 8),
      ),
    ],
    dividerColor: dividerClr,
    dividerTheme: DividerThemeData(color: dividerClr),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      backgroundColor: const Color.fromARGB(255, 6, 6, 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
        backgroundColor: cs.secondaryContainer.withValues(alpha: 0.6),
        foregroundColor: cs.onPrimaryContainer,
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
        borderSide: BorderSide(color: cs.primary, width: 1.5),
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
        foregroundColor: WidgetStatePropertyAll<Color>(cs.primaryContainer),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: cs.primary, width: 2)),
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
}
