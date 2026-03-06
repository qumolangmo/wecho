/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/components.dart';
import 'view_models/dsp_controller_view_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WEcho',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: [
        Locale('en'),
        Locale('zh')
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D4FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const DSPController(),
    );
  }
}

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
            onCapturePressed: _viewModel.toggleCapture,
            onSettingsPressed: () => showDialog(
            context: context,
            builder: (BuildContext context) => const DetailsDialog(),
          ),
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
                value: _viewModel.channelBalance,
                min: -6,
                max: 6,
                unit: 'dB',
                expanded: _viewModel.channelBalanceExpanded,
                onToggleExpand: _viewModel.toggleChannelBalanceExpanded,
                onChanged: _viewModel.updateChannelBalance,
              ),
              const SizedBox(height: 16),
              ControlCard(
                icon: Icons.volume_up,
                title: AppLocalizations.of(context)!.globalGain,
                description: AppLocalizations.of(context)!.globalGainDesc,
                value: _viewModel.globalGain,
                min: -15,
                max: 3,
                unit: 'dB',
                expanded: _viewModel.globalGainExpanded,
                onToggleExpand: _viewModel.toggleGlobalGainExpanded,
                onChanged: _viewModel.updateGlobalGain,
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
                icon: Icons.compress, 
                title: AppLocalizations.of(context)!.limiter,
                description: AppLocalizations.of(context)!.limiterDesc,
                enabled: _viewModel.limiterEnabled,
                expanded: _viewModel.limiterExpanded, 
                onToggleExpand: _viewModel.toggleLimiterExpanded,
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
              ),
              const SizedBox(height: 16),
              SwitchControlCard(
                icon: Icons.graphic_eq,
                title: AppLocalizations.of(context)!.highFrequencyGain,
                description: AppLocalizations.of(context)!.highFrequencyGainDesc,
                value: _viewModel.clarity,
                min: 0,
                max: 15,
                unit: '',
                enabled: _viewModel.clarityEnabled,
                expanded: _viewModel.clarityExpanded,
                onToggleExpand: _viewModel.toggleClarityExpanded,
                onToggle: _viewModel.updateClarityEnabled,
                onChanged: _viewModel.updateClarity,
              ),
              const SizedBox(height: 16),
              MultiSliderControlCard(
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
              const SizedBox(height: 16),
              SwitchControlCard(
                icon: Icons.hearing,
                title: AppLocalizations.of(context)!.nice,
                description: AppLocalizations.of(context)!.niceDesc,
                value: _viewModel.evenHarmonicGain,
                min: 0,
                max: 15,
                unit: '',
                enabled: _viewModel.evenHarmonicEnabled,
                expanded: _viewModel.evenHarmonicExpanded,
                onToggleExpand: _viewModel.toggleEvenHarmonicExpanded,
                onToggle: _viewModel.updateEvenHarmonicEnabled,
                onChanged: _viewModel.updateEvenHarmonicGain,
              ),
              const SizedBox(height: 16),
              ConvolveControlCard(
                icon: Icons.waves,
                title: AppLocalizations.of(context)!.convolve,
                description: AppLocalizations.of(context)!.convolveDesc,
                mixValue: _viewModel.convolveMix,
                mixMin: 0,
                mixMax: 1,
                irPath: _viewModel.convolveIrPath,
                enabled: _viewModel.convolveEnabled,
                expanded: _viewModel.convolveExpanded,
                onToggleExpand: _viewModel.toggleConvolveExpanded,
                onToggle: _viewModel.updateConvolveEnabled,
                onMixChanged: _viewModel.updateConvolveMix,
                onIrPathChanged: _viewModel.updateConvolveIrPath,
              ),
              const SizedBox(height: 100),
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
                      ? const Color(0xFF00D4FF).withOpacity(0.4)
                      : Colors.black.withOpacity(0.2),
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
