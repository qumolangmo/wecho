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
EvenHarmonicEffect::EvenHarmonicEffect(bool _enabled, int gain, float _mix)
    : Effect(_enabled) {

    for (auto& harmonic: harmonic_1400_1600) {
        harmonic.setCoeffs({0, 0.2, 0.15, 0.1});
    }

    for (auto& harmonic: harmonic_2600_3000) {
        harmonic.setCoeffs({0, 0.2, 0.15, 0.1});
    }

    float _1400_1600 = 3.649 + 3.190;
    float _2600_3000 = 1.949 + 1.683;

    float max_delay = std::max({_1400_1600, _2600_3000});

    for (int i = 0; i < 2; i++) {
        band_1400_1600[i].setBandPass(1400, 1600);
        band_2600_3000[i].setBandPass(2600, 3000);

        delay_1400_1600[i].setDelay((max_delay - _1400_1600) * SAMPLE_RATE);
        delay_2600_3000[i].setDelay((max_delay - _2600_3000) * SAMPLE_RATE);
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
        band_1400_1600[i].reset();
        band_2600_3000[i].reset();

        delay_1400_1600[i].reset();
        delay_2600_3000[i].reset();
        delay_other[i].reset();

        harmonic_1400_1600[i].reset();
        harmonic_2600_3000[i].reset();
    }
}

void EvenHarmonicEffect::setGain(int gain) {
    float tmp_gain = gain;
    tmp_gain = std::max(0.0f, std::min(15.0f, tmp_gain));
    tmp_gain += 20;

    this->gain.store(std::pow(10.0f, tmp_gain / 20.0f), std::memory_order_release);
    reset();
}

void EvenHarmonicEffect::copyParamsFrom(const EvenHarmonicEffect& other) {
    this->gain.store(other.gain.load(std::memory_order_acquire), std::memory_order_release);
    this->enabled.store(other.enabled.load(std::memory_order_acquire), std::memory_order_release);
}

void EvenHarmonicEffect::run(std::vector<std::vector<float>>& audio) {
    float _gain = gain.load(std::memory_order_acquire);

    float low_l, mid_l, other_l;
    float low_r, mid_r, other_r;

    float origin_low_l, origin_low_r;
    float origin_mid_l, origin_mid_r;

    if (std::fabs(_gain) < 0.00001f) return;

    for (int i = 0; i < audio[0].size(); i++) {
        low_l = mid_l = audio[0][i];
        low_r = mid_r = audio[1][i];

        low_l = band_1400_1600[0].process(low_l);
        low_r = band_1400_1600[1].process(low_r);

        mid_l = band_2600_3000[0].process(mid_l);
        mid_r = band_2600_3000[1].process(mid_r);

        other_l = audio[0][i] - low_l - mid_l;
        other_r = audio[1][i] - low_r - mid_r;

        low_l = delay_1400_1600[0].process(low_l);
        low_r = delay_1400_1600[1].process(low_r);
        mid_l = delay_2600_3000[0].process(mid_l);
        mid_r = delay_2600_3000[1].process(mid_r);

        origin_low_l = low_l;
        origin_low_r = low_r;
        origin_mid_l = mid_l;
        origin_mid_r = mid_r;

        low_l = harmonic_1400_1600[0].process(low_l);
        low_r = harmonic_1400_1600[1].process(low_r);
        mid_l = harmonic_2600_3000[0].process(mid_l);
        mid_r = harmonic_2600_3000[1].process(mid_r);

        audio[0][i] = 
            origin_low_l + origin_mid_l + other_l +
            (low_l + mid_l) * _gain;

        audio[1][i] = 
            origin_low_r + origin_mid_r + other_r +
            (low_r + mid_r) * _gain;
    }
}
