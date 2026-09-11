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

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:wecho/l10n/app_localizations.dart';
import 'package:wecho/models/audio_config.dart';
import 'eq_biquad.dart';
import 'graphic_eq_painter.dart';
import 'neumorphic_selector.dart';

class _EqPreset {
  final String name;
  final double preamp;
  final List<Map<String, Object>> filters;
  const _EqPreset(this.name, this.filters, {this.preamp = 0.0});
}

class GraphicEqPanel extends StatefulWidget {
  final String config;
  final ValueChanged<String> onConfigChanged;
  final bool enabled;

  const GraphicEqPanel({
    super.key,
    required this.config,
    required this.onConfigChanged,
    this.enabled = true,
  });

  @override
  State<GraphicEqPanel> createState() => _GraphicEqPanelState();
}

class _GraphicEqPanelState extends State<GraphicEqPanel> {
  static const _sampleRate = 48000;
  static const _fMin = 20.0, _fMax = 20000.0;
  static const _plotPoints = 256;
  static const _dbMin = -18.0, _dbMax = 18.0;
  static const _gainMin = -12.0, _gainMax = 12.0;
  static const _qMin = 0.1, _qMax = 6.0;
  static const _bandMin = 1, _bandMax = 64;

  static const _presets = <_EqPreset>[
    _EqPreset('Flat', [
      {'type': 'pk', 'freq': 31, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 62, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 125, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 250, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 500, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 1000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 2000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 4000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 8000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 16000, 'q': 1.0, 'gain': 0.0},
    ]),
    _EqPreset('Bass Boost', [
      {'type': 'lsc', 'freq': 100, 'q': 1.0, 'gain': 6.0},
    ], preamp: -1.0),
    _EqPreset('Treble Boost', [
      {'type': 'hsc', 'freq': 6000, 'q': 1.0, 'gain': 6.0},
    ], preamp: -1.0),
    _EqPreset('Vocal', [
      {'type': 'pk', 'freq': 31, 'q': 1.0, 'gain': -2.0},
      {'type': 'pk', 'freq': 62, 'q': 1.0, 'gain': -1.0},
      {'type': 'pk', 'freq': 125, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 250, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 500, 'q': 1.0, 'gain': 4.0},
      {'type': 'pk', 'freq': 1000, 'q': 1.0, 'gain': 3.0},
      {'type': 'pk', 'freq': 2000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 4000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 8000, 'q': 1.0, 'gain': -1.0},
      {'type': 'pk', 'freq': 16000, 'q': 1.0, 'gain': -2.0},
    ]),
    _EqPreset('Rock', [
      {'type': 'pk', 'freq': 31, 'q': 1.0, 'gain': 4.0},
      {'type': 'pk', 'freq': 62, 'q': 1.0, 'gain': 3.0},
      {'type': 'pk', 'freq': 125, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 250, 'q': 1.0, 'gain': -1.0},
      {'type': 'pk', 'freq': 500, 'q': 1.0, 'gain': -2.0},
      {'type': 'pk', 'freq': 1000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 2000, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 4000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 8000, 'q': 1.0, 'gain': 3.0},
      {'type': 'pk', 'freq': 16000, 'q': 1.0, 'gain': 4.0},
    ]),
    _EqPreset('Pop', [
      {'type': 'pk', 'freq': 31, 'q': 1.0, 'gain': -1.0},
      {'type': 'pk', 'freq': 62, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 125, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 250, 'q': 1.0, 'gain': 4.0},
      {'type': 'pk', 'freq': 500, 'q': 1.0, 'gain': 3.0},
      {'type': 'pk', 'freq': 1000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 2000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 4000, 'q': 1.0, 'gain': -1.0},
      {'type': 'pk', 'freq': 8000, 'q': 1.0, 'gain': -1.0},
      {'type': 'pk', 'freq': 16000, 'q': 1.0, 'gain': -2.0},
    ]),
    _EqPreset('Jazz', [
      {'type': 'pk', 'freq': 31, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 62, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 125, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 250, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 500, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 1000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 2000, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 4000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 8000, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 16000, 'q': 1.0, 'gain': 2.0},
    ]),
    _EqPreset('Classical', [
      {'type': 'pk', 'freq': 31, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 62, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 125, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 250, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 500, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 1000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 2000, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 4000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 8000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 16000, 'q': 1.0, 'gain': 3.0},
    ]),
    _EqPreset('Electronic', [
      {'type': 'pk', 'freq': 31, 'q': 1.0, 'gain': 5.0},
      {'type': 'pk', 'freq': 62, 'q': 1.0, 'gain': 4.0},
      {'type': 'pk', 'freq': 125, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 250, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 500, 'q': 1.0, 'gain': -1.0},
      {'type': 'pk', 'freq': 1000, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 2000, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 4000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 8000, 'q': 1.0, 'gain': 4.0},
      {'type': 'pk', 'freq': 16000, 'q': 1.0, 'gain': 5.0},
    ], preamp: -1.0),
    _EqPreset('Acoustic', [
      {'type': 'pk', 'freq': 31, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 62, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 125, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 250, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 500, 'q': 1.0, 'gain': 0.0},
      {'type': 'pk', 'freq': 1000, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 2000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 4000, 'q': 1.0, 'gain': 2.0},
      {'type': 'pk', 'freq': 8000, 'q': 1.0, 'gain': 1.0},
      {'type': 'pk', 'freq': 16000, 'q': 1.0, 'gain': 1.0},
    ]),
  ];

  late IIREqualizerConfig _config;
  late List<double> _freqAxis;
  late final Map<String, String> _presetParamStrings;

  late String _lastConfigString;
  String _currentPresetName = 'Custom';
  int _selectedBand = 0;
  int _bandCount = 10;
  bool _locked = true;

  // Relative drag state.
  double _dragStartY = 0;
  List<double>? _baselineDb;

  @override
  void initState() {
    super.initState();
    _config = IIREqualizerConfig.fromParamString(widget.config);
    _lastConfigString = widget.config;
    _bandCount = _config.filters.length.clamp(_bandMin, _bandMax);
    _freqAxis = EqResponse.freqAxis(_fMin, _fMax, _plotPoints);
    _presetParamStrings = {
      for (final p in _presets) p.name: _presetToConfig(p).toParamString(),
    };
    _currentPresetName = _matchPreset(_lastConfigString);
  }

  @override
  void didUpdateWidget(GraphicEqPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.config != _lastConfigString) {
      _lastConfigString = widget.config;
      _config = IIREqualizerConfig.fromParamString(widget.config);
      _bandCount = _config.filters.length.clamp(_bandMin, _bandMax);
      if (_selectedBand >= _config.filters.length) {
        _selectedBand = (_config.filters.length - 1).clamp(0, _config.filters.length - 1);
      }
      _currentPresetName = _matchPreset(_lastConfigString);
    }
  }

  static IIREqualizerConfig _presetToConfig(_EqPreset p) {
    return IIREqualizerConfig(
      preamp: p.preamp,
      filters: p.filters
          .map((f) => EQFilter(
                enabled: true,
                type: EQFilterTypeX.fromLabel(f['type'] as String),
                fc: (f['freq'] as num).toInt(),
                gain: (f['gain'] as num).toDouble(),
                q: (f['q'] as num).toDouble(),
              ))
          .toList(),
    );
  }

  String _matchPreset(String configString) {
    for (final entry in _presetParamStrings.entries) {
      if (entry.value == configString) return entry.key;
    }
    return 'Custom';
  }

  void _emit(IIREqualizerConfig next) {
    _config = next;
    _lastConfigString = next.toParamString();
    _currentPresetName = _matchPreset(_lastConfigString);
    widget.onConfigChanged(_lastConfigString);
    setState(() {});
  }

  void _applyPreset(_EqPreset preset) {
    final config = _presetToConfig(preset);
    _bandCount = config.filters.length.clamp(_bandMin, _bandMax);
    _selectedBand = _selectedBand.clamp(0, config.filters.length - 1);
    _emit(config);
  }

  String? _responseCacheKey;
  List<double>? _responseCache;

  /// Cached frequency response, keyed by the current config string. Param
  /// changes produce a new List (so shouldRepaint still fires), while
  /// unrelated rebuilds reuse the previous instance and skip the repaint.
  List<double> get _responseDb {
    if (_responseCache != null && _responseCacheKey == _lastConfigString) {
      return _responseCache!;
    }
    _responseCache =
        EqResponse.responseDb(_config.filters, _config.preamp, _freqAxis, _sampleRate);
    _responseCacheKey = _lastConfigString;
    return _responseCache!;
  }

  void _applyBandCount(int n) {
    _bandCount = n;
    final logMin = math.log(_fMin);
    final logMax = math.log(_fMax);
    final filters = List.generate(n, (i) {
      final fc = (i == n - 1)
          ? _fMax.toInt()
          : math.exp(logMin + (logMax - logMin) * i / (n - 1)).round();
      return EQFilter(enabled: true, type: EQFilterType.pk, fc: fc, gain: 0, q: 1.0);
    });
    _selectedBand = _selectedBand.clamp(0, n - 1);
    _emit(_config.copyWith(filters: filters));
  }

  void _updateFilter(int i, EQFilter updated) {
    final filters = List<EQFilter>.from(_config.filters);
    filters[i] = updated;
    _emit(_config.copyWith(filters: filters));
  }

  void _sortBandsByFreq() {
    final filters = _config.filters;
    if (filters.length < 2) return;

    var sorted = true;
    for (var j = 1; j < filters.length; j++) {
      if (filters[j].fc < filters[j - 1].fc) {
        sorted = false;
        break;
      }
    }
    if (sorted) return;

    final selected = filters[_selectedBand.clamp(0, filters.length - 1)];
    final reordered = List<EQFilter>.from(filters)
      ..sort((a, b) => a.fc.compareTo(b.fc));
    _selectedBand = reordered.indexOf(selected);
    _emit(_config.copyWith(filters: reordered));
  }

  Future<void> _showValueDialog({
    required String title,
    required String initial,
    required String suffix,
    required double min,
    required double max,
    required ValueChanged<double> onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ValueEditDialog(
        title: title,
        initial: initial,
        suffix: suffix,
        rangeHint: '$min - $max',
      ),
    );
    if (confirmed == true && mounted) {
      final v = double.tryParse(_ValueEditDialog.lastInput.trim());
      if (v != null) onConfirm(v.clamp(min, max));
    }
  }

  void _addBand() {
    if (_config.filters.length >= _bandMax) return;
    final filters = List<EQFilter>.from(_config.filters);
    int newFc;
    if (filters.length >= 2) {
      final last = filters.last.fc.toDouble();
      final prev = filters[filters.length - 2].fc.toDouble();
      newFc = math.sqrt(last * prev).round();
    } else if (filters.isNotEmpty) {
      newFc = filters.last.fc;
    } else {
      newFc = 1000;
    }
    filters.add(EQFilter(
      enabled: true,
      type: EQFilterType.pk,
      fc: newFc.clamp(_fMin.toInt(), _fMax.toInt()),
      gain: 0,
      q: 1.0,
    ));
    _bandCount = filters.length;
    _selectedBand = filters.length - 1;
    _emit(_config.copyWith(filters: filters));
  }

  void _removeBand(int i) {
    if (_config.filters.length <= _bandMin) return;
    final filters = List<EQFilter>.from(_config.filters)..removeAt(i);
    _bandCount = filters.length;
    _selectedBand = _selectedBand.clamp(0, filters.length - 1);
    _emit(_config.copyWith(filters: filters));
  }

  int _xToFreqIndex(double dxInPlot, double plotW) {
    final t = (dxInPlot / plotW).clamp(0.0, 1.0);
    return (t * (_plotPoints - 1)).round();
  }

  void _onPointerDown(PointerDownEvent d, Size plotSize) {
    _dragStartY = d.localPosition.dy;
    _baselineDb = List<double>.from(_responseDb);
    // _applyRelativeFitting -> _emit already calls setState.
    _applyRelativeFitting(d.localPosition.dx, plotSize, 0.0);
  }

  void _onPointerMove(PointerMoveEvent d, Size plotSize) {
    final dbDelta = -((d.localPosition.dy - _dragStartY) / plotSize.height) * (_dbMax - _dbMin);
    // _applyRelativeFitting -> _emit already calls setState; an extra one here
    // just doubled the markNeedsBuild on every move event.
    _applyRelativeFitting(d.localPosition.dx, plotSize, dbDelta);
  }

  void _onPointerUp(PointerEvent _) {
    _baselineDb = null;
    setState(() {});
  }

  void _applyRelativeFitting(double dx, Size plotSize, double dbDelta) {
    final baseline = _baselineDb;
    if (baseline == null) return;

    final plotW = plotSize.width;
    final idx = _xToFreqIndex(dx - GraphicEqPainter.leftPad, plotW);

    final halfWin = math.max(1, (_plotPoints * 0.05).round());
    final loIdx = (idx - halfWin).clamp(0, _plotPoints - 1);
    final hiIdx = (idx + halfWin).clamp(0, _plotPoints - 1);

    final fLo = _freqAxis[loIdx];
    final fHi = _freqAxis[hiIdx];

    final movableFilters = <int>[];
    for (var j = 0; j < _config.filters.length; j++) {
      final fc = _config.filters[j].fc.toDouble();
      if (fc >= fLo && fc <= fHi) movableFilters.add(j);
    }

    if (movableFilters.isEmpty) {
      final centerF = math.sqrt(fLo * fHi);
      var bestJ = 0;
      var bestDist = double.infinity;
      for (var j = 0; j < _config.filters.length; j++) {
        final fc = _config.filters[j].fc.toDouble();
        final dist = (math.log(fc) - math.log(centerF)).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestJ = j;
        }
      }
      movableFilters.add(bestJ);
    }

    final targetFreqs = <double>[];
    final targetDb = <double>[];
    for (var i = loIdx; i <= hiIdx; i++) {
      targetFreqs.add(_freqAxis[i]);
      targetDb.add(baseline[i] + dbDelta);
    }

    final gains = EqLsqFit.fitGainsSubset(
      allFilters: _config.filters,
      movableIndices: movableFilters,
      freqs: targetFreqs,
      targetDb: targetDb,
      sampleRate: _sampleRate,
      q: 1.0,
    );

    final filters = <EQFilter>[];
    for (var j = 0; j < _config.filters.length; j++) {
      if (movableFilters.contains(j)) {
        filters.add(_config.filters[j].copyWith(
          gain: gains[j]!.clamp(_gainMin, _gainMax),
        ));
      } else {
        filters.add(_config.filters[j]);
      }
    }
    _emit(_config.copyWith(filters: filters));
  }

  String _freqLabel(int f) => f >= 1000
      ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k'
      : f.toString();

  String _fmtGain(double g) =>
      g == 0 ? '0' : (g > 0 ? '+${g.toStringAsFixed(1)}' : g.toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    Widget panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPresetSelector(cs, l10n),
        const SizedBox(height: 8),
        _buildBandCountRow(cs),
        const SizedBox(height: 8),
        _buildPreampSlider(cs),
        const SizedBox(height: 4),
        _buildPlot(cs),
        const SizedBox(height: 12),
        _buildBandTabs(cs),
        const SizedBox(height: 8),
        _buildBandEditor(cs),
      ],
    );

    if (!widget.enabled) {
      panel = Opacity(
        opacity: 0.3,
        child: IgnorePointer(ignoring: true, child: panel),
      );
    }

    return panel;
  }

  String _presetDisplayName(String name, AppLocalizations l10n) {
    switch (name) {
      case 'Flat':
        return l10n.presetFlat;
      case 'Bass Boost':
        return l10n.presetBassBoost;
      case 'Treble Boost':
        return l10n.presetTrebleBoost;
      case 'Vocal':
        return l10n.presetVocal;
      case 'Rock':
        return l10n.presetRock;
      case 'Pop':
        return l10n.presetPop;
      case 'Jazz':
        return l10n.presetJazz;
      case 'Classical':
        return l10n.presetClassical;
      case 'Electronic':
        return l10n.presetElectronic;
      case 'Acoustic':
        return l10n.presetAcoustic;
      default:
        return l10n.presetCustom;
    }
  }

  Widget _buildPresetSelector(ColorScheme cs, AppLocalizations l10n) {
    final isCustom = _currentPresetName == 'Custom';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(l10n.presetLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: NeumorphicSelector<String>(
              items: _presets
                  .map((p) => SelectorItem(
                        value: p.name,
                        label: _presetDisplayName(p.name, l10n),
                      ))
                  .toList(),
              selectedValue: isCustom ? null : _currentPresetName,
              onSelect: (name) {
                final preset = _presets.firstWhere((p) => p.name == name);
                _applyPreset(preset);
              },
              enabled: widget.enabled,
              hint: _presetDisplayName('Custom', l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreampSlider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _buildSliderRow(
        cs: cs,
        label: 'Preamp',
        valueText: '${_fmtGain(_config.preamp)} dB',
        value: _config.preamp,
        min: _dbMin,
        max: _dbMax,
        divisions: ((_dbMax - _dbMin) * 2).round(),
        color: cs.secondary,
        onChanged: (v) => _emit(_config.copyWith(preamp: v)),
      ),
    );
  }

  Widget _buildBandCountRow(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text('Bands',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: TextFormField(
              // Key forces the field to rebuild with the latest band count
              // when a preset with a different band count is applied.
              key: ValueKey('bandCount-$_bandCount'),
              initialValue: _bandCount.toString(),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: const OutlineInputBorder(),
              ),
              onFieldSubmitted: (v) {
                final n = int.tryParse(v);
                if (n != null) {
                  final clamped = n.clamp(_bandMin, _bandMax);
                  if (clamped != _config.filters.length) {
                    _applyBandCount(clamped);
                  } else {
                    setState(() {}); // revert to current
                  }
                } else {
                  setState(() {}); // invalid input, revert
                }
              },
            ),
          ),
          const Spacer(),
          // Reset to flat config for the current band count.
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: 'Reset',
            onPressed: () => _applyBandCount(_bandCount),
            icon: Icon(Icons.refresh, color: cs.onSurfaceVariant),
          ),
          // Lock drawing to prevent accidental edits.
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: _locked ? 'Unlock' : 'Lock',
            onPressed: () => setState(() => _locked = !_locked),
            icon: Icon(
              _locked ? Icons.lock : Icons.lock_open,
              color: _locked ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlot(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 200);

        final plotSize = Size(
          size.width - GraphicEqPainter.leftPad - GraphicEqPainter.rightPad,
          size.height - GraphicEqPainter.topPad - GraphicEqPainter.bottomPad,
        );

        Widget plot = RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              () => EagerGestureRecognizer(),
              (_) {},
            ),
          },
          child: Listener(
            onPointerDown: (d) => _onPointerDown(d, plotSize),
            onPointerMove: (d) => _onPointerMove(d, plotSize),
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerUp,
            child: Container(
              height: size.height,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // Isolate the curve's paint layer so unrelated panel rebuilds
                // (polling, theme) don't re-rasterize the plot.
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: GraphicEqPainter(
                      responseDb: _responseDb,
                      freqCount: _plotPoints,
                      dbMin: _dbMin,
                      dbMax: _dbMax,
                      gridColor: cs.outlineVariant,
                      curveColor: cs.primary,
                      textColor: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        if (_locked) {
          plot = IgnorePointer(ignoring: true, child: plot);
        }
        return plot;
      },
    );
  }

  Widget _buildBandTabs(ColorScheme cs) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _config.filters.length + 1,
        itemBuilder: (context, i) {
          // Trailing "+" tab: append a new band.
          if (i == _config.filters.length) {
            final reached = _config.filters.length >= _bandMax;
            return GestureDetector(
              onTap: reached ? null : _addBand,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: reached
                        ? cs.outlineVariant
                        : cs.primary.withValues(alpha: 0.5),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: reached
                      ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                      : cs.primary,
                ),
              ),
            );
          }
          final f = _config.filters[i];
          final selected = i == _selectedBand;
          return GestureDetector(
            onTap: () => setState(() => _selectedBand = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: selected ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(
                _freqLabel(f.fc),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBandEditor(ColorScheme cs) {
    if (_config.filters.isEmpty) return const SizedBox.shrink();
    final i = _selectedBand.clamp(0, _config.filters.length - 1);
    final f = _config.filters[i];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter type selector + band label + delete button.
          Row(
            children: [
              Text('Band ${i + 1}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const Spacer(),
              SizedBox(
                height: 32,
                child: DropdownButton<EQFilterType>(
                  value: f.type,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w600),
                  items: EQFilterType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (t) {
                    if (t != null) _updateFilter(i, f.copyWith(type: t));
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Red circular close button: delete this band.
              // Disabled at the band minimum to prevent emptying the list.
              GestureDetector(
                onTap: _config.filters.length <= _bandMin
                    ? null
                    : () => _removeBand(i),
                child: Opacity(
                  opacity: _config.filters.length <= _bandMin ? 0.3 : 1,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: cs.onError,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Freq slider (log scale 20-20000). Tapping the label/value opens
          // a numeric edit dialog; releasing the slider re-sorts the tabs.
          _buildSliderRow(
            cs: cs,
            label: 'Freq',
            valueText: '${f.fc} Hz',
            value: _freqToSlider(f.fc.toDouble()),
            min: 0.0,
            max: 1.0,
            divisions: _plotPoints - 1,
            color: cs.secondary,
            onChanged: (v) => _updateFilter(i, f.copyWith(fc: _sliderToFreq(v).round())),
            onChangeEnd: (_) => _sortBandsByFreq(),
            onLabelTap: () => _showValueDialog(
              title: 'Freq',
              initial: f.fc.toString(),
              suffix: ' Hz',
              min: _fMin,
              max: _fMax,
              onConfirm: (v) {
                _updateFilter(i, f.copyWith(fc: v.round()));
                _sortBandsByFreq();
              },
            ),
          ),

          _buildSliderRow(
            cs: cs,
            label: 'Gain',
            valueText: _fmtGain(f.gain),
            value: f.gain,
            min: _gainMin,
            max: _gainMax,
            divisions: ((_gainMax - _gainMin) * 10).round(),
            color: cs.primary,
            onChanged: (v) => _updateFilter(i, f.copyWith(gain: v)),
            onLabelTap: () => _showValueDialog(
              title: 'Gain',
              initial: f.gain.toStringAsFixed(1),
              suffix: ' dB',
              min: _gainMin,
              max: _gainMax,
              onConfirm: (v) => _updateFilter(i, f.copyWith(gain: v)),
            ),
          ),
          _buildSliderRow(
            cs: cs,
            label: 'Q',
            valueText: f.q.toStringAsFixed(2),
            value: f.q,
            min: _qMin,
            max: _qMax,
            divisions: ((_qMax - _qMin) * 10).round(),
            color: cs.tertiary,
            onChanged: (v) => _updateFilter(i, f.copyWith(q: v)),
            onLabelTap: () => _showValueDialog(
              title: 'Q',
              initial: f.q.toStringAsFixed(2),
              suffix: '',
              min: _qMin,
              max: _qMax,
              onConfirm: (v) => _updateFilter(i, f.copyWith(q: v)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required ColorScheme cs,
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    VoidCallback? onLabelTap,
  }) {
    Widget leading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ),
        SizedBox(
          width: 56,
          child: Text(valueText,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
    if (onLabelTap != null) {
      leading = GestureDetector(
        onTap: onLabelTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: leading),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          leading,
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: widget.enabled ? onChanged : null,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Log-scale freq <-> 0..1 slider mapping.
  static double _freqToSlider(double freq) {
    final t = (math.log(freq) - math.log(_fMin)) / (math.log(_fMax) - math.log(_fMin));
    return t.clamp(0.0, 1.0);
  }

  static double _sliderToFreq(double t) {
    return math.exp(math.log(_fMin) + t * (math.log(_fMax) - math.log(_fMin)));
  }
}

class _ValueEditDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String suffix;
  final String rangeHint;

  static String lastInput = '';

  const _ValueEditDialog({
    required this.title,
    required this.initial,
    required this.suffix,
    required this.rangeHint,
  });

  @override
  State<_ValueEditDialog> createState() => _ValueEditDialogState();
}

class _ValueEditDialogState extends State<_ValueEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx, bool confirmed) {
    if (confirmed) {
      _ValueEditDialog.lastInput = _controller.text;
    }
    Navigator.of(ctx).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          suffixText: widget.suffix,
          hintText: widget.rangeHint,
        ),
        onSubmitted: (_) => _submit(context, true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _submit(context, true),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
