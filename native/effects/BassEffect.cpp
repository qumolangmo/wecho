/*
 * Copyright (C) 2026 qumolangmo
 *
 * This file is part of Wecho.
 *
 * Wecho is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Wecho is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Wecho.  If not, see <https://www.gnu.org/licenses/>.
 */
#include "effect.hpp"

/*********************************************BassEffect*****************************************************/
BassEffect::BassEffect(bool _enabled, int _gain, float _Q, float _center_freq)
    : Effect(_enabled)
    , Q(_Q)
    , center_freq(_center_freq) {

    setGain(_gain);

    filter[0].setLowPass({_center_freq, _Q});
    filter[1].setLowPass({_center_freq, _Q});

    reset();
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
    filter[0].setLowPass({freq, q});
    filter[1].setLowPass({freq, q});
}

void BassEffect::setQ(float Q) {
    Q = std::max(0.1f, std::min(1.5f, Q));
    this->Q.store(Q, std::memory_order_release);

    float freq = center_freq.load(std::memory_order_acquire);
    filter[0].setLowPass({freq, Q});
    filter[1].setLowPass({freq, Q});
}

void BassEffect::setCenterFreq(float center_freq) {
    this->center_freq.store(center_freq, std::memory_order_release);

    float q = Q.load(std::memory_order_acquire);
    filter[0].setLowPass({center_freq, q});
    filter[1].setLowPass({center_freq, q});
}

void BassEffect::copyParamsFrom(const BassEffect& other) {
    reset();

    setCenterFreq(other.center_freq.load(std::memory_order_acquire));
    setQ(other.Q.load(std::memory_order_acquire));
    setGain(other.gain.load(std::memory_order_acquire));
    
    setEnabled(other.acquireReadEnabled());
}

void BassEffect::run(std::vector<std::vector<float>>& audio) {
    float _gain = gain.load(std::memory_order_relaxed);

    if (std::fabs(_gain) < 0.00001f) return;

    for (int i = 0; i < audio[0].size(); i++) {
        audio[0][i] += filter[0].process(audio[0][i]) * _gain * 1.5f;
        audio[1][i] += filter[1].process(audio[1][i]) * _gain * 1.5f;
    }
}
