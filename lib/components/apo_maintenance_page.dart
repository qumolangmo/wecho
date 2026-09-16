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
import '../l10n/app_localizations.dart';
import '../models/apo_installer.dart';
import '../styles/neumorphic_styles.dart';

class ApoMaintenancePage extends StatefulWidget {
  const ApoMaintenancePage({super.key});

  @override
  State<ApoMaintenancePage> createState() => _ApoMaintenancePageState();
}

class _ApoMaintenancePageState extends State<ApoMaintenancePage> {
  final ApoInstaller _installer = ApoInstaller();
  ApoStatus? _status;
  bool _loading = true;
  String? _statusError;
  bool _busy = false;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await _installer.getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
        _statusError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusError = e.toString();
      });
    }
  }

  Future<void> _runOp(Future<ApoOpResult> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await op();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _log.addAll(result.log);
      if (_log.length > 400) {
        _log.removeRange(0, _log.length - 400);
      }
    });

    final l10n = AppLocalizations.of(context)!;
    String message;
    if (result.cancelled) {
      message = l10n.apoUacCancelled;
    } else if (result.success) {
      message = l10n.apoOpSuccess;
    } else {
      message = result.error.isEmpty
          ? l10n.apoOpFailed
          : '${l10n.apoOpFailed}: ${result.error}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    _refreshStatus();
  }

  void _confirmUninstall() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.apoUninstallConfirmTitle),
        content: Text(l10n.apoUninstallConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _runOp(_installer.uninstall);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

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
          l10n.apoMaintenance,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(l10n.apoMaintenance, colorScheme),
                  const SizedBox(height: 12),
                  _buildStatusCard(colorScheme),
                  const SizedBox(height: 24),
                  _buildSectionTitle(l10n.apoDevices, colorScheme),
                  const SizedBox(height: 12),
                  _buildDevicesCard(colorScheme),
                  const SizedBox(height: 24),
                  if (_log.isNotEmpty) ...[
                    _buildSectionTitle(l10n.exportLogs, colorScheme),
                    const SizedBox(height: 12),
                    _buildLogCard(colorScheme),
                  ],
                ],
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
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

  Widget _buildCard({required Widget child, required ColorScheme colorScheme}) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        boxShadow: NeumorphicStyles.mainCardShadow(colorScheme.surface),
      ),
      child: child,
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return _buildCard(
        colorScheme: colorScheme,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      );
    }

    if (_statusError != null || _status == null) {
      return _buildCard(
        colorScheme: colorScheme,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.apoStatusFailed,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                _statusError ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final installed = _status!.installed;
    return _buildCard(
      colorScheme: colorScheme,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  installed ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: installed ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  installed ? l10n.apoInstalled : l10n.apoNotInstalled,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (_status!.installDir.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${l10n.apoInstallDir}: ${_status!.installDir}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: l10n.apoInstall,
                    icon: Icons.download_for_offline,
                    onTap: installed || _busy
                        ? null
                        : () => _runOp(_installer.install),
                    colorScheme: colorScheme,
                    enabled: !installed && !_busy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: l10n.apoUninstall,
                    icon: Icons.delete_forever,
                    onTap: !installed || _busy
                        ? null
                        : _confirmUninstall,
                    colorScheme: colorScheme,
                    enabled: installed && !_busy,
                    danger: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: l10n.apoUpdate,
                    icon: Icons.update,
                    onTap: !installed || _busy
                        ? null
                        : () => _runOp(_installer.update),
                    colorScheme: colorScheme,
                    enabled: installed && !_busy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: l10n.apoRestartAudioService,
                    icon: Icons.restart_alt,
                    onTap: _busy ? null : () => _runOp(_installer.restartAudioService),
                    colorScheme: colorScheme,
                    enabled: !_busy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.apoRestartHint,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesCard(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return _buildCard(
        colorScheme: colorScheme,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      );
    }

    final devices = _status?.devices ?? const <ApoDevice>[];
    if (devices.isEmpty) {
      return _buildCard(
        colorScheme: colorScheme,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.noAppsFound,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return _buildCard(
      colorScheme: colorScheme,
      child: Column(
        children: [
          for (var i = 0; i < devices.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                  height: 1,
                ),
              ),
            _buildDeviceTile(devices[i], colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceTile(ApoDevice device, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    final canToggle = !_busy && device.state == 'active';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_stateLabel(device.state)} · ${device.bound ? l10n.apoBound : l10n.apoNotBound}',
                  style: TextStyle(
                    fontSize: 12,
                    color: device.bound
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: canToggle
                ? () => _runOp(
                    () => device.bound
                        ? _installer.unbindDevice(device.guid)
                        : _installer.bindDevice(device.guid))
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: canToggle
                    ? (device.bound
                        ? colorScheme.error.withValues(alpha: 0.1)
                        : colorScheme.primary.withValues(alpha: 0.1))
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
              ),
              child: Text(
                device.bound ? l10n.apoUnbindAction : l10n.apoBind,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: !canToggle
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                      : device.bound
                          ? colorScheme.error
                          : colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stateLabel(String state) {
    final l10n = AppLocalizations.of(context)!;
    switch (state) {
      case 'active':
        return l10n.apoStateActive;
      case 'disabled':
        return l10n.apoStateDisabled;
      case 'unplugged':
        return l10n.apoStateUnplugged;
      case 'notpresent':
        return l10n.apoStateNotPresent;
      default:
        return l10n.apoStateUnknown;
    }
  }

  Widget _buildLogCard(ColorScheme colorScheme) {
    return _buildCard(
      colorScheme: colorScheme,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          reverse: true,
          child: SelectableText(
            _log.join('\n'),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required ColorScheme colorScheme,
    required bool enabled,
    bool danger = false,
  }) {
    final color = !enabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : danger
            ? colorScheme.error
            : colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: enabled
              ? (danger
                  ? colorScheme.error.withValues(alpha: 0.12)
                  : colorScheme.primary.withValues(alpha: 0.12))
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
