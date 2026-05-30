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
#include "../utils/debug.hpp"
#include <chrono>
#include <atomic>

bool FFTWFPlan::wisdom_imported = false;
std::string FFTWFPlan::wisdom_path = "";

ConvolveEffect::ConvolveEffect(bool enabled, float mix)
    : Effect(enabled)
    , mix(mix){

    convolver.setIr("this_is_an_message_of_init_convolve_effect___not_an_error");
    reset();
}

ConvolveEffect::~ConvolveEffect() {}

Priority ConvolveEffect::priority() const {
    return CONVOLVE_EFFECT;
}

void ConvolveEffect::reset() {
    convolver.reset();
}

void ConvolveEffect::run(std::vector<std::vector<float>>& audio) {
    convolver.convolve(audio, audio);
}

void ConvolveEffect::setMix(float mix) {
    this->mix.store(mix, std::memory_order_release);
}

void ConvolveEffect::setIr(const std::string& ir_path) {
    convolver.setIr(ir_path);
    reset();
}

void ConvolveEffect::setIr(const std::vector<std::vector<float>>& ir_data) {
    convolver.setIr(ir_data);
    reset();
}
