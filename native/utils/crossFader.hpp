/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#ifndef __CROSS_FADER_H__
#define __CROSS_FADER_H__

#include <vector>
#include <utility>

/* If you want to apply the CrossFader in yourself effect,
 *
 * Please: 
 *
 * 1. implement copyParamsFrom(stateless, only params copy) in your effect class.
 * 2. update your filter coeffs in set method. 
 * 3. in flutter initlization, the enable switch must be passed as the final param, otherwise your effect maybe not work first time.
 *
 */
template <typename T>
concept EffectInstance = requires(T t, const T& other, std::vector<std::vector<float>>& audio) {
    {t.copyParamsFrom(other)};
    {t.reset()};
    {t.run(audio)};
    {t.isEnabled()};
};

template <EffectInstance T>
class CrossFader {
private:
    static constexpr int SAMPLE_RATE = 48000;
    static constexpr int FRAME_SIZE_PER_CHANNEL = 480;
    T cache1, cache2;
    T* current;
    T* target;
    int fade_samples;
    int fade_counter;
    bool is_cross_fading;
    bool is_fade_in;
    bool is_fade_out;

    std::vector<std::vector<float>> current_audio, target_audio;
public:
    template<typename... Args>
    CrossFader(int fade_time_ms, Args&&... args)
        : fade_samples(static_cast<int>(fade_time_ms * SAMPLE_RATE / 1000)),
          fade_counter(0),
          current_audio(2, std::vector<float>(FRAME_SIZE_PER_CHANNEL)),
          target_audio(2, std::vector<float>(FRAME_SIZE_PER_CHANNEL)),
          cache1(std::forward<Args>(args)...),
          cache2(std::forward<Args>(args)...),
          current(&cache1),
          target(&cache2),
          is_cross_fading(false),
          is_fade_in(false),
          is_fade_out(false) {}

    void process(std::vector<std::vector<float>>& audio) {
        if (is_cross_fading) {
            std::copy(audio.begin(), audio.end(), current_audio.begin());
            std::copy(audio.begin(), audio.end(), target_audio.begin());

            current->run(current_audio);
            target->run(target_audio);

            float t;

            for (int i = 0; i < audio[0].size(); i++) {
                t = static_cast<float>(fade_counter) / fade_samples;

                audio[0][i] = current_audio[0][i] * (1.0 - t) + target_audio[0][i] * t;
                audio[1][i] = current_audio[1][i] * (1.0 - t) + target_audio[1][i] * t;
                fade_counter++;
            }

            if (fade_counter >= fade_samples) {
                std::swap(current, target);
                is_cross_fading = false;
                fade_counter = 0;
            }
        } else if (is_fade_in || is_fade_out) {
            std::copy(audio.begin(), audio.end(), current_audio.begin());

            if (is_fade_in) {
                target->run(current_audio);
            } else {
                current->run(current_audio);
            }

            float t;
            for (int i = 0; i < audio[0].size(); i++) {
                t = static_cast<float>(fade_counter) / fade_samples;

                if (is_fade_in) {
                    audio[0][i] = audio[0][i] * (1.0 - t) + current_audio[0][i] * t;
                    audio[1][i] = audio[1][i] * (1.0 - t) + current_audio[1][i] * t;
                } else {
                    audio[0][i] = current_audio[0][i] * (1.0 - t) + audio[0][i] * t;
                    audio[1][i] = current_audio[1][i] * (1.0 - t) + audio[1][i] * t;
                }
                fade_counter++;
            }

            if (fade_counter >= fade_samples) {
                std::swap(current, target);
                is_fade_in = false;
                is_fade_out = false;
                fade_counter = 0;
            }
        } else {
            current->run(audio);
        }
    }

    template <typename F>
    void update(F setNewParam) {
        if (!is_cross_fading) {
            target->copyParamsFrom(*current);

            setNewParam(*target);

            if (target->isEnabled() != current->isEnabled()) {
                is_fade_in = target->isEnabled();
                is_fade_out = !is_fade_in;
                fade_counter = 0;
            } else {
                is_cross_fading = true;
                fade_counter = 0;
            }
        } else {
            setNewParam(*target);
        }
    }

    void reset() {
        current->reset();

        if (target) {
            target->reset();
        }

        is_cross_fading = false;
        is_fade_in = false;
        is_fade_out = false;
        fade_counter = 0;
    }

    bool isEnabled() const {
        return is_cross_fading || is_fade_in || is_fade_out || current->isEnabled();
    }
};

#endif