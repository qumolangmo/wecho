/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"

/*********************************************BassEffect*****************************************************/
BassEffect::BassEffect(bool _enabled, int _gain, float _Q, float _center_freq)
    : Effect(_enabled)
    , Q(_Q)
    , center_freq(_center_freq) {

    setGain(_gain);

    filter[0].setLowPass(_center_freq, _Q, 44100);
    filter[1].setLowPass(_center_freq, _Q, 44100);
}

BassEffect::~BassEffect() {}

Priority BassEffect::priority() const {
    return BASS_EFFECT;
}

void BassEffect::reset() {
    filter[0].reset();
    filter[1].reset();
}

void BassEffect::setGain(int gain) {
    gain = std::max(0, std::min(15, gain));
    this->gain.store(std::pow(10.0f, gain / 20.0f), std::memory_order_release);

    float freq = center_freq.load(std::memory_order_acquire);
    float q = Q.load(std::memory_order_acquire);
    filter[0].setLowPass(freq, q, 44100);
    filter[1].setLowPass(freq, q, 44100);

    reset();
}

void BassEffect::setQ(float Q) {
    Q = std::max(0.1f, std::min(1.5f, Q));
    this->Q.store(Q, std::memory_order_release);

    float freq = center_freq.load(std::memory_order_acquire);
    filter[0].setLowPass(freq, Q, 44100);
    filter[1].setLowPass(freq, Q, 44100);

    reset();
}

void BassEffect::setCenterFreq(float center_freq) {
    center_freq = std::max(30.0f, std::min(100.0f, center_freq));
    this->center_freq.store(center_freq, std::memory_order_release);

    float q = Q.load(std::memory_order_acquire);
    filter[0].setLowPass(center_freq, q, 44100);
    filter[1].setLowPass(center_freq, q, 44100);

    reset();
}

void BassEffect::copyParamsFrom(const BassEffect& other) {
    this->gain.store(other.gain.load(std::memory_order_acquire), std::memory_order_release);
    this->Q.store(other.Q.load(std::memory_order_acquire), std::memory_order_release);
    this->center_freq.store(other.center_freq.load(std::memory_order_acquire), std::memory_order_release);
    this->enabled.store(other.enabled.load(std::memory_order_acquire), std::memory_order_release);
}

void BassEffect::run(std::vector<std::vector<float>>& audio) {
    float _gain = gain.load(std::memory_order_acquire);

    if (std::fabs(_gain) < 0.00001f) return;

    for (int i = 0; i < audio[0].size(); i++) {
        audio[0][i] += filter[0].process(audio[0][i]) * _gain * 1.5f;
        audio[1][i] += filter[1].process(audio[1][i]) * _gain * 1.5f;
    }
}
