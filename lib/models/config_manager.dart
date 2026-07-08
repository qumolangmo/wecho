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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_config.dart';

class ConfigManager {
  static const String _keyAutoOutputSwitch = 'autoOutputSwitch';
  static const String _keySpeakerConfig = 'config_speaker';
  static const String _keyHeadphoneConfig = 'config_headphone';
  static const String _keyDisabledConfig = 'config_disabled';
  static const String _keyScriptLibrary = 'scriptLibrary';
  static const String _keyScriptParamsPrefix = 'scriptParams_'; // + mode name
  static const String _keyActiveScriptPrefix = 'activeScript_'; // + mode name

  final SharedPreferences _prefs;
  OutputMode _currentMode = OutputMode.disabled;
  String _currentOutputDevice = 'unknown';
  String _previousOutputDevice = 'unknown';
  Function(OutputMode mode, AudioConfig config)? onConfigChanged;
  Function(String device)? onDeviceChanged;

  ConfigManager(this._prefs);

  bool get autoOutputSwitch => _prefs.getBool(_keyAutoOutputSwitch) ?? true;

  OutputMode get currentMode => _currentMode;

  String get currentOutputDevice => _currentOutputDevice;

  Future<void> initialize() async {
    final autoSwitch = autoOutputSwitch;
    if (!autoSwitch) {
      _currentMode = OutputMode.disabled;
    }
  }

  Future<void> setAutoOutputSwitch(bool enabled) async {
    await _prefs.setBool(_keyAutoOutputSwitch, enabled);
    if (!enabled) {
      _currentMode = OutputMode.disabled;
    }
  }

  /// *****************************************Script Library****************************************

  Map<String, String> loadScriptLibrary() {
    final json = _prefs.getString(_keyScriptLibrary);
    if (json == null) return {};
    return Map<String, String>.from(jsonDecode(json));
  }

  Future<void> saveScriptLibrary(Map<String, String> library) async {
    await _prefs.setString(_keyScriptLibrary, jsonEncode(library));
  }

  Future<void> saveScriptToLibrary(String desc, String code) async {
    final library = loadScriptLibrary();
    library[desc] = code;
    await saveScriptLibrary(library);
  }

  Future<void> deleteScriptFromLibrary(String desc) async {
    final library = loadScriptLibrary();
    library.remove(desc);
    await saveScriptLibrary(library);
    // Also remove params for this script from all modes
    for (final mode in OutputMode.values) {
      final paramsMap = loadScriptParams(mode);
      paramsMap.remove(desc);
      await saveScriptParams(mode, paramsMap);
    }
  }

  /// *****************************************Script params****************************************

  Map<String, List<ScriptParam>> loadScriptParams(OutputMode mode) {
    final key = '$_keyScriptParamsPrefix${mode.name}';
    final json = _prefs.getString(key);
    if (json == null) return {};
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(
      k,
      (v as List).map((e) => ScriptParam.fromJson(e as Map<String, dynamic>)).toList(),
    ));
  }

  Future<void> saveScriptParams(OutputMode mode, Map<String, List<ScriptParam>> paramsMap) async {
    final key = '$_keyScriptParamsPrefix${mode.name}';
    final encoded = jsonEncode(paramsMap.map((k, v) => MapEntry(k, v.map((p) => p.toJson()).toList())));
    await _prefs.setString(key, encoded);
  }

  Future<void> saveScriptParamsForDesc(OutputMode mode, String desc, List<ScriptParam> params) async {
    final paramsMap = loadScriptParams(mode);
    paramsMap[desc] = params;
    await saveScriptParams(mode, paramsMap);
  }

  List<ScriptParam> loadScriptParamsForDesc(OutputMode mode, String desc) {
    final paramsMap = loadScriptParams(mode);
    return paramsMap[desc] ?? [];
  }

  /// *****************************************Active script****************************************

  String getActiveScriptDesc(OutputMode mode) {
    return _prefs.getString('$_keyActiveScriptPrefix${mode.name}') ?? '';
  }

  Future<void> setActiveScriptDesc(OutputMode mode, String desc) async {
    await _prefs.setString('$_keyActiveScriptPrefix${mode.name}', desc);
  }

  /// *****************************************General Config****************************************

  Future<void> saveConfig(OutputMode mode, AudioConfig config) async {
    final key = _getConfigKey(mode);
    await _prefs.setString(key, config.toJsonString());
  }

  AudioConfig loadConfig(OutputMode mode) {
    final key = _getConfigKey(mode);
    final jsonString = _prefs.getString(key);
    if (jsonString != null && jsonString.isNotEmpty) {
      return AudioConfig.fromJsonString(jsonString);
    }
    return AudioConfig();
  }

  AudioConfig getCurrentConfig() {
    return loadConfig(_currentMode);
  }

  Future<void> updateOutputDevice(String device) async {
    _previousOutputDevice = _currentOutputDevice;
    _currentOutputDevice = device;

    if (autoOutputSwitch) {
      final newMode = _determineMode(device);
      if (newMode != _currentMode) {
        _currentMode = newMode;
        final config = getCurrentConfig();
        onConfigChanged?.call(_currentMode, config);
      }
    } else if (_currentMode != OutputMode.disabled) {
      _currentMode = OutputMode.disabled;
      final config = getCurrentConfig();
      onConfigChanged?.call(_currentMode, config);
    }

    onDeviceChanged?.call(device);
  }

  OutputMode _determineMode(String device) {
    final lowerDevice = device.toLowerCase();
    if (lowerDevice.contains('speaker') || lowerDevice.contains('扬声器')) {
      return OutputMode.speaker;
    } else if (lowerDevice.contains('headphone') ||
        lowerDevice.contains('earphone') ||
        lowerDevice.contains('耳机') ||
        lowerDevice.contains('wired') ||
        lowerDevice.contains('bluetooth')) {
      return OutputMode.headphone;
    }
    return OutputMode.disabled;
  }

  String _getConfigKey(OutputMode mode) {
    switch (mode) {
      case OutputMode.speaker:
        return _keySpeakerConfig;
      case OutputMode.headphone:
        return _keyHeadphoneConfig;
      case OutputMode.disabled:
        return _keyDisabledConfig;
    }
  }

  String getModeDisplayName(OutputMode mode) {
    switch (mode) {
      case OutputMode.speaker:
        return 'Speaker';
      case OutputMode.headphone:
        return 'Headphone';
      case OutputMode.disabled:
        return 'Disabled';
    }
  }

  /// *****************************************Config Management****************************************

  static const String _keyLastSelectedConfig = 'lastSelectedConfig';

  Future<Directory> _getConfigsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final configsDir = Directory('${appDir.path}/wecho_configs');
    if (!await configsDir.exists()) {
      await configsDir.create(recursive: true);
    }
    return configsDir;
  }

  Future<void> saveConfigWithName(String name, AudioConfig config) async {
    final configsDir = await _getConfigsDirectory();
    final file = File('${configsDir.path}/$name.json');
    await file.writeAsString(config.toJsonString());
  }

  Future<AudioConfig?> loadConfigByName(String name) async {
    try {
      final configsDir = await _getConfigsDirectory();
      final file = File('${configsDir.path}/$name.json');
      if (!await file.exists()) {
        return null;
      }
      final jsonString = await file.readAsString();
      return AudioConfig.fromJsonString(jsonString);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveLastSelectedConfig(String? name) async {
    if (name == null) {
      await _prefs.remove(_keyLastSelectedConfig);
    } else {
      await _prefs.setString(_keyLastSelectedConfig, name);
    }
  }

  String? getLastSelectedConfig() {
    return _prefs.getString(_keyLastSelectedConfig);
  }

  Future<List<String>> loadSavedConfigNames() async {
    final configsDir = await _getConfigsDirectory();
    if (!await configsDir.exists()) {
      return [];
    }
    final files = await configsDir.list().toList();
    return files
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.json'))
        .map((name) => name.substring(0, name.length - 5))
        .toList();
  }

  Future<void> deleteConfigByName(String name) async {
    final configsDir = await _getConfigsDirectory();
    final file = File('${configsDir.path}/$name.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
