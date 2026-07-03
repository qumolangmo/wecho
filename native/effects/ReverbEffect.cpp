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
    , room_size(0.54f)
    , damping(0.25f)
    , mix(0.5f)
    , stereo_width(1.f)
    , mod_depth(0.57f)
    , mod_freq(4.3f)
    , pre_delay_ms(10)
    , matrix_type(0) {

    for (int i = 0; i < fdn_delay.size(); i++) {
        fdn_delay[i].setDelay(static_cast<int>(delay_sec[i] * (0.5f + 1.5f * room_size) *SAMPLE_RATE));
        z1[i] = 0.0f;
    }

    mod_phase = 0.0f;
    pre_delay_samples = pre_delay_ms * SAMPLE_RATE / 1000;

    pre_delay_l.setDelay(pre_delay_samples);
    pre_delay_r.setDelay(pre_delay_samples);
}

ReverbEffect::~ReverbEffect() {}

Priority ReverbEffect::priority() const {
    return REVERB_EFFECT;
}

void ReverbEffect::reset() {
    mod_phase = 0.0f;
    for (int i = 0; i < fdn_delay.size(); i++) {
        fdn_delay[i].reset();
        z1[i] = 0.0f;
    }

    pre_delay_l.reset();
    pre_delay_r.reset();
}

void ReverbEffect::setRoomSize(float room_size) {
    this->room_size.store(room_size, std::memory_order_release);

    for (int i = 0; i < fdn_delay.size(); i++) {
        fdn_delay[i].setDelay(static_cast<int>(delay_sec[i] * (0.5f + 1.5f * room_size) *SAMPLE_RATE));
    }
}

void ReverbEffect::setDamping(float damping) {
    this->damping.store(damping, std::memory_order_release);
}

void ReverbEffect::setMix(float mix) {
    this->mix.store(mix, std::memory_order_release);
}

void ReverbEffect::setStereoWidth(float stereo_width) {
    this->stereo_width.store(stereo_width, std::memory_order_release);
}

void ReverbEffect::setModDepth(float mod_depth) {
    this->mod_depth.store(mod_depth, std::memory_order_release);
}

void ReverbEffect::setModFreq(float mod_freq) {
    this->mod_freq.store(mod_freq, std::memory_order_release);
}

void ReverbEffect::setPreDelay(int pre_delay_ms) {
    pre_delay_ms = std::max(0, std::min(200, pre_delay_ms));
    pre_delay_samples = pre_delay_ms * SAMPLE_RATE / 1000;

    this->pre_delay_ms.store(pre_delay_ms, std::memory_order_release);

    pre_delay_l.setDelay(pre_delay_samples);
    pre_delay_r.setDelay(pre_delay_samples);
}

void ReverbEffect::setMatrixType(int matrix_type) {
    matrix_type = std::max(0, std::min(NUM_MATRICES - 1, matrix_type));
    this->matrix_type.store(matrix_type, std::memory_order_release);
}

void ReverbEffect::copyParamsFrom(const ReverbEffect& other) {
    this->room_size.store(other.room_size.load(std::memory_order_acquire), std::memory_order_release);
    this->damping.store(other.damping.load(std::memory_order_acquire), std::memory_order_release);
    this->mix.store(other.mix.load(std::memory_order_acquire), std::memory_order_release);
    this->stereo_width.store(other.stereo_width.load(std::memory_order_acquire), std::memory_order_release);
    this->mod_depth.store(other.mod_depth.load(std::memory_order_acquire), std::memory_order_release);
    this->mod_freq.store(other.mod_freq.load(std::memory_order_acquire), std::memory_order_release);
    this->pre_delay_ms.store(other.pre_delay_ms.load(std::memory_order_acquire), std::memory_order_release);
    this->matrix_type.store(other.matrix_type.load(std::memory_order_acquire), std::memory_order_release);

    setRoomSize(this->room_size);
    setPreDelay(this->pre_delay_ms);

    this->setEnabled(other.isEnabled());
}

void ReverbEffect::applyFeedbackMatrix(std::array<float, NUM_DELAY>& sample, int matrix_type) {
    const auto& matrix = feedback_matrices[matrix_type];
    std::array<float, NUM_DELAY> tmp;

    for (int i = 0; i < NUM_DELAY; i++) {
        tmp[i] = 0.0f;

        for (int j = 0; j < NUM_DELAY; j++) {
            tmp[i] += matrix[i][j] * sample[j];
        }

        tmp[i] *= 0.353553f;
    }

    sample = std::move(tmp);
}

void ReverbEffect::run(std::vector<std::vector<float>>& audio) {
    float mod_depth_factor = mod_depth.load(std::memory_order_acquire) * 0.2f;
    float mix_factor = mix.load(std::memory_order_acquire);
    float damping_factor = 1.0f - damping.load(std::memory_order_acquire) * 0.6f;
    float stereo_width_factor = stereo_width.load(std::memory_order_acquire);

    float phase_delta = 2.0f * M_PI * mod_freq.load(std::memory_order_acquire) / SAMPLE_RATE;
    int matrix_type_factor = matrix_type.load(std::memory_order_acquire);

    for (int i = 0; i < audio[0].size(); i++) {
        float l = audio[0][i];
        float r = audio[1][i];

        float pre_l = pre_delay_l.process(l);
        float pre_r = pre_delay_r.process(r);

        mod_phase += phase_delta;
        mod_phase > 2.0f * M_PI ? mod_phase -= 2.0f * M_PI : mod_phase;
        float mod_offset = mod_depth_factor * std::sin(mod_phase) * 2.0f;

        std::array<float, NUM_DELAY> sample;

        for (int j = 0; j < NUM_DELAY; j++) {
            int offset = fdn_delay[j].getDelay() + mod_offset;
            float frac = offset - static_cast<int>(offset);

            sample[j] = fdn_delay[j].read(offset) * (1.0f - frac) 
                        + fdn_delay[j].read(offset - 1) * frac;
        }

        for (int j = 0; j < NUM_DELAY; j++) {
            z1[j] = damping_factor * z1[j] + (1.0f - damping_factor) * sample[j];
            sample[j] = z1[j];
        }

        applyFeedbackMatrix(sample, matrix_type_factor);

        float input_sum = (l + r) * 0.5f;
        float feedback_gain = 0.5f + room_size * 0.35f;
        feedback_gain = std::min(feedback_gain, 0.85f);

        for (int j = 0; j < NUM_DELAY; j++) {
            float dry = (j % 2 == 0) ? pre_l : pre_r;
            fdn_delay[j].write(dry + sample[j] * feedback_gain);
        }

        float sum_l = 0, sum_r = 0;
        for (int i = 0; i < NUM_DELAY; i++) {
            if (i % 2 == 0) {
                sum_l += sample[i];
            } else {
                sum_r += sample[i];
            }
        }

        float l_out = sum_l * 0.25f;
        float r_out = sum_r * 0.25f;
        float mid = (l_out + r_out) * 0.5f;
        float side = (l_out - r_out) * stereo_width_factor;
        l_out = mid + side;
        r_out = mid - side;


        audio[0][i] = pre_l * (1.0f - mix_factor) + l_out * mix_factor * makeup_gain[matrix_type_factor];
        audio[1][i] = pre_r * (1.0f - mix_factor) + r_out * mix_factor * makeup_gain[matrix_type_factor];
    }
}
