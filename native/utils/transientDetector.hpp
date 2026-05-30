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

#ifndef __TRANSIENT_DETECTOR_H__
#define __TRANSIENT_DETECTOR_H__

#include <cmath>

class TransientDetector {
private:
    float env, gain;
    float attack_c, release_c;
    static constexpr int SAMPLE_RATE = 48000;

public:
    TransientDetector(float attack_s, float release_s, float gain)
        : env(0)
        , gain(gain) {

        attack_c = 1 - std::exp(-1 / (SAMPLE_RATE * attack_s));
        release_c = std::exp(-1 / (SAMPLE_RATE * release_s));
    }

    float process(float x) {
        float abs_x = std::abs(x);
        env = (abs_x > env) 
            ? env + attack_c * (abs_x - env) 
            : env * release_c;

        float transient = x - x * env;
        return x + transient * (gain - 1);
    }

    void reset() {
        env = 0;
    }

    void setGain(float gain) {
        this->gain = gain;
    }

    void setAttack(float attack_s) {
        attack_c = 1 - std::exp(-1 / (SAMPLE_RATE * attack_s));
    }

    void setRelease(float release_s) {
        release_c = std::exp(-1 / (SAMPLE_RATE * release_s));
    }
};

class EnvelopeDetector {
private:
    float last_env;
    float env;
    float attack_c, release_c;
    static constexpr int SAMPLE_RATE = 48000;

public:
    EnvelopeDetector(float attack_s, float release_s)
        : env(0) {

        setAttack(attack_s);
        setRelease(release_s);
    }

    void setAttack(float attack_s) {
        attack_c = 1 - std::exp(-1 / (SAMPLE_RATE * attack_s));
    }

    void setRelease(float release_s) {
        release_c = std::exp(-1 / (SAMPLE_RATE * release_s));
    }

    float process(float x) {
        float abs_x = std::abs(x);
        env = (abs_x > env) 
            ? env + attack_c * (abs_x - env) 
            : env * release_c;
        return env;
    }

    void reset() {
        last_env = 0;
        env = 0;
    }

    float getLastEnv() const {
        return last_env;
    }

};

#endif