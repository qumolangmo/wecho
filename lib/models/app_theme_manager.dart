/// Global theme manager using ValueNotifier - follows wecho's StatelessWidget architecture
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class AppThemeManager {
  static const String _kThemeModeKey = 'wecho_theme_mode';
  static const String _kThemeKey = 'wecho_theme_index';

  static SharedPreferences? _prefs;

  static final ValueNotifier<AppTheme> currentTheme = ValueNotifier(AppTheme.defaultTheme);
  static final ValueNotifier<ThemeMode> currentMode = ValueNotifier(ThemeMode.light);

  static AppTheme get theme => currentTheme.value;
  static ThemeMode get themeMode => currentMode.value;
  static bool get isDark => currentMode.value == ThemeMode.dark;

  /// Initialize theme manager - load saved preferences from disk.
  /// Must be called before runApp.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Restore theme mode (default: light)
    final modeIndex = _prefs!.getInt(_kThemeModeKey);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
      currentMode.value = ThemeMode.values[modeIndex];
    }

    // Restore app theme (default: defaultTheme)
    final themeIndex = _prefs!.getInt(_kThemeKey);
    if (themeIndex != null && themeIndex >= 0 && themeIndex < AppTheme.values.length) {
      currentTheme.value = AppTheme.values[themeIndex];
    }
  }

  static void setTheme(AppTheme t) {
    currentTheme.value = t;
    _prefs?.setInt(_kThemeKey, t.index);
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
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary.withValues(alpha: 0.5);
          return null;
        }),
      ),
    );
  }
}
