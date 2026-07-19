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

/***********************************************ClarityEffect***********************************************/
ClarityEffect::ClarityEffect(bool _enabled, int gain)
    : Effect(_enabled) {

    low_pass_filter[0].setLowPass({8000, 0.7071});
    low_pass_filter[1].setLowPass({8000, 0.7071});

    setGain(gain);
    reset();
}

ClarityEffect::~ClarityEffect() {}

Priority ClarityEffect::priority() const {
    return CLARITY_EFFECT;
}

void ClarityEffect::reset() {
    low_pass_filter[0].reset();
    low_pass_filter[1].reset();

    last_l = 0.0f;
    last_r = 0.0f;
}

void ClarityEffect::setGain(int gain) {
    this->gain.store(2.0f + 3.0f * std::sqrt(gain / 15.0f), std::memory_order_release);
}

void ClarityEffect::copyParamsFrom(const ClarityEffect& other) {
    reset();

    setGain(other.gain.load(std::memory_order_acquire));
    
    setEnabled(other.acquireReadEnabled());
}

void ClarityEffect::run(std::span<float, SAMPLES_LENGTH_PER_FRAME> audio) {
    static_assert((bufferType() == BufferType::INTERLEAVED), "ClarityEffect run with non-interleaved buffer type");

    float _gain = gain.load(std::memory_order_relaxed);

    if (std::fabs(_gain) < 0.00001f) return;

    for (int i = 0; i < SAMPLES_LENGTH_PER_FRAME; i += 2) {
        float prev_l = audio[i];
        float prev_r = audio[i + 1];

        prev_l = low_pass_filter[0].process(prev_l);
        prev_r = low_pass_filter[1].process(prev_r);

        float diff_l = last_l - prev_l;
        float diff_r = last_r - prev_r;

        last_l = prev_l;
        last_r = prev_r;

        float post_l = diff_l * _gain + audio[i];
        float post_r = diff_r * _gain + audio[i + 1];

        audio[i] = post_l;
        audio[i + 1] = post_r;
    }
}