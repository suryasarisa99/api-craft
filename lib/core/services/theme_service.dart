import 'package:api_craft/core/constants/globals.dart';
import 'package:api_craft/app/themes/app_themes.dart';
import 'package:api_craft/app/themes/models/theme_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final ThemeInfo activeTheme;
  final Color? seedColor;

  ThemeState({required this.activeTheme, this.seedColor});

  ThemeData get themeData => activeTheme.getThemeData(seedColor);
}

class ThemeService extends Notifier<ThemeState> {
  static const String _kThemeIdKey = 'theme_id';
  static const String _kSeedColorKey = 'theme_seed_color';

  @override
  ThemeState build() {
    return _loadFromPrefs();
  }

  ThemeState _loadFromPrefs() {
    final themeId = prefs.getString(_kThemeIdKey);
    final seedColorValue = prefs.getInt(_kSeedColorKey);
    debugPrint(
      'ThemeService: _loadFromPrefs: themeId: $themeId, seedColorValue: $seedColorValue',
    );

    Color? seedColor;
    if (seedColorValue != null) {
      seedColor = Color(seedColorValue);
    }

    if (themeId != null) {
      final theme = AppThemes.themes.firstWhere(
        (t) => t.id == themeId,
        orElse: () => AppThemes.themes.first,
      );
      return ThemeState(activeTheme: theme, seedColor: seedColor);
    }
    return ThemeState(activeTheme: AppThemes.themes.first, seedColor: null);
  }

  Future<void> setTheme(ThemeInfo theme) async {
    state = ThemeState(activeTheme: theme, seedColor: state.seedColor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeIdKey, theme.id);
  }

  Future<void> setSeedColor(Color color) async {
    state = ThemeState(activeTheme: state.activeTheme, seedColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeedColorKey, color.value);
  }
}

final themeServiceProvider = NotifierProvider<ThemeService, ThemeState>(
  ThemeService.new,
);
