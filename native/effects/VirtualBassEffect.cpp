#include "effect.hpp"

VirtualBassEffect::VirtualBassEffect(bool enabled) 
    : Effect(enabled)
    , lp_soft_l(0.0f)
    , lp_soft_r(0.0f)
    , envelope_l(0.0f)
    , envelope_r(0.0f)
    , har_envelope_l(0.0f)
    , har_envelope_r(0.0f) {
    
    envelope_rate.store(50.0f, std::memory_order_release);
    mid_gain.store(0.08f, std::memory_order_release);
    high_gain.store(0.16f, std::memory_order_release);
    harmonic_gain.store(1.00f, std::memory_order_release);

    envelope_alpha = 2.0f * M_PI * 25.0f / SAMPLE_RATE;
    lp_soft_alpha = 2.0f * M_PI * 50.0f / SAMPLE_RATE;

    post_gain = std::pow(10.0f, 12.0f / 20.0f);

    for (auto& filter: band_80_150) {
        filter.setBandPass(80, 150);
    }

    for (auto& filter: band_120_600) {
        filter.setBandPass(120, 600);
    }

    for (auto& filter: high_600) {
        filter.setHighPass(600);
    }

    for (auto& inner_harmonic: harmonic) {
        inner_harmonic.setCoeffs({0, 0.13f, 0.13f});
    }

    for (auto& filter: high_120) {
        filter.setHighPass(120);
    }

    reset();
}

VirtualBassEffect::~VirtualBassEffect() {}

void VirtualBassEffect::reset() {

    for (auto& filter: high_120) {
        filter.reset();
    }

    for (auto& filter: harmonic) {
        filter.reset();
    }

    for (auto& filter: band_80_150) {
        filter.reset();
    }

    for (auto& filter: band_120_600) {
        filter.reset();
    }

    for (auto& filter: high_600) {
        filter.reset();
    }


    lp_soft_l = 0.0f;
    lp_soft_r = 0.0f;

    envelope_l = 0.0f;
    envelope_r = 0.0f;
    har_envelope_l = 0.0f;
    har_envelope_r = 0.0f;

}

void VirtualBassEffect::setEnvelopeRate(float envelope_rate) {
    this->envelope_rate.store(envelope_rate, std::memory_order_release);
    lp_soft_alpha = 2.0f * M_PI * envelope_rate / SAMPLE_RATE;
    reset();
}

void VirtualBassEffect::setMidGain(float mid_gain) {
    this->mid_gain.store(mid_gain, std::memory_order_release);
    reset();
}

void VirtualBassEffect::setHighGain(float high_gain) {
    this->high_gain.store(high_gain, std::memory_order_release);
    reset();
}

void VirtualBassEffect::setHarmonicGain(float harmonic_gain) {
    this->harmonic_gain.store(harmonic_gain, std::memory_order_release);
    reset();
}



void VirtualBassEffect::run(std::vector<std::vector<float>>& audio) {
    float lp_soft_alpha = this->lp_soft_alpha;
    float mid_gain = this->mid_gain.load(std::memory_order_acquire);
    float high_gain = this->high_gain.load(std::memory_order_acquire);
    float harmonic_gain = this->harmonic_gain.load(std::memory_order_acquire);

    for (int i = 0; i < audio[0].size(); i++) {
        float hp_l = audio[0][i];
        float hp_r = audio[1][i];
        float bp_l = audio[0][i];
        float bp_r = audio[1][i];
        float lp_l = audio[0][i];
        float lp_r = audio[1][i];

        lp_l = band_80_150[0].process(lp_l);
        lp_r = band_80_150[1].process(lp_r);

        bp_l = band_120_600[0].process(bp_l);
        bp_r = band_120_600[1].process(bp_r);

        hp_l = high_600[0].process(hp_l);
        hp_r = high_600[1].process(hp_r);

        lp_soft_l += lp_soft_alpha * (lp_l - lp_soft_l);
        lp_soft_r += lp_soft_alpha * (lp_r - lp_soft_r);
        lp_l = lp_soft_l;
        lp_r = lp_soft_r;

        float y_comp_hp_l = harmonic[0].process(lp_l);
        float y_comp_hp_r = harmonic[1].process(lp_r);
        y_comp_hp_l = high_120[0].process(y_comp_hp_l);
        y_comp_hp_r = high_120[1].process(y_comp_hp_r);

        float abs_lp_l = std::abs(lp_l);
        float abs_lp_r = std::abs(lp_r);
        envelope_l += envelope_alpha * (abs_lp_l - envelope_l);
        envelope_r += envelope_alpha * (abs_lp_r - envelope_r);
        
        float abs_har_l = std::abs(y_comp_hp_l);
        float abs_har_r = std::abs(y_comp_hp_r);
        har_envelope_l += envelope_alpha * (abs_har_l - har_envelope_l);
        har_envelope_r += envelope_alpha * (abs_har_r - har_envelope_r);
        
        float mod_gain_l = envelope_l / (har_envelope_l + 1e-8f);
        float mod_gain_r = envelope_r / (har_envelope_r + 1e-8f);
        mod_gain_l = std::clamp(mod_gain_l, 0.2f, 5.0f);
        mod_gain_r = std::clamp(mod_gain_r, 0.2f, 5.0f);

        y_comp_hp_l = y_comp_hp_l * mod_gain_l;
        y_comp_hp_r = y_comp_hp_r * mod_gain_r;

        float out_l = mid_gain * 0.25 * bp_l + high_gain * 0.25 * hp_l + 2.4f * y_comp_hp_l * harmonic_gain;
        float out_r = mid_gain * 0.25 * bp_r + high_gain * 0.25 * hp_r + 2.4f * y_comp_hp_r * harmonic_gain;

        audio[0][i] = out_l * post_gain;
        audio[1][i] = out_r * post_gain;
    }
}

void VirtualBassEffect::copyParamsFrom(const VirtualBassEffect& other) {
    this->setEnvelopeRate(other.envelope_rate);
    this->setMidGain(other.mid_gain);
    this->setHighGain(other.high_gain);
    this->setHarmonicGain(other.harmonic_gain);

    this->reset();
    this->setEnabled(other.isEnabled());
}

Priority VirtualBassEffect::priority() const {
    return Priority::VIRTUALBASS_EFFECT;
}


