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

/// A neumorphic-styled button that lays out arbitrary widgets in a row.
///
/// Commonly used as a child inside [GenericControlCard] for action buttons
/// like "Edit Script", "Import", "Export", "Select File", etc.
///
/// Usage:
/// ```dart
/// NeumorphicButton(
///   onTap: () => _openEditor(),
///   enabled: true,
///   children: [
///     Icon(Icons.code, size: 20),
///     SizedBox(width: 8),
///     Expanded(child: Text('Edit Script')),
///     Icon(Icons.edit, size: 18),
///   ],
/// )
/// ```
class NeumorphicButton extends StatelessWidget {
  /// Widgets laid out in a [Row] inside the button.
  ///
  /// You can use [Expanded] or [Flexible] children to control spacing.
  final List<Widget> children;

  /// Called when the button is tapped.
  final VoidCallback? onTap;

  /// Whether the button is interactive.
  final bool enabled;

  /// Internal padding.  Defaults to the project-standard
  /// `symmetric(vertical: 12, horizontal: 16)`.
  final EdgeInsets padding;

  /// Border radius.  Defaults to 12 (matching other inner elements).
  final double borderRadius;

  const NeumorphicButton({
    super.key,
    required this.children,
    this.onTap,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: NeumorphicStyles.conditionalInnerShadow(baseColor, enabled),
        ),
        child: Row(
          children: children,
        ),
      ),
    );
  }
}
