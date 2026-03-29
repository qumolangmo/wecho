/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#ifndef __AUDIO_STREAM_H__
#define __AUDIO_STREAM_H__
#include <vector>
#include "../effects/effect.hpp"
#include "../utils/crossFader.hpp"

class AudioStream {
private:
    std::vector<std::vector<float>> audio;
public:
    int sample_length_per_frame;

public:
    AudioStream(size_t length)
        : audio(2, std::vector<float>(length, 0.0f)) {}

    AudioStream& operator>>(Effect& other) {
        if (other.isEnabled()) {
            other.run(audio);
        }

        return *this;
    }

    void operator>>(float *output) {
        int frame_count = sample_length_per_frame / 2;

        for (int i = 0; i < frame_count; i++) {
            output[i * 2] = audio[0][i];
            output[i * 2 + 1] = audio[1][i];
        }
    }

    void operator<<(float *input) {
        for (int i = 0, idx = 0; i < sample_length_per_frame; i += 2, idx++) {
            audio[0][idx] = input[i] * 0.8;
            audio[1][idx] = input[i + 1] * 0.8;
        }

        audio[0].resize(sample_length_per_frame / 2);
        audio[1].resize(sample_length_per_frame / 2);
    }

    template<typename T>
    AudioStream& operator>>(CrossFader<T>& cross_fader) {
        if (cross_fader.isEnabled()) {
            cross_fader.process(audio);
        }

        return *this;
    }
};
#endif