/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"

SpeakerEffect::SpeakerEffect(bool enabled)
    : Effect(enabled)
    , lp_soft_l(0.0f)
    , lp_soft_r(0.0f)
    , har_soft_l(0.0f)
    , har_soft_r(0.0f) {

    low_120[0].setLowPass(120);
    low_120[1].setLowPass(120);

    band_120_600[0].setBandPass(120, 600);
    band_120_600[1].setBandPass(120, 600);

    high_600[0].setHighPass(600);
    high_600[1].setHighPass(600);

    /* you can change these coeffs to make it better on your device */
    harmonic[0].setCoeffs({0, 0.2, 0, 0.7, 0, 0.1});
    harmonic[1].setCoeffs({0, 0.2, 0, 0.7, 0, 0.1});
}

SpeakerEffect::~SpeakerEffect() {}

void SpeakerEffect::run(std::vector<std::vector<float>>& audio) {
    float _hp_gain = hp_gain.load(std::memory_order_acquire);
    float _bp_gain = bp_gain.load(std::memory_order_acquire);

    for (int i = 0; i < audio[0].size(); i++) {
        float hp_l = audio[0][i];
        float hp_r = audio[1][i];
        float bp_l = audio[0][i];
        float bp_r = audio[1][i];
        float lp_l = audio[0][i];
        float lp_r = audio[1][i];

        hp_l = high_600[0].process(hp_l);
        hp_r = high_600[1].process(hp_r);

        bp_l = band_120_600[0].process(bp_l);
        bp_r = band_120_600[1].process(bp_r);

        lp_l = low_120[0].process(lp_l);
        lp_r = low_120[1].process(lp_r);

        lp_soft_l += lp_soft_alpha * (lp_l - lp_soft_l);
        lp_soft_r += lp_soft_alpha * (lp_r - lp_soft_r);
        lp_l = lp_soft_l;
        lp_r = lp_soft_r;

        float y_comp_hp_l = harmonic[0].process(lp_l);
        float y_comp_hp_r = harmonic[1].process(lp_r);

        har_soft_l += har_soft_alpha * (y_comp_hp_l - har_soft_l);
        har_soft_r += har_soft_alpha * (y_comp_hp_r - har_soft_r);
        y_comp_hp_l = har_soft_l;
        y_comp_hp_r = har_soft_r;

        float out_l = 0.1f * (_hp_gain) * hp_l + 0.2f * (_bp_gain) * bp_l + 0.3 * y_comp_hp_l * 6;
        float out_r = 0.1f * (_hp_gain) * hp_r + 0.2f * (_bp_gain) * bp_r + 0.3 * y_comp_hp_r * 6;

        audio[0][i] = out_l;
        audio[1][i] = out_r;
    }
}

void SpeakerEffect::reset() {
    high_600[0].reset();
    high_600[1].reset();

    band_120_600[0].reset();
    band_120_600[1].reset();

    low_120[0].reset();
    low_120[1].reset();

    harmonic[0].reset();
    harmonic[1].reset();

    lp_soft_l = 0.0f;
    lp_soft_r = 0.0f;
    har_soft_l = 0.0f;
    har_soft_r = 0.0f;
}

Priority SpeakerEffect::priority() const {
    return Priority::SPEAKER_EFFECT;
}

void SpeakerEffect::copyParamsFrom(const SpeakerEffect& other) {
    this->enabled.store(other.enabled.load(std::memory_order_acquire), std::memory_order_release);
    this->bp_gain.store(other.bp_gain.load(std::memory_order_acquire), std::memory_order_release);
    this->hp_gain.store(other.hp_gain.load(std::memory_order_acquire), std::memory_order_release);
    this->_2_harmonic_coeffs.store(other._2_harmonic_coeffs.load(std::memory_order_acquire), std::memory_order_release);
    this->_4_harmonic_coeffs.store(other._4_harmonic_coeffs.load(std::memory_order_acquire), std::memory_order_release);
    this->_6_harmonic_coeffs.store(other._6_harmonic_coeffs.load(std::memory_order_acquire), std::memory_order_release);
}

void SpeakerEffect::set2HarmonicCoeffs(float coeffs) {
    _2_harmonic_coeffs.store(coeffs, std::memory_order_release);

    float coeffs_2 = coeffs;
    float coeffs_4 = _4_harmonic_coeffs.load(std::memory_order_acquire);
    float coeffs_6 = _6_harmonic_coeffs.load(std::memory_order_acquire);
    harmonic[0].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});
    harmonic[1].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});

    reset();
}

void SpeakerEffect::set4HarmonicCoeffs(float coeffs) {
    _4_harmonic_coeffs.store(coeffs, std::memory_order_release);

    float coeffs_2 = _2_harmonic_coeffs.load(std::memory_order_acquire);
    float coeffs_4 = coeffs;
    float coeffs_6 = _6_harmonic_coeffs.load(std::memory_order_acquire);
    harmonic[0].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});
    harmonic[1].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});

    reset();
}

void SpeakerEffect::set6HarmonicCoeffs(float coeffs) {
    _6_harmonic_coeffs.store(coeffs, std::memory_order_release);

    float coeffs_2 = _2_harmonic_coeffs.load(std::memory_order_acquire);
    float coeffs_4 = _4_harmonic_coeffs.load(std::memory_order_acquire);
    float coeffs_6 = coeffs;
    harmonic[0].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});
    harmonic[1].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});

    reset();
}

void SpeakerEffect::setBpGain(float gain) {
    bp_gain.store(gain, std::memory_order_release);

    float coeffs_2 = _2_harmonic_coeffs.load(std::memory_order_acquire);
    float coeffs_4 = _4_harmonic_coeffs.load(std::memory_order_acquire);
    float coeffs_6 = _6_harmonic_coeffs.load(std::memory_order_acquire);
    harmonic[0].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});
    harmonic[1].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});

    reset();
}

void SpeakerEffect::setHpGain(float gain) {
    hp_gain.store(gain, std::memory_order_release);

    float coeffs_2 = _2_harmonic_coeffs.load(std::memory_order_acquire);
    float coeffs_4 = _4_harmonic_coeffs.load(std::memory_order_acquire);
    float coeffs_6 = _6_harmonic_coeffs.load(std::memory_order_acquire);
    harmonic[0].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});
    harmonic[1].setCoeffs({0, coeffs_2, 0, coeffs_4, 0, coeffs_6});

    reset();
}
