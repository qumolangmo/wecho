/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:wecho/l10n/app_localizations.dart';

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
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: 0.3);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: 0.15);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: lightShadow,
              blurRadius: 20,
              offset: const Offset(-6, -6),
            ),
            BoxShadow(
              color: darkShadow,
              blurRadius: 20,
              offset: const Offset(6, 6),
            ),
          ],
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: lightShadow,
                        blurRadius: 8,
                        offset: const Offset(-3, -3),
                      ),
                      BoxShadow(
                        color: darkShadow,
                        blurRadius: 8,
                        offset: const Offset(3, 3),
                      ),
                    ],
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
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: lightShadow,
                        blurRadius: 6,
                        offset: const Offset(-2, -2),
                      ),
                      BoxShadow(
                        color: darkShadow,
                        blurRadius: 6,
                        offset: const Offset(2, 2),
                      ),
                    ],
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
