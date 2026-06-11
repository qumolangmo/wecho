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

    float envelope;
    float envelope_peak;
    float limiter_threshold;
    
public:
    friend class LimiterEffect;
    
    Limiter()
        : threshold(std::pow(10.0f, -18.0f / 20.f))
        , ratio(8.0f)
        , attack_coeff(0.0f)
        , release_coeff(0.0f)
        , makeup_gain(std::pow(10.0f, 6.0f / 20.0f))
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
            release_coeff = std::exp(-1.0f / (release_ms * 0.001f * SAMPLE_RATE));
            release_coeff = std::min(release_coeff, 1.0f);
        } else {
            release_coeff = 0.0f;
        }
    }

    void setAttack(int attack_ms) {
        if (attack_ms > 0) {
            attack_coeff = 1.0f - std::exp(-1.0f / (attack_ms * 0.001f * SAMPLE_RATE));
            attack_coeff = std::min(attack_coeff, 1.0f);
        } else {
            attack_coeff = 0.0f;
        }
    }

    void reset() {
        envelope = 0.0f;
        envelope_peak = 0.0f;
    }
    
    void process(float& input_l, float& input_r) {
        float abs_input_l = std::abs(input_l);
        float abs_input_r = std::abs(input_r);
        float abs_input = std::max(abs_input_l, abs_input_r);

        if (abs_input > envelope) {
            envelope = attack_coeff * envelope + (1.0f - attack_coeff) * abs_input;
        } else {
            envelope = release_coeff * envelope + (1.0f - release_coeff) * abs_input;
        }

        if (abs_input > envelope_peak) {
            envelope_peak = abs_input;
        } else {
            envelope_peak = release_coeff * envelope_peak + (1.0f - release_coeff) * abs_input;
        }

        float gain = makeup_gain;
        
        if (envelope > threshold) {
            float slope = 0.06f * ratio - 0.06f;
            float compression_ratio = 1.0f + slope * (envelope / threshold - 1.0f);

            float gain_reduction = 1.0f / compression_ratio;
            gain = makeup_gain * gain_reduction;
        }

        if (gain * envelope_peak > limiter_threshold) {
            gain = limiter_threshold / envelope_peak;
        }

        input_l *= gain;
        input_r *= gain;
    }
};

#endif