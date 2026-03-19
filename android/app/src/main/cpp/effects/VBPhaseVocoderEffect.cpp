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

    band_150_500[0].resize(2);
    band_150_500[1].resize(2);

    for (auto& band: band_150_500) {
        for (auto& b: band) {
            b.setBandPass(150, 500, 0.7071, 44100);
        }
    }

    high_150[0].resize(2);
    high_150[1].resize(2);

    for (auto& high: high_150) {
        for (auto& h: high) {
            h.setHighPass(150, 0.7071, 44100);
        }
    }

    low_150[0].resize(2);
    low_150[1].resize(2);

    for (auto& low: low_150) {
        for (auto& l: low) {
            l.setLowPass(150, 0.7071, 44100);
        }
    }

    low_2048[0].resize(3);
    low_2048[1].resize(3);

    for (auto& low: low_2048) {
        for (auto& l: low) {
            l.setLowPass(2048, 0.7071, 44100);
        }
    }

    delay[0].setDelay(5513);
    delay[1].setDelay(5513);
}

VBPhaseVocoderEffect::~VBPhaseVocoderEffect() {}

Priority VBPhaseVocoderEffect::priority() const {
    return Priority::MAX_PRIORITY;
}

void VBPhaseVocoderEffect::reset() {
    vb_phase_vcoder[0].reset();
    vb_phase_vcoder[1].reset();

    for (auto& band: band_150_500) {
        for (auto& b: band) {
            b.reset();
        }
    }

    for (auto& high: high_150) {
        for (auto& h: high) {
            h.reset();
        }
    }

    for (auto& low: low_150) {
        for (auto& l: low) {
            l.reset();
        }
    }
}

void VBPhaseVocoderEffect::run(std::vector<std::vector<float>>& audio) {
    for (int i = 0; i < audio[0].size(); i++) {
        float hp_l = audio[0][i];
        float hp_r = audio[1][i];
        float lp_l = audio[0][i];
        float lp_r = audio[1][i];

        for (int j = 0; j < high_150[0].size(); j++) {
            hp_l = high_150[0][j].process(hp_l);
            hp_r = high_150[1][j].process(hp_r);
        }
        hp_l = delay[0].process(hp_l);
        hp_r = delay[1].process(hp_r);

        for (int j = 0; j < low_2048[0].size(); j++) {
            lp_l = low_2048[0][j].process(lp_l);
            lp_r = low_2048[1][j].process(lp_r);
        }

        for (int j = 0; j < low_150[0].size(); j++) {
            lp_l = low_150[0][j].process(lp_l);
            lp_r = low_150[1][j].process(lp_r);
        }

        float harmonic_l = vb_phase_vcoder[0].process(lp_l);
        float harmonic_r = vb_phase_vcoder[1].process(lp_r);
        
        audio[0][i] = hp_l * 0.1 + harmonic_l * 4;
        audio[1][i] = hp_r * 0.1 + harmonic_r * 4;
    }
}

void VBPhaseVocoderEffect::copyParamsFrom(const VBPhaseVocoderEffect& other) {
    this->setEnabled(other.isEnabled());
}