/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#ifndef __ENUM_H__
#define __ENUM_H__

#include <cstddef>
#include <atomic>

using inner_string = wchar_t [1024];

#define EFFECT_PARAMS \
    X(GAIN_EFFECT_GAIN, float) \
    X(BALANCE_EFFECT_BALANCE, float) \
    X(BASS_EFFECT_ENABLED, bool) \
    X(BASS_EFFECT_GAIN, int) \
    X(BASS_EFFECT_CENTER_FREQ, int) \
    X(BASS_EFFECT_Q, float) \
    X(CLARITY_EFFECT_ENABLED, bool) \
    X(CLARITY_EFFECT_GAIN, int) \
    X(EVEN_HARMONIC_EFFECT_ENABLED, bool) \
    X(EVEN_HARMONIC_EFFECT_GAIN, int) \
    X(CONVOLVE_EFFECT_ENABLED, bool) \
    X(CONVOLVE_EFFECT_MIX, float) \
    X(CONVOLVE_EFFECT_IR_PATH, inner_string) \
    X(LIMITER_EFFECT_ENABLED, bool) \
    X(LIMITER_EFFECT_THRESHOLD, int) \
    X(LIMITER_EFFECT_RATIO, int) \
    X(LIMITER_EFFECT_MAKEUP_GAIN, int) \
    X(LIMITER_EFFECT_ATTACK, int) \
    X(LIMITER_EFFECT_RELEASE, int) \
    X(SPEAKER_EFFECT_ENABLED, bool) \
    X(SPEAKER_EFFECT_HP_GAIN, float) \
    X(SPEAKER_EFFECT_BP_GAIN, float) \
    X(SPEAKER_EFFECT_2_HARMONIC_COEFFS, float) \
    X(SPEAKER_EFFECT_4_HARMONIC_COEFFS, float) \
    X(SPEAKER_EFFECT_6_HARMONIC_COEFFS, float) \
    X(LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED, bool) \
    X(MAX_EFFECT_PARAM, int)

enum ParamID {
#define X(name, type) name,
    EFFECT_PARAMS
#undef X
};

struct alignas(8) EffectData {
#define X(name, type) type name;
    EFFECT_PARAMS
#undef X

    template<typename T>
    T& at(int index) {
        static const size_t offsets[] = {
#define X(name, type) offsetof(EffectData, name),
            EFFECT_PARAMS
#undef X
        };

        return *reinterpret_cast<T*>(reinterpret_cast<char*>(this) + offsets[index]);
    }
};

struct alignas(8) SharedData {
    std::atomic<bool> flags;
    EffectData effect_data;
    int ir_data_length;
    float ir_data[2 * 1024 * 1024 - sizeof(EffectData) - sizeof(int) * 2 - 100];
};

enum Priority {
    GAIN_EFFECT,
    CHANNEL_BALANCE_EFFECT,
    SPEAKER_EFFECT,
    CONVOLVE_EFFECT,
    BASS_EFFECT,
    CLARITY_EFFECT,
    EVEN_HARMONIC_EFFECT,
    LIMITER_EFFECT,
    LOOK_AHEAD_SOFT_LIMIT_EFFECT,
    MAX_PRIORITY_EFFECT
};

enum FilterType {
    LOW_PASS,
    BAND_PASS,
    HIGH_PASS,
};

#endif