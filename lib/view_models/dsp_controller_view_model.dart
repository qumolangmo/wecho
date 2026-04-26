/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartz/dartz.dart';
import 'dart:io' show Platform;
import 'dart:async';
import '../models/audio_config.dart';
import '../models/config_manager.dart';

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
  bool limiterExpanded = false;
  bool speakerExciterExpanded = false;
  bool lowcatExpanded = false;

  bool shizukuMode = false;
  bool autoOutputSwitch = true;
  bool shizukuConnected = false;
  String currentAudioOutput = 'unknown';
  String appVersion = 'Unknown';

  bool isCapturing = false;
  bool masterEnabled = true;
  late MethodChannel _channel;
  late SharedPreferences _prefs;
  late ConfigManager _configManager;
  Function()? onStateChanged;
  Function(OutputMode)? onOutputModeChanged;
  OutputMode currentOutputMode = OutputMode.disabled;
  String _lastDevice = '';
  Timer? _pollingTimer;

  bool autoCommit = false;

  DSPControllerViewModel({this.onStateChanged}) {
    _initialize();
  }

  Future<void> _initialize() async {
    _channel = const MethodChannel('audio_capture');
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'updateCaptureStatus') {
        isCapturing = call.arguments as bool;
        onStateChanged?.call();
      } else if (call.method == 'shizukuStatusChanged') {
        shizukuConnected = call.arguments as bool;
        onStateChanged?.call();
      } else if (call.method == 'audioOutputChanged') {
        currentAudioOutput = call.arguments as String;
        onStateChanged?.call();
      }
      return null;
    });

    if (Platform.isWindows) {
      await _invokeMethod('initAPOBridge');
    }

    await _loadSettings();
  
    await _applyAllParams();

    if (Platform.isWindows) {
      await _invokeMethod('commitAPO');
    }

    autoCommit = true;
  
    if (Platform.isAndroid) {
      _startPolling();
      await _fetchCaptureStatus();
    }
  }

  Future<void> update<T>(ParamID id, T value) async {
    _config = _config.copyWith({id: value});
    await setEffectParam(id.index, value);
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollDevice());
  }

  Future<void> _pollDevice() async {
    if (!_configManager.autoOutputSwitch) return;

    final result = await _invokeMethodWithResult<String>('getAutoOutput');
    result.fold(
      (_) {},
      (device) {
        if (device != _lastDevice) {
          _lastDevice = device;
          currentAudioOutput = device;
          _configManager.updateOutputDevice(device);
        }
      },
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _applyAllParams() async {
    for (final paramId in ParamID.values.reversed) {
      await setEffectParam(paramId.index, _config[paramId]);
    }
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _configManager = ConfigManager(_prefs);
    await _configManager.initialize();

    _configManager.onConfigChanged = (mode, config) async {
      _config = config;
      currentOutputMode = mode;
      await _applyAllParams();
      onOutputModeChanged?.call(mode);
      onStateChanged?.call();
    };

    _config = _configManager.getCurrentConfig();
    currentOutputMode = _configManager.currentMode;

    shizukuMode = _prefs.getBool('shizukuMode') ?? false;
    autoOutputSwitch = _prefs.getBool('autoOutputSwitch') ?? true;
    masterEnabled = _prefs.getBool('masterEnabled') ?? true;
    channelBalanceExpanded = _prefs.getBool('channelBalanceExpanded') ?? false;
    globalGainExpanded = _prefs.getBool('globalGainExpanded') ?? false;
    clarityExpanded = _prefs.getBool('clarityExpanded') ?? false;
    bassBoostExpanded = _prefs.getBool('bassBoostExpanded') ?? false;
    evenHarmonicExpanded = _prefs.getBool('evenHarmonicExpanded') ?? false;
    convolveExpanded = _prefs.getBool('convolveExpanded') ?? false;
    limiterExpanded = _prefs.getBool('limiterExpanded') ?? false;
    speakerExciterExpanded = _prefs.getBool('speakerExciterExpanded') ?? false;
    lowcatExpanded = _prefs.getBool('lowcatExpanded') ?? false;

    await _fetchCaptureStatus();
    await setShizukuMode(shizukuMode);
    await setAutoOutputSwitch(autoOutputSwitch);
    await _fetchShizukuStatus();
    await _fetchAutoOutput();
    await _fetchAppVersion();

    onStateChanged?.call();
  }

  Future<void> _saveSettings() async {
    await _configManager.saveConfig(currentOutputMode, _config);
    await _prefs.setBool('shizukuMode', shizukuMode);
    await _prefs.setBool('autoOutputSwitch', autoOutputSwitch);
    await _prefs.setBool('masterEnabled', masterEnabled);
    await _prefs.setBool('channelBalanceExpanded', channelBalanceExpanded);
    await _prefs.setBool('globalGainExpanded', globalGainExpanded);
    await _prefs.setBool('clarityExpanded', clarityExpanded);
    await _prefs.setBool('bassBoostExpanded', bassBoostExpanded);
    await _prefs.setBool('evenHarmonicExpanded', evenHarmonicExpanded);
    await _prefs.setBool('convolveExpanded', convolveExpanded);
    await _prefs.setBool('limiterExpanded', limiterExpanded);
    await _prefs.setBool('speakerExciterExpanded', speakerExciterExpanded);
    await _prefs.setBool('lowcatExpanded', lowcatExpanded);
  }

  Future<void> setShizukuMode(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }
  
    shizukuMode = enabled;
    await _prefs.setBool('shizukuMode', enabled);
    await _invokeMethod('setShizukuMode', enabled);
    if (enabled) {
      await _fetchShizukuStatus();
      if (!isCapturing) {
        await _invokeMethod('startCapture');
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchCaptureStatus();
      }
    } else {
      if (isCapturing) {
        await _invokeMethod('stopCapture');
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchCaptureStatus();
      }
    }
    onStateChanged?.call();
  }

  Future<void> _fetchShizukuStatus() async {
    if (!Platform.isAndroid) {
      return;
    }

    final result = await _invokeMethodWithResult<bool>('getShizukuStatus');
    result.fold(
      (_) {},
      (connected) {
        shizukuConnected = connected;
        onStateChanged?.call();
      },
    );
  }

  Future<void> _fetchCaptureStatus() async {
    if (!Platform.isAndroid) {
      return;
    }

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
    if (!Platform.isAndroid) {
      return;
    }
    
    autoOutputSwitch = enabled;
    await _prefs.setBool('autoOutputSwitch', enabled);
    await _configManager.setAutoOutputSwitch(enabled);
    await _invokeMethod('setAutoOutputSwitch', enabled);
    if (enabled) {
      await _fetchAutoOutput();
    } else {
      await _configManager.updateOutputDevice(currentAudioOutput);
      currentOutputMode = OutputMode.disabled;
      _config = _configManager.loadConfig(OutputMode.disabled);
      await _applyAllParams();
      onOutputModeChanged?.call(OutputMode.disabled);
    }
    onStateChanged?.call();
  }

  Future<void> _fetchAutoOutput() async {
    if (!Platform.isAndroid) {
      return;
    }

    final result = await _invokeMethodWithResult<String>('getAutoOutput');
    result.fold(
      (_) {},
      (device) {
        currentAudioOutput = device;
        if (autoOutputSwitch) {
          _configManager.updateOutputDevice(device);
        }
        onStateChanged?.call();
      },
    );
  }

  Future<void> updateOutputDevice(String device) async {
    await _configManager.updateOutputDevice(device);
  }

  Future<void> switchOutputMode(OutputMode mode) async {
    if (mode == currentOutputMode) return;

    await _configManager.saveConfig(currentOutputMode, _config);
    currentOutputMode = mode;
    _config = _configManager.loadConfig(mode);
    _applyAllParams();
    onOutputModeChanged?.call(mode);
    onStateChanged?.call();
  }

  Future<void> toggleCapture() async {
    if (!isCapturing) {
      await _invokeMethod('startCapture');
    } else {
      await _invokeMethod('stopCapture');
    }
  }

  Future<void> setEffectParam(int paramId, dynamic value) async {
    if (Platform.isWindows) {
      await _invokeMethod('setAPOEffectParam', {'paramId': paramId, 'value': value});

      if (autoCommit) {
        await _invokeMethod('commitAPO');
      }
    } else if (Platform.isAndroid) {
      await _invokeMethod('setEffectParam', {'paramId': paramId, 'value': value});
    }
    
  }

  Future<void> setMasterEnabled(bool enabled) async {
    if (Platform.isWindows) {
      await _invokeMethod('setAPOMasterEnabled', enabled);

      if (autoCommit) {
        await _invokeMethod('commitAPO');
      }
    } else if (Platform.isAndroid) {
      await _invokeMethod('setMasterEnabled', enabled);
    }

  }

  Future<void> _fetchAppVersion() async {
    if (!Platform.isAndroid) {
      return;
    }

    final result = await _invokeMethodWithResult<String>('getAppVersion');
    result.fold(
      (_) {},
      (version) {
        appVersion = version;
        onStateChanged?.call();
      },
    );
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
      case 'limiter':
        limiterExpanded = !limiterExpanded;
        break;
      case 'speakerExciter':
        speakerExciterExpanded = !speakerExciterExpanded;
        break;
      case 'lowcat':
        lowcatExpanded = !lowcatExpanded;
        break;
    }
    await _saveSettings();
    onStateChanged?.call();
  }

  void dispose() {
    _stopPolling();
  }
}
