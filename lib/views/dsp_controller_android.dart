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
import '../models/audio_config.dart';
import '../view_models/dsp_controller_view_model.dart';
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
                          child: AppHeader(
                            isCapturing: _viewModel.isCapturing,
                            showCaptureButton: false,
                            processingLatencyMs: _viewModel.processingLatencyMs,
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
  Widget _buildEffectCard(BuildContext context, List<dynamic> c, AppLocalizations l10n) {
    final expandKey = c[0] as String?;
    final enabledId = c[4] as ParamID?;
    final sliders = c[5] as List;
    final subtitle = c.length > 6 && c[6] != null ? (c[6] as Function)(_viewModel, l10n) as String : null;
    final enabled = enabledId == null ? true : _viewModel.get<bool>(enabledId);
    final leading = c.length > 7 && c[7] != null
        ? ((c[7] as Function)(context, _viewModel) as List).map((w) => _buildSchemaWidget(w, enabled)).toList()
        : null;

    if (enabledId == null) {
      final s = sliders.single as List;
      final id = s[0] as ParamID;
      return ControlCard(
        icon: c[1] as IconData,
        title: (c[2] as Function)(l10n) as String,
        description: (c[3] as Function)(l10n) as String,
        value: clampDouble(_viewModel.get<num>(id).toDouble(), (s[2] as num).toDouble(), (s[3] as num).toDouble()),
        min: (s[2] as num).toDouble(),
        max: (s[3] as num).toDouble(),
        unit: s.length > 5 ? s[5] as String : '',
        expanded: _viewModel.isExpanded(expandKey!),
        onToggleExpand: () => _viewModel.toggleExpanded(expandKey),
        onChanged: (v) => _viewModel.update(id, v),
      );
    }

    return GenericControlCard(
      icon: c[1] as IconData,
      title: (c[2] as Function)(l10n) as String,
      subtitle: subtitle ?? '',
      description: (c[3] as Function)(l10n) as String,
      enabled: enabled,
      expanded: expandKey == null ? null : _viewModel.isExpanded(expandKey),
      onToggleExpand: expandKey == null ? null : () => _viewModel.toggleExpanded(expandKey),
      onToggle: (v) => _viewModel.update(enabledId, v),
      children: [
        ...?leading,
        for (final t in sliders) _buildSlider(t, l10n, enabled),
      ],
    );
  }

  /// Resolves one widget-schema node (untyped tuple) or passes through an
  /// already-built widget. Supported nodes:
  /// - `['selector', [[value, label, deletable?]...], selected, onSelect, onDelete?, hint?]`
  /// - `['button', onTap, [children...], padding?]` (enabled follows the card switch)
  /// - `['row', [children...]]`, `['expanded', child]`
  /// - `['icon', iconData, color, size?]`, `['text', label, style?, ellipsis?]`
  /// - `['gap', size]` (vertical), `['hgap', size]` (horizontal)
  Widget _buildSchemaWidget(dynamic w, bool enabled) {
    if (w is Widget) return w;
    final t = w as List;
    switch (t[0] as String) {
      case 'selector':
        return NeumorphicSelector<dynamic>(
          items: (t[1] as List)
              .map((it) => SelectorItem(
                    value: (it as List)[0],
                    label: it[1] as String,
                    deletable: it.length > 2 && it[2] == true,
                  ))
              .toList(),
          selectedValue: t[2],
          onSelect: t[3] as void Function(dynamic)?,
          onDelete: t.length > 4 ? t[4] as void Function(dynamic)? : null,
          enabled: enabled,
          hint: t.length > 5 ? t[5] as String : 'Select',
        );
      case 'button':
        return NeumorphicButton(
          onTap: t[1] as VoidCallback?,
          enabled: enabled,
          padding: t.length > 3
              ? t[3] as EdgeInsets
              : const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          children: [
            for (final c in t[2] as List) _buildSchemaWidget(c, enabled),
          ],
        );
      case 'row':
        return Row(
          children: [
            for (final c in t[1] as List) _buildSchemaWidget(c, enabled),
          ],
        );
      case 'expanded':
        return Expanded(child: _buildSchemaWidget(t[1], enabled));
      case 'icon':
        return Icon(
          t[1] as IconData,
          color: t[2] as Color?,
          size: t.length > 3 ? (t[3] as num).toDouble() : 20,
        );
      case 'text':
        return Text(
          t[1] as String,
          style: t.length > 2 && t[2] != null ? t[2] as TextStyle : null,
          overflow: t.length > 3 && t[3] == true ? TextOverflow.ellipsis : null,
        );
      case 'gap':
        return SizedBox(height: (t[1] as num).toDouble());
      case 'hgap':
        return SizedBox(width: (t[1] as num).toDouble());
    }
    throw ArgumentError('Unknown widget schema node: $t');
  }

  /// Renders one slider from its untyped tuple
  /// `[id, label, min, max, divisions, unit?, isInt?, showDivider?]`.
  Widget _buildSlider(List<dynamic> t, AppLocalizations l10n, bool enabled) {
    final id = t[0] as ParamID;
    final min = (t[2] as num).toDouble();
    final max = (t[3] as num).toDouble();
    return NeumorphicSlider(
      label: (t[1] as Function)(l10n) as String,
      value: clampDouble(_viewModel.get<num>(id).toDouble(), min, max),
      min: min,
      max: max,
      unit: t.length > 5 ? t[5] as String : '',
      divisions: t[4] as int,
      enabled: enabled,
      showDivider: t.length > 7 ? t[7] as bool : true,
      onChanged: (v) => t.length > 6 && t[6] == true
          ? _viewModel.update(id, v.toInt())
          : _viewModel.update(id, v),
    );
  }
}
