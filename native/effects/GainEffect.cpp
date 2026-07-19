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
        this->setEnabled(false);
        return;
    } else {
        this->setEnabled(true);
    }

    gain = std::max(-20.0f, std::min(9.0f, gain));
    this->gain.store(std::pow(10.0f, gain / 20.0f), std::memory_order_release);
}

void GainEffect::run(std::span<float, SAMPLES_LENGTH_PER_FRAME> audio) {
    static_assert((bufferType() == BufferType::INTERLEAVED), "GainEffect run with non-interleaved buffer type");

    float _gain = gain.load(std::memory_order_relaxed);

    if (std::fabs(_gain) < 0.0001f) return;

    for (int i = 0; i < SAMPLES_LENGTH_PER_FRAME; i += 2) {
        audio[i] *= _gain;
        audio[i + 1] *= _gain;
    }
}