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

  void _showInputDialog(BuildContext context) {
    final controller = TextEditingController(text: value.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('输入$title'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          autofocus: true,
          decoration: InputDecoration(
            hintText: '范围: $min ~ $max',
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v >= min && v <= max) {
                onChanged(v);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 深色主题下卡片背景叠加2%透明灰
    final baseColor = isDark
        ? Color.alphaBlend(Colors.grey.withValues(alpha: 0.02), colorScheme.surface)
        : colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: isActive ? 0.7 : 0.4);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: isActive ? 0.15 : 0.08);

    // 深色主题下未启用卡片添加轮廓线，颜色比背景深20%
    final Border? cardBorder = (isDark && !isActive)
        ? Border.all(
            color: Color.lerp(baseColor, Colors.black, 0.2)!,
            width: 1.0,
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        border: cardBorder,
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            blurRadius: 15,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: darkShadow,
            blurRadius: 15,
            offset: const Offset(0, 0),
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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: lightShadow,
                            blurRadius: 8,
                            offset: const Offset(0, 0),
                          ),
                          BoxShadow(
                            color: darkShadow,
                            blurRadius: 8,
                            offset: const Offset(0, 0),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: darkShadow,
                            blurRadius: 6,
                            offset: const Offset(0, 0),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
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
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _showInputDialog(context),
                        child: Text(
                          '${value.toStringAsFixed(1)}$unit',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
