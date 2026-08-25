/// Global theme manager using ValueNotifier - follows wecho's StatelessWidget architecture
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';

class AppThemeManager {
  static final ValueNotifier<AppTheme> currentTheme = ValueNotifier(AppTheme.defaultTheme);
  static final ValueNotifier<ThemeMode> currentMode = ValueNotifier(ThemeMode.light);

  static AppTheme get theme => currentTheme.value;
  static ThemeMode get themeMode => currentMode.value;
  static bool get isDark => currentMode.value == ThemeMode.dark;

  static void setTheme(AppTheme t) => currentTheme.value = t;
  static void setThemeMode(ThemeMode m) => currentMode.value = m;
  static void toggleDarkMode() {
    currentMode.value = currentMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
          statusBarColor: colorScheme.surface,
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
