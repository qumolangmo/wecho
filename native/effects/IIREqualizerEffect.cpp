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

IIREqualizerEffect::IIREqualizerEffect(bool enabled) 
    : Effect(enabled) {

    biquads[0].resize(10);
    biquads[1].resize(10);

    coeffs[0] = {0, 20, 63, 0};
    coeffs[1] = {1, 63, 125, 0};
    coeffs[2] = {2, 125, 250, 0};
    coeffs[3] = {3, 250, 500, 0};
    coeffs[4] = {4, 500, 1000, 0};
    coeffs[5] = {5, 1000, 2000, 0};
    coeffs[6] = {6, 2000, 4000, 0};
    coeffs[7] = {7, 4000, 8000, 0};
    coeffs[8] = {8, 8000, 16000, 0};
    coeffs[9] = {9, 16000, 20000, 0};

    for (auto& channel: biquads) {
        for (int i = 0; i < 10; i++) {
            channel[i].setPeak({static_cast<float>(coeffs[i].start_freq), 1.0f, static_cast<float>(coeffs[i].gain)});
        }
    }
}
IIREqualizerEffect::~IIREqualizerEffect() {}

void IIREqualizerEffect::run(std::vector<std::vector<float>>& audio) {
    float origin_l, origin_r;

    for (int i = 0; i < audio[0].size(); i++) {
        origin_l = audio[0][i];
        origin_r = audio[1][i];

        for (int j = 0; j < 10; j++) {
            origin_l = biquads[0][j].process(origin_l);
            origin_r = biquads[1][j].process(origin_r);
            
        }

        audio[0][i] = origin_l;
        audio[1][i] = origin_r;
    }
}

Priority IIREqualizerEffect::priority() const {
    return Priority::IIR_EQUALIZER_EFFECT;
}

void IIREqualizerEffect::reset() {
    for (auto& channel: biquads) {
        for (int i = 0; i < 10; i++) {
            channel[i].reset();
        }
    }
}

void IIREqualizerEffect::setCoeffs(IIREqualizerCoeffs coeffs) {
    this->coeffs = coeffs;
    
    for (auto& channel: biquads) {
        for (int i = 0; i < 10; i++) {
            channel[i].setPeak({static_cast<float>(this->coeffs[i].start_freq), 1.0f, static_cast<float>(this->coeffs[i].gain)});
        }
    }
}

void IIREqualizerEffect::copyParamsFrom(const IIREqualizerEffect& other) {
    reset();

    this->coeffs = other.coeffs;
    this->setEnabled(other.isEnabled());
}
