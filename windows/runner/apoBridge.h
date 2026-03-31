#pragma once

#include <memory>
#include <windows.h>
#include <string>
#include <thread>
#include <atomic>
#include <mutex>
#include <unordered_map>
#include <any>
#include <vector>

#include "../../native/enum.h"

namespace wecho {

template<typename T>
concept ValueType = std::is_same_v<T, bool> || std::is_same_v<T, int> || std::is_same_v<T, float> || std::is_same_v<T, std::string>;

class APOBridge {
public:
    static APOBridge& getInstance();

    bool initialize();

    void setProcessorEnabled(bool enabled);

    template<ValueType T>
    void updateEffectParam(ParamID param_id, T value);

    void commit();

private:
    APOBridge();
    ~APOBridge();

    APOBridge(const APOBridge&) = delete;
    APOBridge& operator=(const APOBridge&) = delete;

    void syncAllParams();

    uint64_t current_time_ms();

    bool openSharedMemory();

    void closeSharedMemory();

    void syncCachedParams(const EffectData* data);

    auto loadIr(const std::string& ir_path) -> std::vector<std::vector<float>>;

private:
    HANDLE map_handle = INVALID_HANDLE_VALUE;
    SharedData* shared_data = nullptr;

    std::unique_ptr<EffectData> effect_data;
    bool processor_enabled = false;

    std::atomic<bool> need_flush{false};
    std::thread sender_thread;
    std::atomic<bool> sender_should_exit{false};

    static constexpr int APO_TIMEOUT_MS = 100;
    static constexpr const wchar_t* SHARED_MEMORY_NAME = L"Global\\WechoAPO_SharedData";
};

}
