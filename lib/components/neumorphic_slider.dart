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
import 'package:wecho/l10n/app_localizations.dart';

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
class NeumorphicSlider extends StatefulWidget {
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

  /// Whether to show a divider line below the slider.
  final bool showDivider;

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
    this.showDivider = true,
  })  : minLabel = minLabel ?? '$min$unit',
        maxLabel = maxLabel ?? '$max$unit';

  String get valueText =>
      '${value.toStringAsFixed(decimalPlaces)}$unit';

  @override
  State<NeumorphicSlider> createState() => _NeumorphicSliderState();
}

class _NeumorphicSliderState extends State<NeumorphicSlider> {
  /* Value of an in-flight drag. While it is set, the thumb and the value
   * text render from it directly, so a drag stays smooth at 60 fps even
   * when the owning page throttles (or suspends) rebuilds - the custom UI
   * host rebuilds its whole interpreted tree per state change and would
   * otherwise lag the thumb by the rebuild gap. Once the incoming value
   * catches up with the last drag value, the prop takes over again.
   */
  double? _dragValue;

  @override
  void didUpdateWidget(NeumorphicSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragValue != null && widget.value == _dragValue) {
      _dragValue = null;
    }
  }

  void _showInputDialog() {
    final l10n = AppLocalizations.of(context)!;
    final value = _dragValue ?? widget.value;
    final controller =
        TextEditingController(text: value.toStringAsFixed(widget.decimalPlaces));
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.label.isNotEmpty
            ? '${l10n.input}${widget.label}'
            : l10n.input),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          autofocus: true,
          decoration: InputDecoration(
            hintText: '${l10n.range}: ${widget.min} ~ ${widget.max}',
            suffixText: widget.unit,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v >= widget.min && v <= widget.max) {
                widget.onChanged?.call(v);
                Navigator.pop(dialogContext);
              }
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = _dragValue ?? widget.value;

    return Column(
      children: [
        if (widget.label.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
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
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: Slider(
                  value: value,
                  min: widget.min,
                  max: widget.max,
                  divisions: ((widget.divisions ?? 0) > 0 ? widget.divisions : null),
                  onChanged: widget.enabled
                      ? (v) {
                          setState(() => _dragValue = v);
                          widget.onChanged?.call(v);
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: widget.enabled ? _showInputDialog : null,
              child: Text(
                '${value.toStringAsFixed(widget.decimalPlaces)}${widget.unit}',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        if (widget.showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}
