/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/components.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../models/audio_config.dart';
import '../l10n/app_localizations.dart';

class DSPController extends StatefulWidget {
  const DSPController({super.key});

  @override
  State<DSPController> createState() => _DSPControllerState();
}

class _DSPControllerState extends State<DSPController> {
  late DSPControllerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DSPControllerViewModel(
      onStateChanged: () => setState(() {}),
    );
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
                    label: AppLocalizations.of(context)!.gain,
                    value: _viewModel.get<int>(ParamID.evenHarmonicEffectGain).toDouble(),
                    min: 0,
                    max: 7,
                    unit: '',
                    divisions: 7,
                    onChanged: (v) => _viewModel.update(ParamID.evenHarmonicEffectGain, v.toInt()),
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
              MultiSliderControlCard(
                icon: Icons.speaker, 
                title: AppLocalizations.of(context)!.speakerExciter, 
                description: AppLocalizations.of(context)!.speakerExciterDesc,
                enabled: _viewModel.get<bool>(ParamID.speakerEffectEnabled), 
                expanded: _viewModel.speakerExciterExpanded,
                onToggleExpand: () => _viewModel.toggleExpanded('speakerExciter'), 
                onToggle: (v) => _viewModel.update(ParamID.speakerEffectEnabled, v), 
                sliders: [
                  SliderConfig(
                    label: AppLocalizations.of(context)!.speakerExciterHpGain,
                    value: _viewModel.get<double>(ParamID.speakerEffectHpGain),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 10,
                    onChanged: (v) => _viewModel.update(ParamID.speakerEffectHpGain, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.speakerExciterBpGain,
                    value: _viewModel.get<double>(ParamID.speakerEffectBpGain),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 10,
                    onChanged: (v) => _viewModel.update(ParamID.speakerEffectBpGain, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.speakerExciter2HarmonicCoeffs,
                    value: _viewModel.get<double>(ParamID.speakerEffect2HarmonicCoeffs),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 10,
                    onChanged: (v) => _viewModel.update(ParamID.speakerEffect2HarmonicCoeffs, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.speakerExciter4HarmonicCoeffs,
                    value: _viewModel.get<double>(ParamID.speakerEffect4HarmonicCoeffs),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 10,
                    onChanged: (v) => _viewModel.update(ParamID.speakerEffect4HarmonicCoeffs, v),
                  ),
                  SliderConfig(
                    label: AppLocalizations.of(context)!.speakerExciter6HarmonicCoeffs,
                    value: _viewModel.get<double>(ParamID.speakerEffect6HarmonicCoeffs),
                    min: 0,
                    max: 1,
                    unit: '',
                    divisions: 10,
                    onChanged: (v) => _viewModel.update(ParamID.speakerEffect6HarmonicCoeffs, v),
                  ),
                ]),
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
