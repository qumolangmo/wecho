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
import '../styles/neumorphic_styles.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 32),
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
          const SizedBox(width: 32)
        ],
      ),
    );
  }

  
}
