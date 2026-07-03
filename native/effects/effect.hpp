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

#ifndef __EFFECT_H__
#define __EFFECT_H__
#include <vector>
#include <atomic>
#include <string>

#include "../utils/filter.hpp"
#include "../enum.h"
#include "../utils/convolver.hpp"
#include "../utils/harmonic.hpp"
#include "../utils/limiter.hpp"
#include "../utils/SoftLimiter.hpp"
#include "../tcc/libtcc.h"

#ifndef M_PI
#define M_PI 3.14159265358
#endif

class Effect {
private:
    std::atomic<bool> enabled;
public:
    static constexpr int SAMPLE_RATE = 48000;
    static constexpr int PROCESS_BLOCK_SIZE = 512;
public:
    virtual void run(std::vector<std::vector<float>>& audio) = 0;
    virtual Priority priority() const = 0;
    virtual void reset() = 0;
    virtual ~Effect() = default;

    bool isEnabled() const { return enabled.load(std::memory_order_acquire); }
    void setEnabled(bool enabled) { this->enabled.store(enabled, std::memory_order_release); }

    Effect(bool enabled): enabled(enabled) {}

    bool operator<(const Effect& other) const {
        return priority() < other.priority();
    }
};

class BassEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setGain(int gain);
    void setQ(float Q);
    void setCenterFreq(float center_freq);
    void copyParamsFrom(const BassEffect& other);

    BassEffect(bool enabled, int gain, float Q, float center_freq);
    ~BassEffect();

private:
    std::atomic<float> gain;
    std::atomic<float> Q;
    std::atomic<float> center_freq;
    Biquad<1> filter[2];
};

class ClarityEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setGain(int gain);
    void copyParamsFrom(const ClarityEffect& other);

    ClarityEffect(bool enabled, int gain);
    ~ClarityEffect();

private:
    std::atomic<float> gain;

    Biquad<1> low_pass_filter[2];

    float last_l;
    float last_r;
};

class GainEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setGain(float gain);
    GainEffect(bool enabled, float gain);
    ~GainEffect();

private:
    std::atomic<float> gain;
};

class ChannelBalanceEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setBalance(float balance);
    ChannelBalanceEffect(bool enabled, float balance);
    ~ChannelBalanceEffect();

private:
    std::atomic<float> left_gain;
    std::atomic<float> right_gain;
};

class EvenHarmonicEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setBase(float base);
    void setWarm(float warm);
    void setSugar(float sugar);
    void copyParamsFrom(const EvenHarmonicEffect& other);

    EvenHarmonicEffect(bool enabled, float base, float warm, float sugar);
    ~EvenHarmonicEffect();

private:
    std::atomic<float> base;
    std::atomic<float> warm;
    std::atomic<float> sugar;
    float env_band1_l, env_band1_r, processed_env_band1_l, processed_env_band1_r;
    float env_band2_l, env_band2_r, processed_env_band2_l, processed_env_band2_r;
    float env_band3_l, env_band3_r, processed_env_band3_l, processed_env_band3_r;
    float env_band4_l, env_band4_r, processed_env_band4_l, processed_env_band4_r;

    static constexpr float envelope_rate = 2 * M_PI * 50 / SAMPLE_RATE;

    LinkwitzRiley4Order<BAND_PASS> band1[2];
    LinkwitzRiley4Order<BAND_PASS> band2[2];
    LinkwitzRiley4Order<BAND_PASS> band3[2];
    LinkwitzRiley4Order<BAND_PASS> band4[2];

    DelayLine<1024> delay_band1[2];
    DelayLine<1024> delay_band2[2];
    DelayLine<1024> delay_band3[2];
    DelayLine<1024> delay_band4[2];
    DelayLine<1024> delay_other[2];

    Harmonic<4> harmonic_band1[2];
    Harmonic<4> harmonic_band2[2];
    Harmonic<4> harmonic_band3[2];
    Harmonic<4> harmonic_band4[2];
};

class ConvolveEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setIr(const std::string& ir_path);
    void setIr(const std::vector<std::vector<float>>& ir_data);
    void setMix(float mix);

    ConvolveEffect(bool enabled, float mix);
    ~ConvolveEffect();

private:
    std::atomic<float> mix;

    Convolver convolver;
};

class LimiterEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setThreshold(int threshold);
    void setRatio(int ratio);
    void setMakeupGain(int makeup_gain);
    void setAttack(int attack_ms);
    void setRelease(int release_ms);

    void copyParamsFrom(const LimiterEffect& other);

    LimiterEffect(bool enabled);
    ~LimiterEffect();

private:
    Limiter limiter;
};

class VirtualBassEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setEnvelopeRate(float envelope_rate);

    void copyParamsFrom(const VirtualBassEffect& other);

    VirtualBassEffect(bool enabled);
    ~VirtualBassEffect();

private:
    float post_gain;

    Biquad<1> high_150[2];

    Harmonic<3> harmonic[2];

    LinkwitzRiley4Order<HIGH_PASS> high_600[2];
    LinkwitzRiley4Order<BAND_PASS> band_80_150[2];
    LinkwitzRiley4Order<BAND_PASS> band_120_600[2];

    float lp_soft_l, lp_soft_r;

    float envelope_l, envelope_r;
    float har_envelope_l, har_envelope_r;
    float envelope_alpha;

    /* adjustable parameters */
    std::atomic<float> envelope_rate;
    std::atomic<float> lp_soft_alpha;

};

class LookAheadSoftLimitEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void copyParamsFrom(const LookAheadSoftLimitEffect& other);

    LookAheadSoftLimitEffect(bool enabled);
    ~LookAheadSoftLimitEffect();

private:
    MultiBandLimiter software_limiter;
};

class LowCatEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setCutoffFreq(int freq);
    void copyParamsFrom(const LowCatEffect& other);

    LowCatEffect(bool enabled, int cutoff_freq);
    ~LowCatEffect();

private:
    std::atomic<int> cutoff_freq;
    LinkwitzRiley4Order<HIGH_PASS> high_120[2];
};

class IIREqualizerEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setCoeffs(IIREqualizerCoeffs coeffs);

    void copyParamsFrom(const IIREqualizerEffect& other);

    IIREqualizerEffect(bool enabled);
    ~IIREqualizerEffect();

private:
    std::vector<Biquad<1>> biquads[2];
    IIREqualizerCoeffs coeffs;
};

class ReverbEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void setRoomSize(float room_size);
    void setDamping(float damping);
    void setMix(float mix);
    void setStereoWidth(float stereo_width);
    void setModDepth(float mod_depth);
    void setModFreq(float mod_freq);
    void setPreDelay(int pre_delay_ms);
    void setMatrixType(int matrix_type);

    void copyParamsFrom(const ReverbEffect& other);

    ReverbEffect(bool enabled);
    ~ReverbEffect();

private:
    static constexpr int NUM_DELAY = 8;

    void applyFeedbackMatrix(std::array<float, NUM_DELAY>& sample, int matrix_type);

    static constexpr int NUM_MATRICES = 4;

    DelayLine<4096> pre_delay_l;
    DelayLine<4096> pre_delay_r;

    std::array<DelayLine<4096>, NUM_DELAY> fdn_delay;
    std::array<float, NUM_DELAY> z1;

    static constexpr std::array<float, NUM_DELAY> delay_sec = {0.0157f, 0.0211f, 0.0253f, 0.0317f, 0.0371f, 0.0433f, 0.0497f, 0.0571f};

    // Matrix 0: Hadamard — fastest diffusion, smoothest decay
    static constexpr std::array<std::array<float, NUM_DELAY>, NUM_DELAY> hadamard_matrix = {{
        {1, 1, 1, 1, 1, 1, 1, 1},
        {1,-1, 1,-1, 1,-1, 1,-1},
        {1, 1,-1,-1, 1, 1,-1,-1},
        {1,-1,-1, 1, 1,-1,-1, 1},
        {1, 1, 1, 1,-1,-1,-1,-1},
        {1,-1, 1,-1,-1, 1,-1, 1},
        {1, 1,-1,-1,-1,-1, 1, 1},
        {1,-1,-1, 1,-1, 1, 1,-1}
    }};

    // Matrix 1: Householder — denser tail, warmer tone
    static constexpr std::array<std::array<float, NUM_DELAY>, NUM_DELAY> householder_matrix = {{
        {-0.25f,  0.75f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f},
        {-0.25f, -0.25f,  0.75f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f},
        {-0.25f, -0.25f, -0.25f,  0.75f, -0.25f, -0.25f, -0.25f, -0.25f},
        {-0.25f, -0.25f, -0.25f, -0.25f,  0.75f, -0.25f, -0.25f, -0.25f},
        {-0.25f, -0.25f, -0.25f, -0.25f, -0.25f,  0.75f, -0.25f, -0.25f},
        {-0.25f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f,  0.75f, -0.25f},
        {-0.25f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f,  0.75f},
        { 0.75f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f, -0.25f}
    }};

    // Matrix 2: Circulant — reduced spectral coloration
    static constexpr std::array<std::array<float, NUM_DELAY>, NUM_DELAY> circulant_matrix = {{
        { 0.3536f,  0.3536f,  0.3536f,  0.3536f,  0.3536f,  0.3536f,  0.3536f,  0.3536f},
        { 0.3536f,  0.4904f,  0.2778f, -0.0975f, -0.3536f, -0.2778f,  0.0975f,  0.4904f},
        { 0.3536f,  0.2778f, -0.0975f, -0.4904f, -0.3536f,  0.4904f,  0.0975f, -0.2778f},
        { 0.3536f, -0.0975f, -0.4904f, -0.2778f,  0.3536f,  0.2778f, -0.4904f, -0.0975f},
        { 0.3536f, -0.3536f, -0.3536f,  0.3536f,  0.3536f, -0.3536f, -0.3536f,  0.3536f},
        { 0.3536f, -0.2778f,  0.4904f, -0.0975f, -0.3536f,  0.0975f, -0.4904f,  0.2778f},
        { 0.3536f,  0.0975f, -0.2778f,  0.4904f, -0.3536f, -0.4904f,  0.2778f, -0.0975f},
        { 0.3536f,  0.4904f, -0.0975f, -0.2778f,  0.3536f, -0.2778f, -0.4904f,  0.0975f}
    }};

    // Matrix 3: Sparse Random Orthogonal — extra diffusion, unique texture
    static constexpr std::array<std::array<float, NUM_DELAY>, NUM_DELAY> sparse_matrix = {{
        { 0.5f,  0.5f,  0.0f,  0.0f,  0.5f,  0.5f,  0.0f,  0.0f},
        { 0.5f, -0.5f,  0.0f,  0.0f,  0.5f, -0.5f,  0.0f,  0.0f},
        { 0.0f,  0.0f,  0.5f,  0.5f,  0.0f,  0.0f, -0.5f, -0.5f},
        { 0.0f,  0.0f,  0.5f, -0.5f,  0.0f,  0.0f, -0.5f,  0.5f},
        { 0.5f,  0.5f,  0.0f,  0.0f, -0.5f, -0.5f,  0.0f,  0.0f},
        { 0.5f, -0.5f,  0.0f,  0.0f, -0.5f,  0.5f,  0.0f,  0.0f},
        { 0.0f,  0.0f, -0.5f, -0.5f,  0.0f,  0.0f, -0.5f, -0.5f},
        { 0.0f,  0.0f, -0.5f,  0.5f,  0.0f,  0.0f, -0.5f,  0.5f}
    }};

    std::array<float, 4> makeup_gain = {
        std::pow(10.0f, -1.0f / 20.f), 
        std::pow(10.0f, 9.0f / 20.f), 
        std::pow(10.0f, 9.0f / 20.f), 
        std::pow(10.0f, 7.0f / 20.f)
    };

    static constexpr std::array<std::array<std::array<float, NUM_DELAY>, NUM_DELAY>, NUM_MATRICES> feedback_matrices = {{
        hadamard_matrix, householder_matrix, circulant_matrix, sparse_matrix
    }};

    std::atomic<float> room_size;
    std::atomic<float> damping;
    std::atomic<float> mix;
    std::atomic<float> stereo_width;
    std::atomic<float> mod_depth;
    std::atomic<float> mod_freq;
    std::atomic<int> pre_delay_ms;
    std::atomic<int> matrix_type;
    
    int pre_delay_samples;
    float mod_phase;
};

class ScriptEffect: public Effect {
public:
    ScriptEffect(bool enabled);
    ~ScriptEffect();

    static void setCacheDir(std::string_view cache_dir);
    static std::string_view getCacheDir();
    static std::string getLastError();
    static bool consumeCrashFlag();

    void setCode(std::string code);
    void setParams(ScriptParamsArray params);

    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void copyParamsFrom(const ScriptEffect& other);
    bool isCrashed() const { return crashed; }

private:
    static void errorHandle(void* op, const char* error_msg);
    static std::string last_error;

    std::string code;
    ScriptParamsArray params;

    TCCState* state;
    bool is_loaded;
    bool crashed;
    void (*process_func)(float* input_l, float* input_r, float* output_l, float* output_r);
    void (*params_func)(ScriptParams* params);
    
};


#endif
