/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onCapturePressed;
  final bool isCapturing;

  const AppHeader({
    super.key,
    this.onSettingsPressed,
    this.onCapturePressed,
    this.isCapturing = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildIconButton(
            colorScheme: colorScheme,
            icon: Icons.more_horiz,
            onPressed: onSettingsPressed,
          ),
          Text(
            'WEcho',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              letterSpacing: 1,
            ),
          ),
          _buildCaptureButton(colorScheme),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required ColorScheme colorScheme,
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: 0.7);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: 0.15);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: lightShadow,
              blurRadius: 10,
              offset: const Offset(-4, -4),
            ),
            BoxShadow(
              color: darkShadow,
              blurRadius: 10,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton(ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: 0.7);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: 0.15);

    return GestureDetector(
      onTap: onCapturePressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isCapturing
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 0),
                  ),
                  BoxShadow(
                    color: lightShadow,
                    blurRadius: 10,
                    offset: const Offset(-4, -4),
                  ),
                  BoxShadow(
                    color: darkShadow,
                    blurRadius: 10,
                    offset: const Offset(4, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: lightShadow,
                    blurRadius: 10,
                    offset: const Offset(-4, -4),
                  ),
                  BoxShadow(
                    color: darkShadow,
                    blurRadius: 10,
                    offset: const Offset(4, 4),
                  ),
                ],
        ),
        child: Center(
          child: Icon(
            isCapturing ? Icons.fiber_manual_record : Icons.videocam,
            color: isCapturing ? Colors.red : colorScheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }
}
