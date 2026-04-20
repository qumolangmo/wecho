/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:shared_preferences/shared_preferences.dart';
import 'audio_config.dart';

class ConfigManager {
  static const String _keyAutoOutputSwitch = 'autoOutputSwitch';
  static const String _keySpeakerConfig = 'config_speaker';
  static const String _keyHeadphoneConfig = 'config_headphone';
  static const String _keyDisabledConfig = 'config_disabled';

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
}
