#ifndef RUNNER_WIN_DSP_BRIDGE_H_
#define RUNNER_WIN_DSP_BRIDGE_H_

#include <flutter/flutter_engine.h>

namespace wecho {

// Registers the "audio_capture" MethodChannel with stub handlers so the
// shared Dart DSPControllerViewModel runs on Windows.
// TODO: wire setEffectParam/setMasterEnabled/reloadConfig/latency/freq-response
// to the APO named pipe (\\.\pipe\WechoAPO) following
// wecho-qt/windows_ui/DspController.cpp L355-L460 (PipeMessageHeader protocol
// with FLAG_INITIALIZE and a 500ms reconnect timer).
void RegisterDspBridge(flutter::FlutterEngine* engine);

}  // namespace wecho

#endif  // RUNNER_WIN_DSP_BRIDGE_H_
