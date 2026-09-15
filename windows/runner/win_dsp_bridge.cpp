#include "win_dsp_bridge.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <atomic>
#include <cstdint>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <variant>
#include <vector>

#include "../../native/enum.h"

namespace wecho {
namespace {

constexpr wchar_t kPipeName[] = L"\\\\.\\pipe\\WechoAPO";
constexpr int32_t kMasterEnabledId = MASTER_EFFECT_ENABLED;
constexpr int kReconnectIntervalMs = 500;

struct PipeMessageHeader {
    static constexpr uint32_t MAGIC = 0x57454348u;  // 'W''E''C''H'
    static constexpr uint32_t FLAG_INITIALIZE = 0x00000001u;
    uint32_t magic;
    int32_t param_id;
    uint32_t value_type;
    uint32_t value_size;
    uint32_t flags;
};
static_assert(sizeof(PipeMessageHeader) == 20, "PipeMessageHeader must be 20 bytes");

struct ParamValue {
    uint32_t type = 0xFFFFFFFFu;
    std::vector<uint8_t> bytes;
};

std::mutex g_mtx;
HANDLE g_pipe = INVALID_HANDLE_VALUE;
std::map<int32_t, ParamValue> g_cache;
std::atomic<bool> g_running{false};

uint32_t paramTypeOf(int32_t id) {
    static constexpr uint32_t kTypes[] = {
#define X(name, type, enum_type) enum_type,
        EFFECT_PARAMS
#undef X
    };

    if (id < 0 || id >= static_cast<int32_t>(MAX_EFFECT_PARAM)) {
        return 0xFFFFFFFFu;
    }

    return kTypes[id];
}

void disconnectLocked() {
    if (g_pipe != INVALID_HANDLE_VALUE) {
        CloseHandle(g_pipe);
        g_pipe = INVALID_HANDLE_VALUE;
    }
}

bool writeMessageLocked(int32_t id, uint32_t type, const std::vector<uint8_t>& payload,
                        bool initialize) {
    if (g_pipe == INVALID_HANDLE_VALUE) {
        return false;
    }

    PipeMessageHeader hdr{};
    hdr.magic = PipeMessageHeader::MAGIC;
    hdr.param_id = id;
    hdr.value_type = type;
    hdr.value_size = static_cast<uint32_t>(payload.size());
    hdr.flags = initialize ? PipeMessageHeader::FLAG_INITIALIZE : 0u;

    std::vector<uint8_t> msg(sizeof(hdr) + payload.size());
    std::memcpy(msg.data(), &hdr, sizeof(hdr));
    if (!payload.empty()) {
        std::memcpy(msg.data() + sizeof(hdr), payload.data(), payload.size());
    }

    DWORD written = 0;
    auto success = WriteFile(g_pipe, msg.data(), static_cast<DWORD>(msg.size()), &written, nullptr);

    if (!success || written != msg.size()) {
        disconnectLocked();
        return false;
    }

    return true;
}

void sendInitBatchLocked() {
    for (auto it = g_cache.rbegin(); it != g_cache.rend(); ++it) {
        writeMessageLocked(it->first, it->second.type, it->second.bytes, true);
    }
}

bool connectLocked() {
    if (g_pipe != INVALID_HANDLE_VALUE) {
        return true;
    }

    g_pipe = CreateFileW(kPipeName, GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
    if (g_pipe == INVALID_HANDLE_VALUE) {
        return false;
    }

    DWORD mode = PIPE_READMODE_MESSAGE;
    SetNamedPipeHandleState(g_pipe, &mode, nullptr, nullptr);
    sendInitBatchLocked();
    return true;
}

void workerLoop() {
    while (g_running.load(std::memory_order_acquire)) {
        {
            std::lock_guard<std::mutex> lock(g_mtx);
            // No-op while connected; sends the init batch on (re)connect.
            connectLocked();
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(kReconnectIntervalMs));
    }
}

void submitParam(int32_t id, uint32_t type, std::vector<uint8_t> payload, bool initialize) {
    const uint32_t wire_type = (type == 0xFFFFFFFFu) ? paramTypeOf(id) : type;
    if (wire_type == 0xFFFFFFFFu) {
        return;
    }

    std::lock_guard<std::mutex> lock(g_mtx);
    ParamValue& v = g_cache[id];
    v.type = wire_type;
    v.bytes = std::move(payload);
    writeMessageLocked(id, v.type, v.bytes, initialize);
}

// Encodes a Dart-side value into the wire payload for the param's type.
bool encodePayload(uint32_t type, const flutter::EncodableValue& value, std::vector<uint8_t>& out) {
    switch (type) {
        case PARAM_TYPE_BOOL:
            if (!std::holds_alternative<bool>(value)) return false;
            out.push_back(std::get<bool>(value) ? 1 : 0);
            return true;
        case PARAM_TYPE_INT: {
            int32_t v = 0;
            if (std::holds_alternative<int32_t>(value)) {
                v = std::get<int32_t>(value);
            } else if (std::holds_alternative<int64_t>(value)) {
                v = static_cast<int32_t>(std::get<int64_t>(value));
            } else if (std::holds_alternative<double>(value)) {
                v = static_cast<int32_t>(std::get<double>(value));
            } else {
                return false;
            }
            out.resize(sizeof(v));
            std::memcpy(out.data(), &v, sizeof(v));
            return true;
        }
        case PARAM_TYPE_FLOAT: {
            float v = 0.0f;
            if (std::holds_alternative<double>(value)) {
                v = static_cast<float>(std::get<double>(value));
            } else if (std::holds_alternative<int32_t>(value)) {
                v = static_cast<float>(std::get<int32_t>(value));
            } else if (std::holds_alternative<int64_t>(value)) {
                v = static_cast<float>(std::get<int64_t>(value));
            } else {
                return false;
            }
            out.resize(sizeof(v));
            std::memcpy(out.data(), &v, sizeof(v));
            return true;
        }
        case PARAM_TYPE_STRING: {
            if (!std::holds_alternative<std::string>(value)) return false;
            const std::string& s = std::get<std::string>(value);
            out.assign(s.begin(), s.end());
            return true;
        }
        case PARAM_TYPE_SCRIPT_PARAMS: {
            // Serialized by the Dart side (16 * 68 bytes: name[64] + float).
            if (std::holds_alternative<std::vector<uint8_t>>(value)) {
                out = std::get<std::vector<uint8_t>>(value);
                return true;
            }
            return false;
        }
        default:
            return false;
    }
}

const flutter::EncodableValue* mapArg(const flutter::EncodableMap& args, const char* key) {
    auto it = args.find(flutter::EncodableValue(key));
    return it != args.end() ? &it->second : nullptr;
}

int32_t mapIntArg(const flutter::EncodableMap& args, const char* key) {
    const auto* v = mapArg(args, key);
    if (!v) return -1;
    if (std::holds_alternative<int32_t>(*v)) return std::get<int32_t>(*v);
    if (std::holds_alternative<int64_t>(*v)) return static_cast<int32_t>(std::get<int64_t>(*v));
    return -1;
}

// Returns true when the call was DSP-related (handled over the pipe); false
// leaves the call for the generic stub handlers.
bool handleDspCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                   flutter::MethodResult<flutter::EncodableValue>& result) {
    if (call.method_name() == "setEffectParam") {
        if (!call.arguments() ||
            !std::holds_alternative<flutter::EncodableMap>(*call.arguments())) {
            result.Success(flutter::EncodableValue(false));
            return true;
        }
        const auto& args = std::get<flutter::EncodableMap>(*call.arguments());
        const int32_t id = mapIntArg(args, "paramId");
        const uint32_t type = paramTypeOf(id);
        const auto* value = mapArg(args, "value");
        const auto* init = mapArg(args, "initialize");
        const bool initialize =
            init && std::holds_alternative<bool>(*init) && std::get<bool>(*init);

        std::vector<uint8_t> payload;
        if (type == 0xFFFFFFFFu || !value || !encodePayload(type, *value, payload)) {
            result.Success(flutter::EncodableValue(false));
            return true;
        }
        submitParam(id, type, std::move(payload), initialize);
        result.Success(flutter::EncodableValue(true));
        return true;
    }

    if (call.method_name() == "setMasterEnabled") {
        if (call.arguments() && std::holds_alternative<bool>(*call.arguments())) {
            std::vector<uint8_t> payload{
                static_cast<uint8_t>(std::get<bool>(*call.arguments()) ? 1 : 0)};
            submitParam(kMasterEnabledId, PARAM_TYPE_BOOL, std::move(payload), false);
        }
        result.Success(flutter::EncodableValue(true));
        return true;
    }

    if (call.method_name() == "reloadConfig") {
        // Re-seed the APO from the cache (no-op when disconnected; the worker
        // replays the batch after its next successful connect).
        std::lock_guard<std::mutex> lock(g_mtx);
        sendInitBatchLocked();
        result.Success(flutter::EncodableValue(true));
        return true;
    }

    return false;
}

}  // namespace

void RegisterDspBridge(flutter::FlutterEngine* engine) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        engine->messenger(), "wecho_dsp", &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            if (handleDspCall(call, *result)) {
                return;
            }

            const std::string& method = call.method_name();
            if (method == "getProcessingLatency") {
                result->Success(flutter::EncodableValue(0.0));
            } else if (method == "getCaptureStatus") {
                result->Success(flutter::EncodableValue(false));
            } else if (method == "getAutoOutput") {
                result->Success(flutter::EncodableValue(false));
            } else if (method == "getAppVersion") {
                result->Success(flutter::EncodableValue(std::string(FLUTTER_VERSION)));
            } else if (method == "getInstalledApps" ||
                       method == "getDeviceSimulationFreqResponse") {
                result->Success(flutter::EncodableValue(flutter::EncodableList()));
            } else if (method == "setPowerSaving" || method == "setAutoOutputSwitch" ||
                       method == "startCapture" || method == "stopCapture" ||
                       method == "requestShizukuPermission" || method == "readAssetFile") {
                result->Success(flutter::EncodableValue(true));
            } else {
                result->NotImplemented();
            }
        });

    // Keep the channel alive for the lifetime of the process.
    channel.release();

    if (!g_running.exchange(true, std::memory_order_acq_rel)) {
        std::thread(workerLoop).detach();
    }
}

}  // namespace wecho
