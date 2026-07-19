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

LookAheadSoftLimitEffect::LookAheadSoftLimitEffect(bool enabled)
    : Effect(enabled) {

    reset();
}

LookAheadSoftLimitEffect::~LookAheadSoftLimitEffect() {}

Priority LookAheadSoftLimitEffect::priority() const {
    return LOOK_AHEAD_SOFT_LIMIT_EFFECT;
}

void LookAheadSoftLimitEffect::reset() {
    software_limiter.reset();
}

void LookAheadSoftLimitEffect::copyParamsFrom(const LookAheadSoftLimitEffect& other) {
    reset();

    this->setEnabled(other.isEnabled());
}

void LookAheadSoftLimitEffect::run(std::span<float, SAMPLES_LENGTH_PER_FRAME> audio) {
    static_assert((bufferType() == BufferType::INTERLEAVED), "LookAheadSoftLimitEffect run with non-interleaved buffer type");

    for (int i = 0; i < SAMPLES_LENGTH_PER_FRAME; i += 2) {
        auto [l, r] = software_limiter.process(audio[i], audio[i + 1]);

        audio[i] = l;
        audio[i + 1] = r;
    }
}