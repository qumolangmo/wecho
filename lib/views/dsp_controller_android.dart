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
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Script Runtime Crash'),
            content: SingleChildScrollView(
              child: Text(
                error,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
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

  @override
  Widget build(BuildContext context) {
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
              ControlCard(
                icon: Icons.balance,
                title: AppLocalizations.of(context)!.channelBalance,
                description: AppLocalizations.of(context)!.channelBalanceDesc,
                value: _viewModel.get<double>(ParamID.balanceEffectBalance),
                min: -6,
                max: 6,
                unit: 'dB',
                expanded: _viewModel.channelBalanceExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('channelBalance'),
                onChanged: (v) => _viewModel.update(ParamID.balanceEffectBalance, v),
              ),
              const SizedBox(height: 16),
              ControlCard(
                icon: Icons.volume_up,
                title: AppLocalizations.of(context)!.globalGain,
                description: AppLocalizations.of(context)!.globalGainDesc,
                value: _viewModel.get<double>(ParamID.gainEffectGain),
                min: -15,
                max: 9,
                unit: 'dB',
                expanded: _viewModel.globalGainExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('globalGain'),
                onChanged: (v) => _viewModel.update(ParamID.gainEffectGain, v),
              ),
              const SizedBox(height: 16),
              SimpleControlCard(
                icon: Icons.keyboard_double_arrow_down,
                title: AppLocalizations.of(context)!.multiBandLimiter,
                description: AppLocalizations.of(context)!.multiBandLimiterDesc,
                enabled: _viewModel.get<bool>(ParamID.lookAheadSoftLimitEffectEnabled),
                onToggle: (v) => _viewModel.update(ParamID.lookAheadSoftLimitEffectEnabled, v),
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
                icon: Icons.compress, 
                title: AppLocalizations.of(context)!.limiter,
                description: AppLocalizations.of(context)!.limiterDesc,
                enabled: _viewModel.get<bool>(ParamID.limiterEffectEnabled),
                expanded: _viewModel.limiterExpanded, 
                onToggleExpand: () => _viewModel.toggleExpanded('limiter'),
                onToggle: (v) => _viewModel.update(ParamID.limiterEffectEnabled, v),
                sliders: [
                  SliderConfig(
                    label: AppLocalizations.of(context)!.limiterThreshold,
                    value: _viewModel.get<int>(ParamID.limiterEffectThreshold).toDouble(),
                    min: -30,
                    max: 0,
                    unit: 'dB',
                    divisions: 30,
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectThreshold, v.toInt()),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.limiterAttack,
                    value: _viewModel.get<int>(ParamID.limiterEffectAttack).toDouble(),
                    min: 1,
                    max: 200,
                    unit: 'ms',
                    divisions: 199,
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectAttack, v.toInt()),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.limiterRelease,
                    value: _viewModel.get<int>(ParamID.limiterEffectRelease).toDouble(),
                    min: 1,
                    max: 1000,
                    unit: 'ms',
                    divisions: 999,
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectRelease, v.toInt()),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.limiterRatio,
                    value: _viewModel.get<int>(ParamID.limiterEffectRatio).toDouble(),
                    min: 1,
                    max: 10,
                    unit: '',
                    divisions: 20,
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectRatio, v.toInt()),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.limiterMakeupGain,
                    value: _viewModel.get<int>(ParamID.limiterEffectMakeupGain).toDouble(),
                    min: 0,
                    max: 15,
                    unit: 'dB',
                    divisions: 15,
                    onChanged: (v) => _viewModel.update(ParamID.limiterEffectMakeupGain, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
                icon: Icons.graphic_eq,
                title: AppLocalizations.of(context)!.highFrequencyGain, 
                description: AppLocalizations.of(context)!.highFrequencyGainDesc,
                enabled: _viewModel.get<bool>(ParamID.clarityEffectEnabled),
                expanded: _viewModel.clarityExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('clarity'),
                onToggle: (v) => _viewModel.update(ParamID.clarityEffectEnabled, v),
                sliders: [
                  SliderConfig(
                    label: AppLocalizations.of(context)!.gain,
                    value: _viewModel.get<int>(ParamID.clarityEffectGain).toDouble(),
                    min: 0,
                    max: 15,
                    unit: '',
                    divisions: 15,
                    onChanged: (v) => _viewModel.update(ParamID.clarityEffectGain, v.toInt()),
                  ),
                ], 
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
                icon: Icons.equalizer,
                title: AppLocalizations.of(context)!.lowFrequencyGain,
                description: AppLocalizations.of(context)!.lowFrequencyGainDesc,
                enabled: _viewModel.get<bool>(ParamID.bassEffectEnabled),
                expanded: _viewModel.bassBoostExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('bassBoost'),
                onToggle: (v) => _viewModel.update(ParamID.bassEffectEnabled, v),
                sliders: [
                  SliderConfig(
                    label: AppLocalizations.of(context)!.gain,
                    value: _viewModel.get<int>(ParamID.bassEffectGain).toDouble(),
                    min: 0,
                    max: 15,
                    unit: '',
                    divisions: 15,
                    onChanged: (v) => _viewModel.update(ParamID.bassEffectGain, v.toInt()),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.centerFreq,
                    value: _viewModel.get<int>(ParamID.bassEffectCenterFreq).toDouble(),
                    min: 30,
                    max: 100,
                    unit: 'Hz',
                    divisions: 70,
                    onChanged: (v) => _viewModel.update(ParamID.bassEffectCenterFreq, v.toInt()),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.q,
                    value: _viewModel.get<double>(ParamID.bassEffectQ),
                    min: 0.1,
                    max: 1.5,
                    unit: '',
                    divisions: 140,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.bassEffectQ, v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
                icon: Icons.hearing,
                title: AppLocalizations.of(context)!.nice,
                description: AppLocalizations.of(context)!.niceDesc,
                enabled: _viewModel.get<bool>(ParamID.evenHarmonicEffectEnabled),
                expanded: _viewModel.evenHarmonicExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('evenHarmonic'),
                onToggle: (v) => _viewModel.update(ParamID.evenHarmonicEffectEnabled, v),
                sliders: [
                  SliderConfig(
                    label: AppLocalizations.of(context)!.niceBase,
                    value: _viewModel.get<double>(ParamID.evenHarmonicEffectBase),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 100,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.evenHarmonicEffectBase, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.niceWarm,
                    value: _viewModel.get<double>(ParamID.evenHarmonicEffectWarm),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 100,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.evenHarmonicEffectWarm, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.niceSugar,
                    value: _viewModel.get<double>(ParamID.evenHarmonicEffectSugar),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 100,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.evenHarmonicEffectSugar, v),
                  ),
                ], 
              ),
              const SizedBox(height: 16),
              ConvolveControlCard(
                icon: Icons.waves,
                title: AppLocalizations.of(context)!.convolve,
                description: AppLocalizations.of(context)!.convolveDesc,
                mixValue: _viewModel.get<double>(ParamID.convolveEffectMix),
                mixMin: 0,
                mixMax: 1,
                irPath: _viewModel.get<String>(ParamID.convolveEffectIrPath),
                enabled: _viewModel.get<bool>(ParamID.convolveEffectEnabled),
                expanded: _viewModel.convolveExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('convolve'),
                onToggle: (v) => _viewModel.update(ParamID.convolveEffectEnabled, v),
                onMixChanged: (v) => _viewModel.update(ParamID.convolveEffectMix, v),
                onIrPathChanged: (v) => _viewModel.update(ParamID.convolveEffectIrPath, v),
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
                icon: Icons.filter_list,
                title: AppLocalizations.of(context)!.lowcat,
                description: AppLocalizations.of(context)!.lowcatDesc,
                enabled: _viewModel.get<bool>(ParamID.lowcatEffectEnabled),
                expanded: _viewModel.lowcatExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('lowcat'),
                onToggle: (v) => _viewModel.update(ParamID.lowcatEffectEnabled, v),
                sliders: [
                  SliderConfig(
                    label: AppLocalizations.of(context)!.cutoffFrequency,
                    value: _viewModel.get<int>(ParamID.lowcatEffectCutoffFrequency).toDouble(),
                    min: 20,
                    max: 300,
                    unit: 'Hz',
                    divisions: 280,
                    onChanged: (v) => _viewModel.update(ParamID.lowcatEffectCutoffFrequency, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              EqualizerControlCard(
                icon: Icons.graphic_eq,
                title: AppLocalizations.of(context)!.equalizer,
                description: AppLocalizations.of(context)!.equalizerDesc,
                enabled: _viewModel.get<bool>(ParamID.iirEqualizerEffectEnabled),
                expanded: _viewModel.equalizerExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('equalizer'),
                bands: _viewModel.get<List<IIREqualizerCoeffs>>(ParamID.iirEqualizerEffectCoeffs),
                onToggle: (v) => _viewModel.update(ParamID.iirEqualizerEffectEnabled, v),
                onBandsChanged: (v) => _viewModel.update(ParamID.iirEqualizerEffectCoeffs, v),
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
                icon: Icons.surround_sound,
                title: AppLocalizations.of(context)!.virtualBass,
                description: AppLocalizations.of(context)!.virtualBassDesc,
                enabled: _viewModel.get<bool>(ParamID.virtualbassEffectEnabled),
                expanded: _viewModel.virtualBassExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('virtualBass'),
                onToggle: (v) => _viewModel.update(ParamID.virtualbassEffectEnabled, v),
                sliders: [
                  SliderConfig(
                    label: AppLocalizations.of(context)!.virtualBassEnvelopeRate,
                    value: _viewModel.get<int>(ParamID.virtualbassEffectEnvelopeRate).toDouble(),
                    min: 5,
                    max: 60,
                    unit: 'Hz',
                    divisions: 55,
                    onChanged: (v) => _viewModel.update(ParamID.virtualbassEffectEnvelopeRate, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
                icon: Icons.spatial_audio,
                title: AppLocalizations.of(context)!.reverb,
                description: AppLocalizations.of(context)!.reverbDesc,
                enabled: _viewModel.get<bool>(ParamID.reverbEffectEnabled),
                expanded: _viewModel.reverbExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('reverb'),
                onToggle: (v) => _viewModel.update(ParamID.reverbEffectEnabled, v),
                sliders: [
                  SliderConfig(
                    label: AppLocalizations.of(context)!.reverbRoomSize,
                    value: _viewModel.get<double>(ParamID.reverbEffectRoomSize),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 100,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectRoomSize, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.reverbDamping,
                    value: _viewModel.get<double>(ParamID.reverbEffectDamping),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 100,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectDamping, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.reverbMix,
                    value: _viewModel.get<double>(ParamID.reverbEffectMix),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 100,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectMix, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.reverbStereoWidth,
                    value: _viewModel.get<double>(ParamID.reverbEffectStereoWidth),
                    min: 0.1,
                    max: 2,
                    unit: '',
                    divisions: 190,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectStereoWidth, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.reverbModDepth,
                    value: _viewModel.get<double>(ParamID.reverbEffectModDepth),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 100,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectModDepth, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.reverbModFreq,
                    value: _viewModel.get<double>(ParamID.reverbEffectModFreq),
                    min: 0.1,
                    max: 5,
                    unit: '',
                    divisions: 49,
                    decimalPlaces: 2,
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectModFreq, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.reverbPreDelay,
                    value: _viewModel.get<int>(ParamID.reverbEffectPreDelay).toDouble(),
                    min: 0,
                    max: 60,
                    unit: 'ms',
                    divisions: 60,
                    onChanged: (v) => _viewModel.update(ParamID.reverbEffectPreDelay, v.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ScriptEffectCard(
                icon: Icons.code,
                title: parseScriptDesc(_viewModel.get<String>(ParamID.scriptEffectCode)),
                description: AppLocalizations.of(context)!.scriptEffectDesc,
                enabled: _viewModel.get<bool>(ParamID.scriptEffectEnabled),
                expanded: _viewModel.scriptExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('script'),
                onToggle: (v) => _viewModel.update(ParamID.scriptEffectEnabled, v),
                activeScriptDesc: _viewModel.activeScriptDesc,
                scriptLibrary: _viewModel.getScriptLibrary(),
                onScriptSelect: (desc) => _viewModel.switchScript(desc),
                onScriptDelete: (desc) => _viewModel.deleteScript(desc),
                onCodeEditorTap: () {
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
                onImportScript: (code) async {
                  final desc = await _viewModel.importScript(code);
                  if (desc.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Import failed: script missing @desc annotation')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Imported: $desc')),
                    );
                  }
                },
                onExportScript: () async {
                  final code = _viewModel.exportScriptCode();
                  if (code == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No active script to export')),
                    );
                    return;
                  }
                  final desc = _viewModel.activeScriptDesc;
                  final fileName = '${desc.replaceAll(RegExp(r'[^\w\-. ]'), '_')}.c';
                  final path = await FilePicker.platform.saveFile(
                    dialogTitle: 'Export Script',
                    fileName: fileName,
                    type: FileType.custom,
                    allowedExtensions: ['c'],
                    bytes: Uint8List.fromList(utf8.encode(code)),
                  );
                  if (path != null) {
                    // saveFile with bytes writes the file directly
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Exported to: ${path.split('/').last}')),
                    );
                  }
                },
                sliders: _viewModel.get<List<ScriptParam>>(ParamID.scriptEffectParams).asMap().entries.map((entry) {
                    final i = entry.key;
                    final param = entry.value;
                    return SliderConfig(
                      label: param.name,
                      value: param.value,
                      min: param.min,
                      max: param.max,
                      unit: '',
                      divisions: ((param.max - param.min) / param.step).round(),
                      decimalPlaces: param.step < 0.01 ? 3 : (param.step < 0.1 ? 2 : 1),
                      onChanged: (v) {
                        final params = List<ScriptParam>.from(
                          _viewModel.get<List<ScriptParam>>(ParamID.scriptEffectParams),
                        );
                        params[i] = ScriptParam(param.name, v, min: param.min, max: param.max, step: param.step);
                        _viewModel.update(ParamID.scriptEffectParams, params);
                      },
                    );
                  }).toList(),
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
