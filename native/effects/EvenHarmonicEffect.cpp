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

/**********************************************EvenHarmonicEffect***************************************************/
EvenHarmonicEffect::EvenHarmonicEffect(bool _enabled, float _base, float _warm, float _sugar)
    : Effect(_enabled)    
    , base(_base)
    , warm(_warm)
    , sugar(_sugar) {

    float group_delay_band1 = 0;
    float group_delay_band2 = 0.25;
    float group_delay_band3 = 0.5;
    float group_delay_band4 = 1;

    float max_delay = std::max({group_delay_band1, group_delay_band2, group_delay_band3, group_delay_band4});

    for (int i = 0; i < 2; i++) {
        harmonic_band1[i].setCoeffs({0, 0.2, 0.1, 0.0});
        harmonic_band2[i].setCoeffs({0, 0.2, 0.0, 0.2});
        harmonic_band3[i].setCoeffs({0, 0.2, 0.1, 0.15});
        harmonic_band4[i].setCoeffs({0, 0.2, 0.1, 0.15});
    
        band1[i].setBandPass(150, 300);
        band2[i].setBandPass(600, 800);
        band3[i].setBandPass(1400, 1600);
        band4[i].setBandPass(2600, 3000);

        delay_band1[i].setDelay((max_delay - group_delay_band1) * SAMPLE_RATE);
        delay_band2[i].setDelay((max_delay - group_delay_band2) * SAMPLE_RATE);
        delay_band3[i].setDelay((max_delay - group_delay_band3) * SAMPLE_RATE);
        delay_band4[i].setDelay((max_delay - group_delay_band4) * SAMPLE_RATE);
        delay_other[i].setDelay((max_delay) * SAMPLE_RATE);
    }

    reset();
}

EvenHarmonicEffect::~EvenHarmonicEffect() {}

Priority EvenHarmonicEffect::priority() const {
    return EVEN_HARMONIC_EFFECT;
}

void EvenHarmonicEffect::reset() {
    for (int i = 0; i < 2; i++) {
        harmonic_band1[i].reset();
        harmonic_band2[i].reset();
        harmonic_band3[i].reset();
        harmonic_band4[i].reset();

        band1[i].reset();
        band2[i].reset();
        band3[i].reset();
        band4[i].reset();

        delay_band1[i].reset();
        delay_band2[i].reset();
        delay_band3[i].reset();
        delay_band4[i].reset();
        delay_other[i].reset();
    }

    env_band1_l = env_band1_r = env_band2_l = env_band2_r 
    = env_band3_l = env_band3_r = env_band4_l = env_band4_r = 0;

    processed_env_band1_l = processed_env_band1_r 
    = processed_env_band2_l = processed_env_band2_r 
    = processed_env_band3_l = processed_env_band3_r 
    = processed_env_band4_l = processed_env_band4_r = 0;
}

void EvenHarmonicEffect::setBase(float base) {
    this->base.store(std::max(0.0f, std::min(1.0f, base)), std::memory_order_release);
}

void EvenHarmonicEffect::setWarm(float warm) {
    this->warm.store(std::max(0.0f, std::min(1.0f, warm)), std::memory_order_release);
}

void EvenHarmonicEffect::setSugar(float sugar) {
    this->sugar.store(std::max(0.0f, std::min(1.0f, sugar)), std::memory_order_release);
}

void EvenHarmonicEffect::copyParamsFrom(const EvenHarmonicEffect& other) {
    reset();

    this->base.store(other.base.load(std::memory_order_acquire), std::memory_order_release);
    this->warm.store(other.warm.load(std::memory_order_acquire), std::memory_order_release);
    this->sugar.store(other.sugar.load(std::memory_order_acquire), std::memory_order_release);
    this->setEnabled(other.isEnabled());
}

void EvenHarmonicEffect::run(std::vector<std::vector<float>>& audio) {
    static float _gain = std::pow(10.0f, 12.0f / 20.0f);

    if (std::fabs(_gain) < 0.00001f) return;

    float _base = base.load(std::memory_order_acquire);
    float _warm = warm.load(std::memory_order_acquire);
    float _sugar = sugar.load(std::memory_order_acquire);

    float origin_band1_l, origin_band1_r;
    float origin_band2_l, origin_band2_r;
    float origin_band3_l, origin_band3_r;
    float origin_band4_l, origin_band4_r;
    float origin_other_l, origin_other_r;

    float delayed_origin_band1_l, delayed_origin_band1_r;
    float delayed_origin_band2_l, delayed_origin_band2_r;
    float delayed_origin_band3_l, delayed_origin_band3_r;
    float delayed_origin_band4_l, delayed_origin_band4_r;
    float delayed_origin_other_l, delayed_origin_other_r;

    float processed_band1_l, processed_band1_r;
    float processed_band2_l, processed_band2_r;
    float processed_band3_l, processed_band3_r;
    float processed_band4_l, processed_band4_r;

    float filtered_band1_l, filtered_band1_r;
    float filtered_band2_l, filtered_band2_r;
    float filtered_band3_l, filtered_band3_r;
    float filtered_band4_l, filtered_band4_r;

    if (std::fabs(_gain) < 0.00001f) return;

    for (int i = 0; i < audio[0].size(); i++) {
        origin_band1_l = origin_band2_l = origin_band3_l = origin_band4_l = audio[0][i];
        origin_band1_r = origin_band2_r = origin_band3_r = origin_band4_r = audio[1][i];

        origin_band1_l = band1[0].process(origin_band1_l);
        origin_band2_l = band2[0].process(origin_band2_l);
        origin_band3_l = band3[0].process(origin_band3_l);
        origin_band4_l = band4[0].process(origin_band4_l);
        
        origin_band1_r = band1[1].process(origin_band1_r);
        origin_band2_r = band2[1].process(origin_band2_r);
        origin_band3_r = band3[1].process(origin_band3_r);
        origin_band4_r = band4[1].process(origin_band4_r);
        
        origin_other_l = audio[0][i] - origin_band1_l - origin_band2_l - origin_band3_l - origin_band4_l;
        origin_other_r = audio[1][i] - origin_band1_r - origin_band2_r - origin_band3_r - origin_band4_r;

        delayed_origin_band1_l = delay_band1[0].process(origin_band1_l);
        delayed_origin_band2_l = delay_band2[0].process(origin_band2_l);
        delayed_origin_band3_l = delay_band3[0].process(origin_band3_l);
        delayed_origin_band4_l = delay_band4[0].process(origin_band4_l);
        delayed_origin_other_l = delay_other[0].process(origin_other_l);

        delayed_origin_band1_r = delay_band1[1].process(origin_band1_r);
        delayed_origin_band2_r = delay_band2[1].process(origin_band2_r);
        delayed_origin_band3_r = delay_band3[1].process(origin_band3_r);
        delayed_origin_band4_r = delay_band4[1].process(origin_band4_r);
        delayed_origin_other_r = delay_other[1].process(origin_other_r);

        float abs_delayed_origin_band1_l = std::fabs(delayed_origin_band1_l);
        float abs_delayed_origin_band1_r = std::fabs(delayed_origin_band1_r);
        float abs_delayed_origin_band2_l = std::fabs(delayed_origin_band2_l);
        float abs_delayed_origin_band2_r = std::fabs(delayed_origin_band2_r);
        float abs_delayed_origin_band3_l = std::fabs(delayed_origin_band3_l);
        float abs_delayed_origin_band3_r = std::fabs(delayed_origin_band3_r);
        float abs_delayed_origin_band4_l = std::fabs(delayed_origin_band4_l);
        float abs_delayed_origin_band4_r = std::fabs(delayed_origin_band4_r);

        env_band1_l += envelope_rate * (abs_delayed_origin_band1_l - env_band1_l);
        env_band1_r += envelope_rate * (abs_delayed_origin_band1_r - env_band1_r);
        env_band2_l += envelope_rate * (abs_delayed_origin_band2_l - env_band2_l);
        env_band2_r += envelope_rate * (abs_delayed_origin_band2_r - env_band2_r);
        env_band3_l += envelope_rate * (abs_delayed_origin_band3_l - env_band3_l);
        env_band3_r += envelope_rate * (abs_delayed_origin_band3_r - env_band3_r);
        env_band4_l += envelope_rate * (abs_delayed_origin_band4_l - env_band4_l);
        env_band4_r += envelope_rate * (abs_delayed_origin_band4_r - env_band4_r);

        processed_band1_l = harmonic_band1[0].process(delayed_origin_band1_l);
        processed_band2_l = harmonic_band2[0].process(delayed_origin_band2_l);
        processed_band3_l = harmonic_band3[0].process(delayed_origin_band3_l);
        processed_band4_l = harmonic_band4[0].process(delayed_origin_band4_l);

        processed_band1_r = harmonic_band1[1].process(delayed_origin_band1_r);
        processed_band2_r = harmonic_band2[1].process(delayed_origin_band2_r);
        processed_band3_r = harmonic_band3[1].process(delayed_origin_band3_r);
        processed_band4_r = harmonic_band4[1].process(delayed_origin_band4_r);

        float abs_processed_band1_l = std::fabs(processed_band1_l);
        float abs_processed_band1_r = std::fabs(processed_band1_r);
        float abs_processed_band2_l = std::fabs(processed_band2_l);
        float abs_processed_band2_r = std::fabs(processed_band2_r);
        float abs_processed_band3_l = std::fabs(processed_band3_l);
        float abs_processed_band3_r = std::fabs(processed_band3_r);
        float abs_processed_band4_l = std::fabs(processed_band4_l);
        float abs_processed_band4_r = std::fabs(processed_band4_r);

        processed_env_band1_l += envelope_rate * (abs_processed_band1_l - processed_env_band1_l);
        processed_env_band1_r += envelope_rate * (abs_processed_band1_r - processed_env_band1_r);
        processed_env_band2_l += envelope_rate * (abs_processed_band2_l - processed_env_band2_l);
        processed_env_band2_r += envelope_rate * (abs_processed_band2_r - processed_env_band2_r);
        processed_env_band3_l += envelope_rate * (abs_processed_band3_l - processed_env_band3_l);
        processed_env_band3_r += envelope_rate * (abs_processed_band3_r - processed_env_band3_r);
        processed_env_band4_l += envelope_rate * (abs_processed_band4_l - processed_env_band4_l);
        processed_env_band4_r += envelope_rate * (abs_processed_band4_r - processed_env_band4_r);

        float mod_gain_band1_l = env_band1_l / (processed_env_band1_l + 1e-8f);
        float mod_gain_band1_r = env_band1_r / (processed_env_band1_r + 1e-8f);
        float mod_gain_band2_l = env_band2_l / (processed_env_band2_l + 1e-8f);
        float mod_gain_band2_r = env_band2_r / (processed_env_band2_r + 1e-8f);
        float mod_gain_band3_l = env_band3_l / (processed_env_band3_l + 1e-8f);
        float mod_gain_band3_r = env_band3_r / (processed_env_band3_r + 1e-8f);
        float mod_gain_band4_l = env_band4_l / (processed_env_band4_l + 1e-8f);
        float mod_gain_band4_r = env_band4_r / (processed_env_band4_r + 1e-8f);

        mod_gain_band1_l = std::clamp(mod_gain_band1_l, 0.2f, 5.0f);
        mod_gain_band1_r = std::clamp(mod_gain_band1_r, 0.2f, 5.0f);
        mod_gain_band2_l = std::clamp(mod_gain_band2_l, 0.2f, 5.0f);
        mod_gain_band2_r = std::clamp(mod_gain_band2_r, 0.2f, 5.0f);
        mod_gain_band3_l = std::clamp(mod_gain_band3_l, 0.2f, 5.0f);
        mod_gain_band3_r = std::clamp(mod_gain_band3_r, 0.2f, 5.0f);
        mod_gain_band4_l = std::clamp(mod_gain_band4_l, 0.2f, 5.0f);
        mod_gain_band4_r = std::clamp(mod_gain_band4_r, 0.2f, 5.0f);

        processed_band1_l *= mod_gain_band1_l;
        processed_band1_r *= mod_gain_band1_r;
        processed_band2_l *= mod_gain_band2_l;
        processed_band2_r *= mod_gain_band2_r;
        processed_band3_l *= mod_gain_band3_l;
        processed_band3_r *= mod_gain_band3_r;
        processed_band4_l *= mod_gain_band4_l;
        processed_band4_r *= mod_gain_band4_r;

        audio[0][i] = (
            processed_band1_l * _warm
            + processed_band2_l * _base
            + (processed_band3_l
            + processed_band4_l) * _sugar
        ) * _gain
            + delayed_origin_band1_l
            + delayed_origin_band2_l
            + delayed_origin_band3_l
            + delayed_origin_band4_l
            + delayed_origin_other_l;

        audio[1][i] = (
            processed_band1_r * _warm
            + processed_band2_r * _base
            + (processed_band3_r
            + processed_band4_r) * _sugar
        ) * _gain
            + delayed_origin_band1_r
            + delayed_origin_band2_r
            + delayed_origin_band3_r
            + delayed_origin_band4_r
            + delayed_origin_other_r;
    }
}
