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

import 'dart:io';

import 'package:flutter/services.dart';

abstract class DspPlatformBridge {
  factory DspPlatformBridge() {
    if (Platform.isWindows) {
      return MethodChannelBridge('wecho_dsp');
    }
    // Android runner. Adjust here when a Linux runner lands.
    return MethodChannelBridge('audio_capture');
  }

  /// Sends a method with optional arguments to the native side.
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]);

  /// Installs the native -> Dart callback dispatcher.
  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler);
}

class MethodChannelBridge implements DspPlatformBridge {
  MethodChannelBridge(String name) : _channel = MethodChannel(name);

  final MethodChannel _channel;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  @override
  void setMethodCallHandler(
      Future<dynamic> Function(MethodCall call)? handler) {
    _channel.setMethodCallHandler(handler);
  }
}

class DspNativeCallbacks {
  DspNativeCallbacks({
    this.onCaptureStatusChanged,
    this.onAudioOutputChanged,
    this.onOutputModeChanged,
    this.onScriptCompileError,
  });

  /// Pushed when capture starts/stops.
  final void Function(bool capturing)? onCaptureStatusChanged;

  /// Pushed when the default audio output device changes.
  final void Function(String device)? onAudioOutputChanged;

  /// Pushed when the output mode (normal/direct) changes.
  final Future<void> Function(String output)? onOutputModeChanged;

  /// Pushed when a TCC script fails to compile in the DSP.
  final void Function(String error)? onScriptCompileError;
}

void installNativeEventDispatcher(DspPlatformBridge bridge, DspNativeCallbacks callbacks) {
  final table = <String, Future<void> Function(dynamic args)>{
    'updateCaptureStatus': (args) async =>
        callbacks.onCaptureStatusChanged?.call(args as bool),
    'audioOutputChanged': (args) async =>
        callbacks.onAudioOutputChanged?.call(args as String),
    'onOutputModeChanged': (args) async => callbacks.onOutputModeChanged?.call(
        Map<String, dynamic>.from(args as Map)['output'] as String),
    'onScriptCompileError': (args) async =>
        callbacks.onScriptCompileError?.call(args as String),
  };

  bridge.setMethodCallHandler((call) async {
    final handler = table[call.method];
    if (handler != null) {
      await handler(call.arguments);
    }
    return null;
  });
}
