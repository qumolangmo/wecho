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

#ifndef __ENUM_H__
#define __ENUM_H__

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include "scripting/wecho_dsp_c_api.h"

using FloatArray = float[65536 * 2];
using FileName = char[4096];
using ScriptCode = char[65536 * 2];

struct Coeffs {
    int32_t index;
    int32_t start_freq;
    int32_t end_freq;
    int32_t gain;
};

using IIREqualizerCoeffs = std::array<Coeffs, 10>;

using ScriptParamsArray = ScriptParams[16];

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
    X(EVEN_HARMONIC_EFFECT_BASE, float) \
    X(EVEN_HARMONIC_EFFECT_WARM, float) \
    X(EVEN_HARMONIC_EFFECT_SUGAR, float) \
    X(CONVOLVE_EFFECT_ENABLED, bool) \
    X(CONVOLVE_EFFECT_MIX, float) \
    X(CONVOLVE_EFFECT_IR_PATH, FileName) \
    X(CONVOLVE_EFFECT_IR_DATA, FloatArray) \
    X(COMPRESSOR_EFFECT_ENABLED, bool) \
    X(COMPRESSOR_EFFECT_THRESHOLD, int) \
    X(COMPRESSOR_EFFECT_RATIO, int) \
    X(COMPRESSOR_EFFECT_MAKEUP_GAIN, int) \
    X(COMPRESSOR_EFFECT_ATTACK, int) \
    X(COMPRESSOR_EFFECT_RELEASE, int) \
    X(LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED, bool) \
    X(LOW_CAT_EFFECT_ENABLED, bool) \
    X(LOW_CAT_EFFECT_CUTOFF_FREQ, int) \
    X(IIR_EQUALIZER_EFFECT_ENABLED, bool) \
    X(IIR_EQUALIZER_EFFECT_COEFFS, IIREqualizerCoeffs) \
    X(VIRTUALBASS_EFFECT_ENABLED, bool) \
    X(VIRTUALBASS_EFFECT_ENVELOPE_RATE, int) \
    X(VIRTUALBASS_EFFECT_MID_GAIN, float) \
    X(VIRTUALBASS_EFFECT_HIGH_GAIN, float) \
    X(VIRTUALBASS_EFFECT_HARMONIC_GAIN, float) \
    X(REVERB_EFFECT_ENABLED, bool) \
    X(REVERB_EFFECT_ROOM_SIZE, float) \
    X(REVERB_EFFECT_DAMPING, float) \
    X(REVERB_EFFECT_MIX, float) \
    X(REVERB_EFFECT_STEREO_WIDTH, float) \
    X(REVERB_EFFECT_MOD_DEPTH, float) \
    X(REVERB_EFFECT_MOD_FREQ, float) \
    X(REVERB_EFFECT_PRE_DELAY, int) \
    X(REVERB_EFFECT_MATRIX_TYPE, int) \
    X(SCRIPT_EFFECT_ENABLED, bool) \
    X(SCRIPT_EFFECT_PARAMS, ScriptParamsArray) \
    X(SCRIPT_EFFECT_CODE, ScriptCode) \
    X(DIFF_SURROUNDING_EFFECT_ENABLED, bool) \
    X(DIFF_SURROUNDING_EFFECT_DELAY_MS, int) \
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
    DIFF_SURROUNDING_EFFECT,
    VIRTUALBASS_EFFECT,
    CONVOLVE_EFFECT,
    BASS_EFFECT,
    CLARITY_EFFECT,
    IIR_EQUALIZER_EFFECT,
    EVEN_HARMONIC_EFFECT,
    COMPRESSOR_EFFECT,
    LOOK_AHEAD_SOFT_LIMIT_EFFECT,
    LOW_CAT_EFFECT,
    REVERB_EFFECT,
    SCRIPT_EFFECT,
    MAX_PRIORITY_EFFECT
};

enum FilterType {
    LOW_PASS,
    BAND_PASS,
    HIGH_PASS,
};

enum BufferType {
    INTERLEAVED,
    PLANAR
};

#endif