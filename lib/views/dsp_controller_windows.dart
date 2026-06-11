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
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../components_windows/components_windows.dart';
import '../components_windows/global_gain_card.dart';
import '../components_windows/channel_balance_card.dart';
import '../components_windows/convolution_card.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_config.dart';

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
      backgroundColor: const Color(0xFFEEF2F7),
      body: Column(
        children: [
          WindowsTitleBar(title: 'WEcho'),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(-4, -4), blurRadius: 8, spreadRadius: 1),
                BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(4, -4), blurRadius: 8, spreadRadius: 1),
                BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(4, 4), blurRadius: 8, spreadRadius: 1),
                BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(-4, 4), blurRadius: 8, spreadRadius: 1),
              ],
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
                          color: _viewModel.masterEnabled ? const Color(0xFF334155) : const Color(0xFF888888),
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
                  inactiveTrackColor: const Color(0xFFE0E0E0),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = (constraints.maxWidth ~/ 340);
                  crossAxisCount = crossAxisCount.clamp(1, 4);
                  
                  return MasonryGridView.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    padding: const EdgeInsets.all(20),
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      switch (index) {
                        case 0:
                          return ChannelBalanceCard(
                            title: AppLocalizations.of(context)!.channelBalance,
                            description: AppLocalizations.of(context)!.channelBalanceDesc,
                            value: _viewModel.get<double>(ParamID.balanceEffectBalance),
                            min: -6,
                            max: 6,
                            unit: 'dB',
                            expanded: true,
                            onToggleExpand: () {},
                            onChanged: (value) => _viewModel.update(ParamID.balanceEffectBalance, value),
                          );
                        case 1:
                          return GlobalGainCard(
                            title: AppLocalizations.of(context)!.globalGain,
                            description: AppLocalizations.of(context)!.globalGainDesc,
                            value: _viewModel.get<double>(ParamID.gainEffectGain),
                            min: -15,
                            max: 3,
                            unit: 'dB',
                            expanded: true,
                            onToggleExpand: () {},
                            onChanged: (value) => _viewModel.update(ParamID.gainEffectGain, value),
                          );
                        case 2:
                          return MultiSliderControlCard(
                            icon: Icons.keyboard_double_arrow_down,
                            title: AppLocalizations.of(context)!.multiBandLimiter,
                            description: AppLocalizations.of(context)!.multiBandLimiterDesc,
                            enabled: _viewModel.get<bool>(ParamID.lookAheadSoftLimitEffectEnabled),
                            expanded: false,
                            onToggleExpand: () {},
                            onToggle: (value) => _viewModel.update(ParamID.lookAheadSoftLimitEffectEnabled, value),
                            sliders: [],
                          );
                        case 3:
                          return MultiSliderControlCard(
                            icon: Icons.compress,
                            title: AppLocalizations.of(context)!.limiter,
                            description: AppLocalizations.of(context)!.limiterDesc,
                            enabled: _viewModel.get<bool>(ParamID.limiterEffectEnabled),
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: (value) => _viewModel.update(ParamID.limiterEffectEnabled, value),
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterThreshold,
                                value: _viewModel.get<int>(ParamID.limiterEffectThreshold).toDouble(),
                                min: -30,
                                max: 0,
                                unit: 'dB',
                                divisions: 30,
                                onChanged: (value) => _viewModel.update(ParamID.limiterEffectThreshold, value.toInt()),
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterAttack,
                                value: _viewModel.get<int>(ParamID.limiterEffectAttack).toDouble(),
                                min: 1,
                                max: 200,
                                unit: 'ms',
                                divisions: 199,
                                onChanged: (value) => _viewModel.update(ParamID.limiterEffectAttack, value.toInt()),
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterRelease,
                                value: _viewModel.get<int>(ParamID.limiterEffectRelease).toDouble(),
                                min: 1,
                                max: 1000,
                                unit: 'ms',
                                divisions: 999,
                                onChanged: (value) => _viewModel.update(ParamID.limiterEffectRelease, value.toInt()),
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterRatio,
                                value: _viewModel.get<int>(ParamID.limiterEffectRatio).toDouble(),
                                min: 1,
                                max: 10,
                                unit: '',
                                divisions: 9,
                                onChanged: (value) => _viewModel.update(ParamID.limiterEffectRatio, value.toInt()),
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.limiterMakeupGain,
                                value: _viewModel.get<int>(ParamID.limiterEffectMakeupGain).toDouble(),
                                min: 0,
                                max: 15,
                                unit: 'dB',
                                divisions: 15,
                                onChanged: (value) => _viewModel.update(ParamID.limiterEffectMakeupGain, value.toInt()),
                              ),
                            ],
                          );
                        case 4:
                          return MultiSliderControlCard(
                            icon: Icons.graphic_eq,
                            title: AppLocalizations.of(context)!.highFrequencyGain,
                            description: AppLocalizations.of(context)!.highFrequencyGainDesc,
                            enabled: _viewModel.get<bool>(ParamID.clarityEffectEnabled),
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: (value) => _viewModel.update(ParamID.clarityEffectEnabled, value),
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.gain,
                                value: _viewModel.get<int>(ParamID.clarityEffectGain).toDouble(),
                                min: 0,
                                max: 15,
                                unit: '',
                                divisions: 15,
                                onChanged: (value) => _viewModel.update(ParamID.clarityEffectGain, value.toInt()),
                              ),
                            ],
                          );
                        case 5:
                          return MultiSliderControlCard(
                            icon: Icons.equalizer,
                            title: AppLocalizations.of(context)!.lowFrequencyGain,
                            description: AppLocalizations.of(context)!.lowFrequencyGainDesc,
                            enabled: _viewModel.get<bool>(ParamID.bassEffectEnabled),
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: (value) => _viewModel.update(ParamID.bassEffectEnabled, value),
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.gain,
                                value: _viewModel.get<int>(ParamID.bassEffectGain).toDouble(),
                                min: 0,
                                max: 15,
                                unit: '',
                                divisions: 15,
                                onChanged: (value) => _viewModel.update(ParamID.bassEffectGain, value.toInt()),
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.centerFreq,
                                value: _viewModel.get<int>(ParamID.bassEffectCenterFreq).toDouble(),
                                min: 30,
                                max: 100,
                                unit: 'Hz',
                                divisions: 70,
                                onChanged: (value) => _viewModel.update(ParamID.bassEffectCenterFreq, value.toInt()),
                              ),
                              SliderConfig(
                                label: AppLocalizations.of(context)!.q,
                                value: _viewModel.get<double>(ParamID.bassEffectQ),
                                min: 0.1,
                                max: 1.5,
                                unit: '',
                                divisions: 140,
                                decimalPlaces: 2,
                                onChanged: (value) => _viewModel.update(ParamID.bassEffectQ, value),
                              ),
                            ],
                          );
                        case 6:
                          return MultiSliderControlCard(
                            icon: Icons.hearing,
                            title: AppLocalizations.of(context)!.nice,
                            description: AppLocalizations.of(context)!.niceDesc,
                            enabled: _viewModel.get<bool>(ParamID.evenHarmonicEffectEnabled),
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: (value) => _viewModel.update(ParamID.evenHarmonicEffectEnabled, value),
                            sliders: [
                              SliderConfig(
                                label: AppLocalizations.of(context)!.niceBase,
                                value: _viewModel.get<int>(ParamID.evenHarmonicEffectBase).toDouble(),
                                min: 0,
                                max: 1,
                                unit: '',
                                divisions: 100,
                                decimalPlaces: 2,
                                onChanged: (value) => _viewModel.update(ParamID.evenHarmonicEffectBase, value.toInt()),
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
                          );
                        case 7:
                          return ConvolutionCard(
                            title: AppLocalizations.of(context)!.convolve,
                            description: AppLocalizations.of(context)!.convolveDesc,
                            mix: _viewModel.get<double>(ParamID.convolveEffectMix),
                            filePath: _viewModel.get<String>(ParamID.convolveEffectIrPath),
                            enabled: _viewModel.get<bool>(ParamID.convolveEffectEnabled),
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: (value) => _viewModel.update(ParamID.convolveEffectEnabled, value),
                            onMixChanged: (value) => _viewModel.update(ParamID.convolveEffectMix, value),
                            onFileSelected: (value) => _viewModel.update(ParamID.convolveEffectIrPath, value),
                          );
                        case 8:
                          return MultiSliderControlCard(
                            icon: Icons.filter_list, 
                            title: AppLocalizations.of(context)!.lowcat, 
                            description: AppLocalizations.of(context)!.lowcatDesc, 
                            enabled: _viewModel.get<bool>(ParamID.lowcatEffectEnabled),
                            expanded: true,
                            onToggleExpand: () {},
                            onToggle: (value) => _viewModel.update(ParamID.lowcatEffectEnabled, value),
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
                          );
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
