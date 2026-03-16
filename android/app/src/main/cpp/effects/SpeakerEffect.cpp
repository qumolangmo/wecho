/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"
#include <android/log.h>

#define LOG_TAG "WEchoEngine"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

SpeakerEffect::SpeakerEffect(bool enabled)
    : Effect(enabled)
    , rms_est_l(0.0f)
    , rms_est_r(0.0f)
    , gain_agc_l(1.0f)
    , gain_agc_r(1.0f) 
    , env_l(0.0f)
    , env_r(0.0f)
    , env_slow_l(0.0f)
    , env_slow_r(0.0f)
    , lp_soft_l(0.0f)
    , lp_soft_r(0.0f)
    , har_soft_l(0.0f)
    , har_soft_r(0.0f) {

    low_120[0].resize(1);
    low_120[1].resize(1);

    for (auto& low: low_120) {
        for (auto& l: low) {
            l.setLowPass(120, 0.7071, 44100);
        }
    }

    band_120_400[0].resize(1);
    band_120_400[1].resize(1);
    band_120_400[2].resize(1);
    band_120_400[3].resize(1);

    for (auto& band: band_120_400) {
        for (auto& b: band) {
            b.setBandPass(120, 400, 0.7071, 44100);
        }
    }

    high_400[0].resize(2);
    high_400[1].resize(2);

    for (auto& high: high_400) {
        for (auto& h: high) {
            h.setHighPass(400, 0.7071, 44100);
        }
    }

}

SpeakerEffect::~SpeakerEffect() {}

void SpeakerEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        float hp_l = audio[0][i];
        float hp_r = audio[1][i];
        float bp_l = audio[0][i];
        float bp_r = audio[1][i];
        float lp_l = audio[0][i];
        float lp_r = audio[1][i];

        for (int j = 0; j < high_400[0].size(); j++) {
            hp_l = high_400[0][j].process(hp_l);
            hp_r = high_400[1][j].process(hp_r);
        }

        for (int j = 0; j < band_120_400[0].size(); j++) {
            bp_l = band_120_400[0][j].process(bp_l);
            bp_r = band_120_400[1][j].process(bp_r);
        }

        for (int j = 0; j < low_120[0].size(); j++) {
            lp_l = low_120[0][j].process(lp_l);
            lp_r = low_120[1][j].process(lp_r);
        }

        lp_soft_l += lp_soft_alpha * (lp_l - lp_soft_l);
        lp_soft_r += lp_soft_alpha * (lp_r - lp_soft_r);
        lp_l = lp_soft_l;
        lp_r = lp_soft_r;

        env_l = env_l + env_alpha * (std::abs(lp_l) - env_l);
        env_r = env_r + env_alpha * (std::abs(lp_r) - env_r);
        env_slow_l = env_slow_l + env_slow_alpha * (std::abs(lp_l) - env_slow_l);
        env_slow_r = env_slow_r + env_slow_alpha * (std::abs(lp_r) - env_slow_r);

        static float transient_threshold = 0.01f;
        float transient_l = env_l - env_slow_l;
        float transient_r = env_r - env_slow_r;
        transient_l = std::max(transient_l - transient_threshold, 0.0f);
        transient_r = std::max(transient_r - transient_threshold, 0.0f);

        float harmonic_gate_l = std::tanh(transient_l * 15.0f);
        float harmonic_gate_r = std::tanh(transient_r * 15.0f);

        float even_lp_l = std::abs(lp_l);
        float even_lp_r = std::abs(lp_r);
        float odd_lp_l = lp_l * lp_l;
        float odd_lp_r = lp_r * lp_r;

        float dc_offset_l = even_lp_l * 0.01f;
        float dc_offset_r = even_lp_r * 0.01f;

        float y_lp_l = (even_lp_l + odd_lp_l - dc_offset_l) * 0.5f;
        float y_lp_r = (even_lp_r + odd_lp_r - dc_offset_r) * 0.5f;

        float y_comp_hp_l = band_120_400[2][0].process(y_lp_l) * harmonic_gate_l;
        float y_comp_hp_r = band_120_400[3][0].process(y_lp_r) * harmonic_gate_r;
        har_soft_l += har_soft_alpha * (y_comp_hp_l - har_soft_l);
        har_soft_r += har_soft_alpha * (y_comp_hp_r - har_soft_r);
        y_comp_hp_l = har_soft_l;
        y_comp_hp_r = har_soft_r;

        if (odd_lp_l > rms_est_l) {
            rms_est_l += attack_coeff * (odd_lp_l - rms_est_l);
        } else {
            rms_est_l += release_coeff * (odd_lp_l - rms_est_l);
        }

        if (odd_lp_r > rms_est_r) {
            rms_est_r += attack_coeff * (odd_lp_r - rms_est_r);
        } else {
            rms_est_r += release_coeff * (odd_lp_r - rms_est_r);
        }

        float target_gain_l;
        float rms_db_l = 10.0f * std::log10(rms_est_l + 1e-7f);

        if (rms_db_l > -12.0f) {
            target_gain_l = 0.4f;
        } else if (rms_db_l > -18.f) {
            target_gain_l = 0.6f;
        } else if (rms_db_l > -24.0f) {
            target_gain_l = 0.8f;
        } else {
            target_gain_l = 1.0f;
        }

        float target_gain_r;
        float rms_db_r = 10.0f * std::log10(rms_est_r + 1e-7f);

        if (rms_db_r > -12.0f) {
            target_gain_r = 0.4f;
        } else if (rms_db_r > -18.f) {
            target_gain_r = 0.6f;
        } else if (rms_db_r > -24.0f) {
            target_gain_r = 0.8f;
        } else {
            target_gain_r = 1.0f;
        }

        gain_agc_l += gain_smooth * (target_gain_l - gain_agc_l);
        gain_agc_r += gain_smooth * (target_gain_r - gain_agc_r);

        float out_l = 0.1f * hp_l + 0.2f * bp_l + 0.3 * y_comp_hp_l * 32;
        float out_r = 0.1f * hp_r + 0.2f * bp_r + 0.3 * y_comp_hp_r * 32;

        audio[0][i] = out_l;
        audio[1][i] = out_r;
    }
}

void SpeakerEffect::reset() {
    for (auto& high: high_400) {
        for (auto& h: high) {
            h.reset();
        }
    }

    for (auto& band: band_120_400) {
        for (auto& b: band) {
            b.reset();
        }
    }

    for (auto& low: low_120) {
        for (auto& l: low) {
            l.reset();
        }
    }

    env_l = 0.0f;
    env_r = 0.0f;
    env_slow_l = 0.0f;
    env_slow_r = 0.0f;
    rms_est_l = 0.0f;
    rms_est_r = 0.0f;
    gain_agc_l = 1.0f;
    gain_agc_r = 1.0f;

    lp_soft_l = 0.0f;
    lp_soft_r = 0.0f;
    har_soft_l = 0.0f;
    har_soft_r = 0.0f;
}

Priority SpeakerEffect::priority() const {
    return Priority::SPEAKER_EFFECT;
}

void SpeakerEffect::copyParamsFrom(const SpeakerEffect& other) {
    this->enabled.store(other.isEnabled(), std::memory_order_release);
}