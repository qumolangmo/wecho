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

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show clampDouble;
import '../components/components.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_config.dart';
import '../models/autoeq_index.dart';
import '../models/config_manager.dart';
import '../models/dsp_platform_bridge.dart';
import '../views/script_editor_page.dart';

enum AppsLoadState { idle, loading, loaded, noPermission }

class AppError {
  final String message;
  const AppError(this.message);
}

class DSPControllerViewModel {
  AudioConfig _config = AudioConfig();

  /// Effect-card expansion states, keyed by card expand key. The keys double
  /// as the SharedPreferences keys and are unchanged from the previous
  /// per-field implementation, so persisted states stay compatible.
  static const List<String> _expandKeys = [
    'channelBalanceExpanded',
    'globalGainExpanded',
    'clarityExpanded',
    'bassBoostExpanded',
    'evenHarmonicExpanded',
    'convolveExpanded',
    'compressorExpanded',
    'lowcatExpanded',
    'equalizerExpanded',
    'virtualBassExpanded',
    'reverbExpanded',
    'scriptExpanded',
    'diffSurroundingEffectExpanded',
    'deviceSimulationExpanded',
    'bassResonatorExpanded',
  ];
  final Map<String, bool> _expandedState = {};

  bool isExpanded(String key) => _expandedState[key] ?? false;

  /// Data-driven description of every effect card on the main page, in
  /// display order. The view renders the UI purely from this list.
  final List<List<dynamic>> effectCards = _buildEffectCards();

  bool autoOutputSwitch = true;
  bool powerSaving = true;
  String currentAudioOutput = 'unknown';
  String appVersion = 'Unknown';
  /// ***************************************** tcc compile error & crash state variable ****************************************
  String _lastCompileError = '';
  String get lastCompileError => _lastCompileError;
  void Function(String error)? onScriptCompileError;
  final StreamController<String> _compileErrorController = StreamController<String>.broadcast();
  Stream<String> get compileErrorStream => _compileErrorController.stream;
  /// ***********************************************************************************************
  bool isCapturing = false;
  double processingLatencyMs = 0;
  static const double deadlineMs = 512 / 48000 * 1000; // 10.67ms
  bool masterEnabled = true;
  Set<String> appBlacklist = {};
  List<Map<String, dynamic>> installedApps = [];

  AppsLoadState appsLoadState = AppsLoadState.idle;

  late DspPlatformBridge _channel;

  late SharedPreferences _prefs;
  late ConfigManager _configManager;
  Function()? onStateChanged;
  Function(String)? onOutputModeChanged;
  String currentDeviceKey = 'disabled';
  Timer? _pollingTimer;

  /// Latency is polled every second and displayed only in the header.
  /// Exposed as a ValueNotifier so the header rebuilds locally instead of
  /// triggering a full-page setState on every poll.
  final ValueNotifier<double> latencyNotifier = ValueNotifier<double>(0);

  /// Debounced persistence state: slider drags and EQ curve drags fire
  /// update() on every tick; JSON-serializing the whole config (including the
  /// multi-KB script code) and writing prefs per tick stalls the UI thread.
  /// The trailing timer coalesces bursts into a single save.
  static const _configSaveDelay = Duration(milliseconds: 500);
  Timer? _configSaveDebounce;
  ParamID? _lastUpdatedParamId;
  Map<String, String>? _scriptLibraryCache;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  final Completer<void> _settingsLoadedCompleter = Completer<void>();
  Future<void> get settingsLoaded => _settingsLoadedCompleter.future;

  String? loadingImagePath;

  DSPControllerViewModel({this.onStateChanged}) {
    _initialize();
  }

  Future<void> _initialize() async {
    _channel = DspPlatformBridge();
    // Native -> Dart events; the table/dispatcher live in the bridge file.
    installNativeEventDispatcher(
      _channel,
      DspNativeCallbacks(
        onCaptureStatusChanged: (capturing) {
          isCapturing = capturing;
          onStateChanged?.call();
        },
        onAudioOutputChanged: (device) {
          currentAudioOutput = device;
          onStateChanged?.call();
        },
        onOutputModeChanged: (output) async {
          currentAudioOutput = output;
          if (autoOutputSwitch) {
            await _configManager.updateOutputDevice(output);
          }
          onStateChanged?.call();
        },
        onScriptCompileError: (error) {
          _lastCompileError = error;
          _compileErrorController.add(error);
          onScriptCompileError?.call(error);
        },
      ),
    );

    await _loadSettings();


    if (Platform.isWindows) {
      await _pushFullConfigToApo();
    }

    if (Platform.isAndroid) {
      await requestShizukuPermission();
      _startPolling();
      await _fetchCaptureStatus();
    }

    _initCompleter.complete();
  }

  Future<void> update<T>(ParamID id, T value) async {
    _config = _config.copyWith({id: value});
    _lastUpdatedParamId = id;
    // Notify the UI before the async platform call so sliders/switches react
    // instantly even when the channel round-trip is slow.
    onStateChanged?.call();
    await setEffectParam(id.index, value);
    _configSaveDebounce?.cancel();
    _configSaveDebounce = Timer(_configSaveDelay, _flushConfigSave);
  }

  /// Debounced persistence: saves the current config once parameter updates
  /// settle down, plus script params when the last update touched them.
  Future<void> _flushConfigSave() async {
    _configSaveDebounce = null;
    await _configManager.saveConfig(currentDeviceKey, _config);
    if (_lastUpdatedParamId == ParamID.scriptEffectParams) {
      await _saveCurrentScriptParams();
    }
  }

  T get<T>(ParamID id) => _config[id] as T;

  Future<List<double>?> getDeviceSimulationFreqResponse() async {
    try {
      final result = await _channel.invokeMethod<dynamic>('getDeviceSimulationFreqResponse');
      if (result == null) return null;
      return (result as List).cast<num>().map((e) => e.toDouble()).toList();
    } on PlatformException {
      return null;
    }
  }

  Future<Either<AppError, void>> _invokeMethod(String method, [dynamic arguments]) async {
    try {
      await _channel.invokeMethod(method, arguments);
      return const Right(null);
    } on PlatformException catch (e) {
      return Left(AppError(e.message ?? 'Unknown error'));
    }
  }

  Future<Either<AppError, T>> _invokeMethodWithResult<T>(String method, [dynamic arguments]) async {
    try {
      final result = await _channel.invokeMethod(method, arguments);
      return Right(result as T);
    } on PlatformException catch (e) {
      return Left(AppError(e.message ?? 'Unknown error'));
    } catch (_) {
      return Left(AppError('$method not available on this platform'));
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollLatency();
    });
  }

  Future<void> _pollLatency() async {
    final result = await _invokeMethodWithResult<double>('getProcessingLatency');
    result.fold(
      (_) {},
      (latency) {
        processingLatencyMs = latency;
        // Local update only: the header listens to this notifier. A full-page
        // onStateChanged here rebuilt every effect card every second.
        latencyNotifier.value = latency;
      },
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  String get activeScriptDesc {
    try {
      return _configManager.getActiveScriptDesc(currentDeviceKey);
    } catch (_) {
      return '';
    }
  }

  Future<void> _saveCurrentScriptParams() async {
    final desc = activeScriptDesc;
    if (desc.isEmpty) return;
    final params = _config[ParamID.scriptEffectParams] as List<ScriptParam>;
    await _configManager.saveScriptParamsForDesc(currentDeviceKey, desc, params);
  }

  void _loadCurrentScriptParams() {
    final desc = activeScriptDesc;
    if (desc.isEmpty) {
      _config = _config.copyWith({ParamID.scriptEffectParams: <ScriptParam>[]});
      return;
    }

    final library = _configManager.loadScriptLibrary();
    final code = library[desc];
    if (code != null) {
      _config = _config.copyWith({ParamID.scriptEffectCode: code});
    }

    final savedParams = _configManager.loadScriptParamsForDesc(currentDeviceKey, desc);
    _syncScriptParams(savedParams: savedParams);
  }

  void _syncScriptParams({List<ScriptParam>? savedParams}) {
    final code = _config[ParamID.scriptEffectCode] as String;
    if (code.isEmpty) {
      if ((_config[ParamID.scriptEffectParams] as List<ScriptParam>).isNotEmpty) {
        _config = _config.copyWith({ParamID.scriptEffectParams: <ScriptParam>[]});
      }
      return;
    }
    final parsed = parseScriptParams(code);
    if (parsed.isEmpty) {
      if ((_config[ParamID.scriptEffectParams] as List<ScriptParam>).isNotEmpty) {
        _config = _config.copyWith({ParamID.scriptEffectParams: <ScriptParam>[]});
      }
      return;
    }

    final mergeSource = savedParams ?? _config[ParamID.scriptEffectParams] as List<ScriptParam>;
    final merged = parsed.map((np) {
      final old = mergeSource.where((op) => op.name == np.name);
      return ScriptParam(
        np.name,
        old.isNotEmpty ? old.first.value : np.value,
        min: np.min, max: np.max, step: np.step,
      );
    }).toList();
    _config = _config.copyWith({ParamID.scriptEffectParams: merged});
  }

  Map<String, String> getScriptLibrary() {
    final cached = _scriptLibraryCache;
    if (cached != null) return cached;
    try {
      // Cache the parsed library: jsonDecoding the whole library (including
      // full script sources) on every widget rebuild is expensive.
      return _scriptLibraryCache = _configManager.loadScriptLibrary();
    } catch (_) {
      return {};
    }
  }

  void _invalidateScriptLibraryCache() {
    _scriptLibraryCache = null;
  }

  /// Returns false if missing @desc, true otherwise.
  /// Compile errors are pushed via onScriptCompileError callback.
  Future<bool> saveScript(String code) async {
    final desc = parseScriptDesc(code);
    if (desc.isEmpty || desc == 'not found desc.') return false;
    await _configManager.saveScriptToLibrary(desc, code);
    _invalidateScriptLibraryCache();
    await _configManager.setActiveScriptDesc(currentDeviceKey, desc);

    _config = _config.copyWith({ParamID.scriptEffectCode: code});
    _syncScriptParams();

    await _configManager.saveScriptParamsForDesc(currentDeviceKey, desc, _config[ParamID.scriptEffectParams] as List<ScriptParam>);

    _lastCompileError = '';
    await setEffectParam(ParamID.scriptEffectCode.index, code);
    await setEffectParam(ParamID.scriptEffectParams.index, _config[ParamID.scriptEffectParams]);
    await _saveSettings();
    onStateChanged?.call();
    return true;
  }

  Future<void> switchScript(String desc) async {
    final library = _configManager.loadScriptLibrary();
    final code = library[desc];
    if (code == null) return;

    await _saveCurrentScriptParams();

    await _configManager.setActiveScriptDesc(currentDeviceKey, desc);
    _config = _config.copyWith({ParamID.scriptEffectCode: code});

    final savedParams = _configManager.loadScriptParamsForDesc(currentDeviceKey, desc);
    _syncScriptParams(savedParams: savedParams);
 
    await _configManager.saveScriptParamsForDesc(currentDeviceKey, desc, _config[ParamID.scriptEffectParams] as List<ScriptParam>);
    await setEffectParam(ParamID.scriptEffectCode.index, code);
    await setEffectParam(ParamID.scriptEffectParams.index, _config[ParamID.scriptEffectParams]);
    await _saveSettings();
    onStateChanged?.call();
  }

  Future<void> deleteScript(String desc) async {
    await _configManager.deleteScriptFromLibrary(desc);
    _invalidateScriptLibraryCache();
    if (activeScriptDesc == desc) {
      await _configManager.setActiveScriptDesc(currentDeviceKey, '');
      _config = _config.copyWith({
        ParamID.scriptEffectCode: '',
        ParamID.scriptEffectParams: <ScriptParam>[],
      });
      await _saveSettings();
    }
    onStateChanged?.call();
  }

  /// Import a script from external .c file content.
  /// Parses @desc, saves to script library, but does NOT switch to it.
  /// Returns the desc of the imported script, or empty string if invalid.
  Future<String> importScript(String code) async {
    final desc = parseScriptDesc(code);
    if (desc.isEmpty || desc == 'not found desc.') return '';
    await _configManager.saveScriptToLibrary(desc, code);
    _invalidateScriptLibraryCache();
    onStateChanged?.call();
    return desc;
  }

  /// Export the current active script code.
  /// Returns null if no active script.
  String? exportScriptCode() {
    final desc = activeScriptDesc;
    if (desc.isEmpty) return null;
    final library = _configManager.loadScriptLibrary();
    return library[desc];
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _configManager = ConfigManager(_prefs);
    await _configManager.initialize();

    _configManager.onConfigChanged = (deviceKey, config) async {
      // Config is about to be replaced wholesale; drop any pending debounced
      // save of the old config so it can't land after the switch.
      _configSaveDebounce?.cancel();
      _configSaveDebounce = null;
      await _saveCurrentScriptParams();
      await _configManager.saveConfig(currentDeviceKey, _config);

      _config = config;
      currentDeviceKey = deviceKey;
      _loadCurrentScriptParams();

      onOutputModeChanged?.call(deviceKey);
      onStateChanged?.call();
    };

    _config = _configManager.getCurrentConfig();

    var library = _configManager.loadScriptLibrary();
    final defaultDesc = parseScriptDesc(kDefaultScriptCode);
    // Always overwrite template script to ensure it's up-to-date
    await _configManager.saveScriptToLibrary(defaultDesc, kDefaultScriptCode);
    library = _configManager.loadScriptLibrary();
    // Ensure default script is active for current mode if none set
    currentDeviceKey = _configManager.currentDeviceKey;
    var curActiveDesc = _configManager.getActiveScriptDesc(currentDeviceKey);
    if (curActiveDesc.isEmpty) {

      final legacyDesc = _prefs.getString('activeScriptDesc') ?? '';
      if (legacyDesc.isNotEmpty) {
        await _configManager.setActiveScriptDesc(currentDeviceKey, legacyDesc);
        curActiveDesc = legacyDesc;
      } else {
        await _configManager.setActiveScriptDesc(currentDeviceKey, defaultDesc);
        curActiveDesc = defaultDesc;
      }
    }

    final code = library[curActiveDesc];
    if (code != null) {
      _config = _config.copyWith({ParamID.scriptEffectCode: code});
    }

    final savedParams = _configManager.loadScriptParamsForDesc(currentDeviceKey, curActiveDesc);
    _syncScriptParams(savedParams: savedParams);

    autoOutputSwitch = _prefs.getBool('autoOutputSwitch') ?? true;
    powerSaving = _prefs.getBool('powerSaving') ?? true;
    masterEnabled = _prefs.getBool('masterEnabled') ?? true;
    for (final key in _expandKeys) {
      _expandedState[key] = _prefs.getBool(key) ?? false;
    }
    loadingImagePath = _prefs.getString('loadingImagePath');

    final blacklistJson = _prefs.getString('appBlacklist');
    if (blacklistJson != null) {
      appBlacklist = (jsonDecode(blacklistJson) as List).cast<String>().toSet();
    }

    await _fetchCaptureStatus();
    await setAutoOutputSwitch(autoOutputSwitch);
    await setPowerSaving(powerSaving);
    await _fetchAutoOutput();
    await _fetchAppVersion();
    await _loadLogSettings();

    onStateChanged?.call();

    _settingsLoadedCompleter.complete();
  }

  Future<void> _saveSettings() async {
    await _configManager.saveConfig(currentDeviceKey, _config);
    await _prefs.setBool('autoOutputSwitch', autoOutputSwitch);
    await _prefs.setBool('powerSaving', powerSaving);
    await _prefs.setBool('masterEnabled', masterEnabled);
    await _prefs.setString('appBlacklist', jsonEncode(appBlacklist.toList()));
    await _prefs.setString('loadingImagePath', loadingImagePath ?? '');
  }

  

  Future<void> requestShizukuPermission() async {
    await _invokeMethod('requestShizukuPermission');
    onStateChanged?.call();
  }

  Future<void> setLoadingImagePath(String? path) async {
    loadingImagePath = path;
    await _prefs.setString('loadingImagePath', path ?? '');
    onStateChanged?.call();
  }

  Future<void> _fetchCaptureStatus() async {
    final result = await _invokeMethodWithResult<bool>('getCaptureStatus');
    result.fold(
      (_) {},
      (capturing) {
        isCapturing = capturing;
        onStateChanged?.call();
      },
    );
  }

  Future<void> setAutoOutputSwitch(bool enabled) async {
    autoOutputSwitch = enabled;
    await _prefs.setBool('autoOutputSwitch', enabled);
    await _configManager.setAutoOutputSwitch(enabled);
    await _invokeMethod('setAutoOutputSwitch', enabled);
    if (enabled) {
      await _fetchAutoOutput();
    } else {
      // Save current script params before switching to disabled mode
      _configSaveDebounce?.cancel();
      _configSaveDebounce = null;
      await _saveCurrentScriptParams();
      await _configManager.saveConfig(currentDeviceKey, _config);
      await _configManager.updateOutputDevice(currentAudioOutput);
      currentDeviceKey = 'disabled';
      _config = _configManager.loadConfig('disabled');
      _loadCurrentScriptParams();
      await _saveSettings();
      await _invokeMethod('reloadConfig', {'device': currentDeviceKey});
      onOutputModeChanged?.call(currentDeviceKey);
    }
    onStateChanged?.call();
  }

  Future<void> setPowerSaving(bool enabled) async {
    powerSaving = enabled;
    await _prefs.setBool('powerSaving', enabled);
    await _invokeMethod('setPowerSaving', enabled);
    onStateChanged?.call();
  }

  Future<void> _fetchAutoOutput() async {
    final result = await _invokeMethodWithResult<String>('getAutoOutput');
    await result.fold<Future<void>>(
      (_) async {},
      (device) async {
        currentAudioOutput = device;
        if (autoOutputSwitch) {
          await _configManager.updateOutputDevice(device);
        }
        onStateChanged?.call();
      },
    );
  }

  Future<void> updateOutputDevice(String device) async {
    await _configManager.updateOutputDevice(device);
  }

  Future<void> toggleCapture() async {
    if (!isCapturing) {
      await _invokeMethod('startCapture');
    } else {
      await _invokeMethod('stopCapture');
    }
  }

  /// Start the audio capture workflow once the first screen (splash + onboarding)
  /// has finished loading. Re-syncs capture status, then requests the
  /// MediaProjection consent + starts capture if not already capturing.
  Future<void> startCaptureWorkflow() async {
    await _fetchCaptureStatus();

    if (!isCapturing) {
      await _invokeMethod('startCapture');
    }
  }

  Future<void> setEffectParam(int paramId, dynamic value, {bool initialize = false}) async {
    dynamic finalValue = value;
    if (paramId == ParamID.scriptEffectParams.index && value is List<ScriptParam>) {
      finalValue = serializeScriptParams(value);
    }

    await _invokeMethod('setEffectParam', {'paramId': paramId, 'value': finalValue, 'initialize': initialize});
  }

  Future<void> _pushFullConfigToApo() async {
    if (!Platform.isWindows) return;

    for (final id in ParamID.values.reversed) {
      if (id == ParamID.dspEnabled) continue; // sent via setMasterEnabled below
      final value = _config[id];
      if (value == null) continue;
      await setEffectParam(id.index, value, initialize: true);
    }
    await setMasterEnabled(masterEnabled);
  }

  Future<void> setMasterEnabled(bool enabled) async {
    await _invokeMethod('setMasterEnabled', enabled);
  }

  Future<String?> readAssetFile(String relPath) async {
    final result = await _invokeMethodWithResult<String>('readAssetFile', {'relPath': relPath});
    return result.fold((_) => null, (text) => text);
  }

  Future<void> _fetchAppVersion() async {
    final result = await _invokeMethodWithResult<String>('getAppVersion');
    result.fold(
      (_) {},
      (version) {
        appVersion = version;
        onStateChanged?.call();
      },
    );
  }

  Future<void> loadInstalledApps() async {

    if (appsLoadState == AppsLoadState.loaded) return;
    appsLoadState = AppsLoadState.loading;
    onStateChanged?.call();

    try {
      final result = await _invokeMethodWithResult<List>('getInstalledApps')
          .timeout(const Duration(seconds: 15));
      result.fold(
        (_) {
          installedApps = [];
          appsLoadState = AppsLoadState.noPermission;
        },
        (apps) {
          final parsed = <Map<String, dynamic>>[];
          for (final item in apps) {
            if (item is Map) {
              parsed.add(Map<String, dynamic>.from(item));
            }
          }
          installedApps = parsed;

          appsLoadState = installedApps.isEmpty
              ? AppsLoadState.noPermission
              : AppsLoadState.loaded;
        },
      );
    } catch (_) {
      installedApps = [];
      appsLoadState = AppsLoadState.noPermission;
    } finally {
      onStateChanged?.call();
    }
  }

  Future<void> openAppDetailSettings() async {
    await _invokeMethod('openAppDetailSettings');
  }

  Future<void> setAppBlacklist(Set<String> packageNames) async {
    appBlacklist = packageNames;
    await _prefs.setString('appBlacklist', jsonEncode(packageNames.toList()));
    onStateChanged?.call();
  }

  Future<void> updateMasterEnabled(bool enabled) async {
    masterEnabled = enabled;
    onStateChanged?.call();
    await setMasterEnabled(enabled);
    await _saveSettings();
  }

  Future<void> toggleExpanded(String key) async {
    _expandedState[key] = !isExpanded(key);
    await _prefs.setBool(key, _expandedState[key]!);
    onStateChanged?.call();
  }

  Future<List<String>> getSavedConfigNames() async {
    return await _configManager.loadSavedConfigNames();
  }

  String? getLastSelectedConfig() {
    return _configManager.getLastSelectedConfig();
  }

  Future<void> saveLastSelectedConfig(String? name) async {
    await _configManager.saveLastSelectedConfig(name);
  }

  Future<bool> isConfigModified(String name) async {
    final savedConfig = await _configManager.loadConfigByName(name);
    if (savedConfig == null) return true;

    final currentJson = _config.toJsonString();
    final savedJson = savedConfig.toJsonString();
    
    return currentJson != savedJson;
  }

  String exportCurrentConfig() {
    return _config.toJsonString();
  }

  Future<void> saveConfig(String name, AudioConfig config) async {
    await _configManager.saveConfigWithName(name, config);
  }

  Future<void> deleteConfig(String name) async {
    await _configManager.deleteConfigByName(name);
  }

  Future<bool> applySavedConfig(String name) async {
    final config = await _configManager.loadConfigByName(name);
    if (config == null) {
      return false;
    }

    _configSaveDebounce?.cancel();
    _configSaveDebounce = null;
    _config = config;

    final scriptCode = _config[ParamID.scriptEffectCode] as String;

    await saveScript(scriptCode);
    await _saveSettings();

    await _configManager.saveLastSelectedConfig(name);
    await _invokeMethod('reloadConfig', {'device': currentDeviceKey});

    onStateChanged?.call();
    return true;
  }

  String exportConfig(String name) {
    final configJson = _config.toJsonString();
    final exportData = {
      'name': name,
      'config': jsonDecode(configJson),
    };
    return jsonEncode(exportData);
  }

  Future<bool> importConfig(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final name = data['name'] as String?;
      final configData = data['config'] as Map<String, dynamic>?;
      
      if (name == null || configData == null) return false;
      
      final config = AudioConfig.fromJson(configData);
      await _configManager.saveConfigWithName(name, config);

      onStateChanged?.call();
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _stopPolling();
    // Flush a pending debounced config save so the last tweak isn't lost.
    if (_configSaveDebounce != null) {
      _configSaveDebounce!.cancel();
      _configSaveDebounce = null;
      _flushConfigSave();
    }
    latencyNotifier.dispose();
  }

  Set<String> logLevels = {'wecho-kotlin', 'wecho-native', 'framework'};
  int logMaxCount = 100;

  Future<List<Map<String, dynamic>>> getLogs() async {    
    final tags = logLevels.toList();
    final result = await _invokeMethodWithResult<List>('getLogs', {'tags': tags, 'maxCount': logMaxCount});
    return result.fold(
      (_) => [],
      (logs) => logs.map((log) {
        if (log is List && log.length >= 3) {
          return {
            'tag': log[0] as String,
            'message': log[1] as String,
            'timestamp': log[2] as int,
          };
        }
        return {'tag': '', 'message': log.toString(), 'timestamp': 0};
      }).toList(),
    );
  }

  Future<void> setLogMaxCount(int count) async {    
    logMaxCount = count;
    await _prefs.setInt('logMaxCount', count);
    onStateChanged?.call();
  }

  Future<void> toggleLogLevel(String level) async {
    if (logLevels.contains(level)) {
      logLevels.remove(level);
    } else {
      logLevels.add(level);
    }
    await _prefs.setStringList('logLevels', logLevels.toList());
    onStateChanged?.call();
  }

  Future<void> _loadLogSettings() async {
    final savedLevels = _prefs.getStringList('logLevels');
    if (savedLevels != null) {
      logLevels = savedLevels.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    }
    logMaxCount = _prefs.getInt('logMaxCount') ?? 100;
  }
}

/// ***************************************** Effect card specs ****************************************

/// Effect-card data table; the view renders purely from this list.
/// To add an effect, append one entry below — no view changes needed.
///
/// card[expandKey, icon, title, desc, enabledId, sliders, subtitle?, leading?]
///   expandKey: String? (also the prefs key; null = not expandable)
///   title/desc: (l10n) => String
///   enabledId: ParamID? (null = no switch, sliders must hold exactly 1 entry)
///   subtitle: (vm, l10n) => String?
///   leading: (context, vm) => List? (custom widgets, see node formats below)
///
/// slider[id, label, min, max, divisions, unit?, isInt?, showDivider?]
///   label: (l10n) => String; defaults: unit '' / isInt false / showDivider true / 2 decimals
///
/// widget nodes inside leading (mixable with plain widgets):
///   selector[items[[value, label, deletable?]...], selected, onSelect, onDelete?, hint?]
///   button[onTap, children[], padding?]   (enabled follows the card switch)
///   row[children[]]   expanded[child]
///   icon[iconData, color, size?]   text[label, style?, ellipsis?]
///   gap[n] (vertical)   hgap[n] (horizontal)
List<List<dynamic>> _buildEffectCards() {
  return [
    // ── Channel Balance ──
    ['channelBalanceExpanded', Icons.balance, (l10n) => l10n.channelBalance, (l10n) => l10n.channelBalanceDesc, null, [
      [ParamID.balanceEffectBalance, _noLabel, -6, 6, -1, 'dB'],
    ]],
    // ── Global Gain ──
    ['globalGainExpanded', Icons.volume_up, (l10n) => l10n.globalGain, (l10n) => l10n.globalGainDesc, null, [
      [ParamID.gainEffectGain, _noLabel, -15, 9, -1, 'dB'],
    ]],
    // ── Multi-Band Limiter (no expandable content) ──
    [null, Icons.keyboard_double_arrow_down, (l10n) => l10n.multiBandLimiter, (l10n) => l10n.multiBandLimiterDesc, ParamID.lookAheadSoftLimitEffectEnabled, const []],
    // ── Compressor ──
    ['compressorExpanded', Icons.compress, (l10n) => l10n.compressor, (l10n) => l10n.compressorDesc, ParamID.compressorEffectEnabled, [
      [ParamID.compressorEffectThreshold, _l10nThreshold, -30, 0, 30, 'dB', true],
      [ParamID.compressorEffectAttack, _l10nAttack, 1, 100, 99, 'ms', true],
      [ParamID.compressorEffectRelease, _l10nRelease, 1, 1000, 999, 'ms', true],
      [ParamID.compressorEffectRatio, _l10nRatio, 1, 10, 100, '', true],
      [ParamID.compressorEffectMakeupGain, _l10nMakeupGain, 0, 15, 15, 'dB', true, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => '${vm.get<int>(ParamID.compressorEffectThreshold).toDouble().toStringAsFixed(2)}dB'],
    // ── Device Simulation ──
    ['deviceSimulationExpanded', Icons.headphones, (l10n) => l10n.deviceSimulationEffect, (l10n) => l10n.deviceSimulationEffectDesc, ParamID.deviceSimulationEffectEnabled, const [],
      (DSPControllerViewModel vm, AppLocalizations l10n) => _deviceSimulationDisplayName(vm.get<String>(ParamID.deviceSimulationEffectConfig)),
      (BuildContext context, DSPControllerViewModel vm) => [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: DeviceSimulationCard(viewModel: vm),
        ),
      ],
    ],
    // ── IIR Equalizer ──
    ['equalizerExpanded', Icons.graphic_eq, (l10n) => l10n.equalizer, (l10n) => l10n.equalizerDesc, ParamID.iirEqualizerEffectEnabled, const [],
      (DSPControllerViewModel vm, AppLocalizations l10n) => vm.get<String>(ParamID.iirEqualizerEffectConfig).split('\n').first,
      (BuildContext context, DSPControllerViewModel vm) => [
        GraphicEqPanel(
          config: vm.get<String>(ParamID.iirEqualizerEffectConfig),
          onConfigChanged: (v) => vm.update<String>(ParamID.iirEqualizerEffectConfig, v),
          enabled: vm.get<bool>(ParamID.iirEqualizerEffectEnabled),
        ),
        const SizedBox(height: 16),
      ],
    ],
    // ── FDN Reverb ──
    ['reverbExpanded', Icons.spatial_audio, (l10n) => l10n.reverb, (l10n) => l10n.reverbDesc, ParamID.reverbEffectEnabled, [
      [ParamID.reverbEffectMix, _l10nReverbMix, 0, 1, 100],
      [ParamID.reverbEffectRoomSize, _l10nReverbRoomSize, 0, 1, 100],
      [ParamID.reverbEffectDamping, _l10nReverbDamping, 0, 1, 100],
      [ParamID.reverbEffectStereoWidth, _l10nReverbStereoWidth, 0.1, 2, 190],
      [ParamID.reverbEffectModDepth, _l10nReverbModDepth, 0, 1, 100],
      [ParamID.reverbEffectModFreq, _l10nReverbModFreq, 0.1, 5, 49],
      [ParamID.reverbEffectPreDelay, _l10nReverbPreDelay, 0, 60, 60, 'ms', true, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => vm.get<double>(ParamID.reverbEffectMix).toStringAsFixed(2), (BuildContext context, DSPControllerViewModel vm) {
      final l10n = AppLocalizations.of(context)!;
      return [
        ['selector', [
          [0, l10n.reverbMatrixHadamard],
          [1, l10n.reverbMatrixHouseholder],
          [2, l10n.reverbMatrixCirculant],
          [3, l10n.reverbMatrixSparse],
        ], vm.get<int>(ParamID.reverbEffectMatrixType), (v) => vm.update(ParamID.reverbEffectMatrixType, v), null, l10n.reverbMatrixType],
        const SizedBox(height: 16),
      ];
    }],
    // ── Diff Surrounding ──
    ['diffSurroundingEffectExpanded', Icons.equalizer, (l10n) => l10n.diffSurroundingEffect, (l10n) => l10n.diffSurroundingEffectDesc, ParamID.diffSurroundingEffectEnabled, [
      [ParamID.diffSurroundingEffectDelayMs, _l10nDelayMs, 0, 20, 20, 'ms', true, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => '${vm.get<int>(ParamID.diffSurroundingEffectDelayMs)}'],
    // ── Bass Boost ──
    ['bassBoostExpanded', Icons.equalizer, (l10n) => l10n.lowFrequencyGain, (l10n) => l10n.lowFrequencyGainDesc, ParamID.bassEffectEnabled, [
      [ParamID.bassEffectGain, _l10nGain, 0, 15, 15, '', true],
      [ParamID.bassEffectCenterFreq, _l10nCenterFreq, 30, 100, 70, 'Hz', true],
      [ParamID.bassEffectQ, _l10nQ, 0.1, 1.5, 140, '', false, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => '${vm.get<int>(ParamID.bassEffectGain)}'],
    // ── Low Cut ──
    ['lowcatExpanded', Icons.filter_list, (l10n) => l10n.lowcat, (l10n) => l10n.lowcatDesc, ParamID.lowcatEffectEnabled, [
      [ParamID.lowcatEffectCutoffFrequency, _l10nCutoffFrequency, 20, 300, 280, 'Hz', true, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => '${vm.get<int>(ParamID.lowcatEffectCutoffFrequency)} Hz'],
    // ── Bass Resonator ──
    ['bassResonatorExpanded', Icons.surround_sound_outlined, (l10n) => l10n.bassResonator, (l10n) => l10n.bassResonatorDesc, ParamID.bassResonatorEffectEnabled, [
      [ParamID.bassResonatorEffectHighGain, _l10nHighGain, -6, 6, 120, 'dB'],
      [ParamID.bassResonatorEffectGain, _l10nCenterGain, 0, 1, 100],
      [ParamID.bassResonatorEffectCenterFreq, _l10nCenterFreq, 20, 200, 180, 'Hz'],
      [ParamID.bassResonatorEffectQ, _l10nQ, 0.8, 3.0, 220, '', false, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => '${vm.get<double>(ParamID.bassResonatorEffectCenterFreq)}Hz'],
    // ── Virtual Bass ──
    ['virtualBassExpanded', Icons.surround_sound, (l10n) => l10n.virtualBass, (l10n) => l10n.virtualBassDesc, ParamID.virtualbassEffectEnabled, [
      [ParamID.virtualbassEffectEnvelopeRate, _l10nVirtualBassEnvelopeRate, 5, 150, 145, 'Hz', true],
      [ParamID.virtualbassEffectMidGain, _l10nVirtualBassMidGain, 0, 1, 100],
      [ParamID.virtualbassEffectHighGain, _l10nVirtualBassHighGain, 0, 1, 100],
      [ParamID.virtualbassEffectHarmonicGain, _l10nVirtualBassHarmonicGain, 0, 2, 200, '', false, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => '${vm.get<int>(ParamID.virtualbassEffectEnvelopeRate)} Hz'],
    // ── Clarity ──
    ['clarityExpanded', Icons.graphic_eq, (l10n) => l10n.highFrequencyGain, (l10n) => l10n.highFrequencyGainDesc, ParamID.clarityEffectEnabled, [
      [ParamID.clarityEffectGain, _l10nGain, 0, 15, 15, '', true, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => '${vm.get<int>(ParamID.clarityEffectGain)}'],
    // ── Even Harmonic / Nice ──
    ['evenHarmonicExpanded', Icons.hearing, (l10n) => l10n.nice, (l10n) => l10n.niceDesc, ParamID.evenHarmonicEffectEnabled, [
      [ParamID.evenHarmonicEffectBase, _l10nNiceBase, 0, 1, 100],
      [ParamID.evenHarmonicEffectWarm, _l10nNiceWarm, 0, 1, 100],
      [ParamID.evenHarmonicEffectSugar, _l10nNiceSugar, 0, 1, 100, '', false, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => vm.get<double>(ParamID.evenHarmonicEffectBase).toStringAsFixed(2)],
    // ── Convolution Reverb ──
    ['convolveExpanded', Icons.waves, (l10n) => l10n.convolve, (l10n) => l10n.convolveDesc, ParamID.convolveEffectEnabled, [
      [ParamID.convolveEffectMix, _l10nMixRatio, 0, 1, 100, '', false, false],
    ], (DSPControllerViewModel vm, AppLocalizations l10n) => vm.get<String>(ParamID.convolveEffectIrPath).split('/').last, (BuildContext context, DSPControllerViewModel vm) {
      final l10n = AppLocalizations.of(context)!;
      final colorScheme = Theme.of(context).colorScheme;
      final irPath = vm.get<String>(ParamID.convolveEffectIrPath);
      return [
        ['button', () async {
          try {
            final result = await FilePicker.pickFiles(
              type: FileType.any,
              withData: false,
              withReadStream: false,
            );
            if (result != null && result.files.single.path != null) {
              vm.update(ParamID.convolveEffectIrPath, result.files.single.path!);
            }
          } catch (e) {
            debugPrint('Error picking file: $e');
          }
        }, [
          ['icon', Icons.audio_file, colorScheme.primary],
          ['hgap', 12],
          ['expanded', ['text', irPath.isEmpty ? l10n.selectIRFile : irPath.split('/').last,
            TextStyle(fontSize: 14, color: irPath.isEmpty ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.onSurface), true]],
          ['hgap', 8],
          ['icon', Icons.folder_open, colorScheme.onSurfaceVariant],
        ]],
        const SizedBox(height: 16),
      ];
    }],
    // ── Script Effect ──
    ['scriptExpanded', Icons.code, (l10n) => l10n.scriptEffect, (l10n) => l10n.scriptEffectDesc, ParamID.scriptEffectEnabled, const [],
      (DSPControllerViewModel vm, AppLocalizations l10n) => parseScriptDesc(vm.get<String>(ParamID.scriptEffectCode)),
      (BuildContext context, DSPControllerViewModel vm) {
        final l10n = AppLocalizations.of(context)!;
        final colorScheme = Theme.of(context).colorScheme;
        final enabled = vm.get<bool>(ParamID.scriptEffectEnabled);
        final onColor = enabled ? colorScheme.primary : colorScheme.onSurfaceVariant;
        final library = vm.getScriptLibrary();
        return [
          ['selector', [
            for (final desc in library.keys) [desc, desc, true],
          ], vm.activeScriptDesc.isNotEmpty && library.containsKey(vm.activeScriptDesc) ? vm.activeScriptDesc : null,
            (desc) => vm.switchScript(desc), (desc) => vm.deleteScript(desc), l10n.selectScript],
          ['gap', 12],
          ['button', () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ScriptEditorPage(
                  initialCode: vm.get<String>(ParamID.scriptEffectCode),
                  onSave: (code) => vm.saveScript(code),
                  compileErrorStream: vm.compileErrorStream,
                ),
              ),
            );
          }, [
            ['icon', Icons.code, onColor],
            ['hgap', 8],
            ['expanded', ['text', l10n.editScript, TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant)]],
            ['icon', Icons.edit, onColor],
          ]],
          ['gap', 12],
          ['row', [
            ['expanded', ['button', () => _importScriptFile(context, vm), [
              const Spacer(),
              ['icon', Icons.file_download, onColor, 18],
              ['hgap', 6],
              ['text', l10n.importScript, TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)],
              const Spacer(),
            ], const EdgeInsets.symmetric(vertical: 10, horizontal: 12)]],
            ['hgap', 12],
            ['expanded', ['button', () => _exportScriptFile(context, vm), [
              const Spacer(),
              ['icon', Icons.file_upload, onColor, 18],
              ['hgap', 6],
              ['text', l10n.exportScript, TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)],
              const Spacer(),
            ], const EdgeInsets.symmetric(vertical: 10, horizontal: 12)]],
          ]],
          ['gap', 12],
          // Dynamic parameter sliders
          ...vm.get<List<ScriptParam>>(ParamID.scriptEffectParams).asMap().entries.map((entry) {
            final i = entry.key;
            final param = entry.value;
            final params = vm.get<List<ScriptParam>>(ParamID.scriptEffectParams);
            final isLast = i == params.length - 1;
            return NeumorphicSlider(
              label: param.name,
              value: clampDouble(param.value, param.min, param.max),
              min: param.min,
              max: param.max,
              unit: '',
              divisions: ((param.max - param.min) / param.step).round(),
              decimalPlaces: param.step < 0.01 ? 3 : (param.step < 0.1 ? 2 : 1),
              enabled: enabled,
              showDivider: !isLast,
              onChanged: (v) {
                final params = List<ScriptParam>.from(
                  vm.get<List<ScriptParam>>(ParamID.scriptEffectParams),
                );
                params[i] = ScriptParam(param.name, v, min: param.min, max: param.max, step: param.step);
                vm.update(ParamID.scriptEffectParams, params);
              },
            );
          }),
        ];
      },
    ],
  ];
}

Future<void> _importScriptFile(BuildContext context, DSPControllerViewModel vm) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['c', 'h', 'txt'],
  );
  if (result != null && result.files.single.path != null) {
    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    // Strip UTF-8 BOM if present
    var start = 0;
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      start = 3;
    }
    final data = bytes.sublist(start);
    // Try UTF-8 first, fall back to ASCII (latin-1)
    String code;
    try {
      code = utf8.decode(data);
    } catch (_) {
      code = latin1.decode(data);
    }
    if (code.isNotEmpty) {
      final desc = await vm.importScript(code);
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (desc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailedNoDesc)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importedScript(desc))),
        );
      }
    }
  }
}

Future<void> _exportScriptFile(BuildContext context, DSPControllerViewModel vm) async {
  final l10n = AppLocalizations.of(context)!;
  final code = vm.exportScriptCode();
  if (code == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.noActiveScriptToExport)),
    );
    return;
  }
  final desc = vm.activeScriptDesc;
  final fileName = '${desc.replaceAll(RegExp(r'[^\w\-. ]'), '_')}.c';
  final path = await FilePicker.saveFile(
    dialogTitle: l10n.exportScript,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['c'],
    bytes: Uint8List.fromList(utf8.encode(code)),
  );
  if (path != null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.exportedTo(path.split('/').last))),
    );
  }
}

// Localized slider labels, kept as top-level functions so the spec list
// above stays readable.
String _noLabel(AppLocalizations l10n) => '';
String _l10nThreshold(AppLocalizations l10n) => l10n.compressorThreshold;
String _l10nAttack(AppLocalizations l10n) => l10n.compressorAttack;
String _l10nRelease(AppLocalizations l10n) => l10n.compressorRelease;
String _l10nRatio(AppLocalizations l10n) => l10n.compressorRatio;
String _l10nMakeupGain(AppLocalizations l10n) => l10n.compressorMakeupGain;
String _l10nReverbMix(AppLocalizations l10n) => l10n.reverbMix;
String _l10nReverbRoomSize(AppLocalizations l10n) => l10n.reverbRoomSize;
String _l10nReverbDamping(AppLocalizations l10n) => l10n.reverbDamping;
String _l10nReverbStereoWidth(AppLocalizations l10n) => l10n.reverbStereoWidth;
String _l10nReverbModDepth(AppLocalizations l10n) => l10n.reverbModDepth;
String _l10nReverbModFreq(AppLocalizations l10n) => l10n.reverbModFreq;
String _l10nReverbPreDelay(AppLocalizations l10n) => l10n.reverbPreDelay;
String _l10nDelayMs(AppLocalizations l10n) => l10n.delayMs;
String _l10nGain(AppLocalizations l10n) => l10n.gain;
String _l10nCenterFreq(AppLocalizations l10n) => l10n.centerFreq;
String _l10nQ(AppLocalizations l10n) => l10n.q;
String _l10nCutoffFrequency(AppLocalizations l10n) => l10n.cutoffFrequency;
String _l10nHighGain(AppLocalizations l10n) => l10n.highGain;
String _l10nCenterGain(AppLocalizations l10n) => l10n.centerGain;
String _l10nVirtualBassEnvelopeRate(AppLocalizations l10n) => l10n.virtualBassEnvelopeRate;
String _l10nVirtualBassMidGain(AppLocalizations l10n) => l10n.virtualBassMidGain;
String _l10nVirtualBassHighGain(AppLocalizations l10n) => l10n.virtualBassHighGain;
String _l10nVirtualBassHarmonicGain(AppLocalizations l10n) => l10n.virtualBassHarmonicGain;
String _l10nNiceBase(AppLocalizations l10n) => l10n.niceBase;
String _l10nNiceWarm(AppLocalizations l10n) => l10n.niceWarm;
String _l10nNiceSugar(AppLocalizations l10n) => l10n.niceSugar;
String _l10nMixRatio(AppLocalizations l10n) => l10n.mixRatio;

/// AutoEq spec ("autoeq@<byteOffset>:<rowCount>") -> device display name.
final Map<int, String> _autoEqNameByKey = {
  for (final e in kAutoEqIndex) (e.dataOffset << 20) | e.rowCount: e.name,
};

String _deviceSimulationDisplayName(String config) {
  final spec = config.split('\n').last.trim();
  if (!spec.startsWith('autoeq@')) {
    // Legacy CSV path: .../output_csv/<type>/<name>.csv
    return spec.split('/').last.split('.').first;
  }
  final parts = spec.substring(7).split(':');
  final offset = int.tryParse(parts[0]);
  final rows = parts.length > 1 ? int.tryParse(parts[1]) : null;
  if (offset == null || rows == null) return '';
  return _autoEqNameByKey[(offset << 20) | rows] ?? '';
}
