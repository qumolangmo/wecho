/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#ifndef __LIMITER_HPP__
#define __LIMITER_HPP__

#include <cmath>
#include <algorithm>

class Limiter {
private:
    float threshold;
    float ratio;
    float attack_coeff;
    float release_coeff;
    float makeup_gain;
    static constexpr int SAMPLE_RATE = 48000;

    float peak;
    float envelope;
    float envelope_peak;
    float limiter_threshold;
public:
    Limiter()
        : threshold(std::pow(10.0f, -18.0f / 20.f))
        , ratio(8.0f)
        , makeup_gain(std::pow(10.0f, 6.0f / 20.0f))
        , peak(0.0f)
        , envelope(0.0f)
        , envelope_peak(0.0f)
        , limiter_threshold(1.0f) {

        setRelease(100);
        setAttack(10);
    }

    void setThreshold(int threshold_dB) {
        this->threshold = std::pow(10.0f, threshold_dB / 20.0f);
    }

    void setRatio(float ratio) {
        this->ratio = ratio;
    }

    void setMakeupGain(int makeup_gain_dB) {
        this->makeup_gain = std::pow(10.0f, makeup_gain_dB / 20.0f);
    }

    void setRelease(int release_ms) {
        if (release_ms > 0) {
            release_coeff = std::exp(-1.0 / (release_ms * 0.001 * SAMPLE_RATE));
            release_coeff = release_coeff > 1.0f ? 1.0f : release_coeff;
        } else {
            release_coeff = 0.0;
        }
    }

    void setAttack(int attack_ms) {
        if (attack_ms > 0) {
            attack_coeff = 1.0f - std::exp(-1.0 / (attack_ms * 0.001 * SAMPLE_RATE));
            attack_coeff = attack_coeff > 1.0f ? 1.0f : attack_coeff;
        } else {
            attack_coeff = 0.0;
        }
    }

    void reset() {
        peak = 0.0f;
        envelope = 0.0f;
    }
    

    void process(float& input_l, float& input_r) {
        float abs_input_l = std::abs(input_l);
        float abs_input_r = std::abs(input_r);
        float abs_input = std::max(abs_input_l, abs_input_r);

        envelope *= release_coeff;
        if (abs_input > envelope) {
            envelope += attack_coeff * (abs_input - envelope);
        }

        envelope_peak *= release_coeff;
        if (abs_input > envelope_peak) {
            envelope_peak = abs_input;
        }

        float gain = makeup_gain;
        if (envelope > threshold) {
            float slope = 0.06f * ratio - 0.06f;

            float compression_ratio = 1.0f + slope * (envelope / threshold - 1.0f);
            gain = makeup_gain * compression_ratio;
        }

        if (gain * envelope_peak > limiter_threshold) {
            gain = limiter_threshold / envelope_peak;
        }

        input_l *= gain;
        input_r *= gain;
    }
};

#endif