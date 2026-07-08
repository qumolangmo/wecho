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
import '../styles/neumorphic_styles.dart';

/// A neumorphic-styled slider that can be used as a child widget inside
/// [GenericControlCard] or any other container.
///
/// Usage:
/// ```dart
/// NeumorphicSlider(
///   label: 'Gain',
///   value: _gain,
///   min: 0,
///   max: 100,
///   unit: 'dB',
///   divisions: 100,
///   onChanged: (v) => setState(() => _gain = v),
/// )
/// ```
class NeumorphicSlider extends StatelessWidget {
  /// Display label shown above the slider track.  Empty string hides the
  /// label row entirely.
  final String label;

  /// Current slider value.
  final double value;

  /// Minimum value.
  final double min;

  /// Maximum value.
  final double max;

  /// Unit suffix appended to the displayed value (e.g. 'dB', 'Hz').
  final String unit;

  /// Number of discrete divisions, or `null` for a continuous slider.
  final int? divisions;

  /// Called when the user drags the slider.
  final ValueChanged<double>? onChanged;

  /// Whether the slider is interactive.
  final bool enabled;

  /// Number of decimal places shown in the value text.
  final int decimalPlaces;

  /// Custom label for the min end.  Defaults to `"$min$unit"`.
  final String minLabel;

  /// Custom label for the max end.  Defaults to `"$max$unit"`.
  final String maxLabel;

  const NeumorphicSlider({
    super.key,
    this.label = '',
    required this.value,
    required this.min,
    required this.max,
    this.unit = '',
    this.divisions,
    this.onChanged,
    this.enabled = true,
    this.decimalPlaces = 2,
    String? minLabel,
    String? maxLabel,
  })  : minLabel = minLabel ?? '$min$unit',
        maxLabel = maxLabel ?? '$max$unit';

  String get valueText =>
      '${value.toStringAsFixed(decimalPlaces)}$unit';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;

    return Column(
      children: [
        if (label.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
            boxShadow: NeumorphicStyles.conditionalInnerShadow(baseColor, enabled),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colorScheme.primary,
              inactiveTrackColor: colorScheme.surfaceContainerHighest,
              thumbColor: colorScheme.primary,
              overlayColor: colorScheme.primary.withValues(alpha: 0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Text(
                maxLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
