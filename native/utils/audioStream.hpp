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

#ifndef __AUDIO_STREAM_H__
#define __AUDIO_STREAM_H__
#include "../effects/effect.hpp"
#include "../utils/crossFader.hpp"

#ifdef __ANDROID__
#include "oboe/Oboe.h"
#endif

template<typename T>
concept HasBufferType = requires(T& t, std::span<float, SAMPLES_LENGTH_PER_FRAME> audio) {
    {T::bufferType()};
    {t.isEnabled()};
    {t.run(audio)};
};

template<int MaxSamples>
struct RingBuffer {
    std::array<float, MaxSamples> buffer;
    std::atomic<int> write_pos = 0;
    std::atomic<int> read_pos = 0;

    void reset() {
        buffer.fill(0.0);
        write_pos.store(0, std::memory_order_release);
        read_pos.store(0, std::memory_order_release);
    }

    void write(int write_count, const float* input) {
        int w_pos = write_pos.load(std::memory_order_acquire);
        int next_write_pos = (w_pos + write_count) % MaxSamples;

        if (w_pos < next_write_pos || next_write_pos == 0) {
            memcpy(buffer.data() + w_pos, input, sizeof(float) * write_count);
        } else {
            memcpy(buffer.data() + w_pos, input, sizeof(float) * (MaxSamples - w_pos));
            memcpy(buffer.data(), input + (MaxSamples - w_pos), sizeof(float) * next_write_pos);
        }

        write_pos.store(next_write_pos, std::memory_order_release);
    }

    void read(int read_count, float* output) {
        int r_pos = read_pos.load(std::memory_order_acquire);
        int next_read_pos = (r_pos + read_count) % MaxSamples;

        if (r_pos < next_read_pos || next_read_pos == 0) {
            memcpy(output, buffer.data() + r_pos, sizeof(float) * read_count);
        } else {
            memcpy(output, buffer.data() + r_pos, sizeof(float) * (MaxSamples - r_pos));
            memcpy(output + (MaxSamples - r_pos), buffer.data(), sizeof(float) * next_read_pos);
        }

        read_pos.store(next_read_pos, std::memory_order_release);
    }
};

class AudioStream
#ifdef __ANDROID__
: public oboe::AudioStreamDataCallback
#endif
{
private:
    static const int SAMPLES_LENGTH_PER_FRAME = 1024;
    static const int SAMPLES_LENGTH_PER_CHANNEL = SAMPLES_LENGTH_PER_FRAME / 2;

    std::array<float, SAMPLES_LENGTH_PER_FRAME> audio, temp;

    RingBuffer<SAMPLES_LENGTH_PER_FRAME * 4> ring_buffer;

    BufferType current_buffer_type;

public:
    AudioStream()
        : current_buffer_type(BufferType::INTERLEAVED) {}
    
    template<typename T>
    AudioStream& operator>>(T& next) {
        if (!next.isEnabled()) {
            return *this;
        }

        checkAndConvertBufferType(next);

        next.run(audio);

        return *this;
    }

    void operator>>(float *output) {
        if (current_buffer_type == BufferType::INTERLEAVED) {
            memcpy(output, audio.data(), sizeof(float) * SAMPLES_LENGTH_PER_FRAME);
        } else {
            for (int i = 0; i < SAMPLES_LENGTH_PER_CHANNEL; i++) {
                output[i * 2] = audio[i];
                output[i * 2 + 1] = audio[i + SAMPLES_LENGTH_PER_CHANNEL];
            }
        }
    }

    void operator<<(float *input) {
        if (current_buffer_type == BufferType::INTERLEAVED) {
            memcpy(audio.data(), input, sizeof(float) * SAMPLES_LENGTH_PER_FRAME);
        } else {
            for (int i = 0; i < SAMPLES_LENGTH_PER_CHANNEL; i++) {
                audio[i] = input[i * 2] * 0.8f;
                audio[i + SAMPLES_LENGTH_PER_CHANNEL] = input[i * 2 + 1] * 0.8f;
            }
        }
    }

    template<typename T>
    AudioStream& operator>>(CrossFader<T>& cross_fader) {
        if (!cross_fader.isEnabled()) {
            return *this;
        }

        checkAndConvertBufferType(cross_fader);

        cross_fader.run(audio);

        return *this;
    }

    template<HasBufferType T>
    void checkAndConvertBufferType(T& next) {
        if (current_buffer_type == T::bufferType()) {
            return;
        }

        temp = audio;

        if (current_buffer_type != BufferType::INTERLEAVED) {
            current_buffer_type = BufferType::INTERLEAVED;

            for (int i = 0; i < SAMPLES_LENGTH_PER_CHANNEL; i++) {
                audio[i * 2] = temp[i];
                audio[i * 2 + 1] = temp[i + SAMPLES_LENGTH_PER_CHANNEL];
            }
        } else {
            current_buffer_type = BufferType::PLANAR;

            for (int i = 0; i < SAMPLES_LENGTH_PER_CHANNEL; i++) {
                audio[i] = temp[i * 2];
                audio[i + SAMPLES_LENGTH_PER_CHANNEL] = temp[i * 2 + 1];
            }
        }
    }

#ifdef __ANDROID__
    enum End {};
    static End end;

    void operator>>(End& end) {
        ring_buffer.write(SAMPLES_LENGTH_PER_FRAME, audio.data());
    }

    oboe::DataCallbackResult onAudioReady(oboe::AudioStream* stream, void* audio_data, int frame_count) override {
        ring_buffer.read(frame_count * 2, static_cast<float*>(audio_data));

        return oboe::DataCallbackResult::Continue;
    }
#endif
};
#endif