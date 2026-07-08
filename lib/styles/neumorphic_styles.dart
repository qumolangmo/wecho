/// Copyright (C) 2026 qumolangmo
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

class NeumorphicStyles {
  NeumorphicStyles._();

  static const double radiusSmall = 10.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusXXLarge = 28.0;

  static const EdgeInsets paddingSmall = EdgeInsets.all(8.0);
  static const EdgeInsets paddingMedium = EdgeInsets.all(12.0);
  static const EdgeInsets paddingLarge = EdgeInsets.all(16.0);
  static const EdgeInsets paddingXLarge = EdgeInsets.all(20.0);
  static const EdgeInsets paddingXXLarge = EdgeInsets.all(24.0);
  
  static const EdgeInsets paddingHorizontalSmall = EdgeInsets.symmetric(horizontal: 8.0);
  static const EdgeInsets paddingHorizontalMedium = EdgeInsets.symmetric(horizontal: 12.0);
  static const EdgeInsets paddingHorizontalLarge = EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets paddingHorizontalXLarge = EdgeInsets.symmetric(horizontal: 20.0);
  
  static const EdgeInsets paddingVerticalSmall = EdgeInsets.symmetric(vertical: 8.0);
  static const EdgeInsets paddingVerticalMedium = EdgeInsets.symmetric(vertical: 12.0);
  static const EdgeInsets paddingVerticalLarge = EdgeInsets.symmetric(vertical: 16.0);

  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  static const double spacingXXXL = 32.0;

  static const double shadowBlurSmall = 8.0;
  static const double shadowBlurMedium = 10.0;
  static const double shadowBlurLarge = 12.0;
  static const double shadowBlurXLarge = 15.0;
  static const double shadowBlurXXLarge = 20.0;

  static const Offset shadowOffsetSmall = Offset(3, 3);
  static const Offset shadowOffsetMedium = Offset(4, 4);
  static const Offset shadowOffsetLarge = Offset(5, 5);

  static const double fontSizeXS = 10.0;
  static const double fontSizeSM = 11.0;
  static const double fontSizeMD = 12.0;
  static const double fontSizeLG = 13.0;
  static const double fontSizeXL = 14.0;
  static const double fontSizeXXL = 15.0;
  static const double fontSizeXXXL = 16.0;
  static const double fontSizeTitle = 18.0;
  static const double fontSizeHeader = 24.0;

  static Color lightShadow(Color baseColor, {double alpha = 0.7}) {
    return baseColor
        .withRed(255)
        .withGreen(255)
        .withBlue(255)
        .withValues(alpha: alpha);
  }

  static Color darkShadow(Color baseColor, {double alpha = 0.15}) {
    return baseColor
        .withRed(0)
        .withGreen(0)
        .withBlue(0)
        .withValues(alpha: alpha);
  }

  static List<BoxShadow> neumorphicShadowPair(
    Color baseColor, {
    double blurRadius = 10.0,
    Offset offset = const Offset(4, 4),
    double lightAlpha = 0.7,
    double darkAlpha = 0.15,
  }) {
    return [
      BoxShadow(
        color: lightShadow(baseColor, alpha: lightAlpha),
        blurRadius: blurRadius,
        offset: -offset,
      ),
      BoxShadow(
        color: darkShadow(baseColor, alpha: darkAlpha),
        blurRadius: blurRadius,
        offset: offset,
      ),
    ];
  }

  static List<BoxShadow> smallNeumorphicShadow(Color baseColor) {
    return neumorphicShadowPair(
      baseColor,
      blurRadius: shadowBlurSmall,
      offset: shadowOffsetSmall,
    );
  }

  static List<BoxShadow> mediumNeumorphicShadow(Color baseColor) {
    return neumorphicShadowPair(
      baseColor,
      blurRadius: shadowBlurMedium,
      offset: shadowOffsetMedium,
    );
  }

  static List<BoxShadow> largeNeumorphicShadow(Color baseColor) {
    return neumorphicShadowPair(
      baseColor,
      blurRadius: shadowBlurLarge,
      offset: shadowOffsetMedium,
    );
  }

  static List<BoxShadow> xLargeNeumorphicShadow(Color baseColor) {
    return neumorphicShadowPair(
      baseColor,
      blurRadius: shadowBlurXLarge,
      offset: shadowOffsetLarge,
    );
  }

  static List<BoxShadow> innerShadowPair(
    Color baseColor, {
    double blurRadius = 6.0,
    Offset offset = const Offset(3, 3),
    double lightAlpha = 0.7,
    double darkAlpha = 0.15,
  }) {
    return [
      BoxShadow(
        color: darkShadow(baseColor, alpha: darkAlpha),
        blurRadius: blurRadius,
        offset: offset,
      ),
      BoxShadow(
        color: lightShadow(baseColor, alpha: lightAlpha),
        blurRadius: blurRadius,
        offset: -offset,
      ),
    ];
  }

  static List<BoxShadow> enabledInnerShadow(Color baseColor) {
    return innerShadowPair(
      baseColor,
      blurRadius: 6.0,
      offset: const Offset(3, 3),
      lightAlpha: 0.7,
      darkAlpha: 0.15,
    );
  }

  static List<BoxShadow> disabledInnerShadow(Color baseColor) {
    return innerShadowPair(
      baseColor,
      blurRadius: 6.0,
      offset: const Offset(3, 3),
      lightAlpha: 0.4,
      darkAlpha: 0.08,
    );
  }

  static List<BoxShadow> conditionalInnerShadow(Color baseColor, bool enabled) {
    return enabled ? enabledInnerShadow(baseColor) : disabledInnerShadow(baseColor);
  }

  static List<BoxShadow> activeIconBoxShadow(Color baseColor) {
    return [
      BoxShadow(
        color: lightShadow(baseColor, alpha: 0.7),
        blurRadius: 8.0,
        offset: const Offset(-3, -3),
      ),
      BoxShadow(
        color: darkShadow(baseColor, alpha: 0.15),
        blurRadius: 8.0,
        offset: const Offset(3, 3),
      ),
    ];
  }

  static List<BoxShadow> inactiveIconBoxShadow(Color baseColor) {
    return [
      BoxShadow(
        color: darkShadow(baseColor, alpha: 0.15),
        blurRadius: 6.0,
        offset: const Offset(2, 2),
      ),
    ];
  }

  static List<BoxShadow> conditionalIconBoxShadow(Color baseColor, bool isActive) {
    return isActive ? activeIconBoxShadow(baseColor) : inactiveIconBoxShadow(baseColor);
  }

  static List<BoxShadow> mainCardShadow(Color baseColor) {
    return [
      BoxShadow(
        color: lightShadow(baseColor, alpha: 0.7),
        blurRadius: 15.0,
        offset: const Offset(-5, -5),
      ),
      BoxShadow(
        color: darkShadow(baseColor, alpha: 0.15),
        blurRadius: 15.0,
        offset: const Offset(5, 5),
      ),
    ];
  }

  static List<BoxShadow> disabledMainCardShadow(Color baseColor) {
    return [
      BoxShadow(
        color: lightShadow(baseColor, alpha: 0.4),
        blurRadius: 15.0,
        offset: const Offset(-5, -5),
      ),
      BoxShadow(
        color: darkShadow(baseColor, alpha: 0.08),
        blurRadius: 15.0,
        offset: const Offset(5, 5),
      ),
    ];
  }

  static List<BoxShadow> conditionalMainCardShadow(Color baseColor, bool enabled) {
    return enabled ? mainCardShadow(baseColor) : disabledMainCardShadow(baseColor);
  }

  static BoxDecoration neumorphicDecoration(
    Color baseColor, {
    double radius = radiusMedium,
    double blurRadius = 10.0,
    Offset offset = const Offset(4, 4),
    double lightAlpha = 0.7,
    double darkAlpha = 0.15,
  }) {
    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: neumorphicShadowPair(
        baseColor,
        blurRadius: blurRadius,
        offset: offset,
        lightAlpha: lightAlpha,
        darkAlpha: darkAlpha,
      ),
    );
  }

  static BoxDecoration smallNeumorphicDecoration(Color baseColor, {double radius = radiusSmall}) {
    return neumorphicDecoration(
      baseColor,
      radius: radius,
      blurRadius: shadowBlurSmall,
      offset: shadowOffsetSmall,
    );
  }

  static BoxDecoration mediumNeumorphicDecoration(Color baseColor, {double radius = radiusMedium}) {
    return neumorphicDecoration(
      baseColor,
      radius: radius,
      blurRadius: shadowBlurMedium,
      offset: shadowOffsetMedium,
    );
  }

  static BoxDecoration largeNeumorphicDecoration(Color baseColor, {double radius = radiusLarge}) {
    return neumorphicDecoration(
      baseColor,
      radius: radius,
      blurRadius: shadowBlurLarge,
      offset: shadowOffsetMedium,
    );
  }

  static BoxDecoration xLargeNeumorphicDecoration(Color baseColor, {double radius = radiusXLarge}) {
    return neumorphicDecoration(
      baseColor,
      radius: radius,
      blurRadius: shadowBlurXLarge,
      offset: shadowOffsetLarge,
    );
  }

  static BoxDecoration innerNeumorphicDecoration(
    Color baseColor, {
    double radius = radiusMedium,
    bool enabled = true,
  }) {
    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: conditionalInnerShadow(baseColor, enabled),
    );
  }

  static TextStyle titleStyle(Color color, {double fontSize = fontSizeTitle}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static TextStyle bodyStyle(Color color, {double fontSize = fontSizeXL}) {
    return TextStyle(
      fontSize: fontSize,
      color: color,
    );
  }

  static TextStyle captionStyle(Color color, {double fontSize = fontSizeMD}) {
    return TextStyle(
      fontSize: fontSize,
      color: color,
    );
  }

  static TextStyle smallCaptionStyle(Color color, {double fontSize = fontSizeSM}) {
    return TextStyle(
      fontSize: fontSize,
      color: color,
    );
  }
}

extension NeumorphicExtension on ColorScheme {
  Color get lightShadow => NeumorphicStyles.lightShadow(surface);

  Color get darkShadow => NeumorphicStyles.darkShadow(surface);

  List<BoxShadow> get neumorphicShadowPair => 
      NeumorphicStyles.neumorphicShadowPair(surface);

  BoxDecoration neumorphicDecoration({
    double radius = NeumorphicStyles.radiusMedium,
    double blurRadius = 10.0,
    Offset offset = const Offset(4, 4),
  }) => NeumorphicStyles.neumorphicDecoration(
        surface,
        radius: radius,
        blurRadius: blurRadius,
        offset: offset,
      );

  List<BoxShadow> innerShadow(bool enabled) =>
      NeumorphicStyles.conditionalInnerShadow(surface, enabled);

  List<BoxShadow> iconBoxShadow(bool isActive) =>
      NeumorphicStyles.conditionalIconBoxShadow(surface, isActive);

  List<BoxShadow> mainCardShadow(bool enabled) =>
      NeumorphicStyles.conditionalMainCardShadow(surface, enabled);
}
