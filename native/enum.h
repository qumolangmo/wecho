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
#include <cstdint>
#include <string>

using FloatArray = float[65536 * 2];
using FileName = char[4096];

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
    X(CONVOLVE_EFFECT_IR_PATH, FileName) \
    X(CONVOLVE_EFFECT_IR_DATA, FloatArray) \
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
    X(LOW_CAT_EFFECT_ENABLED, bool) \
    X(LOW_CAT_EFFECT_CUTOFF_FREQ, int) \
    X(MAX_EFFECT_PARAM, int)

enum ParamID {
#define X(name, type) name,
    EFFECT_PARAMS
#undef X
};

enum ParamType {
    PARAM_TYPE_BOOL,
    PARAM_TYPE_INT,
    PARAM_TYPE_FLOAT,
    PARAM_TYPE_STRING,
    PARAM_TYPE_ARRAY,
};

struct alignas(4) EffectData {
#define X(name, type) type name;
    EFFECT_PARAMS
#undef X
};

struct alignas(8) SharedData {
    /* 
     * true: owner apo
     * false: owner ui
     */
    std::atomic<bool> flags = false;
    static_assert(sizeof(std::atomic<bool>) == sizeof(bool), "std::atomic<bool> must be the same size as bool");
    static_assert(sizeof(bool) == 1, "bool must be 1 byte");

    /* only apo update this field */
    std::atomic<uint64_t> last_heart_beat = 0;
    static_assert(sizeof(std::atomic<uint64_t>) == sizeof(uint64_t), "std::atomic<uint64_t> must be the same size as uint64_t");
    static_assert(sizeof(uint64_t) == 8, "uint64_t must be 8 bytes");

    std::atomic<bool> enabled_apo = false;
    std::atomic<int> ir_length = 0;
    static_assert(sizeof(std::atomic<int>) == sizeof(int), "std::atomic<int> must be the same size as int");
    static_assert(sizeof(int) == 4, "int must be 4 bytes");

    EffectData effect_data;
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
    LOW_CAT_EFFECT,
    MAX_PRIORITY_EFFECT
};

enum FilterType {
    LOW_PASS,
    BAND_PASS,
    HIGH_PASS,
};

#endif