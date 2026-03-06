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
    : Effect(_enabled)
    , last_mid_envelope_l(0)
    , last_mid_envelope_r(0) {

    harmonic_150_600[0].setCoeffs({0, 0.2, 0.18, 0.10, 0.08, 0.03});
    harmonic_150_600[1].setCoeffs({0, 0.2, 0.18, 0.10, 0.08, 0.03});

    harmonic_1000_4000[0].setCoeffs({0, 0.4, 0.15, 0.25, 0.10, 0.15, 0.05, 0.08, 0.02, 0.03});
    harmonic_1000_4000[1].setCoeffs({0, 0.4, 0.15, 0.25, 0.10, 0.15, 0.05, 0.08, 0.02, 0.03});

    harmonic_8000_16000[0].setCoeffs({0, 0.18, 0.12, 0.04, 0.04, 0.01, 0.01});
    harmonic_8000_16000[1].setCoeffs({0, 0.18, 0.12, 0.04, 0.04, 0.01, 0.01});

    harmonic_other[0].setCoeffs({0, 0.07, 0.04});
    harmonic_other[1].setCoeffs({0, 0.07, 0.04});

    float _150_600 = 17.421 + 4.353;
    float _1000_4000 = 2.609 + 0.636;
    float _8000_16000 = 0.430 + 0.127;

    float max_delay = std::max({_150_600, _1000_4000, _8000_16000});

    for (int i = 0; i < 2; i++) {
        band_150_600[i] = std::vector<Biquad<BAND_PASS>>(2);
        band_1000_4000[i] = std::vector<Biquad<BAND_PASS>>(2);
        band_8000_16000[i] = std::vector<Biquad<BAND_PASS>>(3);

        for (auto& filter: band_150_600[i]) {
            filter.setBandPass(150, 600, 0.707, 44100);
        }
        for (auto& filter: band_1000_4000[i]) {
            filter.setBandPass(1000, 4000, 0.707, 44100);
        }
        for (auto& filter: band_8000_16000[i]) {
            filter.setBandPass(8000, 16000, 0.707, 44100);
        }

        delay_150_600[i].setDelay((max_delay - _150_600) * 44100);
        delay_1000_4000[i].setDelay((max_delay - _1000_4000) * 44100);
        delay_8000_16000[i].setDelay((max_delay - _8000_16000) * 44100);
        delay_other[i].setDelay((max_delay) * 44100);
    }

    setGain(gain);
}

EvenHarmonicEffect::~EvenHarmonicEffect() {}

Priority EvenHarmonicEffect::priority() const {
    return EVEN_HARMONIC_EFFECT;
}

void EvenHarmonicEffect::reset() {
    for (int i = 0; i < 2; i++) {
        for (auto& filter: band_150_600[i]) {
            filter.reset();
        }
        for (auto& filter: band_1000_4000[i]) {
            filter.reset();
        }
        for (auto& filter: band_8000_16000[i]) {
            filter.reset();
        }

        delay_150_600[i].reset();
        delay_1000_4000[i].reset();
        delay_8000_16000[i].reset();
        delay_other[i].reset();
    }

    harmonic_150_600[0].reset();
    harmonic_150_600[1].reset();
    harmonic_1000_4000[0].reset();
    harmonic_1000_4000[1].reset();
    harmonic_8000_16000[0].reset();
    harmonic_8000_16000[1].reset();
    harmonic_other[0].reset();
    harmonic_other[1].reset();

    last_mid_envelope_l = last_mid_envelope_r = 0;
}

void EvenHarmonicEffect::setGain(int gain) {
    float tmp_gain = gain;
    tmp_gain = std::max(0.0f, std::min(15.0f, tmp_gain));

    tmp_gain /= 15.0f;
    tmp_gain *= tmp_gain;
    tmp_gain *= tmp_gain;

    this->gain.store(tmp_gain, std::memory_order_release);
    reset();
}

void EvenHarmonicEffect::copyParamsFrom(const EvenHarmonicEffect& other) {
    this->gain.store(other.gain.load(std::memory_order_acquire), std::memory_order_release);
    this->enabled.store(other.enabled.load(std::memory_order_acquire), std::memory_order_release);
}

void EvenHarmonicEffect::run(std::vector<std::vector<float>>& audio) {
    float _gain = gain.load(std::memory_order_acquire);

    float low_l, mid_l, high_l, other_l;
    float low_r, mid_r, high_r, other_r;

    float origin_low_l, origin_low_r;
    float origin_mid_l, origin_mid_r;
    float origin_high_l, origin_high_r;
    float origin_other_l, origin_other_r;

    if (std::fabs(_gain) < 0.00001f) return;

    float low_wet = _gain * low_mix;
    float mid_wet = _gain * mid_mix;
    float high_wet = _gain * high_mix;
    float other_wet = _gain * other_mix;

    for (int i = 0; i < audio[0].size(); i++) {
        low_l = mid_l = high_l = audio[0][i];
        low_r = mid_r = high_r = audio[1][i];

        for (int j = 0; j < 2; j++) {
            low_l = band_150_600[0][j].process(low_l);
            low_r = band_150_600[1][j].process(low_r);
            mid_l = band_1000_4000[0][j].process(mid_l);
            mid_r = band_1000_4000[1][j].process(mid_r);
            high_l = band_8000_16000[0][j].process(high_l);
            high_r = band_8000_16000[1][j].process(high_r);
        }

        high_l = band_8000_16000[0][2].process(high_l);
        high_r = band_8000_16000[1][2].process(high_r);

        other_l = audio[0][i] - low_l - mid_l - high_l;
        other_r = audio[1][i] - low_r - mid_r - high_r;

        low_l = delay_150_600[0].process(low_l);
        low_r = delay_150_600[1].process(low_r);
        mid_l = delay_1000_4000[0].process(mid_l);
        mid_r = delay_1000_4000[1].process(mid_r);
        high_l = delay_8000_16000[0].process(high_l);
        high_r = delay_8000_16000[1].process(high_r);
        //other_l = delay_other[0].process(other_l);
        //other_r = delay_other[1].process(other_r);

        origin_low_l = low_l;
        origin_low_r = low_r;
        origin_mid_l = mid_l;
        origin_mid_r = mid_r;
        origin_high_l = high_l;
        origin_high_r = high_r;
        origin_other_l = other_l;
        origin_other_r = other_r;

        low_l = harmonic_150_600[0].process(low_l);
        low_r = harmonic_150_600[1].process(low_r);
        mid_l = harmonic_1000_4000[0].process(mid_l);
        mid_r = harmonic_1000_4000[1].process(mid_r);
        high_l = harmonic_8000_16000[0].process(high_l);
        high_r = harmonic_8000_16000[1].process(high_r);
        other_l = harmonic_other[0].process(other_l);
        other_r = harmonic_other[1].process(other_r);

        audio[0][i] = 
            origin_low_l + origin_mid_l + 
            origin_high_l + origin_other_l +
            low_l * low_wet + mid_l * mid_wet + high_l * high_wet + other_l * other_wet;

        audio[1][i] = 
            origin_low_r + origin_mid_r + 
            origin_high_r + origin_other_r +
            low_r * low_wet + mid_r * mid_wet + high_r * high_wet + other_r * other_wet;
    }
    
}
