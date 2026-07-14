#include "effect.hpp"

AudioGraphicEffect::AudioGraphicEffect(bool enabled): Effect(enabled) {}

AudioGraphicEffect::~AudioGraphicEffect() {}

void AudioGraphicEffect::run(std::vector<std::vector<float>>& audio) {

}

Priority AudioGraphicEffect::priority() const {

}

void AudioGraphicEffect::reset() {

}

void AudioGraphicEffect::setGraphic(std::string graphic) {

}

void AudioGraphicEffect::copyParamsFrom(const AudioGraphicEffect& other) {

}