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
    reset();

    setRoomSize(other.room_size.load(std::memory_order_acquire));
    setDamping(other.damping.load(std::memory_order_acquire));
    setMix(other.mix.load(std::memory_order_acquire));
    setStereoWidth(other.stereo_width.load(std::memory_order_acquire));
    setModDepth(other.mod_depth.load(std::memory_order_acquire));
    setModFreq(other.mod_freq.load(std::memory_order_acquire));
    setPreDelay(other.pre_delay_ms.load(std::memory_order_acquire));
    setMatrixType(other.matrix_type.load(std::memory_order_acquire));

    setEnabled(other.acquireReadEnabled());
}

void ReverbEffect::applyFeedbackMatrix(std::array<float, NUM_DELAY>& sample, int matrix_type) {
    const auto& matrix = feedback_matrices[matrix_type];
    std::array<float, NUM_DELAY> tmp;

    for (int i = 0; i < NUM_DELAY; i++) {
        tmp[i] = 0.0f;

        for (int j = 0; j < NUM_DELAY; j++) {
            tmp[i] += matrix[i][j] * sample[j];
        }

        tmp[i] *= makeup_gain[matrix_type];
    }

    sample = std::move(tmp);
}

void ReverbEffect::run(std::vector<std::vector<float>>& audio) {
    float mod_depth_factor = mod_depth.load(std::memory_order_relaxed) * 2.0f;
    float mix_factor = mix.load(std::memory_order_relaxed);
    float damping_factor = 1.0f - damping.load(std::memory_order_relaxed) * 0.6f;
    float stereo_width_factor = stereo_width.load(std::memory_order_relaxed);

    float phase_delta = 2.0f * M_PI * mod_freq.load(std::memory_order_relaxed) / SAMPLE_RATE;
    int matrix_type_factor = matrix_type.load(std::memory_order_relaxed);

    for (int i = 0; i < audio[0].size(); i++) {
        float l = audio[0][i];
        float r = audio[1][i];

        float pre_l = pre_delay_l.process(l);
        float pre_r = pre_delay_r.process(r);

        mod_phase += phase_delta;
        mod_phase > 2.0f * M_PI ? mod_phase -= 2.0f * M_PI : mod_phase;

        std::array<float, NUM_DELAY> sample;

        for (int j = 0; j < NUM_DELAY; j++) {
            float base_delay = fdn_delay[j].getDelay();
            float mod_phase_j = mod_phase + j * 0.5f;
            float mod = mod_depth_factor * std::sin(mod_phase_j) * 1.6f;

            float read_pos = base_delay + mod;
            int offset = static_cast<int>(read_pos);
            float frac = read_pos - offset;

            float y0 = fdn_delay[j].read(offset - 1);
            float y1 = fdn_delay[j].read(offset);
            float y2 = fdn_delay[j].read(offset + 1);
            float y3 = fdn_delay[j].read(offset + 2);

            float a0 = -0.5f * y0 + 1.5f * y1 - 1.5f * y2 + 0.5f * y3;
            float a1 = y0 - 2.5f * y1 + 2.0f * y2 - 0.5f * y3;
            float a2 = -0.5f * y0 + 0.5f * y2;
            float a3 = y1;

            sample[j] = ((a0 * frac + a1) * frac + a2) * frac + a3;
        }

        for (int j = 0; j < NUM_DELAY; j++) {
            z1[j] = damping_factor * z1[j] + (1.0f - damping_factor) * sample[j];
            sample[j] = z1[j];
        }

        applyFeedbackMatrix(sample, matrix_type_factor);

        float feedback_gain = 0.5f + room_size * 0.35f;
        feedback_gain = std::min(feedback_gain, 0.85f);

        for (int j = 0; j < NUM_DELAY; j++) {
            float dry = ((j & 1) == 0) ? l : r;
            fdn_delay[j].write(dry + sample[j] * feedback_gain);
        }

        float sum_l = 0, sum_r = 0;
        for (int i = 0; i < NUM_DELAY; i++) {
            if ((i & 1) == 0) {
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


        audio[0][i] = pre_l * (1.0f - mix_factor) + l_out * mix_factor;
        audio[1][i] = pre_r * (1.0f - mix_factor) + r_out * mix_factor;
    }
}
