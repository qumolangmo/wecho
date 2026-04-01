#include "effect.hpp"
#include "../utils/vbPhaseVocoder.hpp"

int PitchPicker::hps_candidate = 5;
int PitchPicker::swipe_candidate = 5;
int PitchPicker::max_harmonic = 5;
float PitchPicker::cutoff = 150.f;
float PitchPicker::min_freq = 30.0f;
int PitchPicker::fft_size = 512;
int PitchPicker::half_fft = fft_size / 2;
float PitchPicker::fb = (float)fs / fft_size;

VBPhaseVocoderEffect::VBPhaseVocoderEffect(bool enabled)
    : Effect(enabled)
    , vb_phase_vcoder() {

    band_150_500[0].setBandPass(150, 500);
    band_150_500[1].setBandPass(150, 500);

    high_150[0].setHighPass(150);
    high_150[1].setHighPass(150);

    low_150[0].setLowPass(150);
    low_150[1].setLowPass(150);

    low_2048[0].setLowPass(2048);
    low_2048[1].setLowPass(2048);

    delay[0].setDelay(5513);
    delay[1].setDelay(5513);

    reset();
}

VBPhaseVocoderEffect::~VBPhaseVocoderEffect() {}

Priority VBPhaseVocoderEffect::priority() const {
    return Priority::MAX_PRIORITY_EFFECT;
}

void VBPhaseVocoderEffect::reset() {
    vb_phase_vcoder[0].reset();
    vb_phase_vcoder[1].reset();

    for (auto& band: band_150_500) {
        band.reset();
    }

    for (auto& high: high_150) {
        high.reset();
    }

    for (auto& low: low_150) {
        low.reset();
    }
}

void VBPhaseVocoderEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        float hp_l = audio[0][i];
        float hp_r = audio[1][i];
        float lp_l = audio[0][i];
        float lp_r = audio[1][i];

        hp_l = high_150[0].process(hp_l);
        hp_r = high_150[1].process(hp_r);
        
        hp_l = delay[0].process(hp_l);
        hp_r = delay[1].process(hp_r);

        lp_l = low_2048[0].process(lp_l);
        lp_r = low_2048[1].process(lp_r);

        lp_l = low_150[0].process(lp_l);
        lp_r = low_150[1].process(lp_r);

        float harmonic_l = vb_phase_vcoder[0].process(lp_l);
        float harmonic_r = vb_phase_vcoder[1].process(lp_r);
        
        audio[0][i] = hp_l * 0.1 + harmonic_l * 4;
        audio[1][i] = hp_r * 0.1 + harmonic_r * 4;
    }
}

void VBPhaseVocoderEffect::copyParamsFrom(const VBPhaseVocoderEffect& other) {
    this->setEnabled(other.isEnabled());
}