/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wecho/l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _shizukuMode = false;
  bool _autoOutputSwitch = true;
  String _version = 'Loading...';
  late final MethodChannel _channel;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _channel = const MethodChannel('audio_capture');
    _loadSettings();
    _loadVersion();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _shizukuMode = _prefs.getBool('shizukuMode') ?? false;
      _autoOutputSwitch = _prefs.getBool('autoOutputSwitch') ?? true;
    });
    await _setShizukuMode(_shizukuMode);
    await _setAutoOutputSwitch(_autoOutputSwitch);
  }

  Future<void> _loadVersion() async {
    try {
      final result = await _channel.invokeMethod('getAppVersion');
      setState(() {
        _version = result as String;
      });
    } on PlatformException {
      setState(() {
        _version = 'Unknown';
      });
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    await _prefs.setBool(key, value);
    switch (key) {
      case 'shizukuMode':
        await _setShizukuMode(value);
        break;
      case 'autoOutputSwitch':
        await _setAutoOutputSwitch(value);
        break;
    }
  }

  Future<void> _setShizukuMode(bool enabled) async {
    try {
      await _channel.invokeMethod('setShizukuMode', enabled);
    } on PlatformException catch (e) {
      debugPrint('Error setting shizuku mode: ${e.message}');
    }
  }

  Future<void> _setAutoOutputSwitch(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoOutputSwitch', enabled);
    } on PlatformException catch (e) {
      debugPrint('Error setting auto output switch: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Icon(
            Icons.arrow_back,
            color: colorScheme.primary,
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!.settings,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(AppLocalizations.of(context)!.captureSettings, colorScheme),
              const SizedBox(height: 12),
              _buildSettingsCard(
                children: [
                  _buildSwitchTile(
                    icon: Icons.settings_input_component,
                    title: AppLocalizations.of(context)!.shizukuMode,
                    subtitle: AppLocalizations.of(context)!.shizukuModeDesc,
                    value: _shizukuMode,
                    onChanged: (value) {
                      setState(() {
                        _shizukuMode = value;
                      });
                      _saveSetting('shizukuMode', value);
                    },
                    colorScheme: colorScheme,
                  ),
                  _buildDivider(colorScheme),
                  _buildSwitchTile(
                    icon: Icons.headphones,
                    title: AppLocalizations.of(context)!.autoOutputSwitch,
                    subtitle: AppLocalizations.of(context)!.autoOutputSwitchDesc,
                    value: _autoOutputSwitch,
                    onChanged: (value) {
                      setState(() {
                        _autoOutputSwitch = value;
                      });
                      _saveSetting('autoOutputSwitch', value);
                    },
                    colorScheme: colorScheme,
                  ),
                ],
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(AppLocalizations.of(context)!.info, colorScheme),
              const SizedBox(height: 12),
              _buildInfoCard(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSettingsCard({
    required List<Widget> children,
    required ColorScheme colorScheme,
  }) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: 0.3);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: 0.15);

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            blurRadius: 15,
            offset: const Offset(-5, -5),
          ),
          BoxShadow(
            color: darkShadow,
            blurRadius: 15,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme colorScheme,
  }) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: 0.3);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: 0.15);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: lightShadow,
                  blurRadius: 8,
                  offset: const Offset(-3, -3),
                ),
                BoxShadow(
                  color: darkShadow,
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: value ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
        height: 1,
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final lightShadow = baseColor.withRed(255).withGreen(255).withBlue(255).withValues(alpha: 0.3);
    final darkShadow = baseColor.withRed(0).withGreen(0).withBlue(0).withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            blurRadius: 15,
            offset: const Offset(-5, -5),
          ),
          BoxShadow(
            color: darkShadow,
            blurRadius: 15,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(AppLocalizations.of(context)!.captureSampleRate, '48000 Hz', colorScheme),
          _buildDetailRow(AppLocalizations.of(context)!.playbackSampleRate, '47999 Hz', colorScheme),
          _buildDetailRow(AppLocalizations.of(context)!.captureBitDepth, '32bit', colorScheme),
          _buildDetailRow(AppLocalizations.of(context)!.playbackBitDepth, '32bit', colorScheme),
          _buildDetailRow(AppLocalizations.of(context)!.applicationVersion, 'v$_version', colorScheme),
          const SizedBox(height: 8),
          _buildDetailRow(AppLocalizations.of(context)!.betaContaction, '1087859913', colorScheme),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
