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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wecho/l10n/app_localizations.dart';
import 'app_blacklist_page.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../styles/neumorphic_styles.dart';
import '../models/app_theme.dart';
import '../models/app_theme_manager.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final viewModel = widget.viewModel;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        top: false,
        child: ValueListenableBuilder<AppTheme>(
          valueListenable: AppThemeManager.currentTheme,
          builder: (context, _, __) => ValueListenableBuilder<ThemeMode>(
            valueListenable: AppThemeManager.currentMode,
            builder: (context, _, ___) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(l10n.appearance, colorScheme),
              const SizedBox(height: 12),
              _buildAppearanceCard(colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle(AppLocalizations.of(context)!.captureSettings, colorScheme),
              const SizedBox(height: 12),
              _buildSettingsCard(
                children: [
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
                  _buildSwitchTile(
                    icon: Icons.battery_saver,
                    title: AppLocalizations.of(context)!.powerSaving,
                    subtitle: AppLocalizations.of(context)!.powerSavingDesc,
                    value: viewModel.powerSaving,
                    onChanged: (value) => viewModel.setPowerSaving(value),
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
              _buildSectionTitle(AppLocalizations.of(context)!.loadingImage, colorScheme),
              const SizedBox(height: 12),
              _buildLoadingImageCard(context, colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle(AppLocalizations.of(context)!.info, colorScheme),
              const SizedBox(height: 12),
              _buildInfoCard(context, colorScheme),
            ],
          ),
        ),
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

  Widget _buildAppearanceCard(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    final baseColor = colorScheme.surface;
    final themes = AppTheme.values;

    String themeLabel(AppTheme theme) => switch (theme) {
      AppTheme.defaultTheme => l10n.themeDefault,
      AppTheme.greenApple => l10n.themeGreenApple,
      AppTheme.honey => l10n.themeHoney,
      AppTheme.strawberry => l10n.themeStrawberryDaiquiri,
      AppTheme.yinYang => l10n.themeYinYang,
      AppTheme.coralMagenta => l10n.themeCoralMagenta,
      AppTheme.lavenderPurple => l10n.themeLavenderPurple,
      AppTheme.tealCyan => l10n.themeTealCyan,
      AppTheme.random => l10n.themeRandom,
    };

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        boxShadow: NeumorphicStyles.mainCardShadow(baseColor),
      ),
      child: Column(
        children: [
          _buildDivider(colorScheme),
          _buildSwitchTile(
            icon: Icons.nightlight,
            title: l10n.darkMode,
            subtitle: l10n.darkModeDesc,
            value: AppThemeManager.isDark,
            onChanged: (_) => AppThemeManager.toggleDarkMode(),
            colorScheme: colorScheme,
          ),
          _buildDivider(colorScheme),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.applyTheme,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.applyColor,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: themes.length,
                  itemBuilder: (context, index) {
                    final theme = themes[index];
                    final isSelected = AppThemeManager.theme == theme;
                    final themeColor = AppThemeBuilder.build(theme, Brightness.light).primary;
                    return GestureDetector(
                      onTap: () {
                        AppThemeManager.setTheme(theme);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                          border: Border.all(
                            color: isSelected ? colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // 圆圈大小随卡片宽度变化（35%），缩放时自动调整
                                final circleSize = constraints.maxWidth * 0.35;
                                return Center(
                                  child: Container(
                                    width: circleSize,
                                    height: circleSize,
                                    decoration: BoxDecoration(
                                      color: themeColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: themeColor.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: isSelected
                                        ? Icon(Icons.check, color: Colors.white, size: circleSize * 0.5)
                                        : null,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),

                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                themeLabel(theme),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
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
    final isYinYangDark = colorScheme.brightness == Brightness.dark && colorScheme.primary == const Color(0xFFFFFFFF);

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
                  ? Icon(Icons.check, size: 12, color: isYinYangDark ? Colors.black : Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? (isYinYangDark ? Colors.black : colorScheme.primary) : colorScheme.onSurface,
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
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
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
            Icon(icon, size: 18, color: colorScheme.onPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onPrimary,
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
      final result = await FilePicker.saveFile(
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

  Widget _buildLoadingImageCard(BuildContext context, ColorScheme colorScheme) {
    final baseColor = colorScheme.surface;
    final viewModel = widget.viewModel;
    final l10n = AppLocalizations.of(context)!;
    final hasImage = viewModel.loadingImagePath != null && viewModel.loadingImagePath!.isNotEmpty;

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
              l10n.loadingImageDesc,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (hasImage)
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                    border: Border.all(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                    child: Image.file(
                      File(viewModel.loadingImagePath!),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/ic_wecho.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    l10n.selectLoadingImage,
                    Icons.image,
                    () => _selectLoadingImage(context),
                    colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                if (hasImage)
                  GestureDetector(
                    onTap: () => viewModel.setLoadingImagePath(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            l10n.clearLoadingImage,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectLoadingImage(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          await widget.viewModel.setLoadingImagePath(filePath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${AppLocalizations.of(context)!.loadingImage}: ${result.files.first.name}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.selectLoadingImage}: $e')),
        );
      }
    }
  }
}
