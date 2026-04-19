/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:wecho/components/neumorphic_description_dialog.dart';

class MultiSliderControlCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onToggle;
  final List<SliderConfig> sliders;

  const MultiSliderControlCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggle,
    required this.sliders,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: enabled ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: enabled ? 0.15 : 0.08);

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
          _buildSlidersSection(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: enabled ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: enabled ? 0.15 : 0.08);

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
                  boxShadow: enabled
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
                  color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
                    sliders.first.valueText,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeThumbColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlidersSection(BuildContext context, ColorScheme colorScheme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: sliders.map((slider) => _buildSlider(context, colorScheme, slider)).toList(),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSlider(BuildContext context, ColorScheme colorScheme, SliderConfig slider) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: enabled ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: enabled ? 0.15 : 0.08);

    return Column(
      children: [
        if (slider.label.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slider.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                slider.valueText,
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
              value: slider.value,
              min: slider.min,
              max: slider.max,
              divisions: slider.divisions,
              onChanged: enabled ? slider.onChanged : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slider.minLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Text(
                slider.maxLabel,
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

class SliderConfig {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String minLabel;
  final String maxLabel;
  final int decimalPlaces;

  SliderConfig({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.divisions,
    required this.onChanged,
    String? minLabel,
    String? maxLabel,
    this.decimalPlaces = 2,
  })  : minLabel = minLabel ?? '$min$unit',
        maxLabel = maxLabel ?? '$max$unit';

  String get valueText => '${value.toStringAsFixed(decimalPlaces)}$unit';
}
