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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:wecho/l10n/app_localizations.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../styles/neumorphic_styles.dart';

class AppBlacklistPage extends StatefulWidget {
  final DSPControllerViewModel viewModel;
  const AppBlacklistPage({super.key, required this.viewModel});

  @override
  State<AppBlacklistPage> createState() => _AppBlacklistPageState();
}

class _AppBlacklistPageState extends State<AppBlacklistPage> with WidgetsBindingObserver {
  late Set<String> _selectedPackages;
  String _searchQuery = '';
  Function()? _previousCallback;

  DSPControllerViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedPackages = Set.from(vm.appBlacklist);
    _previousCallback = vm.onStateChanged;
    vm.onStateChanged = _onViewModelStateChanged;

    vm.loadInstalledApps();
  }

  void _onViewModelStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && vm.appsLoadState == AppsLoadState.noPermission) {
      vm.loadInstalledApps();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    vm.onStateChanged = _previousCallback;
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredApps {
    if (_searchQuery.isEmpty) return vm.installedApps;

    final q = _searchQuery.toLowerCase();

    return vm.installedApps.where((app) {
      final name = (app['appName'] as String).toLowerCase();
      final pkg = (app['packageName'] as String).toLowerCase();

      return name.contains(q) || pkg.contains(q);
    }).toList();
  }

  void _togglePackage(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await vm.setAppBlacklist(_selectedPackages);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () async {
              await vm.setAppBlacklist(_selectedPackages);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Icon(Icons.arrow_back, color: colorScheme.primary),
          ),
          title: Text(
            l10n.appBlacklist,
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
          ),
        ),
        body: SafeArea(
          child: _buildBody(colorScheme, l10n),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, AppLocalizations l10n) {
    switch (vm.appsLoadState) {
      case AppsLoadState.idle:
      case AppsLoadState.loading:
        return _buildLoading(colorScheme, l10n);
      case AppsLoadState.noPermission:
        return _buildNoPermission(colorScheme, l10n);
      case AppsLoadState.loaded:
        return _buildLoaded(colorScheme, l10n);
    }
  }

  // ── 加载中 ──

  Widget _buildLoading(ColorScheme colorScheme, AppLocalizations l10n) {
    return _neumorphicCard(
      colorScheme: colorScheme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(l10n.loadingApps, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ── 无权限 ──

  Widget _buildNoPermission(ColorScheme colorScheme, AppLocalizations l10n) {
    return _neumorphicCard(
      colorScheme: colorScheme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list_alt, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(l10n.appListPermissionTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(l10n.appListPermissionDesc,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _neumorphicButton(
            label: l10n.openAppSettings,
            colorScheme: colorScheme,
            primary: true,
            onTap: () => vm.openAppDetailSettings(),
          ),
          const SizedBox(height: 12),
          _neumorphicButton(
            label: l10n.retry,
            colorScheme: colorScheme,
            primary: false,
            onTap: () => vm.loadInstalledApps(),
          ),
        ],
      ),
    );
  }

  // ── 已加载：搜索栏 + 提示 + 列表 ──

  Widget _buildLoaded(ColorScheme colorScheme, AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: _buildSearchBar(colorScheme, l10n),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text(l10n.selectedCount(_selectedPackages.length),
                  style: TextStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(l10n.blacklistEffectiveHint,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Expanded(child: _buildAppList(colorScheme, l10n)),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme, AppLocalizations l10n) {
    final baseColor = colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
        boxShadow: NeumorphicStyles.innerShadowPair(baseColor),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: l10n.searchApps,
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
      ),
    );
  }

  Widget _buildAppList(ColorScheme colorScheme, AppLocalizations l10n) {
    final apps = _filteredApps;
    if (apps.isEmpty) {
      return Center(
        child: Text(l10n.noAppsFound, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
      );
    }

    final items = <_ListItem>[];
    final selectedApps = apps.where((a) => _selectedPackages.contains(a['packageName'] as String)).toList();
    final unselectedUserApps = apps.where((a) =>
        !(a['isSystem'] as bool) && !_selectedPackages.contains(a['packageName'] as String)).toList();
    final unselectedSystemApps = apps.where((a) =>
        (a['isSystem'] as bool) && !_selectedPackages.contains(a['packageName'] as String)).toList();

    if (selectedApps.isNotEmpty) {
      items.add(_ListItem.header(l10n.selectedApps));
      for (final app in selectedApps) {
        items.add(_ListItem.app(app));
      }
    }
    if (unselectedUserApps.isNotEmpty) {
      items.add(_ListItem.header(l10n.userApps));
      for (final app in unselectedUserApps) {
        items.add(_ListItem.app(app));
      }
    }
    if (unselectedSystemApps.isNotEmpty) {
      items.add(_ListItem.header(l10n.systemApps));
      for (final app in unselectedSystemApps) {
        items.add(_ListItem.app(app));
      }
    }

    final baseColor = colorScheme.surface;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        boxShadow: NeumorphicStyles.mainCardShadow(baseColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item.isHeader) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: colorScheme.primary, letterSpacing: 0.5,
                  ),
                ),
              );
            }
            final app = item.app!;
            final packageName = app['packageName'] as String;
            final appName = app['appName'] as String;
            final isSelected = _selectedPackages.contains(packageName);
            final isSystem = app['isSystem'] as bool;
            final iconBytes = app['icon'] as List<int>?;

            return InkWell(
              onTap: () => _togglePackage(packageName),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusSmall),
                        boxShadow: NeumorphicStyles.activeIconBoxShadow(colorScheme.surface),
                      ),
                      child: (iconBytes != null && iconBytes.isNotEmpty)
                          ? Image.memory(
                              Uint8List.fromList(iconBytes),
                              width: 28,
                              height: 28,
                              gaplessPlayback: true,
                            )
                          : Icon(
                              isSystem ? Icons.android : Icons.music_note,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appName,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(packageName,
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _togglePackage(packageName),
                      activeColor: colorScheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 通用拟物化组件 ──

  Widget _neumorphicCard({required ColorScheme colorScheme, required Widget child}) {
    final baseColor = colorScheme.surface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NeumorphicStyles.spacingXXXL),
        child: Container(
          padding: NeumorphicStyles.paddingXXLarge,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(NeumorphicStyles.radiusXLarge),
            boxShadow: NeumorphicStyles.mainCardShadow(baseColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _neumorphicButton({
    required String label,
    required ColorScheme colorScheme,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: primary ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
          border: primary ? null : Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: NeumorphicStyles.fontSizeXL, fontWeight: FontWeight.w600,
            color: primary ? colorScheme.onPrimary : colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ListItem {
  final bool isHeader;
  final String title;
  final Map<String, dynamic>? app;

  _ListItem._({required this.isHeader, required this.title, this.app});

  factory _ListItem.header(String title) => _ListItem._(isHeader: true, title: title);
  factory _ListItem.app(Map<String, dynamic> app) => _ListItem._(isHeader: false, title: '', app: app);
}
