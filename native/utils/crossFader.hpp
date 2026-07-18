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
#ifndef __CROSS_FADER_H__
#define __CROSS_FADER_H__

#include <vector>
#include <utility>
#include <functional>

/* If you want to apply the CrossFader in yourself effect,
 *
 * Please: 
 *
 * 1. implement copyParamsFrom in your effect class.
 * 2. update your filter coeffs in set method or copyParamsFrom method. 
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
    static constexpr int FRAME_SIZE_PER_CHANNEL = 512;
    T cache1, cache2;
    T* current;
    T* target;
    int fade_samples;
    int fade_counter;
    std::atomic<bool> is_cross_fading;
    std::atomic<bool> is_fade_in;
    std::atomic<bool> is_fade_out;

    std::vector<std::vector<float>> current_audio, target_audio;
    std::function<void(T&)> next;
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
        bool _is_cross_fading = is_cross_fading.load(std::memory_order_acquire);
        bool _is_fade_in = is_fade_in.load(std::memory_order_acquire);
        bool _is_fade_out = is_fade_out.load(std::memory_order_acquire);

        if (_is_cross_fading) {
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
                is_cross_fading.store(false, std::memory_order_release);
                fade_counter = 0;

                processPendingUpdate();
            }
        } else if (_is_fade_in || _is_fade_out) {
            std::copy(audio.begin(), audio.end(), current_audio.begin());

            if (_is_fade_in) {
                target->run(current_audio);
            } else {
                current->run(current_audio);
            }

            float t;
            for (int i = 0; i < audio[0].size(); i++) {
                t = static_cast<float>(fade_counter) / fade_samples;

                if (_is_fade_in) {
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
                is_fade_in.store(false, std::memory_order_release);
                is_fade_out.store(false, std::memory_order_release);
                fade_counter = 0;

                processPendingUpdate();
            }
        } else {
            current->run(audio);
        }
    }

    template<typename F>
    void update(F setNewParam, bool initialize = false) {
        if (initialize) {
            is_cross_fading.store(false, std::memory_order_release);
            is_fade_in.store(false, std::memory_order_release);
            is_fade_out.store(false, std::memory_order_release);
            fade_counter = 0;
            next = nullptr;

            setNewParam(*current);
            setNewParam(*target);
        } else {
            if (!is_cross_fading.load(std::memory_order_acquire)
                && !is_fade_in.load(std::memory_order_acquire)
                && !is_fade_out.load(std::memory_order_acquire)) {

                startFade(setNewParam);
            } else {
                next = setNewParam;
            }
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
        return is_cross_fading.load(std::memory_order_acquire) 
            || is_fade_in.load(std::memory_order_acquire) 
            || is_fade_out.load(std::memory_order_acquire) 
            || current->isEnabled();
    }

private:
    template<typename F>
    void startFade(F setNewParam) {
        target->copyParamsFrom(*current);
        setNewParam(*target);

        if (target->isEnabled() != current->isEnabled()) {
            is_fade_in.store(target->isEnabled(), std::memory_order_release);
            is_fade_out.store(!is_fade_in.load(std::memory_order_acquire), std::memory_order_release);
        } else {
            is_cross_fading.store(true, std::memory_order_release);
        }
        fade_counter = 0;
    }

    void processPendingUpdate() {
        if (next) {
            startFade(next);
            next = nullptr;
        }
    }
};

#endif