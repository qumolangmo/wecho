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

import 'dart:async' show Timer;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../l10n/app_localizations.dart';
import '../models/apo_installer.dart';
import '../view_models/dsp_controller_view_model.dart';

class AppHeader extends StatefulWidget {
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onCapturePressed;
  final bool isCapturing;
  final bool showCaptureButton;
  final double processingLatencyMs;

  const AppHeader({
    super.key,
    this.onSettingsPressed,
    this.onCapturePressed,
    this.isCapturing = false,
    this.showCaptureButton = true,
    this.processingLatencyMs = 0,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> with WindowListener {
  static const MethodChannel _dspChannel = MethodChannel('wecho_dsp');

  bool _maximized = false;
  bool _versionMismatch = false;
  bool _versionCheckInFlight = false;
  bool _pipeConnected = false;
  Timer? _pipeTimer;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((v) {
        if (mounted) {
          setState(() => _maximized = v);
        }
      });

      _pipeTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollPipe());
    }
  }

  @override
  void dispose() {
    _pipeTimer?.cancel();
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _pollPipe() async {
    try {
      final connected = await _dspChannel.invokeMethod<bool>('getPipeConnected') ?? false;
      if (!mounted || connected == _pipeConnected) return;
      setState(() => _pipeConnected = connected);
    } on PlatformException {
      if (!mounted || !_pipeConnected) return;
      setState(() => _pipeConnected = false);
    } on MissingPluginException {
      _pipeTimer?.cancel();
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _maximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _maximized = false);
    }
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  /* Flat caption button in Windows chrome style: transparent at rest, a
   * subtle surface tint on hover and a red plate for close.
   */
  Widget _captionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? hoverColor,
    Color? hoverIconColor,
  }) {
    return _CaptionButton(icon: icon, onTap: onTap, hoverColor: hoverColor, hoverIconColor: hoverIconColor);
  }

  Widget _windowButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _captionButton(icon: Icons.horizontal_rule, onTap: windowManager.minimize),
        _captionButton(icon: _maximized ? Icons.filter_none : Icons.crop_square, onTap: _toggleMaximize),
        _captionButton(
          icon: Icons.close,
          onTap: windowManager.close,
          hoverColor: Theme.of(context).colorScheme.error,
          hoverIconColor: Colors.white,
        ),
      ],
    );
  }

  /* The version recorded at the last successful APO install / update must
   * match this build's version, otherwise keep a reminder plate visible on
   * the left side of the title bar. Re-checked on every rebuild: popping
   * back from the maintenance page rebuilds this header, so the plate
   * clears live without any event plumbing. No record yet means the APO
   * was never installed, so there is nothing to compare.
   */
  Future<void> _checkApoVersion() async {
    if (_versionCheckInFlight) return;
    _versionCheckInFlight = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ApoInstaller.apoUiVersionKey);
    final current = await ApoInstaller().getAppVersion();
    _versionCheckInFlight = false;
    if (!mounted) return;
    final mismatch = saved != null && saved != current;
    if (mismatch == _versionMismatch) return;
    setState(() => _versionMismatch = mismatch);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWindows = Platform.isWindows;
    if (isWindows) {
      _checkApoVersion();
    }

    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'WEcho',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: 1,
          ),
        ),
        if (isWindows) ...[
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _pipeConnected ? Colors.green : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
        if (widget.isCapturing) ...[
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.processingLatencyMs <= 4
                          ? Colors.green
                          : widget.processingLatencyMs <= 8
                              ? Colors.yellow
                              : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'latency: ${widget.processingLatencyMs.toStringAsFixed(2)} ms',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                'deadline: ${DSPControllerViewModel.deadlineMs.toStringAsFixed(2)} ms',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, isWindows ? 0 : 20, 4),
      child: Stack(
        children: [
          /* Title absolutely centered against the full window width; the
           * caption buttons overlay it on the right. Hit testing prefers the
           * top layer, so buttons stay clickable and the rest drags.
           */
          Positioned.fill(
            child: GestureDetector(
              onDoubleTap: isWindows ? _toggleMaximize : null,
              child: DragToMoveArea(
                child: Center(child: title),
              ),
            ),
          ),
          if (isWindows && _versionMismatch)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.apoVersionMismatch,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          if (isWindows)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      size: 24,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: widget.onSettingsPressed,
                  ),
                  _windowButtons(),
                ],
              ),
            )
          else
            const Align(
              alignment: Alignment.centerRight,
              child: SizedBox(width: 32),
            )
        ],
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;
  final Color? hoverIconColor;

  const _CaptionButton({required this.icon, required this.onTap, this.hoverColor, this.hoverIconColor});

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 36,
          color: hovered ? (widget.hoverColor ?? colorScheme.onSurface.withValues(alpha: 0.08)) : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 18,
            color: hovered ? (widget.hoverIconColor ?? colorScheme.onSurface) : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
