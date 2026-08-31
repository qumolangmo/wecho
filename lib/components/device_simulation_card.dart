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

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/audio_config.dart';
import '../styles/neumorphic_styles.dart';
import '../view_models/dsp_controller_view_model.dart';
import 'graphic_eq_painter.dart';
import 'neumorphic_button.dart';

/// A device entry parsed from index.tsv (tab separated: name/filepath/source/rig/type/channels).
class DeviceEntry {
  final String name;
  final String filepath;
  final String source;
  final String rig;
  final String type;
  final String channels;

  const DeviceEntry({
    required this.name,
    required this.filepath,
    required this.source,
    required this.rig,
    required this.type,
    required this.channels,
  });
}

class DeviceSimulationCard extends StatefulWidget {
  final DSPControllerViewModel viewModel;

  const DeviceSimulationCard({super.key, required this.viewModel});

  @override
  State<DeviceSimulationCard> createState() => _DeviceSimulationCardState();
}

class _DeviceSimulationCardState extends State<DeviceSimulationCard> {
  static const _sampleRate = 48000.0;
  static const _fMin = 20.0, _fMax = 20000.0;
  static const _plotPoints = 256;
  static const _dbMin = -24.0, _dbMax = 24.0;

  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final FocusNode _currentFocus = FocusNode();
  final FocusNode _targetFocus = FocusNode();
  final ScrollController _currentScroll = ScrollController();
  final ScrollController _targetScroll = ScrollController();

  /// Marquee: when a headphone name overflows the field, slowly scroll it
  /// in a loop, starting 5s after the input settles (no edit, no focus).
  Timer? _marqueeIdleTimer;
  Timer? _marqueeTick;
  DateTime? _marqueePauseUntil;
  bool _marqueePauseAtStart = false;

  List<DeviceEntry> _index = const [];
  bool _indexLoaded = false;
  bool _indexError = false;

  bool _targetUnlocked = false;
  bool _loading = false;

  /// Actual IR response (dB) resampled to the log frequency axis, or null.
  List<double>? _responseDb;

  @override
  void initState() {
    super.initState();
    _loadIndex();
    _currentFocus.addListener(_onFocusChanged);
    _targetFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _marqueeIdleTimer?.cancel();
    _marqueeTick?.cancel();
    _currentController.dispose();
    _targetController.dispose();
    _currentFocus.dispose();
    _targetFocus.dispose();
    _currentScroll.dispose();
    _targetScroll.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_currentFocus.hasFocus || _targetFocus.hasFocus) {
      _resetMarquee(restart: false);
    } else {
      _resetMarquee();
    }
  }

  void _resetMarquee({bool restart = true}) {
    _marqueeTick?.cancel();
    _marqueeTick = null;
    _marqueeIdleTimer?.cancel();
    _marqueeIdleTimer = null;
    _marqueePauseUntil = null;
    _marqueePauseAtStart = false;
    if (restart) {
      _marqueeIdleTimer = Timer(const Duration(seconds: 2), _startMarquee);
    }
  }

  void _startMarquee() {
    const pause = Duration(seconds: 2);
    _marqueeTick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final now = DateTime.now();
      final controllers = [_currentScroll, _targetScroll]
          .where((sc) => sc.hasClients && sc.position.maxScrollExtent > 0)
          .toList();
      if (controllers.isEmpty) return;

      if (_marqueePauseUntil != null) {
        if (now.isBefore(_marqueePauseUntil!)) return;
        // Pause just elapsed.
        if (!_marqueePauseAtStart) {
          // Was holding at the end: snap back to 0 and hold there.
          _marqueePauseAtStart = true;
          _marqueePauseUntil = now.add(pause);
          for (final sc in controllers) {
            sc.jumpTo(0.0);
          }
        } else {
          // Was holding at the start: resume scrolling.
          _marqueePauseAtStart = false;
          _marqueePauseUntil = null;
        }
        return;
      }

      var allAtEnd = true;
      for (final sc in controllers) {
        final pos = sc.position;
        final next = pos.pixels + 0.5; // ~10 px/s, slow.
        if (next < pos.maxScrollExtent) {
          sc.jumpTo(next);
          allAtEnd = false;
        } else if (pos.pixels < pos.maxScrollExtent) {
          sc.jumpTo(pos.maxScrollExtent);
        }
      }
      if (allAtEnd) {
        // Hold at the end before looping back.
        _marqueePauseAtStart = false;
        _marqueePauseUntil = now.add(pause);
      }
    });
  }

  Future<void> _loadIndex() async {
    try {
      final content = await widget.viewModel.readAssetFile('output_csv/index.tsv');
      if (content == null) {
        if (mounted) setState(() => _indexError = true);
        return;
      }
      final entries = <DeviceEntry>[];
      final lines = content.split('\n');
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trimRight();
        if (line.trim().isEmpty) continue;
        final parts = line.split('\t');
        if (parts.length < 6) continue;
        entries.add(DeviceEntry(
          name: parts[0],
          filepath: parts[1],
          source: parts[2],
          rig: parts[3],
          type: parts[4],
          channels: parts[5],
        ));
      }
      if (!mounted) return;
      setState(() {
        _index = entries;
        _indexLoaded = true;
      });
      _prefillFromSaved();
    } catch (e) {
      debugPrint('DeviceSimulationCard load index failed: $e');
      if (mounted) setState(() => _indexError = true);
    }
  }

  Future<void> _prefillFromSaved() async {
    await widget.viewModel.settingsLoaded;
    if (!mounted) return;

    final savedConfig = widget.viewModel.get<String>(ParamID.deviceSimulationEffectConfig);
    final newline = savedConfig.indexOf('\n');
    final self = newline < 0 ? savedConfig : savedConfig.substring(0, newline);
    final target = newline < 0 ? '' : savedConfig.substring(newline + 1);

    DeviceEntry? find(String p) {
      if (p.isEmpty) return null;
      for (final e in _index) {
        if (p == e.filepath ||
            p == 'output_csv/${e.filepath}' ||
            p.endsWith('/output_csv/${e.filepath}') ||
            p.endsWith('\\output_csv\\${e.filepath}')) {
          return e;
        }
      }
      return null;
    }

    final selfEntry = find(self);
    final targetEntry = find(target);
    setState(() {
      if (selfEntry != null) {
        _currentController.text = selfEntry.name;
      }
      if (targetEntry != null) {
        _targetController.text = targetEntry.name;
      }
    });
    _resetMarquee();

    if (selfEntry != null) {
      await _refreshResponse();
    }
  }

  DeviceEntry? _exactMatch(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    for (final e in _index) {
      if (e.name == t) return e;
    }
    return null;
  }

  DeviceEntry? get _currentMatch => _exactMatch(_currentController.text);
  DeviceEntry? get _targetMatch => _exactMatch(_targetController.text);

  bool get _fieldsEnabled => _indexLoaded;

  bool get _targetInvalid {
    final text = _targetController.text.trim();
    if (text.isEmpty) return false;
    final match = _exactMatch(text);
    if (match == null) return true;
    final current = _currentMatch;
    if (current != null && !_targetUnlocked) {
      return !(match.rig == current.rig && match.type == current.type);
    }
    return false;
  }

  bool get _canLoad =>
      _currentMatch != null &&
      (_targetController.text.trim().isEmpty || !_targetInvalid);

  List<DeviceEntry> _currentCandidates() {
    final q = _currentController.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _index
        .where((e) => e.name.toLowerCase().contains(q))
        .take(10)
        .toList();
  }

  bool _isSameRigType(DeviceEntry a, DeviceEntry b) =>
      a.rig == b.rig && a.type == b.type;

  List<DeviceEntry> _targetCandidates(bool matching) {
    final q = _targetController.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final current = _currentMatch;
    if (current == null) {
      return _index
          .where((e) => e.name.toLowerCase().contains(q))
          .take(10)
          .toList();
    }
    return _index
        .where((e) =>
            e.name.toLowerCase().contains(q) &&
            (matching ? _isSameRigType(e, current) : !_isSameRigType(e, current)))
        .take(10)
        .toList();
  }

  bool get _showSelfCandidates =>
      _fieldsEnabled &&
      _currentFocus.hasFocus &&
      _currentController.text.trim().isNotEmpty &&
      _currentMatch == null &&
      _currentCandidates().isNotEmpty;

  bool get _showTargetCandidates {
    if (!_fieldsEnabled || !_targetFocus.hasFocus) return false;
    final text = _targetController.text.trim();
    if (text.isEmpty || _targetMatch != null) return false;
    if (_currentMatch == null) return _targetCandidates(true).isNotEmpty;
    if (_targetCandidates(true).isNotEmpty) return true;
    return _targetUnlocked && _targetCandidates(false).isNotEmpty;
  }

  void _onCurrentChanged(String value) {
    final text = value.trim();
    setState(() {
      if (text.isEmpty) {
        // current headphone cleared: force clear simulate headphone too.
        _targetUnlocked = false;
        _targetController.clear();
      }
    });
    _resetMarquee();
  }

  void _onTargetChanged(String value) {
    setState(() {});
    _resetMarquee();
  }

  void _selectSelf(DeviceEntry e) {
    _currentController.text = e.name;
    _currentController.selection = TextSelection.collapsed(offset: e.name.length);
    setState(() {});
    _resetMarquee();
  }

  void _selectTarget(DeviceEntry e) {
    _targetController.text = e.name;
    _targetController.selection = TextSelection.collapsed(offset: e.name.length);
    setState(() {});
    _resetMarquee();
  }

  void _onRandomTarget() {
    final current = _currentMatch;
    if (current == null) return;

    final pool = _index
        .where((e) =>
            e != current &&
            (_targetUnlocked || _isSameRigType(e, current)))
        .toList();
    if (pool.isEmpty) return;

    _selectTarget(pool[Random().nextInt(pool.length)]);
  }

  Future<void> _onLoad() async {
    final self = _currentMatch;
    if (self == null) return;
    final target = _targetMatch;
    setState(() => _loading = true);

    try {
      final config = target == null
          ? 'output_csv/${self.filepath}'
          : 'output_csv/${self.filepath}\noutput_csv/${target.filepath}';
      await widget.viewModel.update(ParamID.deviceSimulationEffectConfig, config);
      await _refreshResponse();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshResponse() async {
    final bins = await widget.viewModel.getDeviceSimulationFreqResponse();
    if (!mounted) return;
    setState(() => _responseDb = _resampleResponse(bins));
  }

  List<double>? _resampleResponse(List<double>? bins) {
    if (bins == null || bins.length < 2) return null;

    final nyquist = _sampleRate / 2;
    final binHz = nyquist / (bins.length - 1);
    final logMin = log(_fMin);
    final logMax = log(_fMax);

    return List.generate(_plotPoints, (i) {
      final f = exp(logMin + (logMax - logMin) * i / (_plotPoints - 1));
      final pos = f / binHz;
      final i0 = pos.floor().clamp(0, bins.length - 1);
      final i1 = (i0 + 1).clamp(0, bins.length - 1);
      final t = pos - i0;
      return bins[i0] * (1 - t) + bins[i1] * t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final targetDisabled = _currentController.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_indexError)
          _buildStatusText("索引加载失败", colorScheme.error)
        else if (!_indexLoaded)
          _buildStatusText("加载中...", colorScheme.onSurfaceVariant)
        else ...[
          const SizedBox(height: 4),
          // 当前耳机（上下堆叠）
          _buildDeviceField(
            label: "当前耳机",
            hint: "输入当前使用的耳机型号",
            controller: _currentController,
            focusNode: _currentFocus,
            scrollController: _currentScroll,
            enabled: _fieldsEnabled,
            isCurrent: true,
            onChanged: _onCurrentChanged,
            candidateSections: [
              if (_showSelfCandidates)
                _buildCandidateSection(_currentCandidates(),
                    query: _currentController.text.trim(),
                    onSelect: _selectSelf),
            ],
          ),
          const SizedBox(height: 12),
          // 模拟耳机（上下堆叠）
          _buildDeviceField(
            label: "模拟耳机",
            hint: "输入要模拟的耳机型号",
            controller: _targetController,
            focusNode: _targetFocus,
            scrollController: _targetScroll,
            enabled: _fieldsEnabled && !targetDisabled,
            isCurrent: false,
            onChanged: _onTargetChanged,
            candidateSections: _showTargetCandidates
                ? [
                    if (_targetCandidates(true).isNotEmpty)
                      _buildCandidateSection(
                          _targetCandidates(true),
                          query: _targetController.text.trim(),
                          onSelect: _selectTarget),
                    if (_targetUnlocked && _targetCandidates(false).isNotEmpty)
                      _buildCandidateSection(
                          _targetCandidates(false),
                          query: _targetController.text.trim(),
                          label: "无法完美模拟（不同类型）",
                          onSelect: _selectTarget),
                  ]
                : const [],
          ),
          const SizedBox(height: 12),
          // 底部按钮：解锁不完美模拟独占一行，随机模拟+加载放一行
          _buildUnlockButton(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildRandomButton()),
              const SizedBox(width: 8),
              Expanded(child: NeumorphicButton(
                  onTap: _canLoad ? _onLoad : null,
                  enabled: _canLoad,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  children: [
                    const Spacer(),
                    if (_loading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    else
                      Icon(Icons.download,
                          color: _canLoad ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "加载",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _canLoad ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
          
          if (_responseDb != null) ...[
            const SizedBox(height: 12),
            Text(
              "实际频响曲线",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: GraphicEqPainter(
                    responseDb: _responseDb!,
                    freqCount: _plotPoints,
                    dbMin: _dbMin,
                    dbMax: _dbMax,
                    gridColor: colorScheme.outlineVariant,
                    curveColor: colorScheme.primary,
                    textColor: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildStatusText(String message, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message, style: TextStyle(fontSize: 13, color: color)),
    );
  }

  Widget _buildDeviceField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ScrollController scrollController,
    required bool enabled,
    required bool isCurrent,
    required ValueChanged<String> onChanged,
    required List<Widget> candidateSections,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;
    // 清除按钮颜色：当前耳机用红色，模拟耳机未激活时用深棕色
    final clearColor = isCurrent
        ? colorScheme.error
        : (enabled ? colorScheme.error : Color.lerp(baseColor, Colors.black, 0.35)!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: NeumorphicStyles.innerNeumorphicDecoration(baseColor, enabled: enabled),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            scrollController: scrollController,
            enabled: enabled,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 14,
              color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: enabled && controller.text.isNotEmpty
                        ? () {
                            controller.clear();
                            onChanged('');
                          }
                        : null,
                    child: Opacity(
                      opacity: enabled ? 1 : 0.5,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: clearColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colorScheme.onError,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 28,
                maxWidth: 28,
                minHeight: 28,
                maxHeight: 28,
              ),
            ),
          ),
        ),
        ...candidateSections,
      ],
    );
  }

  Widget _buildCandidateSection(
    List<DeviceEntry> entries, {
    String? label,
    required String query,
    required ValueChanged<DeviceEntry> onSelect,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;
    final scrollController = ScrollController();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
        boxShadow: NeumorphicStyles.smallNeumorphicShadow(baseColor),
      ),
      // 限制最大高度，超出后显示滚动条
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          radius: const Radius.circular(4),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (label != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                for (var i = 0; i < entries.length; i++)
                  InkWell(
                    onTap: () => onSelect(entries[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: i < entries.length - 1
                          ? BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                            )
                          : null,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildHighlightedText(
                              entries[i].name,
                              query,
                              colorScheme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String name, String query, ColorScheme cs) {
    if (query.isEmpty) {
      return Text(
        name,
        style: TextStyle(fontSize: 14, color: cs.onSurface),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final lower = name.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(
        name,
        style: TextStyle(fontSize: 14, color: cs.onSurface),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: cs.onSurface),
        children: [
          if (idx > 0) TextSpan(text: name.substring(0, idx)),
          TextSpan(
            text: name.substring(idx, idx + query.length),
            style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
          ),
          if (idx + query.length < name.length)
            TextSpan(text: name.substring(idx + query.length)),
        ],
      ),
    );
  }

  Widget _buildUnlockButton() {
    final colorScheme = Theme.of(context).colorScheme;
    final canUnlock = _currentMatch != null;
    final unlocked = _targetUnlocked;
    return NeumorphicButton(
      onTap: canUnlock ? () => setState(() => _targetUnlocked = !_targetUnlocked) : null,
      enabled: canUnlock,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                unlocked ? Icons.lock_open : Icons.lock,
                color: canUnlock
                    ? (unlocked ? colorScheme.primary : colorScheme.onSurface)
                    : colorScheme.onSurfaceVariant,
                size: 16,
              ),
              const SizedBox(width: 4),
              // 文字始终完整显示，不省略
              Text(
                "解锁不完美模拟",
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: canUnlock
                      ? (unlocked ? colorScheme.primary : colorScheme.onSurface)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRandomButton() {
    final colorScheme = Theme.of(context).colorScheme;
    final canRandom = _currentMatch != null;
    return NeumorphicButton(
      onTap: canRandom ? _onRandomTarget : null,
      enabled: canRandom,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      children: [
        const Spacer(),
        Icon(
          Icons.shuffle,
          color: canRandom ? colorScheme.primary : colorScheme.onSurfaceVariant,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          "随机模拟",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: canRandom ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
