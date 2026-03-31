/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../components_windows/components_windows.dart';
import '../components_windows/global_gain_card.dart';
import '../components_windows/channel_balance_card.dart';
import '../components_windows/convolution_card.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../l10n/app_localizations.dart';

class DSPControllerWindows extends StatefulWidget {
  const DSPControllerWindows({super.key});

  @override
  State<DSPControllerWindows> createState() => _DSPControllerWindowsState();
}

class _DSPControllerWindowsState extends State<DSPControllerWindows> {
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
      backgroundColor: const Color(0xFF1a1a2e),
      body: Column(
        children: [
          WindowsTitleBar(title: 'WEcho'),
          // 总开关
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _viewModel.masterEnabled ? const Color(0xFF1e3d5c) : const Color(0xFF2d1f3d),
                  _viewModel.masterEnabled ? const Color(0xFF16294a) : const Color(0xFF1a1a2e),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _viewModel.masterEnabled
                      ? const Color(0xFF00C9E8).withOpacity(0.3)
                      : Colors.black.withOpacity(0.4),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(
                color: _viewModel.masterEnabled
                    ? const Color(0xFF00C9E8).withOpacity(0.5)
                    : const Color(0xFF3a3a5c).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.power_settings_new,
                  color: _viewModel.masterEnabled ? const Color(0xFF00C9E8) : const Color(0xFF888888),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Power',
                        style: TextStyle(
                          color: _viewModel.masterEnabled ? const Color(0xFFE0E0E0) : const Color(0xFF888888),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _viewModel.masterEnabled ? 'APO 已启用' : 'APO 已禁用',
                        style: TextStyle(
                          color: _viewModel.masterEnabled ? const Color(0xFF00C9E8) : const Color(0xFF666666),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _viewModel.masterEnabled,
                  onChanged: _viewModel.updateMasterEnabled,
                  activeColor: const Color(0xFF00C9E8),
                  activeTrackColor: const Color(0xFF00C9E8).withOpacity(0.3),
                  inactiveThumbColor: const Color(0xFF888888),
                  inactiveTrackColor: const Color(0xFF3a3a5c),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = (constraints.maxWidth ~/ 340);
                  crossAxisCount = crossAxisCount.clamp(1, 4);
                  
                  return MasonryGridView.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      switch (index) {
                        case 0:
                          return ChannelBalanceCard(
                            title: AppLocalizations.of(context)!.channelBalance,
                            description: AppLocalizations.of(context)!.channelBalanceDesc,
                            value: _viewModel.channelBalance,
                            min: -6,
                            max: 6,
                            unit: 'dB',
                            expanded: true,
                            onToggleExpand: () {},
                            onChanged: _viewModel.updateChannelBalance,
                          );
                        case 1:
                          return GlobalGainCard(
                            title: AppLocalizations.of(context)!.globalGain,
                            description: AppLocalizations.of(context)!.globalGainDesc,
                            value: _viewModel.globalGain,
                            min: -15,
                            max: 3,
                            unit: 'dB',
                            expanded: true,
                            onToggleExpand: () {},
                            onChanged: _viewModel.updateGlobalGain,
                          );
                        case 2:
                          return MultiSliderControlCard(
                            icon: Icons.keyboard_double_arrow_down,
                            title: AppLocalizations.of(context)!.multiBandLimiter,
                            description: AppLocalizations.of(context)!.multiBandLimiterDesc,
                            enabled: _viewModel.multibandLimiterEnabled,
                            expanded: false,
                            onToggleExpand: () {},
                            onToggle: _viewModel.updateMultibandLimiterEnabled,
                            sliders: [],
                          );
                        case 3:
                          return MultiSliderControlCard(
                            icon: Icons.compress,
                            title: AppLocalizations.of(context)!.limiter,
                            description: AppLocalizations.of(context)!.limiterDesc,
                            enabled: _viewModel.limiterEnabled,
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: _viewModel.updateLimiterEnabled,
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterThreshold,
                                value: _viewModel.limiterThreshold,
                                min: -30,
                                max: 0,
                                unit: 'dB',
                                divisions: 30,
                                onChanged: _viewModel.updateLimiterThreshold,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterAttack,
                                value: _viewModel.limiterAttack,
                                min: 1,
                                max: 200,
                                unit: 'ms',
                                divisions: 199,
                                onChanged: _viewModel.updateLimiterAttack,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterRelease,
                                value: _viewModel.limiterRelease,
                                min: 1,
                                max: 1000,
                                unit: 'ms',
                                divisions: 999,
                                onChanged: _viewModel.updateLimiterRelease,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterRatio,
                                value: _viewModel.limiterRatio,
                                min: 1,
                                max: 10,
                                unit: '',
                                divisions: 20,
                                onChanged: _viewModel.updateLimiterRatio,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterMakeupGain,
                                value: _viewModel.limiterMakeupGain,
                                min: 0,
                                max: 15,
                                unit: 'dB',
                                divisions: 15,
                                onChanged: _viewModel.updateLimiterMakeupGain,
                              ),
                            ],
                          );
                        case 4:
                          return MultiSliderControlCard(
                            icon: Icons.graphic_eq,
                            title: AppLocalizations.of(context)!.highFrequencyGain,
                            description: AppLocalizations.of(context)!.highFrequencyGainDesc,
                            enabled: _viewModel.clarityEnabled,
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: _viewModel.updateClarityEnabled,
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.gain,
                                value: _viewModel.clarity,
                                min: 0,
                                max: 15,
                                unit: '',
                                divisions: 15,
                                onChanged: _viewModel.updateClarity,
                              ),
                            ],
                          );
                        case 5:
                          return MultiSliderControlCard(
                            icon: Icons.equalizer,
                            title: AppLocalizations.of(context)!.lowFrequencyGain,
                            description: AppLocalizations.of(context)!.lowFrequencyGainDesc,
                            enabled: _viewModel.bassBoostEnabled,
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: _viewModel.updateBassBoostEnabled,
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.gain,
                                value: _viewModel.bassBoost,
                                min: 0,
                                max: 15,
                                unit: '',
                                divisions: 15,
                                onChanged: _viewModel.updateBassBoost,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.centerFreq,
                                value: _viewModel.bassCenterFreq,
                                min: 30,
                                max: 100,
                                unit: 'Hz',
                                divisions: 70,
                                onChanged: _viewModel.updateBassCenterFreq,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.q,
                                value: _viewModel.bassQ,
                                min: 0.1,
                                max: 1.5,
                                unit: '',
                                divisions: 140,
                                decimalPlaces: 2,
                                onChanged: _viewModel.updateBassQ,
                              ),
                            ],
                          );
                        case 6:
                          return MultiSliderControlCard(
                            icon: Icons.hearing,
                            title: AppLocalizations.of(context)!.nice,
                            description: AppLocalizations.of(context)!.niceDesc,
                            enabled: _viewModel.evenHarmonicEnabled,
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: _viewModel.updateEvenHarmonicEnabled,
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.gain,
                                value: _viewModel.evenHarmonicGain,
                                min: 0,
                                max: 7,
                                unit: '',
                                divisions: 7,
                                onChanged: _viewModel.updateEvenHarmonicGain,
                              ),
                            ],
                          );
                        case 7:
                          return ConvolutionCard(
                            title: AppLocalizations.of(context)!.convolve,
                            description: AppLocalizations.of(context)!.convolveDesc,
                            mix: _viewModel.convolveMix,
                            filePath: _viewModel.convolveIrPath,
                            enabled: _viewModel.convolveEnabled,
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: _viewModel.updateConvolveEnabled,
                            onMixChanged: _viewModel.updateConvolveMix,
                            onFileSelected: _viewModel.updateConvolveIrPath,
                          );
                        case 8:
                          return MultiSliderControlCard(
                            icon: Icons.speaker,
                            title: AppLocalizations.of(context)!.speakerExciter,
                            description: AppLocalizations.of(context)!.speakerExciterDesc,
                            enabled: _viewModel.speakerExciterEnabled,
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: _viewModel.updateSpeakerExciterEnabled,
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.speakerExciterHpGain,
                                value: _viewModel.speakerExciterHpGain,
                                min: 0,
                                max: 1,
                                unit: '',
                                divisions: 10,
                                onChanged: _viewModel.updateSpeakerExciterHpGain,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.speakerExciterBpGain,
                                value: _viewModel.speakerExciterBpGain,
                                min: 0,
                                max: 1,
                                unit: '',
                                divisions: 10,
                                onChanged: _viewModel.updateSpeakerExciterBpGain,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.speakerExciter2HarmonicCoeffs,
                                value: _viewModel.speakerExciter2HarmonicCoeffs,
                                min: 0,
                                max: 1,
                                unit: '',
                                divisions: 10,
                                onChanged: _viewModel.updateSpeakerExciter2HarmonicCoeffs,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.speakerExciter4HarmonicCoeffs,
                                value: _viewModel.speakerExciter4HarmonicCoeffs,
                                min: 0,
                                max: 1,
                                unit: '',
                                divisions: 10,
                                onChanged: _viewModel.updateSpeakerExciter4HarmonicCoeffs,
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.speakerExciter6HarmonicCoeffs,
                                value: _viewModel.speakerExciter6HarmonicCoeffs,
                                min: 0,
                                max: 1,
                                unit: '',
                                divisions: 10,
                                onChanged: _viewModel.updateSpeakerExciter6HarmonicCoeffs,
                              ),
                            ],
                          );
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
