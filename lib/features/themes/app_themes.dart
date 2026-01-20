import 'package:api_craft/features/themes/models/theme_info.dart';
import 'package:api_craft/features/themes/them5.dart';
import 'package:api_craft/features/themes/theme.dart';
import 'package:api_craft/features/themes/theme1.dart';
import 'package:api_craft/features/themes/theme2.dart';
import 'package:api_craft/features/themes/theme3.dart';
import 'package:api_craft/features/themes/theme4.dart';
import 'package:flutter/material.dart';

class AppThemes {
  static final List<ThemeInfo> themes = [
    ThemeInfo(
      id: 'theme1',
      name: 'Dark Green',
      isDark: true,
      fixedTheme: theme1,
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
      id: 'custom_dark',
      name: 'Custom Dark',
      isDark: true,
      supportCustomColor: true,
      themeBuilder: (seedColor) => _buildTheme(
        brightness: Brightness.dark,
        seedColor: seedColor ?? Colors.blue,
      ),
    ),
    ThemeInfo(
      id: 'catppuccin_macchiato',
      name: 'Catppuccin Macchiato',
      isDark: true,
      fixedTheme: catppuccinMacchiato,
    ),
    ThemeInfo(
      id: 'custom_light',
      name: 'Custom Light',
      isDark: false,
      supportCustomColor: true,
      themeBuilder: (seedColor) => _buildTheme(
        brightness: Brightness.light,
        seedColor: seedColor ?? Colors.blue,
      ),
    ),
  ];

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color seedColor,
  }) {
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // Base colors based on brightness
    final backgroundClr = brightness == Brightness.dark
        ? const Color(0xFF1B1B1B) // Or slightly lighter than pure black
        : const Color(0xFFFFFFFF);

    // Common extensions logic - can be refined
    return ThemeData(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      colorScheme: cs,
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundClr,
      extensions: [
        AppTheme(
          statusBarBackground: brightness == Brightness.dark
              ? const Color(0xFF1B1B1B)
              : cs.surface,
          statusBarText: cs.onSurface,
          topBarBackground: brightness == Brightness.dark
              ? const Color(0xFF1B1B1B)
              : cs.surface,
          topBarText: cs.onSurface,
          menuTheme: brightness == Brightness.dark
              ? const Color(0xFF262626)
              : cs.surfaceContainerHigh,
          divider: cs.outlineVariant,
        ),
        SidebarTheme(
          background: backgroundClr,
          itemActive: brightness == Brightness.dark
              ? const Color.fromARGB(150, 70, 70, 70)
              : cs.secondaryContainer.withValues(alpha: 0.5),
          itemSelected: cs.secondary.withValues(alpha: 0.1),
          itemHover: cs.primaryContainer.withValues(alpha: 0.6),
          itemFocused: cs.primaryContainer.withValues(alpha: 0.6),
          indentLine: brightness == Brightness.dark
              ? const Color.fromARGB(149, 20, 20, 20)
              : cs.outlineVariant,
          text: cs.onSurface,
        ),
        BottomPannelTheme(
          background: backgroundClr,
          headerBackground: brightness == Brightness.dark
              ? const Color(0xFF202020)
              : cs.surfaceContainer,
          text: cs.onSurface,
          divider: cs.primaryContainer.withValues(alpha: 0.6),
        ),
      ],
      dividerColor: cs.outlineVariant,
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF212121)
            : cs.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6.0),
          ),
          backgroundColor: cs.secondaryContainer.withValues(alpha: 0.6),
          foregroundColor: cs.onSecondaryContainer,
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
        ),
      ),
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
      iconTheme: IconThemeData(color: cs.onSurfaceVariant),
      inputDecorationTheme: InputDecorationThemeData(
        isDense: true,
        floatingLabelStyle: TextStyle(
          height: 1,
          fontSize: 14,
          color: cs.onSurfaceVariant,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        prefixIconConstraints: BoxConstraints.tight(Size(32, 28)),
        suffixIconConstraints: BoxConstraints.tight(Size(32, 28)),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(cs.primary),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.transparent,
          border: Border(bottom: BorderSide(color: cs.primary, width: 2)),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
