/// App Theme definitions
/// Generated from wecho主题配色方案表.xlsx
/// Themes: Default, Fresh Green, Amber Gold, Rose Red,
/// Night Black, Coral Magenta, Lavender Purple, Teal Cyan, Terracotta
import 'package:flutter/material.dart';

enum AppTheme {
  defaultTheme('默认', 'Default'),
  greenApple('清新绿', 'Fresh Green'),
  honey('琥珀金', 'Amber Gold'),
  strawberry('玫瑰红', 'Rose Red'),
  yinYang('暗夜黑', 'Night Black'),
  coralMagenta('珊瑚洋红', 'Coral Magenta'),
  lavenderPurple('薰衣草紫', 'Lavender Purple'),
  tealCyan('松石绿', 'Turquoise'),
  terracotta('落日橘', 'Sunset Orange');

  final String labelZh;
  final String labelEn;
  const AppTheme(this.labelZh, this.labelEn);

  String get label => labelZh;
}

/// Build ColorScheme for a given theme and brightness
class AppThemeBuilder {
  static ColorScheme build(AppTheme theme, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _buildDark(theme);
    }
    return _buildLight(theme);
  }

  static ColorScheme _buildLight(AppTheme theme) {
    switch (theme) {
      case AppTheme.greenApple:
        return _greenAppleLight();
      case AppTheme.honey:
        return _honeyLight();
      case AppTheme.strawberry:
        return _strawberryLight();
      case AppTheme.yinYang:
        return _yinYangLight();
      case AppTheme.coralMagenta:
        return _coralMagentaLight();
      case AppTheme.lavenderPurple:
        return _lavenderPurpleLight();
      case AppTheme.tealCyan:
        return _tealCyanLight();
      case AppTheme.terracotta:
        return _terracottaLight();
      case AppTheme.defaultTheme:
      default:
        return _defaultThemeLight();
    }
  }

  static ColorScheme _buildDark(AppTheme theme) {
    switch (theme) {
      case AppTheme.greenApple:
        return _greenAppleDark();
      case AppTheme.honey:
        return _honeyDark();
      case AppTheme.strawberry:
        return _strawberryDark();
      case AppTheme.yinYang:
        return _yinYangDark();
      case AppTheme.coralMagenta:
        return _coralMagentaDark();
      case AppTheme.lavenderPurple:
        return _lavenderPurpleDark();
      case AppTheme.tealCyan:
        return _tealCyanDark();
      case AppTheme.terracotta:
        return _terracottaDark();
      case AppTheme.defaultTheme:
      default:
        return _defaultThemeDark();
    }
  }

  // === 默认 (Default) 蓝色调===
  static ColorScheme _defaultThemeLight() => ColorScheme.fromSeed(
        seedColor: const Color(0xFF448AFF),
        brightness: Brightness.light,
      );

  static ColorScheme _defaultThemeDark() => ColorScheme.fromSeed(
        seedColor: const Color(0xFF448AFF),
        brightness: Brightness.dark,
      );

  // === 清新绿 (Fresh Green) ===
  static ColorScheme _greenAppleLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF006D2F),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFF96F8A9),
        onPrimaryContainer: Color(0xFF002109),
        secondary: Color(0xFF006D2F),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFF96F8A9),
        onSecondaryContainer: Color(0xFF002109),
        tertiary: Color(0xFFB91D22),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFDAD5),
        onTertiaryContainer: Color(0xFF410003),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFBFDF7),
        onBackground: Color(0xFF1A1C19),
        surface: Color(0xFFFBFDF7),
        onSurface: Color(0xFF1A1C19),
        surfaceVariant: Color(0xFFDDE5DA),
        onSurfaceVariant: Color(0xFF414941),
        outline: Color(0xFF717970),
        outlineVariant: Color(0xFFC1C9BE),
        inverseSurface: Color(0xFF2F312E),
        onInverseSurface: Color(0xFFF0F2EC),
        inversePrimary: Color(0xFF7ADB8F),
      );

  static ColorScheme _greenAppleDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF7ADB8F),
        onPrimary: Color(0xFF003915),
        primaryContainer: Color(0xFF005222),
        onPrimaryContainer: Color(0xFF96F8A9),
        secondary: Color(0xFF7ADB8F),
        onSecondary: Color(0xFF003915),
        secondaryContainer: Color(0xFF005222),
        onSecondaryContainer: Color(0xFF96F8A9),
        tertiary: Color(0xFFFFB3AD),
        onTertiary: Color(0xFF690006),
        tertiaryContainer: Color(0xFF93000E),
        onTertiaryContainer: Color(0xFFFFDAD5),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        background: Color(0xFF1A1C19),
        onBackground: Color(0xFFE2E3DE),
        surface: Color(0xFF1A1C19),
        onSurface: Color(0xFFE2E3DE),
        surfaceVariant: Color(0xFF414941),
        onSurfaceVariant: Color(0xFFC1C9BE),
        outline: Color(0xFF8B9389),
        outlineVariant: Color(0xFF414941),
        inverseSurface: Color(0xFFE2E3DE),
        onInverseSurface: Color(0xFF1A1C19),
        inversePrimary: Color(0xFF006D2F),
      );

  // === 琥珀金 (Amber Gold) ===
  static ColorScheme _honeyLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF885200),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFC996),
        onPrimaryContainer: Color(0xFF2B1700),
        secondary: Color(0xFF994700),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFDBC8),
        onSecondaryContainer: Color(0xFF321300),
        tertiary: Color(0xFF90427A),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFD8EE),
        onTertiaryContainer: Color(0xFF3B002F),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFFFBFF),
        onBackground: Color(0xFF1F1B16),
        surface: Color(0xFFFFFBFF),
        onSurface: Color(0xFF1F1B16),
        surfaceVariant: Color(0xFFF1DFD0),
        onSurfaceVariant: Color(0xFF50453A),
        outline: Color(0xFF827568),
        outlineVariant: Color(0xFFD5C3B5),
        inverseSurface: Color(0xFF352F2A),
        onInverseSurface: Color(0xFFFAEFE7),
        inversePrimary: Color(0xFFFFB869),
      );

  static ColorScheme _honeyDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFB869),
        onPrimary: Color(0xFF482900),
        primaryContainer: Color(0xFF673D00),
        onPrimaryContainer: Color(0xFFFFC996),
        secondary: Color(0xFFFFB688),
        onSecondary: Color(0xFF522300),
        secondaryContainer: Color(0xFF753300),
        onSecondaryContainer: Color(0xFFFFDBC8),
        tertiary: Color(0xFFFFAFDE),
        onTertiary: Color(0xFF5A1249),
        tertiaryContainer: Color(0xFF772961),
        onTertiaryContainer: Color(0xFFFFD8EE),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        background: Color(0xFF1F1B16),
        onBackground: Color(0xFFEBE0D9),
        surface: Color(0xFF1F1B16),
        onSurface: Color(0xFFEBE0D9),
        surfaceVariant: Color(0xFF50453A),
        onSurfaceVariant: Color(0xFFD5C3B5),
        outline: Color(0xFF9D8E81),
        outlineVariant: Color(0xFF50453A),
        inverseSurface: Color(0xFFEBE0D9),
        onInverseSurface: Color(0xFF1F1B16),
        inversePrimary: Color(0xFF885200),
      );

  // === 玫瑰红 (Rose Red) ===
  static ColorScheme _strawberryLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFFB61E40),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFF61E40),
        onPrimaryContainer: Color(0xFF001945),
        secondary: Color(0xFFB61E40),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFF61E40),
        onSecondaryContainer: Color(0xFF141B2C),
        tertiary: Color(0xFF715573),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFF8D8FF),
        onTertiaryContainer: Color(0xFF291331),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFBFDF7),
        onBackground: Color(0xFF1A1C19),
        surface: Color(0xFFFBFDF7),
        onSurface: Color(0xFF1A1C19),
        surfaceVariant: Color(0xFFDDE5DA),
        onSurfaceVariant: Color(0xFF414941),
        outline: Color(0xFF717970),
        outlineVariant: Color(0xFFC1C9BE),
        inverseSurface: Color(0xFF2F312E),
        onInverseSurface: Color(0xFFF0F2EC),
        inversePrimary: Color(0xFFFFB2B9),
      );

  static ColorScheme _strawberryDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFB2B9),
        onPrimary: Color(0xFF3D0018),
        primaryContainer: Color(0xF3D61E40),
        onPrimaryContainer: Color(0xFFFFFFFF),
        secondary: Color(0xFFFFB2B9),
        onSecondary: Color(0xFF3D0018),
        secondaryContainer: Color(0xF3D61E40),
        onSecondaryContainer: Color(0xFFFFFFFF),
        tertiary: Color(0xFFDEBCDF),
        onTertiary: Color(0xFF402843),
        tertiaryContainer: Color(0xFF4A375C),
        onTertiaryContainer: Color(0xFFFFFFFF),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFFFFF),
        background: Color(0xFF1A1C19),
        onBackground: Color(0xFFE2E3DE),
        surface: Color(0xFF1A1C19),
        onSurface: Color(0xFFE2E3DE),
        surfaceVariant: Color(0xFF414941),
        onSurfaceVariant: Color(0xFFC1C9BE),
        outline: Color(0xFF8B9389),
        outlineVariant: Color(0xFF414941),
        inverseSurface: Color(0xFFE2E3DE),
        onInverseSurface: Color(0xFF1A1C19),
        inversePrimary: Color(0xFFB61E40),
      );

  // === 暗夜黑 (Night Black) ===
  static ColorScheme _yinYangLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF000000),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFF00000),
        onPrimaryContainer: Color(0xFF001945),
        secondary: Color(0xFF000000),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFF00000),
        onSecondaryContainer: Color(0xFF141B2C),
        tertiary: Color(0xFF715573),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFF8D8FF),
        onTertiaryContainer: Color(0xFF291331),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFBFDF7),
        onBackground: Color(0xFF1A1C19),
        surface: Color(0xFFFBFDF7),
        onSurface: Color(0xFF1A1C19),
        surfaceVariant: Color(0xFFDDE5DA),
        onSurfaceVariant: Color(0xFF414941),
        outline: Color(0xFF717970),
        outlineVariant: Color(0xFFC1C9BE),
        inverseSurface: Color(0xFF2F312E),
        onInverseSurface: Color(0xFFF0F2EC),
        inversePrimary: Color(0xFF555555),
      );

  static ColorScheme _yinYangDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xF3D00000),
        onPrimaryContainer: Color(0xFFFFFFFF),
        secondary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF3D0018),
        secondaryContainer: Color(0xF3D00000),
        onSecondaryContainer: Color(0xFFFFFFFF),
        tertiary: Color(0xFFDEBCDF),
        onTertiary: Color(0xFF402843),
        tertiaryContainer: Color(0xFF4A375C),
        onTertiaryContainer: Color(0xFFFFFFFF),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFFFFF),
        background: Color(0xFF1A1C19),
        onBackground: Color(0xFFE2E3DE),
        surface: Color(0xFF1A1C19),
        onSurface: Color(0xFFE2E3DE),
        surfaceVariant: Color(0xFF414941),
        onSurfaceVariant: Color(0xFFC1C9BE),
        outline: Color(0xFF8B9389),
        outlineVariant: Color(0xFF414941),
        inverseSurface: Color(0xFFE2E3DE),
        onInverseSurface: Color(0xFF1A1C19),
        inversePrimary: Color(0xFFAAAAAA),
      );

  // === 珊瑚洋红 (Coral Magenta) ===
  static ColorScheme _coralMagentaLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFFD9376E),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFF9376E),
        onPrimaryContainer: Color(0xFF001945),
        secondary: Color(0xFFD9376E),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFF9376E),
        onSecondaryContainer: Color(0xFF141B2C),
        tertiary: Color(0xFF715573),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFF8D8FF),
        onTertiaryContainer: Color(0xFF291331),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFBFDF7),
        onBackground: Color(0xFF1A1C19),
        surface: Color(0xFFFBFDF7),
        onSurface: Color(0xFF1A1C19),
        surfaceVariant: Color(0xFFDDE5DA),
        onSurfaceVariant: Color(0xFF414941),
        outline: Color(0xFF717970),
        outlineVariant: Color(0xFFC1C9BE),
        inverseSurface: Color(0xFF2F312E),
        onInverseSurface: Color(0xFFF0F2EC),
        inversePrimary: Color(0xFFFFB1C4),
      );

  static ColorScheme _coralMagentaDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFB1C4),
        onPrimary: Color(0xFF3D0018),
        primaryContainer: Color(0xF3D9376E),
        onPrimaryContainer: Color(0xFFFFFFFF),
        secondary: Color(0xFFFFB1C4),
        onSecondary: Color(0xFF3D0018),
        secondaryContainer: Color(0xF3D9376E),
        onSecondaryContainer: Color(0xFFFFFFFF),
        tertiary: Color(0xFFDEBCDF),
        onTertiary: Color(0xFF402843),
        tertiaryContainer: Color(0xFF4A375C),
        onTertiaryContainer: Color(0xFFFFFFFF),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFFFFF),
        background: Color(0xFF1A1C19),
        onBackground: Color(0xFFE2E3DE),
        surface: Color(0xFF1A1C19),
        onSurface: Color(0xFFE2E3DE),
        surfaceVariant: Color(0xFF414941),
        onSurfaceVariant: Color(0xFFC1C9BE),
        outline: Color(0xFF8B9389),
        outlineVariant: Color(0xFF414941),
        inverseSurface: Color(0xFFE2E3DE),
        onInverseSurface: Color(0xFF1A1C19),
        inversePrimary: Color(0xFFD9376E),
      );

  // === 薰衣草紫 (Lavender Purple) ===
  static ColorScheme _lavenderPurpleLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF6750A4),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFF750A4),
        onPrimaryContainer: Color(0xFF001945),
        secondary: Color(0xFF6750A4),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFF750A4),
        onSecondaryContainer: Color(0xFF141B2C),
        tertiary: Color(0xFF715573),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFF8D8FF),
        onTertiaryContainer: Color(0xFF291331),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFBFDF7),
        onBackground: Color(0xFF1A1C19),
        surface: Color(0xFFFBFDF7),
        onSurface: Color(0xFF1A1C19),
        surfaceVariant: Color(0xFFDDE5DA),
        onSurfaceVariant: Color(0xFF414941),
        outline: Color(0xFF717970),
        outlineVariant: Color(0xFFC1C9BE),
        inverseSurface: Color(0xFF2F312E),
        onInverseSurface: Color(0xFFF0F2EC),
        inversePrimary: Color(0xFFD0BCFF),
      );

  static ColorScheme _lavenderPurpleDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFD0BCFF),
        onPrimary: Color(0xFF3D0018),
        primaryContainer: Color(0xF3D750A4),
        onPrimaryContainer: Color(0xFFFFFFFF),
        secondary: Color(0xFFD0BCFF),
        onSecondary: Color(0xFF3D0018),
        secondaryContainer: Color(0xF3D750A4),
        onSecondaryContainer: Color(0xFFFFFFFF),
        tertiary: Color(0xFFDEBCDF),
        onTertiary: Color(0xFF402843),
        tertiaryContainer: Color(0xFF4A375C),
        onTertiaryContainer: Color(0xFFFFFFFF),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFFFFF),
        background: Color(0xFF1A1C19),
        onBackground: Color(0xFFE2E3DE),
        surface: Color(0xFF1A1C19),
        onSurface: Color(0xFFE2E3DE),
        surfaceVariant: Color(0xFF414941),
        onSurfaceVariant: Color(0xFFC1C9BE),
        outline: Color(0xFF8B9389),
        outlineVariant: Color(0xFF414941),
        inverseSurface: Color(0xFFE2E3DE),
        onInverseSurface: Color(0xFF1A1C19),
        inversePrimary: Color(0xFF6750A4),
      );

  // === 青碧色 (Teal Cyan) ===
  static ColorScheme _tealCyanLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF006A6A),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFF9BF0F0),
        onPrimaryContainer: Color(0xFF002020),
        secondary: Color(0xFF4A6363),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFCCE8E8),
        onSecondaryContainer: Color(0xFF051F1F),
        tertiary: Color(0xFF4E6089),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFD6E2FF),
        onTertiaryContainer: Color(0xFF061C39),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFAFDFD),
        onBackground: Color(0xFF191C1C),
        surface: Color(0xFFFAFDFD),
        onSurface: Color(0xFF191C1C),
        surfaceVariant: Color(0xFFDAE4E3),
        onSurfaceVariant: Color(0xFF3F4948),
        outline: Color(0xFF6F7978),
        outlineVariant: Color(0xFFBEC9C7),
        inverseSurface: Color(0xFF2D3131),
        onInverseSurface: Color(0xFFEFF1F0),
        inversePrimary: Color(0xFF4ED3D3),
      );

  static ColorScheme _tealCyanDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF4ED3D3),
        onPrimary: Color(0xFF003737),
        primaryContainer: Color(0xFF005050),
        onPrimaryContainer: Color(0xFF9BF0F0),
        secondary: Color(0xFFB0CCCB),
        onSecondary: Color(0xFF163434),
        secondaryContainer: Color(0xFF304B4B),
        onSecondaryContainer: Color(0xFFCCE8E8),
        tertiary: Color(0xFFB6C6FF),
        onTertiary: Color(0xFF1D3057),
        tertiaryContainer: Color(0xFF354870),
        onTertiaryContainer: Color(0xFFD6E2FF),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFF191C1C),
        onBackground: Color(0xFFE0E3E2),
        surface: Color(0xFF191C1C),
        onSurface: Color(0xFFE0E3E2),
        surfaceVariant: Color(0xFF3F4948),
        onSurfaceVariant: Color(0xFFBEC9C7),
        outline: Color(0xFF899392),
        outlineVariant: Color(0xFF3F4948),
        inverseSurface: Color(0xFFE0E3E2),
        onInverseSurface: Color(0xFF191C1C),
        inversePrimary: Color(0xFF006A6A),
      );

  // === 赤陶色 (Terracotta) ===
  static ColorScheme _terracottaLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF8C4A2F),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFDBCB),
        onPrimaryContainer: Color(0xFF350D00),
        secondary: Color(0xFF775748),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFDBCB),
        onSecondaryContainer: Color(0xFF2C150A),
        tertiary: Color(0xFF665E2F),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFEDE2A6),
        onTertiaryContainer: Color(0xFF1F1B00),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFFF8F5),
        onBackground: Color(0xFF201A17),
        surface: Color(0xFFFFF8F5),
        onSurface: Color(0xFF201A17),
        surfaceVariant: Color(0xFFF5DED4),
        onSurfaceVariant: Color(0xFF53443C),
        outline: Color(0xFF85746B),
        outlineVariant: Color(0xFFD8C2B8),
        inverseSurface: Color(0xFF362F2B),
        onInverseSurface: Color(0xFFFBEEE8),
        inversePrimary: Color(0xFFFFB596),
      );

  static ColorScheme _terracottaDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFB596),
        onPrimary: Color(0xFF511F05),
        primaryContainer: Color(0xFF6E341A),
        onPrimaryContainer: Color(0xFFFFDBCB),
        secondary: Color(0xFFE7BDA9),
        onSecondary: Color(0xFF442A1D),
        secondaryContainer: Color(0xFF5D4032),
        onSecondaryContainer: Color(0xFFFFDBCB),
        tertiary: Color(0xFFD0C68C),
        onTertiary: Color(0xFF353005),
        tertiaryContainer: Color(0xFF4D471A),
        onTertiaryContainer: Color(0xFFEDE2A6),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFF201A17),
        onBackground: Color(0xFFEDE0DA),
        surface: Color(0xFF201A17),
        onSurface: Color(0xFFEDE0DA),
        surfaceVariant: Color(0xFF53443C),
        onSurfaceVariant: Color(0xFFD8C2B8),
        outline: Color(0xFFA08D83),
        outlineVariant: Color(0xFF53443C),
        inverseSurface: Color(0xFFEDE0DA),
        onInverseSurface: Color(0xFF201A17),
        inversePrimary: Color(0xFF8C4A2F),
      );
}
