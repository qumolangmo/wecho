/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:wecho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.outlineVariant.withOpacity(0.2),
        ),
        boxShadow: enabled
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
          _buildSlidersSection(context, colorScheme),
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
                  color: enabled
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.primaryContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
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
              activeColor: colorScheme.primary,
            ),
            const SizedBox(width: 8),
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
            value: slider.value,
            min: slider.min,
            max: slider.max,
            divisions: slider.divisions,
            onChanged: enabled ? slider.onChanged : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slider.minLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              Text(
                slider.maxLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
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
