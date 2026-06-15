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
import '../view_models/dsp_controller_view_model.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onCapturePressed;
  final bool isCapturing;
  final bool showCaptureButton;
  final double processingLatencyMs;

  const AppHeader({
    super.key,
    this.onSettingsPressed,
    this.onCapturePressed,
    this.isCapturing = false,
    this.showCaptureButton = true,
    this.processingLatencyMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildIconButton(
            colorScheme: colorScheme,
            icon: Icons.more_horiz,
            onPressed: onSettingsPressed,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WEcho',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
              if (isCapturing) ...[
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: processingLatencyMs <= 4
                                ? Colors.green
                                : processingLatencyMs <= 8
                                    ? Colors.yellow
                                    : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'latency: ${processingLatencyMs.toStringAsFixed(2)} ms',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'deadline: ${DSPControllerViewModel.deadlineMs.toStringAsFixed(2)} ms',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          showCaptureButton
              ? _buildCaptureButton(colorScheme)
              : const SizedBox(width: 48),
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
