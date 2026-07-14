#ifndef __OPERATOR_HPP__
#define __OPERATOR_HPP__
#include <vector>
#include <functional>
#include "utils.hpp"
#include "compressor.hpp"
#include "harmonic.hpp"
#include "filter.hpp"
#include "../effects/effect.hpp"

template<typename T>
concept Router = std::is_same_v<T, OperatorType::RouterType>;

template<typename T>
concept AtomicComponent = std::is_same_v<T, OperatorType::AtomicComponentType>;

template<typename T>
concept EffectType = std::is_same_v<T, OperatorType::EffectType>;


class OperatorRoot {
public:
    virtual ~OperatorRoot() = default;
    virtual int getId() const = 0;
    virtual const std::string& getName() const = 0;
};

template<typename... Args>
class OperatorBase : public OperatorRoot {
public:
    virtual void process(Args...) = 0;
};

template<auto Type, typename... Args>
requires Router<decltype(Type)>
class RouterOperator: public OperatorBase<Args...> {
private:
    static constexpr auto type = Type;
    int id;
    std::string name;
    std::function<void(Args...)> process_function;
    AudioBlock* audio;

public:
    int getId() const override { return id; }
    const std::string& getName() const override { return name; }
    void process(Args... args) override { process_function(std::forward<Args>(args)...); }

    RouterOperator(int id, std::string&& name): id(id), name(name) {
        using namespace OperatorType;

        if constexpr (type == Output) {
            process_function = [this] (AudioBlock& output) { output = (*audio); };
        } else if constexpr (type == Mixer) {
            process_function = [this] (std::vector<std::vector<float>>& input_l, std::vector<std::vector<float>>& input_r) {
                std::fill((*audio)[0].begin(), (*audio)[0].end(), 0);
                std::fill((*audio)[1].begin(), (*audio)[1].end(), 0);

                for (int i = 0; i < input_l.size(); i++) {
                    for (int j = 0; j < input_l[0].size(); j++) {
                        (*audio)[0][j] += input_l[i][j];
                        (*audio)[1][j] += input_r[i][j];
                    }
                }
            };
        } else if constexpr (type == Spliter) {
            process_function = [this] (std::vector<std::function<void(const AudioBlock&, AudioBlock*)>>& ops, std::vector<AudioBlock*> cache) {
                for (int i = 0; i < cache.size(); i++) {
                    ops[i]((*audio), cache[i]);
                }
            };
        }
    }
};

template<>
class RouterOperator<OperatorType::Input>: public OperatorBase<AudioBlock&&> {
private:
    static constexpr auto type = OperatorType::Input;
    int id;
    std::string name;
    std::function<void(AudioBlock&&)> process_function;
    AudioBlock audio;

public:
    int getId() const override { return id; }
    const std::string& getName() const override { return name; }
    void process(AudioBlock&& data) override { process_function(std::move(data)); }

    RouterOperator(int id, std::string&& name): id(id), name(name) {
        process_function = [this] (AudioBlock&& data) {
            audio = std::move(data);
        };
    }
};

template<typename T>
concept ImplProcess = requires(T* instance, float input) {
    {instance->process(input)};
};

template<auto Type, typename... Args>
requires AtomicComponent<decltype(Type)>
class AtomicComponentOperator: public OperatorBase<Args...> {
private:
    static constexpr auto type = Type;
    int id;
    std::string name;
    std::function<void(AudioBlock&)> process_function;
    std::function<void(Args...)> set_function;

    std::unique_ptr<Utils> data[2];

    template<ImplProcess T>
    void processStereo(AudioBlock& audio) {
        for (int i = 0; i < Utils::SAMPLES_PER_CHANNEL; i++) {
            audio[0][i] = static_cast<T*>(data[0].get())->process(audio[0][i]);
            audio[1][i] = static_cast<T*>(data[1].get())->process(audio[1][i]);
        }
    }

public:
    int getId() const override { return id; }
    std::string getName() const override { return name; }
    void process(AudioBlock& data) override { process_function(data); }
    void setParam(Args... args) override { set_function(std::forward<Args>(args)...); }

    AtomicComponentOperator(int id, std::string&& name): id(id), name(name), data{} {
        if constexpr (type == OperatorType::Biquad) {
            data[0] = std::make_unique<Biquad<1>>();
            data[1] = std::make_unique<Biquad<1>>();

            set_function = [this] (double a0, double a1, double a2, double b0, double b1, double b2) {
                static_cast<Biquad<1>*>(data[0].get())->reset();
                static_cast<Biquad<1>*>(data[1].get())->reset();
                static_cast<Biquad<1>*>(data[0].get())->setCoeffs({a0, a1, a2, b0, b1, b2});
                static_cast<Biquad<1>*>(data[1].get())->setCoeffs({a0, a1, a2, b0, b1, b2});
            };

            process_function = [this] (AudioBlock& audio) {
                processStereo<Biquad<1>>(audio);
            };

        } else if constexpr (type == OperatorType::DelayLine) {
            data[0] = std::make_unique<DelayLine<8192>>();
            data[1] = std::make_unique<DelayLine<8192>>();

            set_function = [this] (int delay_samples) {
                static_cast<DelayLine<8192>*>(data[0].get())->reset();
                static_cast<DelayLine<8192>*>(data[1].get())->reset();
                static_cast<DelayLine<8192>*>(data[0].get())->setDelay(delay_samples);
                static_cast<DelayLine<8192>*>(data[1].get())->setDelay(delay_samples);
            };

            
            process_function = [this] (AudioBlock& audio) {
                processStereo<DelayLine<8192>>(audio);
            };
        } else if constexpr (type == OperatorType::Harmonic) {
            data[0] = std::make_unique<Harmonic<4>>();
            data[1] = std::make_unique<Harmonic<4>>();
            
            set_function = [this] (float base, float order2, float order3, float order4) {
                static_cast<Harmonic<4>*>(data[0].get())->reset();
                static_cast<Harmonic<4>*>(data[1].get())->reset();
                static_cast<Harmonic<4>*>(data[0].get())->setCoeffs({base, order2, order3, order4});
                static_cast<Harmonic<4>*>(data[1].get())->setCoeffs({base, order2, order3, order4});
            };

            process_function = [this] (AudioBlock& audio) {
                processStereo<Harmonic<4>>(audio);
            };

        } else if constexpr (type == OperatorType::Compressor) {
            data[0] = std::make_unique<Compressor>();

            set_function = [this] (float threshold_db, float ratio, float makeup_gain_db, float release_ms, float attack_ms) {
                static_cast<Compressor*>(data[0].get())->reset();
                static_cast<Compressor*>(data[0].get())->setThreshold(threshold_db);
                static_cast<Compressor*>(data[0].get())->setRatio(ratio);
                static_cast<Compressor*>(data[0].get())->setMakeupGain(makeup_gain_db);
                static_cast<Compressor*>(data[0].get())->setRelease(release_ms);
                static_cast<Compressor*>(data[0].get())->setAttack(attack_ms);
            };

            process_function = [this] (AudioBlock& audio) {
                for (int i = 0; i < Utils::SAMPLES_PER_CHANNEL; i++) {
                    static_cast<Compressor*>(data[0].get())->process(audio[0][i], audio[1][i]);
                }
            };
        } else if constexpr (type == OperatorType::PeakFilter) {
            data[0] = std::make_unique<Biquad<1>>();
            data[1] = std::make_unique<Biquad<1>>();

            set_function = [this] (float freq, float Q, float gain) {
                static_cast<Biquad<1>*>(data[0].get())->reset();
                static_cast<Biquad<1>*>(data[1].get())->reset();
                static_cast<Biquad<1>*>(data[0].get())->setPeak({freq, Q, gain});
                static_cast<Biquad<1>*>(data[1].get())->setPeak({freq, Q, gain});
            };

            process_function = [this] (AudioBlock& audio) {
                processStereo<Biquad<1>>(audio);
            };
        } else if constexpr (type == OperatorType::AllPassFilter) {
            data[0] = std::make_unique<Biquad<1>>();
            data[1] = std::make_unique<Biquad<1>>();

            set_function = [this] (float freq, float Q) {
                static_cast<Biquad<1>*>(data[0].get())->reset();
                static_cast<Biquad<1>*>(data[1].get())->reset();
                static_cast<Biquad<1>*>(data[0].get())->setAllPass({freq, Q});
                static_cast<Biquad<1>*>(data[1].get())->setAllPass({freq, Q});
            };

            process_function = [this] (AudioBlock& audio) {
                processStereo<Biquad<1>>(audio);
            };
        } else if constexpr (type == OperatorType::HighShelf) {
            data[0] = std::make_unique<Biquad<1>>();
            data[1] = std::make_unique<Biquad<1>>();

            set_function = [this] (float freq, float Q, float gain) {
                static_cast<Biquad<1>*>(data[0].get())->reset();
                static_cast<Biquad<1>*>(data[1].get())->reset();
                static_cast<Biquad<1>*>(data[0].get())->setHighShelf({freq, Q, gain});
                static_cast<Biquad<1>*>(data[1].get())->setHighShelf({freq, Q, gain});
            };

            process_function = [this] (AudioBlock& audio) {
                processStereo<Biquad<1>>(audio);
            };
        } else if constexpr (type == OperatorType::LowShelf) {
            data[0] = std::make_unique<Biquad<1>>();
            data[1] = std::make_unique<Biquad<1>>();

            set_function = [this] (float freq, float Q, float gain) {
                static_cast<Biquad<1>*>(data[0].get())->reset();
                static_cast<Biquad<1>*>(data[1].get())->reset();
                static_cast<Biquad<1>*>(data[0].get())->setLowShelf({freq, Q, gain});
                static_cast<Biquad<1>*>(data[1].get())->setLowShelf({freq, Q, gain});
            };

            process_function = [this] (AudioBlock& audio) {
                processStereo<Biquad<1>>(audio);
            };
        } else if constexpr (type == OperatorType::HighPass) {
            data[0] = std::make_unique<Biquad<1>>();
            data[1] = std::make_unique<Biquad<1>>();

            set_function = [this] (float freq, float Q) {
                static_cast<Biquad<1>*>(data[0].get())->reset();
                static_cast<Biquad<1>*>(data[1].get())->reset();
                static_cast<Biquad<1>*>(data[0].get())->setHighPass({freq, Q});
                static_cast<Biquad<1>*>(data[1].get())->setHighPass({freq, Q});
            };

            process_function = [this] (AudioBlock& audio) {
                processStereo<Biquad<1>>(audio);
            };
        } else if constexpr (type == OperatorType::LowPass) {
            data[0] = std::make_unique<Biquad<1>>();
            data[1] = std::make_unique<Biquad<1>>();

            set_function = [this] (float freq, float Q) {
                static_cast<Biquad<1>*>(data[0].get())->reset();
                static_cast<Biquad<1>*>(data[1].get())->reset();
                static_cast<Biquad<1>*>(data[0].get())->setLowPass({freq, Q});
                static_cast<Biquad<1>*>(data[1].get())->setLowPass({freq, Q});
            };

            process_function = [this] (AudioBlock& audio) {
                processStereo<Biquad<1>>(audio);
            };
        }
    }
};

template<auto Type, typename... Args>
requires EffectType<decltype(Type)>
class EffectOperator: public OperatorBase<Args...> {
private:
    static constexpr auto type = Type;
    int id;
    std::string name;
    std::function<void(AudioBlock&)> process_function;
    std::function<void(Args...)> set_function;

    std::unique_ptr<Effect> data;

public:
    int getId() const override { return id; }
    std::string getName() const override { return name; }
    void process(AudioBlock& data) override { process_function(data); }
    void setParam(Args... args) override { set_function(std::forward<Args>(args)...); }

    EffectOperator(int id, std::string name): id(id), name(name), data(nullptr) {
        using namespace OperatorType;

        if constexpr (type == Gain) {
            data = std::make_unique<GainEffect>();

            set_function = [this] (float gain) {
                static_cast<GainEffect*>(data.get())->reset();
                static_cast<GainEffect*>(data.get())->setGain(gain);
            };

            process_function = [this] (AudioBlock& audio) {
                static_cast<GainEffect*>(data.get())->run(audio);
            };
        } else if constexpr (type == ChannelBalance) {
            data = std::make_unique<ChannelBalanceEffect>();

            set_function = [this] (float balance) {
                static_cast<ChannelBalanceEffect*>(data.get())->reset();
                static_cast<ChannelBalanceEffect*>(data.get())->setBalance(balance);
            };

            process_function = [this] (AudioBlock& audio) {
                static_cast<ChannelBalanceEffect*>(data.get())->run(audio);
            };
        } else if constexpr (type == VirtualBass) {
            data = std::make_unique<VirtualBassEffect>();

            set_function = [this] (float envelope_rate, float mid_gain, float high_gain, float harmonic_gain) {
                static_cast<VirtualBassEffect*>(data.get())->reset();
                static_cast<VirtualBassEffect*>(data.get())->setEnvelopeRate(envelope_rate);
                static_cast<VirtualBassEffect*>(data.get())->setMidGain(mid_gain);
                static_cast<VirtualBassEffect*>(data.get())->setHighGain(high_gain);
                static_cast<VirtualBassEffect*>(data.get())->setHarmonicGain(harmonic_gain);
            };

            process_function = [this] (AudioBlock& audio) {
                static_cast<VirtualBassEffect*>(data.get())->run(audio);
            };
        } else if constexpr (type == Bass) {
            data = std::make_unique<BassEffect>();

            set_function = [this] (float gain, float Q, float center_freq) {
                static_cast<BassEffect*>(data.get())->reset();
                static_cast<BassEffect*>(data.get())->setGain(gain);
                static_cast<BassEffect*>(data.get())->setQ(Q);
                static_cast<BassEffect*>(data.get())->setCenterFreq(center_freq);
            };

            process_function = [this] (AudioBlock& audio) {
                static_cast<BassEffect*>(data.get())->run(audio);
            };
        } else if constexpr (type == Clarity) {
            data = std::make_unique<ClarityEffect>();

            set_function = [this] (float gain) {
                static_cast<ClarityEffect*>(data.get())->reset();
                static_cast<ClarityEffect*>(data.get())->setGain(gain);
            };

            process_function = [this] (AudioBlock& audio) {
                static_cast<ClarityEffect*>(data.get())->run(audio);
            };
        } else if constexpr (type == Reverb) {
            data = std::make_unique<ReverbEffect>();

            set_function = [this] (float room_size, float damping, float mix, float stereo_width,
                float mod_depth, float mod_freq, float pre_delay_ms, float matrix_type) {

                static_cast<ReverbEffect*>(data.get())->reset();
                static_cast<ReverbEffect*>(data.get())->setRoomSize(room_size);
                static_cast<ReverbEffect*>(data.get())->setDamping(damping);
                static_cast<ReverbEffect*>(data.get())->setMix(mix);
                static_cast<ReverbEffect*>(data.get())->setStereoWidth(stereo_width);
                static_cast<ReverbEffect*>(data.get())->setModDepth(mod_depth);
                static_cast<ReverbEffect*>(data.get())->setModFreq(mod_freq);
                static_cast<ReverbEffect*>(data.get())->setPreDelay(pre_delay_ms);
                static_cast<ReverbEffect*>(data.get())->setMatrixType(matrix_type);
            };

            process_function = [this] (AudioBlock& audio) {
                static_cast<ReverbEffect*>(data.get())->run(audio);
            };
        }
    }
};

class OperatorFactory {
public:
    template<auto Type, typename... Args>
    static std::unique_ptr<OperatorRoot> createOperator(int id, std::string name) {
        if constexpr (Router<decltype(Type)>) {
            return std::make_unique<RouterOperator<Type, Args...>>(id, std::move(name));
        } else if constexpr (AtomicComponent<decltype(Type)>) {
            return std::make_unique<AtomicComponentOperator<Type, Args...>>(id, std::move(name));
        } else if constexpr (EffectType<decltype(Type)>) {
            return std::make_unique<EffectOperator<Type, Args...>>(id, std::move(name));
        } else {
            static_assert(sizeof(Type) == 0, "Unknown Operator instance");
        }
    }
};

#endif