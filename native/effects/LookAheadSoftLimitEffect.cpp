#include "effect.hpp"

LookAheadSoftLimitEffect::LookAheadSoftLimitEffect(bool enabled)
    : Effect(enabled) {

    reset();
}

LookAheadSoftLimitEffect::~LookAheadSoftLimitEffect() {}

Priority LookAheadSoftLimitEffect::priority() const {
    return LOOK_AHEAD_SOFT_LIMIT_EFFECT;
}

void LookAheadSoftLimitEffect::reset() {
    software_limiter.reset();
}

void LookAheadSoftLimitEffect::copyParamsFrom(const LookAheadSoftLimitEffect& other) {
    this->enabled.store(other.enabled.load(std::memory_order_acquire), std::memory_order_release);
}

void LookAheadSoftLimitEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        auto [l, r] = software_limiter.process(audio[0][i], audio[1][i]);
        audio[0][i] = l;
        audio[1][i] = r;
    }
}