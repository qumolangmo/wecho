#include "apoBridge.h"
#include "irLoader.hpp"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <debugapi.h>
#include <errhandlingapi.h>
#include <handleapi.h>
#include <thread>
#include "../apo/debug.hpp"

namespace wecho {

APOBridge& APOBridge::getInstance() {
    static APOBridge instance;
    return instance;
}

APOBridge::APOBridge() {}

APOBridge::~APOBridge() {
    sender_should_exit.store(true, std::memory_order_release);
    if (sender_thread.joinable()) {
        sender_thread.join();
    }
}

bool APOBridge::initialize() {
    if (sender_thread.joinable()) {
        return true;
    }

    if (!openSharedMemory()) {
        return false;
    }

    effect_data = std::make_unique<EffectData>();

    sender_should_exit.store(false, std::memory_order_release);
    sender_thread = std::thread([this] () {
        while (!sender_should_exit.load(std::memory_order_acquire)) {
            std::this_thread::sleep_for(std::chrono::milliseconds(30));

            uint64_t last_heart_beat = shared_data->last_heart_beat.load(std::memory_order_acquire);
            if (last_heart_beat + APO_TIMEOUT_MS < current_time_ms()) {
                shared_data->flags.store(false, std::memory_order_release);
            }

            bool flags = shared_data->flags.load(std::memory_order_acquire);
            bool _need_flush = need_flush.load(std::memory_order_acquire);

            if (_need_flush && !flags) {
                memcpy(&shared_data->effect_data, effect_data.get(), sizeof(EffectData));
                shared_data->enabled_apo = processor_enabled;

                need_flush.store(false, std::memory_order_release);
                shared_data->flags.store(true, std::memory_order_release);
            }
        }
    });

    return true;
}

bool APOBridge::openSharedMemory() {
    DebugLog("Opening shared memory...\n");

    if (map_handle == INVALID_HANDLE_VALUE) {
        map_handle = OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, SHARED_MEMORY_NAME);

        if (map_handle == INVALID_HANDLE_VALUE) {
            DebugLog("Failed to open shared memory: ", GetLastError());
            return false;
        }
    }

    if (shared_data == nullptr) {
        shared_data = static_cast<SharedData*>(MapViewOfFile(map_handle, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(SharedData)));
        
        if (shared_data == nullptr) {
            DebugLog("Failed to map view of file: ", GetLastError());
            return false;
        }
    }

    DebugLog("Shared memory opened successfully.\n");
    return true;
}

void APOBridge::closeSharedMemory() {
    DebugLog("Closing shared memory...\n");

    if (shared_data != nullptr) {
        UnmapViewOfFile(shared_data);
        shared_data = nullptr;
    }
    if (map_handle != nullptr) {
        CloseHandle(map_handle);
        map_handle = nullptr;
    }

    DebugLog("Shared memory closed successfully.\n");
}

uint64_t APOBridge::current_time_ms() {
    return (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()
    ).count();
}

void APOBridge::setProcessorEnabled(bool enabled) {
    processor_enabled = enabled;
}

template<ValueType T>
void APOBridge::updateEffectParam(ParamID param_id, T value) {
    if constexpr (std::is_same_v<T, bool>) {
        switch (param_id) {
            case BASS_EFFECT_ENABLED:
                effect_data->BASS_EFFECT_ENABLED = value; 
                break;
            case CLARITY_EFFECT_ENABLED:
                effect_data->CLARITY_EFFECT_ENABLED = value; 
                break;
            case EVEN_HARMONIC_EFFECT_ENABLED:
                effect_data->EVEN_HARMONIC_EFFECT_ENABLED = value; 
                break;
            case CONVOLVE_EFFECT_ENABLED:
                effect_data->CONVOLVE_EFFECT_ENABLED = value; 
                break;
            case LIMITER_EFFECT_ENABLED:
                effect_data->LIMITER_EFFECT_ENABLED = value; 
                break;
            case SPEAKER_EFFECT_ENABLED:
                effect_data->SPEAKER_EFFECT_ENABLED = value; 
                break;
            case LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED:
                effect_data->LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED = value; 
                break;
            case LOW_CAT_EFFECT_ENABLED:
                effect_data->LOW_CAT_EFFECT_ENABLED = value; 
                break;
            default:
                break;
        }
    } else if constexpr (std::is_same_v<T, int>) {
        switch (param_id) {
            case BASS_EFFECT_GAIN:
                effect_data->BASS_EFFECT_GAIN = value;
                break;
            case BASS_EFFECT_CENTER_FREQ:
                effect_data->BASS_EFFECT_CENTER_FREQ = value;
                break;
            case CLARITY_EFFECT_GAIN:
                effect_data->CLARITY_EFFECT_GAIN = value;
                break;
            case EVEN_HARMONIC_EFFECT_GAIN:
                effect_data->EVEN_HARMONIC_EFFECT_GAIN = value;
                break;
            case LIMITER_EFFECT_THRESHOLD:
                effect_data->LIMITER_EFFECT_THRESHOLD = value;
                break;
            case LIMITER_EFFECT_RATIO:
                effect_data->LIMITER_EFFECT_RATIO = value;
                break;
            case LIMITER_EFFECT_MAKEUP_GAIN:
                effect_data->LIMITER_EFFECT_MAKEUP_GAIN = value;
                break;
            case LIMITER_EFFECT_ATTACK:
                effect_data->LIMITER_EFFECT_ATTACK = value;
                break;
            case LIMITER_EFFECT_RELEASE:
                effect_data->LIMITER_EFFECT_RELEASE = value;
                break;
            case LOW_CAT_EFFECT_CUTOFF_FREQ:
                effect_data->LOW_CAT_EFFECT_CUTOFF_FREQ = value;
                break;
            default:
                break;
        }
    } else if constexpr (std::is_same_v<T, float>) {
        switch (param_id) {
            case GAIN_EFFECT_GAIN:
                effect_data->GAIN_EFFECT_GAIN = value;
                break;
            case BALANCE_EFFECT_BALANCE:
                effect_data->BALANCE_EFFECT_BALANCE = value;
                break;
            case BASS_EFFECT_Q:
                effect_data->BASS_EFFECT_Q = value;
                break;
            case CONVOLVE_EFFECT_MIX:
                effect_data->CONVOLVE_EFFECT_MIX = value;
                break;
            case SPEAKER_EFFECT_HP_GAIN:
                effect_data->SPEAKER_EFFECT_HP_GAIN = value;
                break;
            case SPEAKER_EFFECT_BP_GAIN:
                effect_data->SPEAKER_EFFECT_BP_GAIN = value;
                break;
            case SPEAKER_EFFECT_2_HARMONIC_COEFFS:
                effect_data->SPEAKER_EFFECT_2_HARMONIC_COEFFS = value;
                break;
            case SPEAKER_EFFECT_4_HARMONIC_COEFFS:
                effect_data->SPEAKER_EFFECT_4_HARMONIC_COEFFS = value;
                break;
            case SPEAKER_EFFECT_6_HARMONIC_COEFFS:
                effect_data->SPEAKER_EFFECT_6_HARMONIC_COEFFS = value;
                break;
            default:
                break;
        }
    } else if constexpr (std::is_same_v<T, std::string>) {
        if (param_id == CONVOLVE_EFFECT_IR_PATH) {
            auto ir_samples = loadIr(value);

            if (ir_samples.size() == 2) {
                int sample_count = std::min(static_cast<int>(ir_samples[0].size()), 65536);

                memcpy(effect_data->CONVOLVE_EFFECT_IR_DATA, ir_samples[0].data(), sample_count * sizeof(float));
                memcpy(effect_data->CONVOLVE_EFFECT_IR_DATA + sample_count, ir_samples[1].data(), sample_count * sizeof(float));
            }

            shared_data->ir_length = ir_samples[0].size() * 2;

            memcpy(effect_data->CONVOLVE_EFFECT_IR_PATH, value.c_str(), value.length() * sizeof(char));
        }
    }
}

void APOBridge::commit() {
    need_flush.store(true, std::memory_order_release);
}

auto APOBridge::loadIr(const std::string& ir_path) -> std::vector<std::vector<float>> {
    std::vector<std::vector<float>> ir_samples(2, std::vector<float>(65536));

    if (!IrLoader::loadAndNormalize(ir_path, ir_samples)) {
        return std::vector<std::vector<float>>(2, std::vector<float>(0));
    }

    return ir_samples;
}

template void APOBridge::updateEffectParam<bool>(ParamID param_id, bool value);
template void APOBridge::updateEffectParam<int>(ParamID param_id, int value);
template void APOBridge::updateEffectParam<float>(ParamID param_id, float value);
template void APOBridge::updateEffectParam<std::string>(ParamID param_id, std::string value);

}
