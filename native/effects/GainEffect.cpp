/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"

/**********************************************GainEffect***************************************************/
GainEffect::GainEffect(bool _enabled, float gain)
    : Effect(_enabled) {

    setGain(gain);
    reset();
}
GainEffect::~GainEffect() {}

Priority GainEffect::priority() const {
    return GAIN_EFFECT;
}

void GainEffect::reset() {}

void GainEffect::setGain(float gain) {
    if (std::abs(gain) < 0.0001f) {
        this->enabled.store(false, std::memory_order_release);
        return;
    } else {
        this->enabled.store(true, std::memory_order_release);
    }

    gain = std::max(-20.0f, std::min(3.0f, gain));
    this->gain.store(std::pow(10.0f, gain / 20.0f), std::memory_order_release);
}

void GainEffect::run(std::vector<std::vector<float>>& audio) {
    float _gain = gain.load(std::memory_order_acquire);

    if (std::fabs(_gain) < 0.0001f) return;

    for (int i = 0; i < audio[0].size(); i++) {
        audio[0][i] *= _gain;
        audio[1][i] *= _gain;
    }
}