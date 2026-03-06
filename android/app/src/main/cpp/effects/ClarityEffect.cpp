/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"

/***********************************************ClarityEffect***********************************************/
ClarityEffect::ClarityEffect(bool _enabled, int gain)
    : Effect(_enabled) {

    low_pass_filter[0].resize(1);
    low_pass_filter[1].resize(1);

    for (auto& filter: low_pass_filter[0]) {
        filter.setLowPass(8000, 0.707, 44100);
    }

    for (auto& filter: low_pass_filter[1]) {
        filter.setLowPass(8000, 0.707, 44100);
    }

    setGain(gain);
}

ClarityEffect::~ClarityEffect() {}

Priority ClarityEffect::priority() const {
    return CLARITY_EFFECT;
}

void ClarityEffect::reset() {
    for (auto& filter: low_pass_filter[0]) {
        filter.reset();
    }

    for (auto& filter: low_pass_filter[1]) {
        filter.reset();
    }

    last_l = 0.0f;
    last_r = 0.0f;
}

void ClarityEffect::setGain(int gain) {
    gain = std::max(0, std::min(15, gain));

    this->gain.store(2.0f + 3.0f * std::sqrt(gain / 15.0f), std::memory_order_release);
    reset();
}

void ClarityEffect::copyParamsFrom(const ClarityEffect& other) {
    this->gain.store(other.gain.load(std::memory_order_acquire), std::memory_order_release);
    this->enabled.store(other.enabled.load(std::memory_order_acquire), std::memory_order_release);
}

void ClarityEffect::run(std::vector<std::vector<float>>& audio) {
    float _gain = gain.load(std::memory_order_acquire);

    if (std::fabs(_gain) < 0.00001f) return;

    for (int i = 0; i < audio[0].size(); i++) {
        float prev_l = audio[0][i];
        float prev_r = audio[1][i];

        for (int j = 0; j < low_pass_filter[0].size(); j++) {
            prev_l = low_pass_filter[0][j].process(prev_l);
            prev_r = low_pass_filter[1][j].process(prev_r);
        }

        float diff_l = last_l - prev_l;
        float diff_r = last_r - prev_r;

        last_l = prev_l;
        last_r = prev_r;

        float post_l = diff_l * _gain + audio[0][i];
        float post_r = diff_r * _gain + audio[1][i];

        audio[0][i] = post_l;
        audio[1][i] = post_r;
    }
}