/// App Theme definitions - ported from RootlessJamesDSP
/// 9 themes: Default, Monet (Material You), Green Apple, Honey,
/// Strawberry Daiquiri, Teal Turquoise, Tidal Wave, Yin Yang, Yotsuba
import 'package:flutter/material.dart';

enum AppTheme {
  defaultTheme('默认', 'Default'),
  monet('动态颜色', 'Monet (Material You)'),
  greenApple('青苹果', 'Green Apple'),
  honey('蜂蜜', 'Honey'),
  strawberry('草莓代基里', 'Strawberry Daiquiri'),
  tealTurquoise('绿松石', 'Teal Turquoise'),
  tidalWave('潮汐', 'Tidal Wave'),
  yinYang('阴阳', 'Yin & Yang'),
  yotsuba('四叶', 'Yotsuba');

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
      case AppTheme.tealTurquoise:
        return _tealTurquoiseLight();
      case AppTheme.tidalWave:
        return _tidalWaveLight();
      case AppTheme.yinYang:
        return _yinYangLight();
      case AppTheme.yotsuba:
        return _yotsubaLight();
      case AppTheme.defaultTheme:
      case AppTheme.monet:
      default:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF448AFF),
          brightness: Brightness.light,
        );
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
      case AppTheme.tealTurquoise:
        return _tealTurquoiseDark();
      case AppTheme.tidalWave:
        return _tidalWaveDark();
      case AppTheme.yinYang:
        return _yinYangDark();
      case AppTheme.yotsuba:
        return _yotsubaDark();
      case AppTheme.defaultTheme:
      case AppTheme.monet:
      default:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF448AFF),
          brightness: Brightness.dark,
        );
    }
  }

  // === Green Apple ===
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

  // === Honey ===
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

  // === Strawberry Daiquiri ===
  static ColorScheme _strawberryLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFFB61E40),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFDADD),
        onPrimaryContainer: Color(0xFF40000D),
        secondary: Color(0xFFB61E40),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFDADD),
        onSecondaryContainer: Color(0xFF40000D),
        tertiary: Color(0xFF775930),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFDDB1),
        onTertiaryContainer: Color(0xFF2A1800),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFCFCFC),
        onBackground: Color(0xFF201A1A),
        surface: Color(0xFFFCFCFC),
        onSurface: Color(0xFF201A1A),
        surfaceVariant: Color(0xFFF4DDDD),
        onSurfaceVariant: Color(0xFF534344),
        outline: Color(0xFF857374),
        outlineVariant: Color(0xFFD7C1C2),
        inverseSurface: Color(0xFF362F2F),
        onInverseSurface: Color(0xFFFBEDED),
        inversePrimary: Color(0xFFFFB2B9),
      );

  static ColorScheme _strawberryDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFB2B9),
        onPrimary: Color(0xFF630019),
        primaryContainer: Color(0xFF8E0527),
        onPrimaryContainer: Color(0xFFFFDADD),
        secondary: Color(0xFFFFB2B9),
        onSecondary: Color(0xFF630019),
        secondaryContainer: Color(0xFF8E0527),
        onSecondaryContainer: Color(0xFFFFDADD),
        tertiary: Color(0xFFE7C189),
        onTertiary: Color(0xFF442C07),
        tertiaryContainer: Color(0xFF5D421B),
        onTertiaryContainer: Color(0xFFFFDDB1),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        background: Color(0xFF201A1A),
        onBackground: Color(0xFFECE0E0),
        surface: Color(0xFF201A1A),
        onSurface: Color(0xFFECE0E0),
        surfaceVariant: Color(0xFF534344),
        onSurfaceVariant: Color(0xFFD7C1C2),
        outline: Color(0xFFA08C8D),
        outlineVariant: Color(0xFF534344),
        inverseSurface: Color(0xFFECE0E0),
        onInverseSurface: Color(0xFF201A1A),
        inversePrimary: Color(0xFFB61E40),
      );

  // === Teal Turquoise ===
  static ColorScheme _tealTurquoiseLight() => ColorScheme.fromSeed(
        seedColor: const Color(0xFF00897B),
        brightness: Brightness.light,
      );

  static ColorScheme _tealTurquoiseDark() => ColorScheme.fromSeed(
        seedColor: const Color(0xFF00897B),
        brightness: Brightness.dark,
      );

  // === Tidal Wave ===
  static ColorScheme _tidalWaveLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF006780),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFB4D4DF),
        onPrimaryContainer: Color(0xFF001f28),
        secondary: Color(0xFF006780),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFB8EAFF),
        onSecondaryContainer: Color(0xFF001f28),
        tertiary: Color(0xFF4E6230),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFCFE7A8),
        onTertiaryContainer: Color(0xFF151E00),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFDFBFF),
        onBackground: Color(0xFF001c3b),
        surface: Color(0xFFFDFBFF),
        onSurface: Color(0xFF001c3b),
        surfaceVariant: Color(0xFFDCE4E8),
        onSurfaceVariant: Color(0xFF40484c),
        outline: Color(0xFF70787c),
        outlineVariant: Color(0xFFC0C8CC),
        inverseSurface: Color(0xFF020400),
        onInverseSurface: Color(0xFFFFE3C4),
        inversePrimary: Color(0xFFB4ECFF),
      );

  static ColorScheme _tidalWaveDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF4FD8EE),
        onPrimary: Color(0xFF003644),
        primaryContainer: Color(0xFF004E61),
        onPrimaryContainer: Color(0xFF9FF0FF),
        secondary: const Color(0xFF4FD8EE),
        onSecondary: Color(0xFF003644),
        secondaryContainer: Color(0xFF004E61),
        onSecondaryContainer: Color(0xFF9FF0FF),
        tertiary: Color(0xFFB4CB8D),
        onTertiary: Color(0xFF273408),
        tertiaryContainer: Color(0xFF3A4A1C),
        onTertiaryContainer: Color(0xFFCFE7A8),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        background: Color(0xFF001c3b),
        onBackground: Color(0xFFD6E3FF),
        surface: Color(0xFF001c3b),
        onSurface: Color(0xFFD6E3FF),
        surfaceVariant: Color(0xFF40484c),
        onSurfaceVariant: Color(0xFFC0C8CC),
        outline: Color(0xFF8A9296),
        outlineVariant: Color(0xFF40484c),
        inverseSurface: Color(0xFFD6E3FF),
        onInverseSurface: Color(0xFF001c3b),
        inversePrimary: Color(0xFF006780),
      );

  // === Yin Yang ===
  static ColorScheme _yinYangLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF000000),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFF000000),
        onPrimaryContainer: Color(0xFFFFFFFF),
        secondary: Color(0xFF000000),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFAAAAAA),
        onSecondaryContainer: Color(0xFF0C0C0C),
        tertiary: Color(0xFFFFFFFF),
        onTertiary: Color(0xFF000000),
        tertiaryContainer: Color(0xFFD8E2FF),
        onTertiaryContainer: Color(0xFF001947),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFDFDFD),
        onBackground: Color(0xFF222222),
        surface: Color(0xFFFDFDFD),
        onSurface: Color(0xFF222222),
        surfaceVariant: Color(0xFFCCCCCC),
        onSurfaceVariant: Color(0xFF515151),
        outline: Color(0xFF838383),
        outlineVariant: Color(0xFFC4C4C4),
        inverseSurface: Color(0xFF333333),
        onInverseSurface: Color(0xFFF4F4F4),
        inversePrimary: Color(0xFF555555),
      );

  static ColorScheme _yinYangDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xFFFFFFFF),
        onPrimaryContainer: Color(0xFF000000),
        secondary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF000000),
        secondaryContainer: Color(0xFF555555),
        onSecondaryContainer: Color(0xFFF0F0F0),
        tertiary: Color(0xFF000000),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFF273055),
        onTertiaryContainer: Color(0xFFD8E2FF),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        background: Color(0xFF0D0D0D),
        onBackground: Color(0xFFE5E5E5),
        surface: Color(0xFF0D0D0D),
        onSurface: Color(0xFFE5E5E5),
        surfaceVariant: Color(0xFF333333),
        onSurfaceVariant: Color(0xFFC4C4C4),
        outline: Color(0xFF8E8E8E),
        outlineVariant: Color(0xFF333333),
        inverseSurface: Color(0xFFE5E5E5),
        onInverseSurface: Color(0xFF0D0D0D),
        inversePrimary: Color(0xFFAAAAAA),
      );

  // === Yotsuba ===
  static ColorScheme _yotsubaLight() => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFFAE3200),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFBC6B6),
        onPrimaryContainer: Color(0xFF3A0B00),
        secondary: Color(0xFFA63B16),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFDBD0),
        onSecondaryContainer: Color(0xFF3A0B00),
        tertiary: Color(0xFF705D00),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFE173),
        onTertiaryContainer: Color(0xFF221B00),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        background: Color(0xFFFFFBFF),
        onBackground: Color(0xFF3D0700),
        surface: Color(0xFFFFFBFF),
        onSurface: Color(0xFF3D0700),
        surfaceVariant: Color(0xFFF5DED7),
        onSurfaceVariant: Color(0xFF53433F),
        outline: Color(0xFF85736E),
        outlineVariant: Color(0xFFD8C2BC),
        inverseSurface: Color(0xFF5E1605),
        onInverseSurface: Color(0xFFFFEDE9),
        inversePrimary: Color(0xFFFFB59E),
      );

  static ColorScheme _yotsubaDark() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFB59E),
        onPrimary: Color(0xFF5C1800),
        primaryContainer: Color(0xFF7F2300),
        onPrimaryContainer: Color(0xFFFBC6B6),
        secondary: Color(0xFFFFB59E),
        onSecondary: Color(0xFF5C1800),
        secondaryContainer: Color(0xFF7F2300),
        onSecondaryContainer: Color(0xFFFFDBD0),
        tertiary: Color(0xFFDEC46C),
        onTertiary: Color(0xFF3A3000),
        tertiaryContainer: Color(0xFF544600),
        onTertiaryContainer: Color(0xFFFFE173),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        background: Color(0xFF3D0700),
        onBackground: Color(0xFFFFDAD3),
        surface: Color(0xFF3D0700),
        onSurface: Color(0xFFFFDAD3),
        surfaceVariant: Color(0xFF53433F),
        onSurfaceVariant: Color(0xFFD8C2BC),
        outline: Color(0xFFA08C87),
        outlineVariant: Color(0xFF53433F),
        inverseSurface: Color(0xFFFFDAD3),
        onInverseSurface: Color(0xFF3D0700),
        inversePrimary: Color(0xFFAE3200),
      );
}
