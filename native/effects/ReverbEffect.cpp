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

ReverbEffect::ReverbEffect(bool enabled)
    : Effect(enabled)
    , room_size(0.5f)
    , damping(0.5f)
    , wet_mix(0.3f)
    , pre_delay_ms(20) {

    for (int i = 0; i < NUM_COMB; i++) {
        comb_delay_l[i].setDelay(COMB_DELAY_MS[i] * SAMPLE_RATE / 1000);
        comb_delay_r[i].setDelay(COMB_DELAY_MS[i] * SAMPLE_RATE / 1000);
        comb_lp_l[i] = 0.0f;
        comb_lp_r[i] = 0.0f;
        comb_feedback[i] = 0.84f + 0.5f * 0.14f;
    }

    for (int i = 0; i < NUM_ALLPASS; i++) {
        allpass_delay_l[i].setDelay(ALLPASS_DELAY_MS[i] * SAMPLE_RATE / 1000);
        allpass_delay_r[i].setDelay(ALLPASS_DELAY_MS[i] * SAMPLE_RATE / 1000);
    }

    pre_delay_l.setDelay(20 * SAMPLE_RATE / 1000);
    pre_delay_r.setDelay(20 * SAMPLE_RATE / 1000);
}

ReverbEffect::~ReverbEffect() {}

Priority ReverbEffect::priority() const {
    return REVERB_EFFECT;
}

void ReverbEffect::reset() {
    for (int i = 0; i < NUM_COMB; i++) {
        comb_delay_l[i].reset();
        comb_delay_r[i].reset();
        comb_lp_l[i] = 0.0f;
        comb_lp_r[i] = 0.0f;
    }

    for (int i = 0; i < NUM_ALLPASS; i++) {
        allpass_delay_l[i].reset();
        allpass_delay_r[i].reset();
    }

    pre_delay_l.reset();
    pre_delay_r.reset();
}

void ReverbEffect::setRoomSize(float room_size) {
    room_size = std::max(0.0f, std::min(1.0f, room_size));
    this->room_size.store(room_size, std::memory_order_release);

    float feedback = 0.84f + room_size * 0.14f;
    for (int i = 0; i < NUM_COMB; i++) {
        comb_feedback[i] = feedback;
    }

    reset();
}

void ReverbEffect::setDamping(float damping) {
    damping = std::max(0.0f, std::min(1.0f, damping));
    this->damping.store(damping, std::memory_order_release);

    reset();
}

void ReverbEffect::setWetMix(float wet_mix) {
    wet_mix = std::max(0.0f, std::min(1.0f, wet_mix));
    this->wet_mix.store(wet_mix, std::memory_order_release);

    reset();
}

void ReverbEffect::setPreDelay(int pre_delay_ms) {
    pre_delay_ms = std::max(0, std::min(200, pre_delay_ms));
    this->pre_delay_ms.store(pre_delay_ms, std::memory_order_release);
    pre_delay_l.setDelay(pre_delay_ms * SAMPLE_RATE / 1000);
    pre_delay_r.setDelay(pre_delay_ms * SAMPLE_RATE / 1000);

    reset();
}

void ReverbEffect::copyParamsFrom(const ReverbEffect& other) {
    this->room_size.store(other.room_size.load(std::memory_order_acquire), std::memory_order_release);
    this->damping.store(other.damping.load(std::memory_order_acquire), std::memory_order_release);
    this->wet_mix.store(other.wet_mix.load(std::memory_order_acquire), std::memory_order_release);
    this->pre_delay_ms.store(other.pre_delay_ms.load(std::memory_order_acquire), std::memory_order_release);
    this->setEnabled(other.isEnabled());

    float feedback = 0.84f + room_size.load(std::memory_order_acquire) * 0.14f;
    for (int i = 0; i < NUM_COMB; i++) {
        comb_feedback[i] = feedback;
    }
}

void ReverbEffect::run(std::vector<std::vector<float>>& audio) {
    float _room_size = room_size.load(std::memory_order_acquire);
    float _damping = damping.load(std::memory_order_acquire);
    float _wet_mix = wet_mix.load(std::memory_order_acquire);

    float damp_coef = _damping;
    float damp_coef_inv = 1.0f - damp_coef;

    for (int i = 0; i < audio[0].size(); i++) {
        float dry_l = audio[0][i];
        float dry_r = audio[1][i];

        float pre_l = pre_delay_l.process(dry_l);
        float pre_r = pre_delay_r.process(dry_r);

        float comb_out_l = 0.0f;
        float comb_out_r = 0.0f;

        for (int c = 0; c < NUM_COMB; c++) {
            float out_l = comb_delay_l[c].read();
            float out_r = comb_delay_r[c].read();

            comb_lp_l[c] = out_l * damp_coef_inv + comb_lp_l[c] * damp_coef;
            comb_lp_r[c] = out_r * damp_coef_inv + comb_lp_r[c] * damp_coef;

            float fb_l = pre_l + comb_lp_l[c] * comb_feedback[c];
            float fb_r = pre_r + comb_lp_r[c] * comb_feedback[c];

            comb_delay_l[c].write(fb_l);
            comb_delay_r[c].write(fb_r);

            comb_out_l += comb_lp_l[c];
            comb_out_r += comb_lp_r[c];
        }

        float allpass_in_l = comb_out_l;
        float allpass_in_r = comb_out_r;

        for (int a = 0; a < NUM_ALLPASS; a++) {
            float buffered_l = allpass_delay_l[a].read();
            float buffered_r = allpass_delay_r[a].read();

            float input_l = allpass_in_l + buffered_l * ALLPASS_FEEDBACK;
            float input_r = allpass_in_r + buffered_r * ALLPASS_FEEDBACK;

            allpass_delay_l[a].write(input_l);
            allpass_delay_r[a].write(input_r);

            allpass_in_l = buffered_l - input_l * ALLPASS_FEEDBACK;
            allpass_in_r = buffered_r - input_r * ALLPASS_FEEDBACK;
        }

        float wet_l = allpass_in_l;
        float wet_r = allpass_in_r;

        audio[0][i] = dry_l * (1.0f - _wet_mix) + wet_l * _wet_mix;
        audio[1][i] = dry_r * (1.0f - _wet_mix) + wet_r * _wet_mix;
    }
}
