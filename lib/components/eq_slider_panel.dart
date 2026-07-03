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

class EqSliderPanel extends StatefulWidget {
  final List<IIREqualizerCoeffs> bands;
  final ValueChanged<List<IIREqualizerCoeffs>> onBandsChanged;
  final bool enabled;

  const EqSliderPanel({
    super.key,
    required this.bands,
    required this.onBandsChanged,
    this.enabled = true,
  });

  @override
  State<EqSliderPanel> createState() => _EqSliderPanelState();
}

class _EqSliderPanelState extends State<EqSliderPanel> {
  late List<IIREqualizerCoeffs> _bands;

  @override
  void initState() {
    super.initState();
    _bands = widget.bands
        .map((b) => IIREqualizerCoeffs(b.index, b.startFreq, b.endFreq, b.gain))
        .toList();
  }

  @override
  void didUpdateWidget(EqSliderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bands = widget.bands
        .map((b) => IIREqualizerCoeffs(b.index, b.startFreq, b.endFreq, b.gain))
        .toList();
  }

  static const _min = -12, _max = 12;

  void _onChanged(int i, double v) {
    final old = _bands[i];
    _bands[i] = IIREqualizerCoeffs(old.index, old.startFreq, old.endFreq, v.round());
    widget.onBandsChanged(List.from(_bands));
    setState(() {});
  }

  String _freq(int f) => f >= 1000
      ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k'
      : f.toString();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget panel = SingleChildScrollView(
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: g == 0
                      ? cs.onSurfaceVariant
                      : g > 0
                          ? cs.primary
                          : Colors.orange,
                ),
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

    if (!widget.enabled) {
      panel = Opacity(
        opacity: 0.3,
        child: IgnorePointer(ignoring: true, child: panel),
      );
    }

    return panel;
  }
}
