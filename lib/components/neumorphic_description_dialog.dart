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
import 'package:wecho/l10n/app_localizations.dart';
import '../styles/neumorphic_styles.dart';

class NeumorphicDescriptionDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const NeumorphicDescriptionDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  static Future<void> show({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return showDialog(
      context: context,
      builder: (context) => NeumorphicDescriptionDialog(
        icon: icon,
        title: title,
        description: description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: NeumorphicStyles.paddingXXLarge,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: NeumorphicStyles.neumorphicShadowPair(
            baseColor,
            blurRadius: NeumorphicStyles.shadowBlurXXLarge,
            offset: const Offset(6, 6),
            lightAlpha: 0.3,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                    boxShadow: NeumorphicStyles.activeIconBoxShadow(baseColor),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(NeumorphicStyles.radiusSmall),
                    boxShadow: NeumorphicStyles.smallNeumorphicShadow(baseColor),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.close,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
