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
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../components/components.dart';
import '../models/audio_config.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../l10n/app_localizations.dart';
import 'script_editor_page.dart';

class DSPController extends StatefulWidget {
  const DSPController({super.key});

  @override
  State<DSPController> createState() => _DSPControllerState();
}

class _DSPControllerState extends State<DSPController> {
  late DSPControllerViewModel _viewModel;
  StreamSubscription<String>? _scriptErrorSubscription;

  @override
  void initState() {
    super.initState();
    _viewModel = DSPControllerViewModel(
      onStateChanged: () => setState(() {}),
    );
    _scriptErrorSubscription = _viewModel.compileErrorStream.listen((error) {
      if (!mounted) return;
      if (error.isNotEmpty && error.contains('Runtime crash')) {
        final l10n = AppLocalizations.of(context)!;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.scriptRuntimeCrash),
            content: SingleChildScrollView(
              child: Text(
                error,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.ok)),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _scriptErrorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickIrFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
        withReadStream: false,
      );
      if (result != null && result.files.single.path != null) {
        _viewModel.update(ParamID.convolveEffectIrPath, result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _importScriptFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['c', 'h', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      // Strip UTF-8 BOM if present
      var start = 0;
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        start = 3;
      }
      final data = bytes.sublist(start);
      // Try UTF-8 first, fall back to ASCII (latin-1)
      String code;
      try {
        code = utf8.decode(data);
      } catch (_) {
        code = latin1.decode(data);
      }
      if (code.isNotEmpty) {
        final desc = await _viewModel.importScript(code);
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        if (desc.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.importFailedNoDesc)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.importedScript(desc))),
          );
        }
      }
    }
  }

  Future<void> _exportScriptFile() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _viewModel.exportScriptCode();
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noActiveScriptToExport)),
      );
      return;
    }
    final desc = _viewModel.activeScriptDesc;
    final fileName = '${desc.replaceAll(RegExp(r'[^\w\-. ]'), '_')}.c';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportScript,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['c'],
      bytes: Uint8List.fromList(utf8.encode(code)),
    );
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportedTo(path.split('/').last))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        flexibleSpace: SafeArea(
          child: AppHeader(
            isCapturing: _viewModel.isCapturing,
            showCaptureButton: !_viewModel.shizukuMode,
            processingLatencyMs: _viewModel.processingLatencyMs,
            onCapturePressed: _viewModel.toggleCapture,
            onSettingsPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage(viewModel: _viewModel)),
              );
              setState(() {});
            },
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        left: true,
        right: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // ── Channel Balance (not refactored) ──
              ControlCard(
                icon: Icons.balance,
                title: l10n.channelBalance,
                description: l10n.channelBalanceDesc,
                value: _viewModel.get<double>(ParamID.balanceEffectBalance),
                min: -6,
                max: 6,
                unit: 'dB',
                expanded: _viewModel.channelBalanceExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('channelBalance'),
                onChanged: (v) => _viewModel.update(ParamID.balanceEffectBalance, v),
              ),
              const SizedBox(height: 16),
              // ── Global Gain (not refactored) ──
              ControlCard(
                icon: Icons.volume_up,
                title: l10n.globalGain,
                description: l10n.globalGainDesc,
                value: _viewModel.get<double>(ParamID.gainEffectGain),
                min: -15,
                max: 9,
                unit: 'dB',
                expanded: _viewModel.globalGainExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('globalGain'),
                onChanged: (v) => _viewModel.update(ParamID.gainEffectGain, v),
              ),
              const SizedBox(height: 16),
              // ── Multi-Band Limiter ──
              GenericControlCard(
                icon: Icons.keyboard_double_arrow_down,
                title: l10n.multiBandLimiter,
                description: l10n.multiBandLimiterDesc,
                enabled: _viewModel.get<bool>(ParamID.lookAheadSoftLimitEffectEnabled),
                onToggle: (v) => _viewModel.update(ParamID.lookAheadSoftLimitEffectEnabled, v),
              ),
              const SizedBox(height: 16),
              // ── Limiter ──
              GenericControlCard(
                icon: Icons.compress,
                title: l10n.limiter,
                subtitle: '${_viewModel.get<int>(ParamID.limiterEffectThreshold).toDouble().toStringAsFixed(2)}dB',
                description: l10n.limiterDesc,
                enabled: _viewModel.get<bool>(ParamID.limiterEffectEnabled),
                expanded: _viewModel.limiterExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('limiter'),
                onToggle: (v) => _viewModel.update(ParamID.limiterEffectEnabled, v),
                children: [
                  NeumorphicSlider(
                    label: l10n.limiterThreshold,
                    value: _viewModel.get<int>(ParamID.limiterEffectThreshold).toDouble(),
                    min: -30, max: 0, unit: 'dB', divisions: 30,
                    enabled: _viewModel.get<bool>(ParamID.limiterEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectThreshold, v.toInt()),
                  ),
                  NeumorphicSlider(
                    label: l10n.limiterAttack,
                    value: _viewModel.get<int>(ParamID.limiterEffectAttack).toDouble(),
                    min: 1, max: 200, unit: 'ms', divisions: 199,
                    enabled: _viewModel.get<bool>(ParamID.limiterEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectAttack, v.toInt()),
                  ),
                  NeumorphicSlider(
                    label: l10n.limiterRelease,
                    value: _viewModel.get<int>(ParamID.limiterEffectRelease).toDouble(),
                    min: 1, max: 1000, unit: 'ms', divisions: 999,
                    enabled: _viewModel.get<bool>(ParamID.limiterEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectRelease, v.toInt()),
                  ),
                  NeumorphicSlider(
                    label: l10n.limiterRatio,
                    value: _viewModel.get<int>(ParamID.limiterEffectRatio).toDouble(),
                    min: 1, max: 10, unit: '', divisions: 20,
                    enabled: _viewModel.get<bool>(ParamID.limiterEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectRatio, v.toInt()),
                  ),
                  NeumorphicSlider(
                    label: l10n.limiterMakeupGain,
                    value: _viewModel.get<int>(ParamID.limiterEffectMakeupGain).toDouble(),
                    min: 0, max: 15, unit: 'dB', divisions: 15,
                    enabled: _viewModel.get<bool>(ParamID.limiterEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectMakeupGain, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Transient Boost / Clarity ──
              GenericControlCard(
                icon: Icons.graphic_eq,
                title: l10n.highFrequencyGain,
                subtitle: '${_viewModel.get<int>(ParamID.clarityEffectGain)}',
                description: l10n.highFrequencyGainDesc,
                enabled: _viewModel.get<bool>(ParamID.clarityEffectEnabled),
                expanded: _viewModel.clarityExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('clarity'),
                onToggle: (v) => _viewModel.update(ParamID.clarityEffectEnabled, v),
                children: [
                  NeumorphicSlider(
                    label: l10n.gain,
                    value: _viewModel.get<int>(ParamID.clarityEffectGain).toDouble(),
                    min: 0, max: 15, unit: '', divisions: 15,
                    enabled: _viewModel.get<bool>(ParamID.clarityEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.clarityEffectGain, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Bass Boost ──
              GenericControlCard(
                icon: Icons.equalizer,
                title: l10n.lowFrequencyGain,
                subtitle: '${_viewModel.get<int>(ParamID.bassEffectGain)}',
                description: l10n.lowFrequencyGainDesc,
                enabled: _viewModel.get<bool>(ParamID.bassEffectEnabled),
                expanded: _viewModel.bassBoostExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('bassBoost'),
                onToggle: (v) => _viewModel.update(ParamID.bassEffectEnabled, v),
                children: [
                  NeumorphicSlider(
                    label: l10n.gain,
                    value: _viewModel.get<int>(ParamID.bassEffectGain).toDouble(),
                    min: 0, max: 15, unit: '', divisions: 15,
                    enabled: _viewModel.get<bool>(ParamID.bassEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.bassEffectGain, v.toInt()),
                  ),
                  NeumorphicSlider(
                    label: l10n.centerFreq,
                    value: _viewModel.get<int>(ParamID.bassEffectCenterFreq).toDouble(),
                    min: 30, max: 100, unit: 'Hz', divisions: 70,
                    enabled: _viewModel.get<bool>(ParamID.bassEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.bassEffectCenterFreq, v.toInt()),
                  ),
                  NeumorphicSlider(
                    label: l10n.q,
                    value: _viewModel.get<double>(ParamID.bassEffectQ),
                    min: 0.1, max: 1.5, unit: '', divisions: 140,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.bassEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.bassEffectQ, v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Wecho Feminine Vocal / Nice ──
              GenericControlCard(
                icon: Icons.hearing,
                title: l10n.nice,
                subtitle: _viewModel.get<double>(ParamID.evenHarmonicEffectBase).toStringAsFixed(2),
                description: l10n.niceDesc,
                enabled: _viewModel.get<bool>(ParamID.evenHarmonicEffectEnabled),
                expanded: _viewModel.evenHarmonicExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('evenHarmonic'),
                onToggle: (v) => _viewModel.update(ParamID.evenHarmonicEffectEnabled, v),
                children: [
                  NeumorphicSlider(
                    label: l10n.niceBase,
                    value: _viewModel.get<double>(ParamID.evenHarmonicEffectBase),
                    min: 0, max: 1, unit: '', divisions: 100,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.evenHarmonicEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.evenHarmonicEffectBase, v),
                  ),
                  NeumorphicSlider(
                    label: l10n.niceWarm,
                    value: _viewModel.get<double>(ParamID.evenHarmonicEffectWarm),
                    min: 0, max: 1, unit: '', divisions: 100,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.evenHarmonicEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.evenHarmonicEffectWarm, v),
                  ),
                  NeumorphicSlider(
                    label: l10n.niceSugar,
                    value: _viewModel.get<double>(ParamID.evenHarmonicEffectSugar),
                    min: 0, max: 1, unit: '', divisions: 100,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.evenHarmonicEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.evenHarmonicEffectSugar, v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Convolution Reverb ──
              GenericControlCard(
                icon: Icons.waves,
                title: l10n.convolve,
                description: l10n.convolveDesc,
                enabled: _viewModel.get<bool>(ParamID.convolveEffectEnabled),
                expanded: _viewModel.convolveExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('convolve'),
                onToggle: (v) => _viewModel.update(ParamID.convolveEffectEnabled, v),
                children: [
                  NeumorphicButton(
                    onTap: _pickIrFile,
                    enabled: _viewModel.get<bool>(ParamID.convolveEffectEnabled),
                    children: [
                      Icon(Icons.audio_file, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _viewModel.get<String>(ParamID.convolveEffectIrPath).isEmpty
                              ? l10n.selectIRFile
                              : _viewModel.get<String>(ParamID.convolveEffectIrPath).split('/').last,
                          style: TextStyle(
                            fontSize: 14,
                            color: _viewModel.get<String>(ParamID.convolveEffectIrPath).isEmpty
                                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                                : colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.folder_open, color: colorScheme.onSurfaceVariant, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NeumorphicSlider(
                    label: l10n.mixRatio,
                    value: _viewModel.get<double>(ParamID.convolveEffectMix),
                    min: 0, max: 1, unit: '', divisions: 100,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.convolveEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.convolveEffectMix, v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Low Cut ──
              GenericControlCard(
                icon: Icons.filter_list,
                title: l10n.lowcat,
                subtitle: '${_viewModel.get<int>(ParamID.lowcatEffectCutoffFrequency)}Hz',
                description: l10n.lowcatDesc,
                enabled: _viewModel.get<bool>(ParamID.lowcatEffectEnabled),
                expanded: _viewModel.lowcatExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('lowcat'),
                onToggle: (v) => _viewModel.update(ParamID.lowcatEffectEnabled, v),
                children: [
                  NeumorphicSlider(
                    label: l10n.cutoffFrequency,
                    value: _viewModel.get<int>(ParamID.lowcatEffectCutoffFrequency).toDouble(),
                    min: 20, max: 300, unit: 'Hz', divisions: 280,
                    enabled: _viewModel.get<bool>(ParamID.lowcatEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.lowcatEffectCutoffFrequency, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── IIR Equalizer ──
              GenericControlCard(
                icon: Icons.graphic_eq,
                title: l10n.equalizer,
                description: l10n.equalizerDesc,
                enabled: _viewModel.get<bool>(ParamID.iirEqualizerEffectEnabled),
                expanded: _viewModel.equalizerExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('equalizer'),
                onToggle: (v) => _viewModel.update(ParamID.iirEqualizerEffectEnabled, v),
                children: [
                  EqSliderPanel(
                    bands: _viewModel.get<List<IIREqualizerCoeffs>>(ParamID.iirEqualizerEffectCoeffs),
                    onBandsChanged: (v) => _viewModel.update(ParamID.iirEqualizerEffectCoeffs, v),
                    enabled: _viewModel.get<bool>(ParamID.iirEqualizerEffectEnabled),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              const SizedBox(height: 16),
              // ── Virtual Bass ──
              GenericControlCard(
                icon: Icons.surround_sound,
                title: l10n.virtualBass,
                subtitle: '${_viewModel.get<int>(ParamID.virtualbassEffectEnvelopeRate)}Hz',
                description: l10n.virtualBassDesc,
                enabled: _viewModel.get<bool>(ParamID.virtualbassEffectEnabled),
                expanded: _viewModel.virtualBassExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('virtualBass'),
                onToggle: (v) => _viewModel.update(ParamID.virtualbassEffectEnabled, v),
                children: [
                  NeumorphicSlider(
                    label: l10n.virtualBassEnvelopeRate,
                    value: _viewModel.get<int>(ParamID.virtualbassEffectEnvelopeRate).toDouble(),
                    min: 5, max: 60, unit: 'Hz', divisions: 55,
                    enabled: _viewModel.get<bool>(ParamID.virtualbassEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.virtualbassEffectEnvelopeRate, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── FDN Reverb ──
              GenericControlCard(
                icon: Icons.spatial_audio,
                title: l10n.reverb,
                subtitle: _viewModel.get<double>(ParamID.reverbEffectMix).toStringAsFixed(2),
                description: l10n.reverbDesc,
                enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                expanded: _viewModel.reverbExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('reverb'),
                onToggle: (v) => _viewModel.update(ParamID.reverbEffectEnabled, v),
                children: [
                  NeumorphicSlider(
                    label: l10n.reverbMix,
                    value: _viewModel.get<double>(ParamID.reverbEffectMix),
                    min: 0, max: 1, unit: '', divisions: 100,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectMix, v),
                  ),
                  NeumorphicSlider(
                    label: l10n.reverbRoomSize,
                    value: _viewModel.get<double>(ParamID.reverbEffectRoomSize),
                    min: 0, max: 1, unit: '', divisions: 100,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectRoomSize, v),
                  ),
                  NeumorphicSlider(
                    label: l10n.reverbDamping,
                    value: _viewModel.get<double>(ParamID.reverbEffectDamping),
                    min: 0, max: 1, unit: '', divisions: 100,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectDamping, v),
                  ),
                  NeumorphicSlider(
                    label: l10n.reverbStereoWidth,
                    value: _viewModel.get<double>(ParamID.reverbEffectStereoWidth),
                    min: 0.1, max: 2, unit: '', divisions: 190,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectStereoWidth, v),
                  ),
                  NeumorphicSlider(
                    label: l10n.reverbModDepth,
                    value: _viewModel.get<double>(ParamID.reverbEffectModDepth),
                    min: 0, max: 1, unit: '', divisions: 100,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectModDepth, v),
                  ),
                  NeumorphicSlider(
                    label: l10n.reverbModFreq,
                    value: _viewModel.get<double>(ParamID.reverbEffectModFreq),
                    min: 0.1, max: 5, unit: '', divisions: 49,
                    decimalPlaces: 2,
                    enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectModFreq, v),
                  ),
                  NeumorphicSlider(
                    label: l10n.reverbPreDelay,
                    value: _viewModel.get<int>(ParamID.reverbEffectPreDelay).toDouble(),
                    min: 0, max: 60, unit: 'ms', divisions: 60,
                    enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectPreDelay, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Script Effect ──
              GenericControlCard(
                icon: Icons.code,
                title: parseScriptDesc(_viewModel.get<String>(ParamID.scriptEffectCode)),
                description: l10n.scriptEffectDesc,
                enabled: _viewModel.get<bool>(ParamID.scriptEffectEnabled),
                expanded: _viewModel.scriptExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('script'),
                onToggle: (v) => _viewModel.update(ParamID.scriptEffectEnabled, v),
                children: [
                  // Script selector
                  NeumorphicSelector<String>(
                    items: _viewModel.getScriptLibrary().keys
                        .map((desc) => SelectorItem(value: desc, label: desc, deletable: true))
                        .toList(),
                    selectedValue: _viewModel.activeScriptDesc.isNotEmpty &&
                            _viewModel.getScriptLibrary().containsKey(_viewModel.activeScriptDesc)
                        ? _viewModel.activeScriptDesc
                        : null,
                    onSelect: (desc) => _viewModel.switchScript(desc),
                    onDelete: (desc) => _viewModel.deleteScript(desc),
                    enabled: _viewModel.get<bool>(ParamID.scriptEffectEnabled),
                    hint: l10n.selectScript,
                  ),
                  const SizedBox(height: 12),
                  // Edit script button
                  NeumorphicButton(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ScriptEditorPage(
                            initialCode: _viewModel.get<String>(ParamID.scriptEffectCode),
                            onSave: (code) => _viewModel.saveScript(code),
                            compileErrorStream: _viewModel.compileErrorStream,
                          ),
                        ),
                      );
                    },
                    enabled: _viewModel.get<bool>(ParamID.scriptEffectEnabled),
                    children: [
                      Icon(Icons.code, color: _viewModel.get<bool>(ParamID.scriptEffectEnabled) ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.editScript,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _viewModel.get<bool>(ParamID.scriptEffectEnabled) ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(Icons.edit, color: _viewModel.get<bool>(ParamID.scriptEffectEnabled) ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Import / Export buttons
                  Row(
                    children: [
                      Expanded(
                        child: NeumorphicButton(
                          onTap: _importScriptFile,
                          enabled: _viewModel.get<bool>(ParamID.scriptEffectEnabled),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          children: [
                            Icon(Icons.file_download, color: _viewModel.get<bool>(ParamID.scriptEffectEnabled) ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 18),
                            const SizedBox(width: 6),
                            Text(l10n.importScript, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeumorphicButton(
                          onTap: _exportScriptFile,
                          enabled: _viewModel.get<bool>(ParamID.scriptEffectEnabled),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          children: [
                            Icon(Icons.file_upload, color: _viewModel.get<bool>(ParamID.scriptEffectEnabled) ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 18),
                            const SizedBox(width: 6),
                            Text(l10n.exportScript, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Dynamic parameter sliders
                  ..._viewModel.get<List<ScriptParam>>(ParamID.scriptEffectParams).asMap().entries.map((entry) {
                    final i = entry.key;
                    final param = entry.value;
                    return NeumorphicSlider(
                      label: param.name,
                      value: param.value,
                      min: param.min,
                      max: param.max,
                      unit: '',
                      divisions: ((param.max - param.min) / param.step).round(),
                      decimalPlaces: param.step < 0.01 ? 3 : (param.step < 0.1 ? 2 : 1),
                      enabled: _viewModel.get<bool>(ParamID.scriptEffectEnabled),
                      onChanged: (v) {
                        final params = List<ScriptParam>.from(
                          _viewModel.get<List<ScriptParam>>(ParamID.scriptEffectParams),
                        );
                        params[i] = ScriptParam(param.name, v, min: param.min, max: param.max, step: param.step);
                        _viewModel.update(ParamID.scriptEffectParams, params);
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, -10),
        child: GestureDetector(
          onTap: () => _viewModel.updateMasterEnabled(!_viewModel.masterEnabled),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _viewModel.masterEnabled
                    ? [
                        const Color(0xFF00D4FF),
                        const Color(0xFF0099CC),
                        const Color(0xFF006699),
                      ]
                    : [
                        Colors.grey.shade400,
                        Colors.grey.shade500,
                        Colors.grey.shade600,
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _viewModel.masterEnabled
                      ? const Color(0xFF00D4FF).withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.power_settings_new,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
