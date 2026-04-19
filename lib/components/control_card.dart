/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:wecho/components/neumorphic_description_dialog.dart';

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
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: isActive ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: isActive ? 0.15 : 0.08);

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            blurRadius: 15,
            offset: const Offset(-5, -5),
          ),
          BoxShadow(
            color: darkShadow,
            blurRadius: 15,
            offset: const Offset(5, 5),
          ),
        ],
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
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: isActive ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: isActive ? 0.15 : 0.08);

    return InkWell(
      onTap: onToggleExpand,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(20),
        bottom: const Radius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => NeumorphicDescriptionDialog.show(
                context: context,
                icon: icon,
                title: title,
                description: description,
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
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
                        ]
                      : [
                          BoxShadow(
                            color: darkShadow,
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSection(BuildContext context, ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: isActive ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: isActive ? 0.15 : 0.08);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                        divisions: (max - min).toInt(),
                        onChanged: onChanged,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$min$unit',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$max$unit',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
