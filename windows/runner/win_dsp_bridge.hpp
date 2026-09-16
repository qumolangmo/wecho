#pragma once

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <atomic>
#include <cstdint>
#include <cstring>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <variant>
#include <vector>

#include "../../native/enum.h"

namespace wecho {

constexpr wchar_t pipe_name[] = L"\\\\.\\pipe\\WechoAPO";
constexpr int32_t master_enabled_id = MASTER_EFFECT_ENABLED;
constexpr int32_t device_simulation_config_id = DEVICE_SIMULATION_EFFECT_CONFIG;
constexpr int reconnect_interval_ms = 100;
// Control-plane commands - must match PipeServer.hpp.
constexpr uint32_t cmd_get_freq_response = 0x80000001u;
constexpr uint32_t cmd_freq_response = 0x80000002u;
constexpr DWORD freq_response_timeout_ms = 2000;

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

/* Bridges the Dart "wecho_dsp" method channel to the APO control pipe: pushes
   parameter updates down and prefetches the device-simulation frequency
   response on a worker thread so the platform thread never blocks.
   All state is static; there is exactly one bridge per process. */
class DspBridge {
public:
    static void registerChannel(flutter::FlutterEngine* engine) {
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), "wecho_dsp", &flutter::StandardMethodCodec::GetInstance());

        channel->SetMethodCallHandler(
            [](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
                if (handleCall(call, *result)) {
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
                } else if (method == "getInstalledApps") {
                    result->Success(flutter::EncodableValue(flutter::EncodableList()));
                } else if (method == "setPowerSaving" || method == "setAutoOutputSwitch" ||
                           method == "startCapture" || method == "stopCapture" ||
                           method == "requestShizukuPermission" || method == "readAssetFile") {
                    result->Success(flutter::EncodableValue(true));
                } else {
                    result->NotImplemented();
                }
            });

        /* keep the channel alive for the lifetime of the process. */
        channel.release();

        registerGetters();

        if (!running.exchange(true, std::memory_order_acq_rel)) {
            std::thread(worker_loop).detach();
        }
    }

private:
    /* get-style method handlers: name -> Dart value. Looked up by handleCall. */
    using DartGetter = std::function<flutter::EncodableValue()>;

    inline static std::mutex pipe_mutex;
    inline static HANDLE pipe = INVALID_HANDLE_VALUE;
    inline static HANDLE io_event = nullptr;
    inline static std::map<int32_t, ParamValue> cache;

    inline static std::mutex freq_mutex;
    inline static std::vector<float> freq_response;
    inline static bool freq_dirty = true;

    inline static std::map<std::string, DartGetter> getters;
    inline static std::atomic<bool> running{false};

    static uint32_t paramTypeOf(int32_t id) {
        static constexpr uint32_t types[] = {
#define X(name, type, enum_type) enum_type,
            EFFECT_PARAMS
#undef X
        };

        if (id < 0 || id >= static_cast<int32_t>(MAX_EFFECT_PARAM)) {
            return 0xFFFFFFFFu;
        }

        return types[id];
    }

    static void disconnectLocked() {
        if (pipe != INVALID_HANDLE_VALUE) {
            CloseHandle(pipe);
            pipe = INVALID_HANDLE_VALUE;
        }
        freq_dirty = true;
    }

    /* synchronous overlapped IO with timeout; returns bytes transferred or 0. */
    static DWORD pipeTransferLocked(bool write, void* buf, DWORD len, DWORD timeout_ms) {
        if (pipe == INVALID_HANDLE_VALUE || !io_event) {
            return 0;
        }

        OVERLAPPED ov{};
        ov.hEvent = io_event;
        ResetEvent(io_event);

        const BOOL ok = write ? WriteFile(pipe, buf, len, nullptr, &ov)
                              : ReadFile(pipe, buf, len, nullptr, &ov);
        DWORD transferred = 0;
        if (ok || GetLastError() == ERROR_IO_PENDING) {
            if (WaitForSingleObject(io_event, timeout_ms) == WAIT_OBJECT_0) {
                GetOverlappedResult(pipe, &ov, &transferred, FALSE);
            } else {
                CancelIoEx(pipe, &ov);
                DWORD tmp = 0;
                GetOverlappedResult(pipe, &ov, &tmp, TRUE);
            }
        }
        return transferred;
    }

    static bool writeMessageLocked(int32_t id, uint32_t type, const std::vector<uint8_t>& payload, bool initialize) {
        if (pipe == INVALID_HANDLE_VALUE) {
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

        auto written = pipeTransferLocked(true, msg.data(), static_cast<DWORD>(msg.size()), freq_response_timeout_ms);
        if (written != msg.size()) {
            disconnectLocked();
            return false;
        }

        return true;
    }

    static void sendInitBatchLocked() {
        for (auto it = cache.rbegin(); it != cache.rend(); ++it) {
            writeMessageLocked(it->first, it->second.type, it->second.bytes, true);
        }
    }

    static bool connectLocked() {
        if (pipe != INVALID_HANDLE_VALUE) {
            return true;
        }

        pipe = CreateFileW(pipe_name, GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
        if (pipe == INVALID_HANDLE_VALUE) {
            return false;
        }

        DWORD mode = PIPE_READMODE_MESSAGE;
        SetNamedPipeHandleState(pipe, &mode, nullptr, nullptr);
        sendInitBatchLocked();
        return true;
    }

    static void refreshFreqResponseLocked() {
        PipeMessageHeader hdr{};
        hdr.magic = PipeMessageHeader::MAGIC;
        hdr.param_id = device_simulation_config_id;
        hdr.value_type = cmd_get_freq_response;
        hdr.value_size = 0;
        hdr.flags = 0;

        if (pipeTransferLocked(true, &hdr, sizeof(hdr), freq_response_timeout_ms) != sizeof(hdr)) {
            disconnectLocked();
            return;
        }

        std::vector<uint8_t> resp(sizeof(PipeMessageHeader) + (1u << 20));
        auto got = pipeTransferLocked(false, resp.data(), static_cast<DWORD>(resp.size()), freq_response_timeout_ms);
        if (got < sizeof(PipeMessageHeader)) {
            disconnectLocked();
            return;
        }

        PipeMessageHeader rh{};
        std::memcpy(&rh, resp.data(), sizeof(rh));
        if (rh.magic != PipeMessageHeader::MAGIC || rh.value_type != cmd_freq_response || got != sizeof(rh) + rh.value_size) {
            return;
        }

        const size_t count = rh.value_size / sizeof(float);
        const auto* begin = reinterpret_cast<const float*>(resp.data() + sizeof(rh));
        std::lock_guard<std::mutex> lock(freq_mutex);
        freq_response.assign(begin, begin + count);
    }

    static void worker_loop() {
        io_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);

        while (running.load(std::memory_order_acquire)) {
            {
                std::lock_guard<std::mutex> lock(pipe_mutex);
                /* no-op while connected; sends the init batch on (re)connect. */
                connectLocked();
                if (pipe != INVALID_HANDLE_VALUE && freq_dirty) {
                    freq_dirty = false;
                    refreshFreqResponseLocked();
                }
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(reconnect_interval_ms));
        }

        if (io_event) {
            CloseHandle(io_event);
            io_event = nullptr;
        }
    }

    static void submitParam(int32_t id, uint32_t type, std::vector<uint8_t> payload, bool initialize) {
        const uint32_t wire_type = (type == 0xFFFFFFFFu) ? paramTypeOf(id) : type;
        if (wire_type == 0xFFFFFFFFu) {
            return;
        }

        std::lock_guard<std::mutex> lock(pipe_mutex);
        ParamValue& entry = cache[id];
        entry.type = wire_type;
        entry.bytes = std::move(payload);
        writeMessageLocked(id, entry.type, entry.bytes, initialize);
        if (id == device_simulation_config_id) {
            freq_dirty = true;
        }
    }

    /* enc a Dart-side value into the wire payload for the param's type. */
    static bool encodePayload(uint32_t type, const flutter::EncodableValue& value, std::vector<uint8_t>& out) {
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
                /* serialized by the Dart side (16 * 68 bytes: name[64] + float). */
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

    static const flutter::EncodableValue* mapArg(const flutter::EncodableMap& args, const char* key) {
        auto it = args.find(flutter::EncodableValue(key));
        return it != args.end() ? &it->second : nullptr;
    }

    static int32_t mapIntArg(const flutter::EncodableMap& args, const char* key) {
        const auto* v = mapArg(args, key);
        if (!v) return -1;
        if (std::holds_alternative<int32_t>(*v)) return std::get<int32_t>(*v);
        if (std::holds_alternative<int64_t>(*v)) return static_cast<int32_t>(std::get<int64_t>(*v));
        return -1;
    }

    /* returns true when the call was DSP-related (handled over the pipe); false
       leaves the call for the generic stub handlers. */
    static bool handleCall(const flutter::MethodCall<flutter::EncodableValue>& call, flutter::MethodResult<flutter::EncodableValue>& result) {
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
                submitParam(master_enabled_id, PARAM_TYPE_BOOL, std::move(payload), false);
            }
            result.Success(flutter::EncodableValue(true));
            return true;
        }

        if (call.method_name() == "reloadConfig") {
            /* Re-seed the APO from the cache (no-op when disconnected; the worker
               replays the batch after its next successful connect). */
            std::lock_guard<std::mutex> lock(pipe_mutex);
            sendInitBatchLocked();
            result.Success(flutter::EncodableValue(true));
            return true;
        }

        const auto getter = getters.find(std::string(call.method_name()));
        if (getter != getters.end()) {
            result.Success(getter->second());
            return true;
        }

        return false;
    }

    static void registerGetters() {
        getters["getDeviceSimulationFreqResponse"] = []() {
            std::lock_guard<std::mutex> lock(freq_mutex);
            flutter::EncodableList list;
            list.reserve(freq_response.size());
            for (float v : freq_response) {
                list.push_back(flutter::EncodableValue(static_cast<double>(v)));
            }
            return flutter::EncodableValue(std::move(list));
        };
    }
};

inline void RegisterDspBridge(flutter::FlutterEngine* engine) {
    DspBridge::registerChannel(engine);
}

}  // namespace wecho
