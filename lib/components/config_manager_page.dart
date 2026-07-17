import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wecho/models/audio_config.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../l10n/app_localizations.dart';
import '../styles/neumorphic_styles.dart';

class ConfigManagerPage extends StatefulWidget {
  final DSPControllerViewModel viewModel;

  const ConfigManagerPage({super.key, required this.viewModel});

  @override
  State<ConfigManagerPage> createState() => _ConfigManagerPageState();
}

class _ConfigManagerPageState extends State<ConfigManagerPage> {
  List<String> _savedConfigs = [];
  String? _selectedConfig;
  String? _lastSelectedConfig;
  bool _isLastConfigModified = false;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final configs = await widget.viewModel.getSavedConfigNames();
    final lastSelected = widget.viewModel.getLastSelectedConfig();

    bool isModified = false;
    if (lastSelected != null && configs.contains(lastSelected)) {
      isModified = await widget.viewModel.isConfigModified(lastSelected);
    }

    setState(() {
      _savedConfigs = configs;
      _lastSelectedConfig = lastSelected;
      _isLastConfigModified = isModified;

      if (lastSelected != null && configs.contains(lastSelected)) {
        _selectedConfig = lastSelected;
      } else {
        _selectedConfig = null;
      }
    });
  }

  Future<void> _applyConfig() async {
    if (_selectedConfig == null) return;

    final success = await widget.viewModel.applySavedConfig(_selectedConfig!);

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.configApplied : l10n.configApplyFailed),
        ),
      );

      if (success) {
        await _loadConfigs();
      }
    }
  }

  Future<void> _saveCurrentConfigTo(String name) async {
    final configJson = widget.viewModel.exportCurrentConfig();
    final config = AudioConfig.fromJsonString(configJson);
    await widget.viewModel.saveConfig(name, config);

    // Update the last selected config to the one just saved
    await widget.viewModel.saveLastSelectedConfig(name);

    // Reload config list and select the saved config
    final configs = await widget.viewModel.getSavedConfigNames();

    if (mounted) {
      setState(() {
        _savedConfigs = configs;
        _lastSelectedConfig = name;
        _selectedConfig = name;
        _isLastConfigModified = false;
      });
    }
  }

  Future<void> _deleteConfig(String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfig),
        content: Text(l10n.deleteConfigConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.viewModel.deleteConfig(name);
      if (_lastSelectedConfig == name) {
        await widget.viewModel.saveLastSelectedConfig(null);
      }
      await _loadConfigs();
    }
  }

  Future<void> _exportConfig() async {
    final l10n = AppLocalizations.of(context)!;

    // Show dialog to input config name
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exportConfig),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.configName,
            hintText: l10n.enterConfigName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final configJson = widget.viewModel.exportCurrentConfig();
    final config = AudioConfig.fromJsonString(configJson);
    await widget.viewModel.saveConfig(name, config);

    // Update the last selected config to the one just saved
    await widget.viewModel.saveLastSelectedConfig(name);

    final json = widget.viewModel.exportConfig(name);

    try {
      final result = await FilePicker.saveFile(
        dialogTitle: l10n.exportConfig,
        fileName: '$name.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(json),
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.configExported)),
        );
        
        // Reload config list and select the saved config
        final configs = await widget.viewModel.getSavedConfigNames();
        setState(() {
          _savedConfigs = configs;
          _lastSelectedConfig = name;
          _selectedConfig = name;
          _isLastConfigModified = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.exportFailed}: $e')),
        );
      }
    }
  }

  Future<void> _importConfig() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final content = utf8.decode(result.files.single.bytes!);

        final success = await widget.viewModel.importConfig(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? l10n.configImported : l10n.importFailed),
            ),
          );
          if (success) {
            _loadConfigs();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.importFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.configManager),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _NeumorphicButton(
                    onTap: _importConfig,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_download, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(l10n.importConfig),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NeumorphicButton(
                    onTap: _exportConfig,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_upload, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(l10n.exportConfig),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Config list
          Expanded(
            child: _savedConfigs.isEmpty
                ? Center(
                    child: Text(
                      l10n.noSavedConfigs,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _savedConfigs.length,
                    itemBuilder: (context, index) {

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Radio<String>(
                            value: _savedConfigs[index],
                            groupValue: _selectedConfig,
                            onChanged: (value) {
                              setState(() {
                                _selectedConfig = value;
                              });
                            },
                            activeColor: colorScheme.primary,
                          ),
                          title: Text(
                            ((_savedConfigs[index] == _lastSelectedConfig) && _isLastConfigModified) ? '${_savedConfigs[index]} *' : _savedConfigs[index],
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: (_selectedConfig == _savedConfigs[index]) ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((_savedConfigs[index] == _lastSelectedConfig) && _isLastConfigModified)
                                IconButton(
                                  icon: Icon(Icons.save, color: colorScheme.primary),
                                  onPressed: () => _saveCurrentConfigTo(_savedConfigs[index]),
                                  tooltip: 'Save changes',
                                ),
                              IconButton(
                                icon: Icon(Icons.delete, color: colorScheme.error),
                                onPressed: () => _deleteConfig(_savedConfigs[index]),
                                tooltip: l10n.deleteConfig,
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _selectedConfig = _savedConfigs[index];
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          // Apply button
          if (_selectedConfig != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: _NeumorphicButton(
                  onTap: _applyConfig,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.applyConfig),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NeumorphicButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _NeumorphicButton({
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(NeumorphicStyles.radiusMedium),
            boxShadow: NeumorphicStyles.innerShadowPair(baseColor),
          ),
          child: child,
        ),
      ),
    );
  }
}
