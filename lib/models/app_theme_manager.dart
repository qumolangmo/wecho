/// Copyright (C) 2026 jiangjie977
///
/// This file is part of Wecho.
///
/// Wecho is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// Wecho is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with Wecho.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class AppThemeManager {
  // dark or light.
  static const String _kThemeModeKey = 'wecho_theme_mode';
  static const String _kThemeKey = 'wecho_theme_index';

  static SharedPreferences? _prefs;

  static final ValueNotifier<AppTheme> currentTheme = ValueNotifier(AppTheme.defaultTheme);
  static final ValueNotifier<ThemeMode> currentMode = ValueNotifier(ThemeMode.light);

  static AppTheme get theme => currentTheme.value;
  static ThemeMode get themeMode => currentMode.value;
  static bool get isDark => currentMode.value == ThemeMode.dark;

  // must be called before runApp.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // restore theme mode (default: light)
    final modeIndex = _prefs!.getInt(_kThemeModeKey);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
      currentMode.value = ThemeMode.values[modeIndex];
    }

    final themeName = _prefs!.getString('wecho_theme_name');
    if (themeName != null) {
      final match = AppTheme.values.where((t) => t.name == themeName).firstOrNull;
      if (match != null) {
        currentTheme.value = match;
      }
    } else {
      // legacy index storage from before the theme list changed
      final themeIndex = _prefs!.getInt(_kThemeKey);
      if (themeIndex != null && themeIndex >= 0 && themeIndex < AppTheme.values.length) {
        currentTheme.value = AppTheme.values[themeIndex];
      }
    }
  }

  static void setTheme(AppTheme t) {
    currentTheme.value = t;
    _prefs?.setString('wecho_theme_name', t.name);
    _prefs?.remove(_kThemeKey);
  }

  static void setThemeMode(ThemeMode m) {
    currentMode.value = m;
    _prefs?.setInt(_kThemeModeKey, m.index);
  }

  static void toggleDarkMode() {
    final newMode = currentMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    currentMode.value = newMode;
    _prefs?.setInt(_kThemeModeKey, newMode.index);
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = AppThemeBuilder.build(currentTheme.value, brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: brightness,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }

          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.5);
          }

          return null;
        }),
      ),
    );
  }
}
