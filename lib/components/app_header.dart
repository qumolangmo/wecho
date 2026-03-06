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
    return Material(
      color: colorScheme.primaryContainer.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton(ColorScheme colorScheme) {
    return Material(
      color: isCapturing
          ? colorScheme.primary.withOpacity(0.4)
          : colorScheme.primaryContainer.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onCapturePressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCapturing ? colorScheme.primary : colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Icon(
              isCapturing ? Icons.fiber_manual_record : Icons.videocam,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
