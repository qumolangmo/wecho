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
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/components.dart';
import '../view_models/dsp_controller_view_model.dart';
import 'effect_card_schema.dart';
import '../l10n/app_localizations.dart';
import '../styles/neumorphic_styles.dart';

class DSPController extends StatefulWidget {
  final DSPControllerViewModel? viewModel;
  const DSPController({super.key, this.viewModel});

  @override
  State<DSPController> createState() => _DSPControllerState();
}

class _DSPControllerState extends State<DSPController> with WidgetsBindingObserver {
  late DSPControllerViewModel _viewModel;
  StreamSubscription<String>? _scriptErrorSubscription;

  final ScrollController _mainScrollController = ScrollController();

  double _statusBarHeight = 24;

  void _updateStatusBarHeight() {
    final top = MediaQuery.of(context).padding.top;
    _statusBarHeight = (top > 0 && top < 100) ? top : 24;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = widget.viewModel ?? DSPControllerViewModel(
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    if (widget.viewModel != null) {
      _viewModel.onStateChanged = () {
        if (mounted) setState(() {});
      };
    }
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

    _viewModel.initialized.then((_) {
      if (!mounted) return;
      _viewModel.startCaptureWorkflow();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scriptErrorSubscription?.cancel();
    _mainScrollController.dispose();

    if (widget.viewModel != null) {
      _viewModel.onStateChanged = null;
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateStatusBarHeight();
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    _updateStatusBarHeight();

    return MediaQuery.removePadding(
      removeTop: true,
      context: context,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: colorScheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: colorScheme.brightness,
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _mainScrollController,
                builder: (context, _) {
                  final t = clampDouble(
                    _mainScrollController.hasClients ? _mainScrollController.offset / 400 : 0,
                    0,
                    1,
                  );
                  return Container(
                    color: Color.lerp(colorScheme.surface, colorScheme.surfaceVariant, t),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: _statusBarHeight),
                        SizedBox(
                          height: 50,
                          // Latency polls every second; listen locally so only
                          // the header rebuilds instead of the whole page.
                          child: ValueListenableBuilder<double>(
                            valueListenable: _viewModel.latencyNotifier,
                            builder: (context, latency, _) => AppHeader(
                              isCapturing: _viewModel.isCapturing,
                              showCaptureButton: false,
                              processingLatencyMs: latency,
                              onCapturePressed: _viewModel.toggleCapture,
                              onSettingsPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SettingsPage(viewModel: _viewModel)),
                                );
                                if (mounted) setState(() {});
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    children: [
                      SafeArea(
                        top: false,
                        bottom: true,
                        left: true,
                        right: true,
                        child: SingleChildScrollView(
                          controller: _mainScrollController,
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Column(
                            children: [
                            for (final spec in _viewModel.effectCards) ...[
                              _buildEffectCard(context, spec, l10n),
                              const SizedBox(height: 16),
                            ],
                            const SizedBox(height: 104),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: NeumorphicStyles.spacingXXXL - 2,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 260,
                            height: 66,
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXXLarge),
                              boxShadow: [
                                BoxShadow(
                                  color: NeumorphicStyles.darkShadow(colorScheme.surface),
                                  blurRadius: NeumorphicStyles.shadowBlurXXLarge,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => ConfigManagerPage(viewModel: _viewModel),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 53,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              colorScheme.primary,
                                              colorScheme.primary.withValues(alpha: 0.8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colorScheme.primary.withValues(alpha: 0.3),
                                              blurRadius: NeumorphicStyles.shadowBlurSmall,
                                              offset: const Offset(0, 0),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.density_small,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        _viewModel.updateMasterEnabled(!_viewModel.masterEnabled);
                                      },
                                      child: Container(
                                        width: 53,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: _viewModel.masterEnabled
                                                ? [
                                                    colorScheme.primary,
                                                    colorScheme.primary.withValues(alpha: 0.8),
                                                  ]
                                                : [
                                                    colorScheme.surfaceVariant,
                                                    colorScheme.surfaceVariant.withValues(alpha: 0.8),
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _viewModel.masterEnabled
                                                  ? colorScheme.primary.withValues(alpha: 0.3)
                                                  : NeumorphicStyles.darkShadow(colorScheme.surface),
                                              blurRadius: NeumorphicStyles.shadowBlurSmall,
                                              offset: const Offset(0, 0),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.power_settings_new,
                                          color: _viewModel.masterEnabled ? Colors.white : colorScheme.onSurfaceVariant,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => SettingsPage(viewModel: _viewModel)),
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      child: Container(
                                        width: 53,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              colorScheme.primary,
                                              colorScheme.primary.withValues(alpha: 0.8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colorScheme.primary.withValues(alpha: 0.3),
                                              blurRadius: NeumorphicStyles.shadowBlurSmall,
                                              offset: const Offset(0, 0),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.settings,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  /// Renders one effect card from its untyped tuple (see [_buildEffectCards]
  /// in the view model for the tuple layout).
  Widget _buildEffectCard(BuildContext context, List<dynamic> c, AppLocalizations l10n) =>
      EffectCardRenderer(_viewModel).buildCard(context, c, l10n);
}
