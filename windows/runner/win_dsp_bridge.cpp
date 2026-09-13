#include "win_dsp_bridge.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

namespace wecho {

namespace {
// Kept alive for the lifetime of the process; the engine outlives us.
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel = nullptr;

const flutter::StandardMethodCodec& Codec() {
  return flutter::StandardMethodCodec::GetInstance();
}
}  // namespace

void RegisterDspBridge(flutter::FlutterEngine* engine) {
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "audio_capture", &Codec());

  g_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        // TODO: replace stubs with the APO pipe bridge (see header).
        if (method == "getProcessingLatency") {
          result->Success(flutter::EncodableValue(0.0));
        } else if (method == "getCaptureStatus") {
          result->Success(flutter::EncodableValue(false));
        } else if (method == "getAutoOutput") {
          result->Success(flutter::EncodableValue(false));
        } else if (method == "getAppVersion") {
          result->Success(flutter::EncodableValue("Windows stub"));
        } else if (method == "getInstalledApps" ||
                   method == "getDeviceSimulationFreqResponse") {
          result->Success(flutter::EncodableValue(flutter::EncodableList()));
        } else if (method == "setEffectParam" || method == "setMasterEnabled" ||
                   method == "reloadConfig" || method == "setPowerSaving" ||
                   method == "setAutoOutputSwitch" || method == "startCapture" ||
                   method == "stopCapture" || method == "requestShizukuPermission" ||
                   method == "readAssetFile") {
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
}

}  // namespace wecho
