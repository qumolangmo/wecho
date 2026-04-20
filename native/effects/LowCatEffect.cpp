#include "effect.hpp"

LowCatEffect::LowCatEffect(bool enabled, int cutoff_freq)
    : Effect(enabled), cutoff_freq(cutoff_freq) {

    high_120[0].setHighPass(cutoff_freq);
    high_120[1].setHighPass(cutoff_freq);

    reset();
}

void LowCatEffect::reset() {
    high_120[0].reset();
    high_120[1].reset();
}

void LowCatEffect::setCutoffFreq(int freq) {
    cutoff_freq.store(freq, std::memory_order_release);
    high_120[0].setHighPass(cutoff_freq);
    high_120[1].setHighPass(cutoff_freq);

    reset();
}

LowCatEffect::~LowCatEffect() {}

void LowCatEffect::copyParamsFrom(const LowCatEffect& other) {
    setCutoffFreq(other.cutoff_freq.load(std::memory_order_acquire));
    this->enabled.store(other.isEnabled(), std::memory_order_release);
}

Priority LowCatEffect::priority() const {
    return Priority::LOW_CAT_EFFECT;
}

void LowCatEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        audio[0][i] = high_120[0].process(audio[0][i]);
        audio[1][i] = high_120[1].process(audio[1][i]);
    }
}

