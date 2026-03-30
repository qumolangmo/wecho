/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"

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
    convolver.convolve(audio, audio);
}

void ConvolveEffect::setMix(float mix) {
    this->mix.store(mix, std::memory_order_release);
}

void ConvolveEffect::setIr(const std::string& ir_path) {
    convolver.setIr(ir_path);
    reset();
}

void ConvolveEffect::setIr(std::vector<std::vector<float>>&& ir_data) {
    convolver.setIr(std::move(ir_data));
    reset();
}
