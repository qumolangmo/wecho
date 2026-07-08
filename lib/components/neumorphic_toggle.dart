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

/// A neumorphic-styled toggle (label + switch) that can be used as a child
/// widget inside [GenericControlCard] or any other container.
///
/// Usage:
/// ```dart
/// NeumorphicToggle(
///   label: 'Bypass',
///   value: _bypass,
///   onChanged: (v) => setState(() => _bypass = v),
/// )
/// ```
class NeumorphicToggle extends StatelessWidget {
  /// Display label on the left of the switch.
  final String label;

  /// Current toggle state.
  final bool value;

  /// Called when the user toggles the switch.
  final ValueChanged<bool>? onChanged;

  /// Whether the toggle is interactive.
  final bool enabled;

  const NeumorphicToggle({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
            boxShadow: NeumorphicStyles.conditionalInnerShadow(baseColor, enabled),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeThumbColor: colorScheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
