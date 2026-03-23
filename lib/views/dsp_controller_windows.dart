/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import '../components_windows/components_windows.dart';
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
      backgroundColor: const Color(0xFFEEF2F7),
      body: Column(
        children: [
          WindowsTitleBar(title: 'WEcho'),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: MultiSliderControlCard(
                  icon: Icons.equalizer,
                  title: AppLocalizations.of(context)!.lowFrequencyGain,
                  description: AppLocalizations.of(context)!.lowFrequencyGainDesc,
                  enabled: _viewModel.bassBoostEnabled,
                  expanded: _viewModel.bassBoostExpanded,
                  onToggleExpand: _viewModel.toggleBassBoostExpanded,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
