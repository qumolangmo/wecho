#include "effect.hpp"

DiffSurroundingEffect::DiffSurroundingEffect(bool enabled, int delay_ms) : Effect(enabled), delay_ms(delay_ms) {
    delay_line.setDelay(delay_ms / 1000.0f * SAMPLE_RATE);
    hp_800.setHighPass(250.0f);
    lp_800.setLowPass(250.0f);
}

DiffSurroundingEffect::~DiffSurroundingEffect() {
    delay_ms.store(0);
}

void DiffSurroundingEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        float hp_r = hp_800.process(audio[1][i]);
        float lp_r = lp_800.process(audio[1][i]);

        float delayed_r = delay_line.process(hp_r);

        audio[1][i] = delayed_r + lp_r;

    }
}

Priority DiffSurroundingEffect::priority() const {
    return Priority::DIFF_SURROUNDING_EFFECT;
}

void DiffSurroundingEffect::reset() {
    delay_line.reset();
}

void DiffSurroundingEffect::setDelayMs(int delay_ms) {
    this->delay_ms.store(delay_ms, std::memory_order_release);

    delay_line.setDelay(delay_ms / 1000.0f * SAMPLE_RATE);
}

void DiffSurroundingEffect::copyParamsFrom(const DiffSurroundingEffect& other) {
    reset();

    setDelayMs(other.delay_ms.load(std::memory_order_acquire));
    
    setEnabled(other.acquireReadEnabled());
}

