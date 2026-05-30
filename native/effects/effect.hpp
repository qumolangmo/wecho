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
#include "../utils/vbPhaseVocoder.hpp"
#include "../utils/SoftLimiter.hpp"

#ifndef M_PI
#define M_PI 3.14159265358
#endif

class Effect {
private:
    std::atomic<bool> enabled;
public:
    static constexpr int SAMPLE_RATE = 48000;
    static constexpr int PROCESS_BLOCK_SIZE = SAMPLE_RATE / 100;
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

    EvenHarmonicEffect(bool enabled, int gain, float base, float warm, float sugar);
    ~EvenHarmonicEffect();

private:
    std::atomic<float> base;
    std::atomic<float> warm;
    std::atomic<float> sugar;

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
    Harmonic<6> harmonic_band2[2];
    Harmonic<6> harmonic_band3[2];
    Harmonic<6> harmonic_band4[2];
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

class SpeakerEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void set2HarmonicCoeffs(float coeffs);
    void set4HarmonicCoeffs(float coeffs);
    void set6HarmonicCoeffs(float coeffs);
    void setBpGain(float gain);
    void setHpGain(float gain);

    void copyParamsFrom(const SpeakerEffect& other);

    SpeakerEffect(bool enabled);
    ~SpeakerEffect();

private:
    Harmonic<6> harmonic[2];

    LinkwitzRiley4Order<HIGH_PASS> high_600[2];
    LinkwitzRiley4Order<BAND_PASS> band_40_120[2];
    LinkwitzRiley4Order<BAND_PASS> band_120_600[2];

    static constexpr float lp_soft_alpha = 2 * M_PI * 50.0f / SAMPLE_RATE;
    static constexpr float har_soft_alpha = 2 * M_PI * 100.0f / SAMPLE_RATE;
    float lp_soft_l, lp_soft_r;
    float har_soft_l, har_soft_r;

    std::atomic<float> _2_harmonic_coeffs;
    std::atomic<float> _4_harmonic_coeffs;
    std::atomic<float> _6_harmonic_coeffs;
    std::atomic<float> bp_gain;
    std::atomic<float> hp_gain;
};

class VBPhaseVocoderEffect: public Effect {
public:
    void run(std::vector<std::vector<float>>& audio) override;
    Priority priority() const override;
    void reset() override;

    void copyParamsFrom(const VBPhaseVocoderEffect& other);

    VBPhaseVocoderEffect(bool enabled);
    ~VBPhaseVocoderEffect();

private:
    VBPhaseVocoder vb_phase_vcoder[2];
    LinkwitzRiley4Order<BAND_PASS> band_150_500[2];
    LinkwitzRiley4Order<HIGH_PASS> high_150[2];
    LinkwitzRiley4Order<LOW_PASS> low_150[2];
    LinkwitzRiley4Order<LOW_PASS> low_2048[2];
    DelayLine<8192> delay[2];
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

#endif
