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

void LookAheadSoftLimitEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        auto [l, r] = software_limiter.process(audio[0][i], audio[1][i]);
        audio[0][i] = l;
        audio[1][i] = r;
    }
}