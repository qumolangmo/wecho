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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wecho/l10n/app_localizations.dart';
import 'app_blacklist_page.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../styles/neumorphic_styles.dart';

class SettingsPage extends StatefulWidget {
  final DSPControllerViewModel viewModel;
  const SettingsPage({super.key, required this.viewModel});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Function()? _previousCallback;

  @override
  void initState() {
    super.initState();
    _previousCallback = widget.viewModel.onStateChanged;
    widget.viewModel.onStateChanged = _onViewModelStateChanged;
  }

  void _onViewModelStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.viewModel.onStateChanged = _previousCallback;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewModel = widget.viewModel;

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
                    value: viewModel.shizukuMode,
                    onChanged: (value) => viewModel.setShizukuMode(value),
                    colorScheme: colorScheme,
                  ),
                  _buildDivider(colorScheme),
                  _buildSwitchTile(
                    icon: Icons.headphones,
                    title: AppLocalizations.of(context)!.autoOutputSwitch,
                    subtitle: AppLocalizations.of(context)!.autoOutputSwitchDesc,
                    value: viewModel.autoOutputSwitch,
                    onChanged: (value) => viewModel.setAutoOutputSwitch(value),
                    colorScheme: colorScheme,
                  ),
                  _buildDivider(colorScheme),
                  _buildNavigationTile(
                    icon: Icons.block,
                    title: AppLocalizations.of(context)!.appBlacklist,
                    subtitle: AppLocalizations.of(context)!.appBlacklistDesc,
                    count: viewModel.appBlacklist.length,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppBlacklistPage(viewModel: viewModel),
                        ),
                      );
                      setState(() {});
                    },
                    colorScheme: colorScheme,
                  ),
                ],
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(AppLocalizations.of(context)!.logSettings, colorScheme),
              const SizedBox(height: 12),
              _buildLogSettingsCard(context, colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle(AppLocalizations.of(context)!.info, colorScheme),
              const SizedBox(height: 12),
              _buildInfoCard(context, colorScheme),
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

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        boxShadow: NeumorphicStyles.mainCardShadow(baseColor),
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
              boxShadow: NeumorphicStyles.activeIconBoxShadow(baseColor),
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

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    final baseColor = colorScheme.surface;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                boxShadow: NeumorphicStyles.activeIconBoxShadow(baseColor),
              ),
              child: Icon(icon, color: count > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final viewModel = widget.viewModel;

    return Container(
      padding: NeumorphicStyles.paddingXLarge,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        boxShadow: NeumorphicStyles.mainCardShadow(baseColor),
      ),
      child: Column(
        children: [
          _buildDetailRow(AppLocalizations.of(context)!.captureSampleRate, '48000 Hz', colorScheme),
          _buildDetailRow(AppLocalizations.of(context)!.playbackSampleRate, '48000 Hz', colorScheme),
          _buildDetailRow(AppLocalizations.of(context)!.captureBitDepth, '32bit', colorScheme),
          _buildDetailRow(AppLocalizations.of(context)!.playbackBitDepth, '32bit', colorScheme),
          _buildDetailRow('Shizuku', viewModel.shizukuConnected ? 'Granted' : 'Not Granted', colorScheme),
          _buildDetailRow('Audio Output', viewModel.currentAudioOutput, colorScheme),
          const SizedBox(height: 8),
          _buildDetailRow(AppLocalizations.of(context)!.applicationVersion, 'v${viewModel.appVersion}', colorScheme),
          const SizedBox(height: 8),
          _buildDetailRow(AppLocalizations.of(context)!.betaContaction, '1087859913', colorScheme),
          _buildDetailRow(AppLocalizations.of(context)!.discord, 'https://discord.gg/RZcXwhmUNt', colorScheme),
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

  Widget _buildLogSettingsCard(BuildContext context, ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final viewModel = widget.viewModel;

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        boxShadow: NeumorphicStyles.mainCardShadow(baseColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.exportLogLevel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.exportLogLevelDesc,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildLogLevelChip(
              'wecho-kotlin',
              AppLocalizations.of(context)!.ktLogs,
              viewModel,
              colorScheme,
            ),
            const SizedBox(height: 8),
            _buildLogLevelChip(
              'wecho-native',
              AppLocalizations.of(context)!.nativeLogs,
              viewModel,
              colorScheme,
            ),
            const SizedBox(height: 8),
            _buildLogLevelChip(
              'framework',
              AppLocalizations.of(context)!.frameworkLogs,
              viewModel,
              colorScheme,
            ),
            const SizedBox(height: 16),
            _buildDivider(colorScheme),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.logMaxCount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.logMaxCountDesc,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildLogMaxCountSelector(context, colorScheme),
            const SizedBox(height: 16),
            _buildDivider(colorScheme),
            const SizedBox(height: 16),
            _buildActionButton(
              AppLocalizations.of(context)!.exportLogs,
              Icons.download,
              () => _exportLogs(context),
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogLevelChip(
    String level,
    String label,
    DSPControllerViewModel viewModel,
    ColorScheme colorScheme,
  ) {
    final isSelected = viewModel.logLevels.contains(level);

    return GestureDetector(
      onTap: () => viewModel.toggleLogLevel(level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  width: 2,
                ),
                color: isSelected ? colorScheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogMaxCountSelector(BuildContext context, ColorScheme colorScheme) {
    final viewModel = widget.viewModel;
    final counts = [
      {'label': AppLocalizations.of(context)!.count100, 'value': 100},
      {'label': AppLocalizations.of(context)!.count200, 'value': 200},
      {'label': AppLocalizations.of(context)!.count500, 'value': 500},
      {'label': AppLocalizations.of(context)!.count1000, 'value': 1000},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: counts.map((count) {
        final isSelected = viewModel.logMaxCount == count['value'];
        return GestureDetector(
          onTap: () => viewModel.setLogMaxCount(count['value'] as int),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
            ),
            child: Text(
              count['label'] as String,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    final viewModel = widget.viewModel;
    final logs = await viewModel.getLogs();
    final l10n = AppLocalizations.of(context)!;

    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.logsExportFailed)),
      );
      return;
    }

    logs.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

    final String logText = logs.map((log) {
      final tag = log['tag'] ?? '';
      final message = log['message'] ?? '';
      final timestamp = log['timestamp'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}.${(timestamp % 1000).toString().padLeft(3, '0')}';
      return '$timeStr [${tag.isNotEmpty ? tag : 'framework'}] $message';
    }).join('\n');

    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportLogs,
        fileName: 'wecho_logs_${DateTime.now().toIso8601String().replaceAll(':', '-')}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: utf8.encode(logText),
      );

      if (!mounted) return;

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.logsExported)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.logsExportFailed}: $e')),
        );
      }
    }
  }
}
