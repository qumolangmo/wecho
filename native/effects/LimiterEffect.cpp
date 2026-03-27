/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"

LimiterEffect::LimiterEffect(bool _enabled)
    : Effect(_enabled) {}

LimiterEffect::~LimiterEffect() {}

void LimiterEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        limiter.process(audio[0][i], audio[1][i]);
    }
}

Priority LimiterEffect::priority() const {
    return LIMITER_EFFECT;
}

void LimiterEffect::reset() {
    limiter.reset();
}

void LimiterEffect::setThreshold(int threshold_dB) {
    limiter.setThreshold(threshold_dB);
}

void LimiterEffect::setRatio(int ratio) {
    limiter.setRatio(ratio);
}

void LimiterEffect::setMakeupGain(int makeup_gain_dB) {
    limiter.setMakeupGain(makeup_gain_dB);
}

void LimiterEffect::setAttack(int attack_ms) {
    limiter.setAttack(attack_ms);
}

void LimiterEffect::setRelease(int release_ms) {
    limiter.setRelease(release_ms);
}

void LimiterEffect::copyParamsFrom(const LimiterEffect& other) {}