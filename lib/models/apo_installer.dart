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

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// A render endpoint reported by the native APO installer.
class ApoDevice {
  final String guid;
  final String name;
  final String state;
  final bool bound;

  const ApoDevice({
    required this.guid,
    required this.name,
    required this.state,
    required this.bound,
  });

  static ApoDevice fromMap(Map<Object?, Object?> map) => ApoDevice(
        guid: map['guid'] as String? ?? '',
        name: map['name'] as String? ?? '',
        state: map['state'] as String? ?? 'unknown',
        bound: map['bound'] as bool? ?? false,
      );
}

/// Snapshot of the WechoAPO system component state.
class ApoStatus {
  final bool installed;
  final String installDir;
  final bool protectedAudioDGDisabled;
  final List<ApoDevice> devices;

  const ApoStatus({
    required this.installed,
    required this.installDir,
    required this.protectedAudioDGDisabled,
    required this.devices,
  });
}

/// Outcome of an elevated maintenance operation.
class ApoOpResult {
  final bool success;
  final bool cancelled;
  final String error;
  final List<String> log;

  const ApoOpResult({
    required this.success,
    required this.cancelled,
    required this.error,
    required this.log,
  });
}

class ApoInstaller {
  static const MethodChannel _channel = MethodChannel('apo_installer');

  /// SharedPreferences key holding the app version recorded at the last
  /// successful install / update of the APO.
  static const String apoUiVersionKey = 'apoUiVersion';

  Future<String> getAppVersion() async {
    final result = await _channel.invokeMethod<dynamic>('getAppVersion');
    return result as String? ?? '';
  }

  Future<ApoStatus> getStatus() async {
    final result = await _channel.invokeMethod<dynamic>('getStatus');
    if (result is! Map) {
      throw StateError('getStatus returned an unexpected payload');
    }
    final devices = <ApoDevice>[];
    final rawDevices = result['devices'];
    if (rawDevices is List) {
      for (final item in rawDevices) {
        if (item is Map) {
          devices.add(ApoDevice.fromMap(Map<Object?, Object?>.from(item)));
        }
      }
    }
    return ApoStatus(
      installed: result['installed'] as bool? ?? false,
      installDir: result['installDir'] as String? ?? '',
      protectedAudioDGDisabled: result['protectedAudioDGDisabled'] as bool? ?? false,
      devices: devices,
    );
  }

  Future<ApoOpResult> install() => _runOp('install');

  Future<ApoOpResult> uninstall() => _runOp('uninstall');

  Future<ApoOpResult> update() => _runOp('update');

  Future<ApoOpResult> toggleProtectedAudioDG() => _runOp('toggleProtectedAudioDG');

  Future<ApoOpResult> restartAudioService() => _runOp('restart');

  Future<ApoOpResult> bindDevice(String guid) => _runOp('bindDevice', guid);

  Future<ApoOpResult> unbindDevice(String guid) => _runOp('unbindDevice', guid);

  Future<ApoOpResult> _runOp(String method, [String? guid]) async {
    try {
      final result = await _channel.invokeMethod<dynamic>(method, guid);
      final out = _opResultFrom(result);
      if (out.success && (method == 'install' || method == 'update')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(apoUiVersionKey, await getAppVersion());
      }
      return out;
    } on PlatformException catch (e) {
      return ApoOpResult(
        success: false,
        cancelled: false,
        error: e.message ?? e.code,
        log: const [],
      );
    } on MissingPluginException {
      return const ApoOpResult(
        success: false,
        cancelled: false,
        error: 'apo_installer channel unavailable',
        log: [],
      );
    }
  }

  ApoOpResult _opResultFrom(dynamic result) {
    if (result is! Map) {
      return const ApoOpResult(
        success: false,
        cancelled: false,
        error: 'Unexpected result payload',
        log: [],
      );
    }
    final log = <String>[];
    final rawLog = result['log'];
    if (rawLog is List) {
      for (final line in rawLog) {
        if (line is String) log.add(line);
      }
    }
    return ApoOpResult(
      success: result['success'] as bool? ?? false,
      cancelled: result['cancelled'] as bool? ?? false,
      error: result['error'] as String? ?? '',
      log: log,
    );
  }
}
