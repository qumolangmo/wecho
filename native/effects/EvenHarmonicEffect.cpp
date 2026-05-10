/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"

/**********************************************EvenHarmonicEffect***************************************************/
EvenHarmonicEffect::EvenHarmonicEffect(bool _enabled, int gain, float _base, float _warm, float _sugar)
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
        harmonic_band1[i].setCoeffs({0, 0.1, 0.05, 0.03});
        harmonic_band2[i].setCoeffs({0, 0.2, 0.1, 0.2, 0.0, 0.1});
        harmonic_band3[i].setCoeffs({0, 0.2, 0.1, 0.15, 0.0, 0.03});
        harmonic_band4[i].setCoeffs({0, 0.2, 0.1, 0.15, 0.0, 0.03});
    
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

    setGain(gain);
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
}

void EvenHarmonicEffect::setGain(int gain) {
    float tmp_gain = gain;
    tmp_gain = std::max(0.0f, std::min(15.0f, tmp_gain));
    tmp_gain += 20;

    this->gain.store(std::pow(10.0f, tmp_gain / 20.0f), std::memory_order_release);
    reset();
}

void EvenHarmonicEffect::setBase(float base) {
    this->base.store(std::max(0.0f, std::min(1.0f, base)), std::memory_order_release);
    reset();
}

void EvenHarmonicEffect::setWarm(float warm) {
    this->warm.store(std::max(0.0f, std::min(1.0f, warm)), std::memory_order_release);
    reset();
}

void EvenHarmonicEffect::setSugar(float sugar) {
    this->sugar.store(std::max(0.0f, std::min(1.0f, sugar)), std::memory_order_release);
    reset();
}

void EvenHarmonicEffect::copyParamsFrom(const EvenHarmonicEffect& other) {
    this->gain.store(other.gain.load(std::memory_order_acquire), std::memory_order_release);
    this->base.store(other.base.load(std::memory_order_acquire), std::memory_order_release);
    this->warm.store(other.warm.load(std::memory_order_acquire), std::memory_order_release);
    this->sugar.store(other.sugar.load(std::memory_order_acquire), std::memory_order_release);
    this->setEnabled(other.isEnabled());
}

void EvenHarmonicEffect::run(std::vector<std::vector<float>>& audio) {
    float _gain = gain.load(std::memory_order_acquire);

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

        processed_band1_l = harmonic_band1[0].process(delayed_origin_band1_l);
        processed_band2_l = harmonic_band2[0].process(delayed_origin_band2_l);
        processed_band3_l = harmonic_band3[0].process(delayed_origin_band3_l);
        processed_band4_l = harmonic_band4[0].process(delayed_origin_band4_l);

        processed_band1_r = harmonic_band1[1].process(delayed_origin_band1_r);
        processed_band2_r = harmonic_band2[1].process(delayed_origin_band2_r);
        processed_band3_r = harmonic_band3[1].process(delayed_origin_band3_r);
        processed_band4_r = harmonic_band4[1].process(delayed_origin_band4_r);

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
