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

LowCatEffect::LowCatEffect(bool enabled, int cutoff_freq)
    : Effect(enabled), cutoff_freq(cutoff_freq) {

    high_120[0].setHighPass(cutoff_freq);
    high_120[1].setHighPass(cutoff_freq);

    reset();
}

void LowCatEffect::reset() {
    high_120[0].reset();
    high_120[1].reset();
}

void LowCatEffect::setCutoffFreq(int freq) {
    cutoff_freq.store(freq, std::memory_order_release);
    high_120[0].setHighPass(cutoff_freq);
    high_120[1].setHighPass(cutoff_freq);
}

LowCatEffect::~LowCatEffect() {}

void LowCatEffect::copyParamsFrom(const LowCatEffect& other) {
    reset();

    setCutoffFreq(other.cutoff_freq.load(std::memory_order_acquire));
    
    setEnabled(other.acquireReadEnabled());
}

Priority LowCatEffect::priority() const {
    return Priority::LOW_CAT_EFFECT;
}

void LowCatEffect::run(std::span<float, SAMPLES_LENGTH_PER_FRAME> audio) {
    static_assert((bufferType() == BufferType::INTERLEAVED), "LowCatEffect run with non-interleaved buffer type");

    for (int i = 0; i < SAMPLES_LENGTH_PER_FRAME; i += 2) {
        audio[i] = high_120[0].process(audio[i]);
        audio[i + 1] = high_120[1].process(audio[i + 1]);
    }
}

