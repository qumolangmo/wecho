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

/// A single option in a [NeumorphicSelector].
class SelectorItem<T> {
  final T value;
  final String label;
  final bool deletable;

  const SelectorItem({
    required this.value,
    required this.label,
    this.deletable = false,
  });
}

/// A neumorphic-style dropdown selector.
///
/// Displays a list of [SelectorItem]s inside a raised container with the
/// project's signature light/dark dual-shadow effect.  Each item can
/// optionally show a delete icon on the right.
///
/// Usage:
/// ```dart
/// NeumorphicSelector<int>(
///   items: [
///     SelectorItem(value: 1, label: 'Option A'),
///     SelectorItem(value: 2, label: 'Option B', deletable: true),
///   ],
///   selectedValue: _selected,
///   onSelect: (v) => setState(() => _selected = v),
///   onDelete: (v) => _removeItem(v),
///   enabled: true,
///   hint: 'Choose...',
/// )
/// ```
class NeumorphicSelector<T> extends StatelessWidget {
  /// The list of selectable items.
  final List<SelectorItem<T>> items;

  /// The currently selected value, or `null` if nothing is selected.
  final T? selectedValue;

  /// Called when the user picks an item.
  final ValueChanged<T>? onSelect;

  /// Called when the user taps the delete icon on an item.
  ///
  /// If `null`, no delete icon is shown on any item (overrides
  /// individual [SelectorItem.deletable] flags).
  final ValueChanged<T>? onDelete;

  /// Whether the selector is interactive.
  final bool enabled;

  /// Placeholder text shown when no item is selected.
  final String hint;

  const NeumorphicSelector({
    super.key,
    required this.items,
    this.selectedValue,
    this.onSelect,
    this.onDelete,
    this.enabled = true,
    this.hint = 'Select',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor
        .withRed(255)
        .withGreen(255)
        .withBlue(255)
        .withValues(alpha: enabled ? 0.7 : 0.4);
    final darkShadow = baseColor
        .withRed(0)
        .withGreen(0)
        .withBlue(0)
        .withValues(alpha: enabled ? 0.15 : 0.08);

    // Ensure the selected value still exists in the item list;
    // otherwise fall back to null so DropdownButton doesn't throw.
    final validValue = items.any((i) => i.value == selectedValue)
        ? selectedValue
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkShadow,
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: lightShadow,
            blurRadius: 6,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: DropdownButton<T>(
        value: validValue,
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(
          Icons.arrow_drop_down,
          color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        items: items
            .map((item) => DropdownMenuItem<T>(
                  value: item.value,
                  child: Row(
                    children: [
                      Expanded(child: Text(item.label)),
                      if (onDelete != null && item.deletable)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop(); // close dropdown first
                            onDelete!(item.value);
                          },
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ))
            .toList(),
        onChanged: enabled
            ? (v) {
                if (v != null) onSelect?.call(v);
              }
            : null,
      ),
    );
  }
}
