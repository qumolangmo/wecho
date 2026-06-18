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
    static constexpr int FRAME_SIZE_PER_CHANNEL = 512;
    static constexpr int SAMPLE_RATE = 48000;

    CrossFader<BassEffect> EBass;
    CrossFader<ClarityEffect> EClarity;
    GainEffect EGain;
    ChannelBalanceEffect EChannelBalance;
    CrossFader<EvenHarmonicEffect> EEvenHarmonic;
    LimiterEffect ELimiter;
    ConvolveEffect EConvolve;
    CrossFader<VirtualBassEffect> EVirtualBass;
    CrossFader<LookAheadSoftLimitEffect> ELookAheadSoftLimiter;
    CrossFader<LowCatEffect> ELowCat;
    CrossFader<IIREqualizerEffect> EIIREQualizer;
    CrossFader<ReverbEffect> EReverb;
    CrossFader<ScriptEffect> EScript;

    std::unordered_map<ParamID, ParamSetter> param_map;
    AudioStream audio_stream;

private:
    AudioProcessor()
        : audio_stream(FRAME_SIZE_PER_CHANNEL * 3)
        , EBass(50.0, false, 0, 1.48f, 60.0f)
        , EClarity(50.0, false, 0)
        , EGain(false, 0)
        , EChannelBalance(false, 0)
        , EEvenHarmonic(80.0, false, 0.0f, 0.0f, 0.0f)
        , EConvolve(false, 0.1f)
        , ELimiter(false)
        , ELookAheadSoftLimiter(100, false)
        , ELowCat(100, false, 120)
        , EIIREQualizer(30, false)
        , EVirtualBass(500, false)
        , EReverb(30, false)
        , EScript(30, false) {

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
                    EBass.update([enabled](BassEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {BASS_EFFECT_GAIN,
                ParamSetter(std::function<void(int)>([this](int gain) {
                    EBass.update([gain](BassEffect& effect) {
                        effect.setGain(gain);
                    });
                }))},
            {BASS_EFFECT_CENTER_FREQ,
                ParamSetter(std::function<void(int)>([this](int center_freq) {
                    EBass.update([center_freq](BassEffect& effect) {
                        effect.setCenterFreq(center_freq);
                    });
                }))},
            {BASS_EFFECT_Q,
                ParamSetter(std::function<void(float)>([this](float Q) {
                    EBass.update([Q](BassEffect& effect) {
                        effect.setQ(Q);
                    });
                }))},
            {CLARITY_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EClarity.update([enabled](ClarityEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {CLARITY_EFFECT_GAIN,
                ParamSetter(std::function<void(int)>([this](int gain) {
                    EClarity.update([gain](ClarityEffect& effect) {
                        effect.setGain(gain);
                    });
                }))},
            {EVEN_HARMONIC_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EEvenHarmonic.update([enabled](EvenHarmonicEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {EVEN_HARMONIC_EFFECT_BASE,
                ParamSetter(std::function<void(float)>([this](float base) {
                    EEvenHarmonic.update([base](EvenHarmonicEffect& effect) {
                        effect.setBase(base);
                    });
                }))},
            {EVEN_HARMONIC_EFFECT_WARM,
                ParamSetter(std::function<void(float)>([this](float warm) {
                    EEvenHarmonic.update([warm](EvenHarmonicEffect& effect) {
                        effect.setWarm(warm);
                    });
                }))},
            {EVEN_HARMONIC_EFFECT_SUGAR,
                ParamSetter(std::function<void(float)>([this](float sugar) {
                    EEvenHarmonic.update([sugar](EvenHarmonicEffect& effect) {
                        effect.setSugar(sugar);
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
                ParamSetter(std::function<void(std::vector<std::vector<float>>&)>([this](std::vector<std::vector<float>>& ir_data) {
                    EConvolve.setIr(ir_data);
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
            {LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    ELookAheadSoftLimiter.update([enabled](LookAheadSoftLimitEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {LOW_CAT_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    ELowCat.update([enabled](LowCatEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {LOW_CAT_EFFECT_CUTOFF_FREQ,
                ParamSetter(std::function<void(int)>([this](int cutoff_freq) {
                    ELowCat.update([cutoff_freq](LowCatEffect& effect) {
                        effect.setCutoffFreq(cutoff_freq);
                    });
                }))},
            {IIR_EQUALIZER_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EIIREQualizer.update([enabled](IIREqualizerEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {IIR_EQUALIZER_EFFECT_COEFFS,
                ParamSetter(std::function<void(IIREqualizerCoeffs)>([this](IIREqualizerCoeffs coeffs) {
                    EIIREQualizer.update([coeffs](IIREqualizerEffect& effect) {
                        effect.setCoeffs(coeffs);
                    });
                }))},
            {VIRTUALBASS_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EVirtualBass.update([enabled](VirtualBassEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {VIRTUALBASS_EFFECT_ENVELOPE_RATE,
                ParamSetter(std::function<void(int)>([this](int envelope_rate) {
                    EVirtualBass.update([envelope_rate](VirtualBassEffect& effect) {
                        effect.setEnvelopeRate(envelope_rate);
                    });
                }))},
            {REVERB_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EReverb.update([enabled](ReverbEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {REVERB_EFFECT_ROOM_SIZE,
                ParamSetter(std::function<void(float)>([this](float room_size) {
                    EReverb.update([room_size](ReverbEffect& effect) {
                        effect.setRoomSize(room_size);
                    });
                }))},
            {REVERB_EFFECT_DAMPING,
                ParamSetter(std::function<void(float)>([this](float damping) {
                    EReverb.update([damping](ReverbEffect& effect) {
                        effect.setDamping(damping);
                    });
                }))},
            {REVERB_EFFECT_WET_MIX,
                ParamSetter(std::function<void(float)>([this](float wet_mix) {
                    EReverb.update([wet_mix](ReverbEffect& effect) {
                        effect.setWetMix(wet_mix);
                    });
                }))},
            {REVERB_EFFECT_PRE_DELAY,
                ParamSetter(std::function<void(float)>([this](float pre_delay) {
                    EReverb.update([pre_delay](ReverbEffect& effect) {
                        effect.setPreDelay(pre_delay);
                    });
                }))},
            {SCRIPT_EFFECT_ENABLED,
                ParamSetter(std::function<void(bool)>([this](bool enabled) {
                    EScript.update([enabled](ScriptEffect& effect) {
                        effect.setEnabled(enabled);
                    });
                }))},
            {SCRIPT_EFFECT_CODE,
                ParamSetter(std::function<void(std::string)>([this](std::string code) {
                    EScript.update([code](ScriptEffect& effect) {
                        effect.setCode(code);
                    });
                }))},
            {SCRIPT_EFFECT_PARAMS,
                ParamSetter(std::function<void(ScriptParams*)>([this](ScriptParams* params) {
                    EScript.update([params](ScriptEffect& effect) {
                        effect.setParams(params);
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

    static void init(std::string_view files_dir) {
        // FFTWFPlan::initWisdom(std::string(files_dir) + "/fftw_wisdom");
        ScriptEffect::setCacheDir(files_dir);
    }

    // TODO: check out KFR/DSP
    void process(float *input, float *output, int length) noexcept {
        audio_stream.sample_length_per_frame = length;

        audio_stream << input;

        audio_stream >> ELimiter >> EChannelBalance 
                     >> EIIREQualizer >> EEvenHarmonic >> EBass >> EClarity 
                     >> EConvolve >> EVirtualBass >> EReverb >> EScript
                     >> ELookAheadSoftLimiter >> ELowCat >> EGain >> output;
    }

    void setEffectParam(ParamID param, std::any value) {
        param_map[param](value);
    }

    void reset() {
        EBass.reset();
        EClarity.reset();
        EGain.reset();
        EChannelBalance.reset();
        EEvenHarmonic.reset();
        EBass.reset();
        ELimiter.reset();
        EConvolve.reset();
        ELookAheadSoftLimiter.reset();
        ELowCat.reset();
        EVirtualBass.reset();
    }
};
#endif