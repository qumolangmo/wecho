/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:wecho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ControlCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final String unit;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<double> onChanged;

  const ControlCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.expanded,
    required this.onToggleExpand,
    required this.onChanged,
  });

  bool get isActive => value != 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.outlineVariant.withOpacity(0.2),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          _buildHeader(context, colorScheme),
          _buildSliderSection(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return InkWell(
      onTap: onToggleExpand,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(20),
        bottom: expanded ? Radius.zero : const Radius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _showDescriptionDialog(context, colorScheme),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${value.toStringAsFixed(1)} $unit',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: colorScheme.onSurfaceVariant,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDescriptionDialog(BuildContext context, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.close,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection(BuildContext context, ColorScheme colorScheme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.outlineVariant.withOpacity(0.2),
                      thumbColor: colorScheme.primary,
                      overlayColor: colorScheme.primary.withOpacity(0.1),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                    ),
                    child: Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: (max - min).toInt(),
                      onChanged: onChanged,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$min$unit',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$max$unit',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
