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

CompressorEffect::CompressorEffect(bool _enabled)
    : Effect(_enabled) {

    reset();
}

CompressorEffect::~CompressorEffect() {}

void CompressorEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        limiter.process(audio[0][i], audio[1][i]);
    }
}

Priority CompressorEffect::priority() const {
    return COMPRESSOR_EFFECT;
}

void CompressorEffect::reset() {
    limiter.reset();
}

void CompressorEffect::setThreshold(int threshold_dB) {
    limiter.setThreshold(threshold_dB);
}

void CompressorEffect::setRatio(int ratio) {
    limiter.setRatio(ratio);
}

void CompressorEffect::setMakeupGain(int makeup_gain_dB) {
    limiter.setMakeupGain(makeup_gain_dB);
}

void CompressorEffect::setAttack(int attack_ms) {
    limiter.setAttack(attack_ms);
}

void CompressorEffect::setRelease(int release_ms) {
    limiter.setRelease(release_ms);
}

void CompressorEffect::copyParamsFrom(const CompressorEffect& other) {}