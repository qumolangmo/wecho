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
import 'package:wecho/models/audio_config.dart';
import 'package:wecho/components/neumorphic_description_dialog.dart';

class EqualizerControlCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final List<IIREqualizerCoeffs> bands;
  final ValueChanged<bool> onToggle;
  final ValueChanged<List<IIREqualizerCoeffs>> onBandsChanged;

  const EqualizerControlCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.expanded,
    required this.onToggleExpand,
    required this.bands,
    required this.onToggle,
    required this.onBandsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surface;
    final light = base.withRed(255).withGreen(255).withBlue(255)
        .withValues(alpha: enabled ? 0.7 : 0.4);
    final dark = base.withRed(0).withGreen(0).withBlue(0)
        .withValues(alpha: enabled ? 0.15 : 0.08);

    return Container(
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: light, blurRadius: 15, offset: const Offset(-5, -5)),
          BoxShadow(color: dark, blurRadius: 15, offset: const Offset(5, 5)),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, cs, base, light, dark),
          _buildContent(cs, base, light, dark),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, Color base,
      Color light, Color dark) {
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
                  color: base,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: enabled
                      ? [
                          BoxShadow(color: light, blurRadius: 8,
                              offset: const Offset(-3, -3)),
                          BoxShadow(color: dark, blurRadius: 8,
                              offset: const Offset(3, 3)),
                        ]
                      : [BoxShadow(color: dark, blurRadius: 6,
                          offset: const Offset(2, 2))],
                ),
                child: Icon(icon,
                    color: enabled ? cs.primary : cs.onSurfaceVariant,
                    size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? cs.onSurface
                              : cs.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(value: enabled, onChanged: onToggle,
                activeThumbColor: cs.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, Color base, Color light, Color dark) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Opacity(
                opacity: enabled ? 1.0 : 0.3,
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: _EqSliderPanel(
                    bands: bands,
                    onBandsChanged: onBandsChanged,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _EqSliderPanel extends StatefulWidget {
  final List<IIREqualizerCoeffs> bands;
  final ValueChanged<List<IIREqualizerCoeffs>> onBandsChanged;

  const _EqSliderPanel({
    required this.bands,
    required this.onBandsChanged,
  });

  @override
  State<_EqSliderPanel> createState() => _EqSliderPanelState();
}

class _EqSliderPanelState extends State<_EqSliderPanel> {
  late List<IIREqualizerCoeffs> _bands;

  @override
  void initState() {
    super.initState();
    _bands = widget.bands.map((b) => IIREqualizerCoeffs(
        b.index, b.startFreq, b.endFreq, b.gain)).toList();
  }

  @override
  void didUpdateWidget(_EqSliderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from parent when bands change externally
    _bands = widget.bands.map((b) => IIREqualizerCoeffs(
        b.index, b.startFreq, b.endFreq, b.gain)).toList();
  }

  static const _min = -15, _max = 15;

  void _onChanged(int i, double v) {
    final old = _bands[i];
    _bands[i] = IIREqualizerCoeffs(
        old.index, old.startFreq, old.endFreq, v.round());
    widget.onBandsChanged(List.from(_bands));
    setState(() {});
  }

  String _freq(int f) => f >= 1000
      ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k'
      : f.toString();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_bands.length, (i) {
          final b = _bands[i];
          final g = b.gain;
          return SizedBox(
            width: 52,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                g > 0 ? '+$g' : '$g',
                style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: g == 0
                        ? cs.onSurfaceVariant
                        : g > 0
                            ? cs.primary
                            : Colors.orange),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: cs.primary,
                      inactiveTrackColor: cs.surfaceContainerHighest,
                      thumbColor: cs.primary,
                      overlayColor: cs.primary.withValues(alpha: 0.1),
                      trackHeight: 6,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: g.toDouble(),
                      min: _min.toDouble(),
                      max: _max.toDouble(),
                      divisions: _max - _min,
                      onChanged: (v) => _onChanged(i, v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(_freq(b.startFreq),
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center, maxLines: 1),
              Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 20,
                  height: 1,
                  color: cs.outlineVariant),
            ]),
          );
        }),
      ),
    );
  }
}
