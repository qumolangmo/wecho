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
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:convert';
import '../models/audio_config.dart';
import '../models/config_manager.dart';

enum AppsLoadState { idle, loading, loaded, noPermission }

class AppError {
  final String message;
  const AppError(this.message);
}

class DSPControllerViewModel {
  AudioConfig _config = AudioConfig();

  bool channelBalanceExpanded = false;
  bool globalGainExpanded = false;
  bool clarityExpanded = false;
  bool bassBoostExpanded = false;
  bool evenHarmonicExpanded = false;
  bool convolveExpanded = false;
  bool compressorExpanded = false;
  bool lowcatExpanded = false;
  bool equalizerExpanded = false;
  bool virtualBassExpanded = false;
  bool reverbExpanded = false;
  bool scriptExpanded = false;
  bool diffSurroundingEffectExpanded = false;
  bool viperReverbEffectExpanded = false;

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

  late MethodChannel _channel;
  late SharedPreferences _prefs;
  late ConfigManager _configManager;
  Function()? onStateChanged;
  Function(String)? onOutputModeChanged;
  String currentDeviceKey = 'disabled';
  Timer? _pollingTimer;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  final Completer<void> _settingsLoadedCompleter = Completer<void>();
  Future<void> get settingsLoaded => _settingsLoadedCompleter.future;

  String? loadingImagePath;

  DSPControllerViewModel({this.onStateChanged}) {
    _initialize();
  }

  Future<void> _initialize() async {
    _channel = const MethodChannel('audio_capture');
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'updateCaptureStatus') {
        isCapturing = call.arguments as bool;
        onStateChanged?.call();
      } else if (call.method == 'audioOutputChanged') {
        final device = call.arguments as String;
        currentAudioOutput = device;
        onStateChanged?.call();
      } else if (call.method == 'onOutputModeChanged') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final output = args['output'] as String;
        currentAudioOutput = output;
        if (autoOutputSwitch) {
          await _configManager.updateOutputDevice(output);
        }
        onStateChanged?.call();
      } else if (call.method == 'onScriptCompileError') {
        _lastCompileError = call.arguments as String;
        _compileErrorController.add(_lastCompileError);
        onScriptCompileError?.call(_lastCompileError);
      }
      return null;
    });

    await _loadSettings();

    await requestShizukuPermission();
    _startPolling();
    await _fetchCaptureStatus();

    _initCompleter.complete();
  }

  Future<void> update<T>(ParamID id, T value) async {
    _config = _config.copyWith({id: value});
    await setEffectParam(id.index, value);
    // Save script params to per-mode storage when updated
    if (id == ParamID.scriptEffectParams && value is List<ScriptParam>) {
      final desc = activeScriptDesc;
      if (desc.isNotEmpty) {
        await _configManager.saveScriptParamsForDesc(currentDeviceKey, desc, value);
      }
    }
    await _saveSettings();
    onStateChanged?.call();
  }

  T get<T>(ParamID id) => _config[id] as T;

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
        onStateChanged?.call();
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
    try {
      return _configManager.loadScriptLibrary();
    } catch (_) {
      return {};
    }
  }

  /// Returns false if missing @desc, true otherwise.
  /// Compile errors are pushed via onScriptCompileError callback.
  Future<bool> saveScript(String code) async {
    final desc = parseScriptDesc(code);
    if (desc.isEmpty || desc == 'not found desc.') return false;
    await _configManager.saveScriptToLibrary(desc, code);
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
    channelBalanceExpanded = _prefs.getBool('channelBalanceExpanded') ?? false;
    globalGainExpanded = _prefs.getBool('globalGainExpanded') ?? false;
    clarityExpanded = _prefs.getBool('clarityExpanded') ?? false;
    bassBoostExpanded = _prefs.getBool('bassBoostExpanded') ?? false;
    evenHarmonicExpanded = _prefs.getBool('evenHarmonicExpanded') ?? false;
    convolveExpanded = _prefs.getBool('convolveExpanded') ?? false;
    compressorExpanded = _prefs.getBool('compressorExpanded') ?? false;
    lowcatExpanded = _prefs.getBool('lowcatExpanded') ?? false;
    equalizerExpanded = _prefs.getBool('equalizerExpanded') ?? false;
    virtualBassExpanded = _prefs.getBool('virtualBassExpanded') ?? false;
    reverbExpanded = _prefs.getBool('reverbExpanded') ?? false;
    scriptExpanded = _prefs.getBool('scriptExpanded') ?? false;
    diffSurroundingEffectExpanded = _prefs.getBool('diffSurroundingEffectExpanded') ?? false;
    viperReverbEffectExpanded = _prefs.getBool('viperReverbEffectExpanded') ?? false;
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
    await _prefs.setBool('channelBalanceExpanded', channelBalanceExpanded);
    await _prefs.setBool('globalGainExpanded', globalGainExpanded);
    await _prefs.setBool('clarityExpanded', clarityExpanded);
    await _prefs.setBool('bassBoostExpanded', bassBoostExpanded);
    await _prefs.setBool('evenHarmonicExpanded', evenHarmonicExpanded);
    await _prefs.setBool('convolveExpanded', convolveExpanded);
    await _prefs.setBool('compressorExpanded', compressorExpanded);
    await _prefs.setBool('lowcatExpanded', lowcatExpanded);
    await _prefs.setBool('equalizerExpanded', equalizerExpanded);
    await _prefs.setBool('virtualBassExpanded', virtualBassExpanded);
    await _prefs.setBool('reverbExpanded', reverbExpanded);
    await _prefs.setBool('scriptExpanded', scriptExpanded);
    await _prefs.setBool('diffSurroundingEffectExpanded', diffSurroundingEffectExpanded);
    await _prefs.setBool('viperReverbEffectExpanded', viperReverbEffectExpanded);
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

  Future<void> setMasterEnabled(bool enabled) async {
    await _invokeMethod('setMasterEnabled', enabled);
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
    await setMasterEnabled(enabled);
    await _saveSettings();
    onStateChanged?.call();
  }

  Future<void> toggleExpanded(String key) async {
    switch (key) {
      case 'channelBalance':
        channelBalanceExpanded = !channelBalanceExpanded;
        break;
      case 'globalGain':
        globalGainExpanded = !globalGainExpanded;
        break;
      case 'clarity':
        clarityExpanded = !clarityExpanded;
        break;
      case 'bassBoost':
        bassBoostExpanded = !bassBoostExpanded;
        break;
      case 'evenHarmonic':
        evenHarmonicExpanded = !evenHarmonicExpanded;
        break;
      case 'convolve':
        convolveExpanded = !convolveExpanded;
        break;
      case 'compressor':
        compressorExpanded = !compressorExpanded;
        break;
      case 'lowcat':
        lowcatExpanded = !lowcatExpanded;
        break;
      case 'equalizer':
        equalizerExpanded = !equalizerExpanded;
        break;
      case 'virtualBass':
        virtualBassExpanded = !virtualBassExpanded;
        break;
      case 'reverb':
        reverbExpanded = !reverbExpanded;
        break;
      case 'script':
        scriptExpanded = !scriptExpanded;
        break;
      case 'diffSurroundingEffect':
        diffSurroundingEffectExpanded = !diffSurroundingEffectExpanded;
        break;
      case 'viperReverbEffect':
        viperReverbEffectExpanded = !viperReverbEffectExpanded;
        break;
    }
    await _saveSettings();
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
