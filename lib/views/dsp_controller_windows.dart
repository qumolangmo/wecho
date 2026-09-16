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

import '../components/app_header.dart';
import '../components/components.dart';
import '../components/effect_detail_pane.dart';
import '../components/effect_list_pane.dart';
import '../styles/neumorphic_styles.dart';
import '../view_models/dsp_controller_view_model.dart';

/// Windows desktop home: master-detail layout. Left rail lists the effects
/// (icon/title/mini switch), right pane edits the selected effect.
/// Android-only features (capture, Shizuku, app blacklist, auto output
/// switch) are intentionally absent.
class DspControllerWindows extends StatefulWidget {
  final DSPControllerViewModel viewModel;

  const DspControllerWindows({super.key, required this.viewModel});

  @override
  State<DspControllerWindows> createState() => _DspControllerWindowsState();
}

class _DspControllerWindowsState extends State<DspControllerWindows> {
  late final DSPControllerViewModel _viewModel = widget.viewModel;

  int _selectedIndex = 3;

  void _handleStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _viewModel.onStateChanged = _handleStateChanged;
  }

  @override
  void dispose() {
    if (_viewModel.onStateChanged == _handleStateChanged) {
      _viewModel.onStateChanged = null;
    }
    super.dispose();
  }

  Widget _buildCard(BuildContext context, {double? width, required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(NeumorphicStyles.radiusXLarge);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: radius,
        boxShadow: NeumorphicStyles.mainCardShadow(colorScheme.surface),
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Latency polls every second; listen locally so only the header
            // rebuilds instead of the whole page.
            ValueListenableBuilder<double>(
              valueListenable: _viewModel.latencyNotifier,
              builder: (context, latency, _) => AppHeader(
                isCapturing: _viewModel.isCapturing,
                showCaptureButton: false,
                processingLatencyMs: latency,
                onCapturePressed: () {},
                onSettingsPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(viewModel: _viewModel),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCard(
                      context,
                      width: 260,
                      child: EffectListPane(
                        viewModel: _viewModel,
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() => _selectedIndex = i),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCard(
                        context,
                        child: EffectDetailPane(
                          viewModel: _viewModel,
                          spec: _viewModel.effectCards[_selectedIndex],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
