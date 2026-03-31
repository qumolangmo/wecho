/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"
#include "../utils/debug.hpp"
#include <chrono>
#include <atomic>

bool FFTWFPlan::wisdom_imported = false;
std::string FFTWFPlan::wisdom_path = "";

ConvolveEffect::ConvolveEffect(bool enabled, float mix)
    : Effect(enabled)
    , mix(mix){

    convolver.setIr("this_is_an_message_of_init_convolve_effect___not_an_error");
    reset();
}

ConvolveEffect::~ConvolveEffect() {}

Priority ConvolveEffect::priority() const {
    return CONVOLVE_EFFECT;
}

void ConvolveEffect::reset() {
    convolver.reset();
}

void ConvolveEffect::run(std::vector<std::vector<float>>& audio) {
    static std::atomic<uint64_t> total_us{0};
    static std::atomic<uint64_t> call_count{0};
    static std::atomic<uint64_t> last_report_time{0};
    
    auto start = std::chrono::high_resolution_clock::now();
    convolver.convolve(audio, audio);
    auto end = std::chrono::high_resolution_clock::now();
    
    uint64_t elapsed_us = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
    uint64_t total = total_us.fetch_add(elapsed_us) + elapsed_us;
    uint64_t count = call_count.fetch_add(1) + 1;
    
    uint64_t now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()
    ).count();
    
    uint64_t last_report = last_report_time.load();
    if (now_ms - last_report >= 2000) {
        if (last_report_time.compare_exchange_strong(last_report, now_ms)) {
            uint64_t avg_us = total / count;
            LOG_D("[ConvolveEffect] current: %llu us, avg: %llu us, calls: %llu", elapsed_us, avg_us, count);
            total_us = 0;
            call_count = 0;
        }
    }
}

void ConvolveEffect::setMix(float mix) {
    this->mix.store(mix, std::memory_order_release);
}

void ConvolveEffect::setIr(const std::string& ir_path) {
    convolver.setIr(ir_path);
    reset();
}

void ConvolveEffect::setIr(const std::vector<std::vector<float>>& ir_data) {
    convolver.setIr(ir_data);
    reset();
}
