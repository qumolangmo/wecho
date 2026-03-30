/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#ifndef __AUDIO_PROCESSOR_HPP__
#define __AUDIO_PROCESSOR_HPP__
#include "effects/effect.hpp"
#include "utils/audioStream.hpp"
#include "utils/crossFader.hpp"

#include <any>
#include <unordered_map>
#include <functional>
#include "enum.h"

class ParamSetter {
private:
    std::function<void(std::any)> setter;

public:
    explicit ParamSetter() : setter([](std::any){}) {}

    template<typename T>
    ParamSetter(std::function<void(T)> func) {
        setter = [func](std::any value){
            func(std::any_cast<T>(value));
        };
    }

    void operator()(std::any value) {
        setter(value);
    }
};

class AudioProcessor {
private:
    static constexpr int FRAME_SIZE_PER_CHANNEL = 441;

    CrossFader<BassEffect> EBass;
    CrossFader<ClarityEffect> EClarity;
    GainEffect EGain;
    ChannelBalanceEffect EChannelBalance;
    CrossFader<EvenHarmonicEffect> EEvenHarmonic;
    LimiterEffect ELimiter;
    ConvolveEffect EConvolve;
    CrossFader<SpeakerEffect> ESpeaker;
    //CrossFader<VBPhaseVocoderEffect> ESpeaker;
    CrossFader<LookAheadSoftLimitEffect> ELookAheadSoftLimiter;

    std::unordered_map<ParamID, ParamSetter> param_map;
    AudioStream audio_stream;

    AudioProcessor()
        : audio_stream(FRAME_SIZE_PER_CHANNEL * 3)
        , EBass(50.0, false, 0, 1.48f, 60.0f)
        , EClarity(50.0, false, 0)
        , EGain(false, 0)
        , EChannelBalance(false, 0)
        , EEvenHarmonic(80.0, false, 0, 0.5f)
        , EConvolve(false, 0.1f)
        , ELimiter(false)
        , ESpeaker(1200, false)
        , ELookAheadSoftLimiter(100, false) {

        param_map = {
            {GAIN_EFFECT_GAIN, 
                ParamSetter(std::function<void(float)>([this](float gain) {
                    EGain.setGain(gain); 
                }))},
            {BALANCE_EFFECT_BALANCE, 
                ParamSetter(std::function<void(float)>([this](float balance) {
                    EChannelBalance.setBalance(balance); 
                }))},
            {BASS_EFFECT_ENABLED, 
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EBass.update([enabled] (BassEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {BASS_EFFECT_GAIN, 
                ParamSetter(std::function<void(int)>([this](int gain) { 
                    EBass.update([gain] (BassEffect& effect) {
                        effect.setGain(gain);
                    });
                }))},
            {BASS_EFFECT_CENTER_FREQ, 
                ParamSetter(std::function<void(int)>([this](int center_freq) { 
                    EBass.update([center_freq] (BassEffect& effect) {
                        effect.setCenterFreq(center_freq);
                    });
                }))},
            {BASS_EFFECT_Q, 
                ParamSetter(std::function<void(float)>([this](float Q) { 
                    EBass.update([Q] (BassEffect& effect) {
                        effect.setQ(Q);
                    });
                }))},
            {CLARITY_EFFECT_ENABLED, 
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EClarity.update([enabled] (ClarityEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {CLARITY_EFFECT_GAIN, 
                ParamSetter(std::function<void(int)>([this](int gain) { 
                    EClarity.update([gain] (ClarityEffect& effect) {
                        effect.setGain(gain);
                    });
                }))},
            {EVEN_HARMONIC_EFFECT_ENABLED, 
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EEvenHarmonic.update([enabled] (EvenHarmonicEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                    // EEvenHarmonic.setEnabled(enabled);
                }))},
            {EVEN_HARMONIC_EFFECT_GAIN, 
                ParamSetter(std::function<void(int)>([this](int gain) { 
                    EEvenHarmonic.update([gain] (EvenHarmonicEffect& effect) {
                        effect.setGain(gain);
                    });
                }))},
            {CONVOLVE_EFFECT_ENABLED, 
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EConvolve.setEnabled(enabled);
                }))},
            {CONVOLVE_EFFECT_MIX, 
                ParamSetter(std::function<void(float)>([this](float mix) { 
                    EConvolve.setMix(mix);
                }))},
            {CONVOLVE_EFFECT_IR_PATH, 
                ParamSetter(std::function<void(std::string)>([this](std::string ir_path) { 
                    EConvolve.setIr(ir_path);
                }))},
            {CONVOLVE_EFFECT_IR_DATA,
                ParamSetter(std::function<void(std::vector<std::vector<float>>&&)>([this](std::vector<std::vector<float>>&& ir_data) {
                    EConvolve.setIr(std::move(ir_data));
                }))},
            {LIMITER_EFFECT_ENABLED, 
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    ELimiter.setEnabled(enabled);
                }))},
            {LIMITER_EFFECT_THRESHOLD, 
                ParamSetter(std::function<void(int)>([this](int threshold) { 
                    ELimiter.setThreshold(threshold);
                }))},
            {LIMITER_EFFECT_RATIO, 
                ParamSetter(std::function<void(int)>([this](int ratio) { 
                    ELimiter.setRatio(ratio);
                }))},
            {LIMITER_EFFECT_MAKEUP_GAIN, 
                ParamSetter(std::function<void(int)>([this](int makeup_gain) { 
                    ELimiter.setMakeupGain(makeup_gain);
                }))},
            {LIMITER_EFFECT_ATTACK, 
                ParamSetter(std::function<void(int)>([this](int attack) { 
                    ELimiter.setAttack(attack);
                }))},
            {LIMITER_EFFECT_RELEASE, 
                ParamSetter(std::function<void(int)>([this](int release) { 
                    ELimiter.setRelease(release);
                }))},
            {SPEAKER_EFFECT_ENABLED, 
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    ESpeaker.update([enabled] (SpeakerEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {SPEAKER_EFFECT_HP_GAIN, 
                ParamSetter(std::function<void(float)>([this](float hp_gain) { 
                    ESpeaker.update([hp_gain] (SpeakerEffect& effect) {
                        effect.setHpGain(hp_gain);
                    });
                }))},
            {SPEAKER_EFFECT_BP_GAIN, 
                ParamSetter(std::function<void(float)>([this](float bp_gain) { 
                    ESpeaker.update([bp_gain] (SpeakerEffect& effect) {
                        effect.setBpGain(bp_gain);
                    });
                }))},
            {SPEAKER_EFFECT_2_HARMONIC_COEFFS, 
                ParamSetter(std::function<void(float)>([this](float coeffs) { 
                    ESpeaker.update([coeffs] (SpeakerEffect& effect) {
                        effect.set2HarmonicCoeffs(coeffs);
                    });
                }))},
            {SPEAKER_EFFECT_4_HARMONIC_COEFFS, 
                ParamSetter(std::function<void(float)>([this](float coeffs) { 
                    ESpeaker.update([coeffs] (SpeakerEffect& effect) {
                        effect.set4HarmonicCoeffs(coeffs);
                    });
                }))},
            {SPEAKER_EFFECT_6_HARMONIC_COEFFS, 
                ParamSetter(std::function<void(float)>([this](float coeffs) { 
                    ESpeaker.update([coeffs] (SpeakerEffect& effect) {
                        effect.set6HarmonicCoeffs(coeffs);
                    });
                }))},
            {LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    ELookAheadSoftLimiter.update([enabled] (LookAheadSoftLimitEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
        };
    }

    ~AudioProcessor() {
        FFTWFPlan::saveWisdom();
    }

public:
    static AudioProcessor& getInstance() {
        static AudioProcessor instance;
        return instance;
    }

    static void init(std::string_view wisdom_path) {
        FFTWFPlan::initWisdom(wisdom_path);
    }

    // TODO: check out KFR/DSP
    void process(float *input, float *output, int length) noexcept {
        audio_stream.sample_length_per_frame = length;

        audio_stream << input;

        audio_stream >> ELimiter >> EGain >> EChannelBalance 
                     >> EEvenHarmonic >> EBass >> EClarity 
                     >> EConvolve >> ESpeaker
                     >> ELookAheadSoftLimiter >> output;
    }

    void setEffectParam(ParamID param, std::any value) {
        param_map[param](value);
    }
};
#endif