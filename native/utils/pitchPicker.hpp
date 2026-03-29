#ifndef __VB_PHASE_VOCODER_HPP__
#define __VB_PHASE_VOCODER_HPP__

#include <algorithm>
#include <vector>
#include <queue>
#include "convolver.hpp"
#include "filter.hpp"

class PitchPicker {
private:
    static constexpr int fs = 4096;

    static int hps_candidate;
    static int swipe_candidate;
    static int max_harmonic;
    static float cutoff;
    static float min_freq;
    static int fft_size;
    static int half_fft;
    static float fb;

    struct HPSResult {
        float freq;
        float hps_value;
        float bin;

        bool operator<(const HPSResult& other) const {
            return hps_value < other.hps_value;
        }
    };

    struct SwipeResult {
        float freq;
        float score;
        float bin;
        float harmonic_match;
    };

    struct FreqResult {
        float freq;
        float harmonic2;
        float harmonic4;
    };

public:
    static void setHPSMaxOutput(int max_output) {
        PitchPicker::hps_candidate = max_output;
    }

    static void setHPSMaxAnalysisHarmonic(int max_harmonic) {
        PitchPicker::max_harmonic = max_harmonic;
    }

    static void setSwipeMaxOutput(int max_output) {
        PitchPicker::swipe_candidate = max_output;
    }

    static void setSwipeMaxAnalysisHarmonic(int max_harmonic) {
        PitchPicker::max_harmonic = max_harmonic;
    }

    static auto hps(const std::vector<float>& cur_mags, const std::vector<float>& freq_bins, int min_k, int max_k) -> std::vector<HPSResult> {
        std::priority_queue<HPSResult> hps_queue;
        for (int k = min_k; k <= max_k; k++) {
            float multi_energy = 0.0f;

            for (int n = 1; n <= max_harmonic; n++) {
                int harmonic_bin = k * n;
                if (harmonic_bin > half_fft) {
                    break;
                }
                multi_energy += std::log(cur_mags[harmonic_bin] + 1e-6f);
            }
            hps_queue.push({freq_bins[k], multi_energy, (float)k});
        }

        std::vector<HPSResult> hps_results;
        static int count = 0;
        
        hps_results.reserve(hps_candidate);
        for (int i = 0; i < hps_candidate && !hps_queue.empty(); i++) {
            hps_results.push_back(hps_queue.top());
            hps_queue.pop();
        }

        return hps_results;
    };

    static auto swipe(const std::vector<float>& mags, const std::vector<HPSResult>& hps_results) -> std::vector<SwipeResult> {
        std::vector<SwipeResult> result;
        result.reserve(swipe_candidate);

        for (const auto& hps : hps_results) {
            float freq = hps.freq;
            int center_bin = hps.bin;

            float search_range = freq * 0.1f;
            float start_freq = std::max(min_freq, freq - search_range);
            float end_freq = std::min(cutoff, freq + search_range);

            float best_combined_score = 0.0f;
            float best_score = 0.0f;
            float best_freq = freq;
            float best_bin = center_bin;
            float best_harmonic_match = 0.0f;

            float start_bin = start_freq / fb;
            float end_bin = end_freq / fb;
            float step = 0.2f;

            for (float bin = start_bin; bin <= end_bin; bin += step) {
                float curr_freq = bin * fb;
                float score = computeSwipeScore(mags, curr_freq, bin);

                float harmonic_match = computeHarmonicMatch(mags, curr_freq, bin);

                float combined_score = score * harmonic_match;

                if (combined_score > best_combined_score) {
                    best_combined_score = combined_score;
                    best_freq = curr_freq;
                    best_bin = bin;
                    best_harmonic_match = harmonic_match;
                }
            }

            if (best_combined_score > 0.3f) {
                result.push_back({best_freq, best_combined_score, best_bin, best_harmonic_match});
            }
        }

        std::sort(result.begin(), result.end(), [](const SwipeResult& a, const SwipeResult& b) {
            return a.score > b.score;
        });

        if (result.size() > swipe_candidate) {
            result.resize(swipe_candidate);
        }

        return result;
    }

    static float computeSwipeScore(const std::vector<float>& mags, float freq, float center_bin) {
        float score = 0.0f;

        for (int h = 1; h <= max_harmonic; h++) {
            float harmonic_bin = center_bin * h;

            if (harmonic_bin >= half_fft - 1) {
                break;
            }

            float peak_mag = parabolicInterpolation(mags, harmonic_bin);

            float valley_left_bin = ((float)h - 0.5f) * center_bin;
            float valley_right_bin = ((float)h + 0.5f) * center_bin;
            float left_mag = parabolicInterpolation(mags, valley_left_bin);
            float right_mag = parabolicInterpolation(mags, valley_right_bin);

            float pvd = peak_mag / (left_mag + right_mag + 1e-6f);
            float weight = 1.0f / h;

            float alignment = 1.0f;

            if (h > 1) {
                float exact_bin = harmonic_bin;
                float frac_part = exact_bin - std::floor(exact_bin);

                alignment = 1.0f - 2.0f * std::min(frac_part, 1.0f - frac_part);
            }

            score += pvd * weight * alignment;
        }

        return score;
    }

    static float computeHarmonicMatch(const std::vector<float>& mags, float freq, float center_bin) {
        float match = 0.0f;
        int count = 0;

        for (int h = 1; h <= max_harmonic; h++) {
            float harmonic_bin = center_bin * h;
            if (harmonic_bin >= half_fft) {
                break;
            }

            int int_bin = std::lround(harmonic_bin);

            bool is_peak = false;
            if (int_bin > 0 && int_bin < half_fft - 1) {
                if (mags[int_bin] >= mags[int_bin - 1] && mags[int_bin] >= mags[int_bin + 1]) {
                    is_peak = true;
                } else {
                    is_peak = false;
                }
            }

            if (is_peak) {
                match += 1.0 / h;
                count++;
            }
        }

        return count > 0 ? match / count : 0.0f;
    }

    static float parabolicInterpolation(const std::vector<float>& mags, float bin) {
        int i = std::lround(bin);

        if (i < 1 || i >= half_fft - 2) {
            i = std::clamp(i, 0, half_fft - 1);
            return mags[i];
        }

        float frac = bin - i;
        float a0 = mags[i - 1], a1 = mags[i], a2 = mags[i + 1];
        return a1 + 0.5f * frac * (a2 - a0 + frac * (a0 - 2 * a1 + a2));
    }
};

#endif