#ifndef __VB_PHASE_VOCODER_H__
#define __VB_PHASE_VOCODER_H__

#include "convolver.hpp"
#include "VMD.hpp"
#include "pitchPicker.hpp"
#include "debug.hpp"

#ifndef M_PI
#define M_PI 3.141592653589793
#endif

class VBPhaseVocoder {
private:
    static constexpr int fs = 4096;
    static constexpr int fft_size = 512;
    static constexpr int harmonic_cutoff = 600;
    static constexpr int min_freq = 30;
    static constexpr int hop_size = fft_size / 4;
    static constexpr int half_fft = fft_size / 2;
    static constexpr int input_48000_size = fft_size * (48000.0f / fs) + 1;
    float cutoff;

    int frame_count = 0;
    int input_48000_count = 0;

    std::vector<float> window;
    std::vector<float> input_buffer;
    std::vector<float> output_buffer;
    std::vector<float> overlap_buf;
    std::vector<float> prev_phase;
    std::vector<float> freq_bins;
    std::vector<float> cur_mags;

    std::vector<float> alphas;
    std::vector<float> gains;
    std::vector<float> harmonic_gain_curve;

    std::vector<float> resample_audio;
    std::vector<float> input_48000_buffer;

    FFTWFComplexArray fft_in, fft_out, shifted_fft, ifft_out;
    FFTWFPlan forward_plan, backward_plan;

    VMD vmd;
    PitchPicker pitch_picker;

public:
    VBPhaseVocoder(float cutoff = 150)
        : cutoff(cutoff)
        , fft_in(fft_size)
        , fft_out(fft_size)
        , shifted_fft(fft_size)
        , ifft_out(fft_size)
        , forward_plan(fft_size, FFTW_FORWARD, fft_in, fft_out, FFTW_ESTIMATE)
        , backward_plan(fft_size, FFTW_BACKWARD, fft_in, fft_out, FFTW_ESTIMATE) {

        window.resize(fft_size);
        for (int i = 0; i < fft_size; i++) {
            window[i] = tukey(i, fft_size);
        }

        input_buffer.resize(fft_size, 0);
        output_buffer.resize(fft_size, 0);
        prev_phase.resize(half_fft + 1, 0);
        overlap_buf.resize(fft_size, 0);
        cur_mags.resize(half_fft + 1, 0);

        freq_bins.resize(half_fft + 1);
        for (int i = 0; i <= half_fft; i++) {
            freq_bins[i] = static_cast<float>(i) * fs / fft_size;
        }

        alphas = {2.0f, 4.0f};
        gains = {1.1f, 3.f};

        harmonic_gain_curve.resize(half_fft + 1, 0);
        for (int i = 0; i <= half_fft; i++) {
            float freq = freq_bins[i];
            if (freq < min_freq || freq > cutoff) {
                harmonic_gain_curve[i] = 0.0f;
            } else {
                harmonic_gain_curve[i] = 1.0f - (freq - min_freq) / (cutoff - min_freq) * 0.3f;
            }
        }

        input_48000_buffer.resize(input_48000_size, 0);
    }

    float process(float sample) {
        input_48000_buffer[input_48000_count] = sample;
        input_48000_count++;
        if (input_48000_count >= input_48000_size) {
            input_48000_count = 0;
            downSample(input_48000_buffer, fft_size);

            auto& modes = vmd.process(resample_audio);
            std::vector<float> steady_audio = modes[0];

            input_buffer = std::move(steady_audio);
        }

        frame_count++;
        if (frame_count >= hop_size) {
            stftAndHarmonicGenerate();
            frame_count = 0;
        }

        float out = overlap_buf[0];
        std::rotate(overlap_buf.begin(), overlap_buf.begin() + 1, overlap_buf.end());
        overlap_buf.back() = 0.0f;

        return out;
    }

    void reset() {
        input_buffer.assign(input_buffer.size(), 0);
        output_buffer.assign(output_buffer.size(), 0);
        prev_phase.assign(prev_phase.size(), 0);
        overlap_buf.assign(overlap_buf.size(), 0);
        frame_count = 0;
        input_48000_count = 0;
        input_48000_buffer.assign(input_48000_buffer.size(), 0);
        vmd.reset();
    }

private:
    void stftAndHarmonicGenerate() {

        fft_in.init(0);

        for (int n = 0; n < fft_size; n++) {
            fft_in[n][0] = input_buffer[n] * window[n];
            fft_in[n][1] = 0.0f;
        }

        forward_plan.execute(fft_in, fft_out);

        shifted_fft.init(0);
        for (int k = 0; k <= half_fft; k++) {
            cur_mags[k] = std::sqrt(fft_out[k][0] * fft_out[k][0] + fft_out[k][1] * fft_out[k][1]);
        }

        const auto& maybe_pitchs = pitch_picker.hps(cur_mags, freq_bins, min_freq, cutoff);
        const auto& realy_pitchs = pitch_picker.swipe(cur_mags, maybe_pitchs);

        int idx = 0;
        for (int k = 0; k <= half_fft; k++) {
            float f = freq_bins[k];

            float re = fft_out[k][0];
            float im = fft_out[k][1];
            float mag = std::sqrt(re * re + im * im);

            float curr_phase = std::atan2(im, re);
            float delta_phase = curr_phase - prev_phase[k] - 2 * M_PI * k * hop_size / fft_size;
            delta_phase = fmodf(delta_phase + M_PI, 2 * M_PI) - M_PI;
            prev_phase[k] = curr_phase;

            if (f > cutoff || f <= min_freq) {
                continue;
            }

            if (idx < realy_pitchs.size() && std::abs(realy_pitchs[idx].freq - f) < 0.0001f) {
                idx++;
            } else {
                continue;
            }

            mag *= harmonic_gain_curve[k];

            for (int i = 0; i < alphas.size(); i++) {
                float alpha = alphas[i];
                float gain = gains[i] * 4.0f;

                float exact_harm_k = alpha * k;
                int harm_k_int = (int)exact_harm_k;
                float harm_k_frac = exact_harm_k - harm_k_int;

                if (harm_k_int < 0 || harm_k_int >= half_fft || freq_bins[harm_k_int] > harmonic_cutoff) {
                    continue;
                }

                auto [cos_theta, sin_theta] = fractionDelayFactor(harm_k_int, harm_k_frac);

                float harm_phase = prev_phase[k] * alpha + delta_phase * alpha;
                harm_phase = fmodf(harm_phase + M_PI, 2 * M_PI) - M_PI;

                float final_cos = std::cos(harm_phase) * cos_theta - std::sin(harm_phase) * sin_theta;
                float final_sin = std::sin(harm_phase) * cos_theta + std::cos(harm_phase) * sin_theta;

                shifted_fft[harm_k_int][0] += mag * gain * final_cos;
                shifted_fft[harm_k_int][1] += mag * gain * final_sin;

                if (harm_k_int + 1 < half_fft) {
                    float interp_gain = harm_k_frac;
                    shifted_fft[harm_k_int + 1][0] += mag * gain * final_cos * interp_gain;
                    shifted_fft[harm_k_int + 1][1] += mag * gain * final_sin * interp_gain;
                }
            }
        }

        for (int k = 1; k < half_fft; k++) {
            shifted_fft[fft_size - k][0] = shifted_fft[k][0];
            shifted_fft[fft_size - k][1] = -shifted_fft[k][1];
        }

        backward_plan.execute(shifted_fft, ifft_out);

        for (int n = 0; n < fft_size; n++) {
            output_buffer[n] = ifft_out[n][0] * 0.666666f / fft_size;
        }

        for (int i = 0; i < fft_size; i++) {
            overlap_buf[i] += output_buffer[i];
        }
    }

    float sinc(float x) {
        if (x == 0) {
            return 1.0f;
        } else {
            return std::sin(x * M_PI) / (x * M_PI);
        }
    }

    void downSample(const std::vector<float>& audio, int resample_length) {
        resample_audio.resize(resample_length);

        float factor = static_cast<float>(audio.size()) / resample_length;
        float position, interval;
        float sum_sinc = 0.0f;
        int left;

        for (int i = 0; i < resample_length; i++) {
            position = i * factor;
            left = static_cast<int>(position);
            resample_audio[i] = 0;
            sum_sinc = 0.f;

            for (int j = -4; j <= 4; j++) {
                int index = left + j;
                if (index >=0 && index < audio.size()) {
                    float s = sinc(position - index);
                    resample_audio[i] += audio[index] * s;
                    sum_sinc += s;
                }
            }

            resample_audio[i] /= sum_sinc;
        }
    }

    std::pair<float, float> fractionDelayFactor(int k, float frac) {
        float theta = -2 * M_PI * (k + frac) * hop_size / fft_size;
        return {std::cos(theta), std::sin(theta)};
    }

    float tukey(int n, int N, float alpha = 0.3f) {
        if (n < 0 || n >= N) {
            return 0.f;
        }

        float x = (float)n / (N - 1);
        float half = alpha / 2.0f;

        if (x < half) {
            float t = x / half;
            return 0.5f * (1.0f - std::cos(M_PI * t));
        } else if (x > 1 - half) {
            float t = (x - (1.0f - half)) / half;
            return 0.5f * (1.0f - std::cos(M_PI * t));
        } else {
            return 1.0f;
        }
    }
};
#endif