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

LimiterEffect::LimiterEffect(bool _enabled)
    : Effect(_enabled) {

    reset();
}

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