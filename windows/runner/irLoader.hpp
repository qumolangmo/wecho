#pragma once

#include <string>
#include <vector>
#include <cmath>
#include <algorithm>
#include "../../native/utils/AudioFile.hpp"

namespace wecho {

class IrLoader {
public:
    static bool loadAndNormalize(const std::string& path, std::vector<std::vector<float>>& out_samples) {        
        static AudioFile<float> audio_file;
        
        if (!audio_file.load(path)) {
            return false;
        }
        
        int num_channels = audio_file.getNumChannels();
        int num_samples = audio_file.getNumSamplesPerChannel();

        const int MAX_SAMPLES = 511 * 1024;
        if (num_samples > MAX_SAMPLES) {
            num_samples = MAX_SAMPLES;
        }
        
        out_samples.resize(2);
        out_samples[0].resize(num_samples);
        out_samples[1].resize(num_samples);
        
        if (num_channels == 1) {
            for (int i = 0; i < num_samples; i++) {
                out_samples[0][i] = audio_file.samples[0][i];
                out_samples[1][i] = audio_file.samples[0][i];
            }
        } else {
            for (int i = 0; i < num_samples; i++) {
                out_samples[0][i] = audio_file.samples[0][i];
                out_samples[1][i] = (num_channels > 1) ? audio_file.samples[1][i] : audio_file.samples[0][i];
            }
        }
        
        normalize(out_samples);
        
        return true;
    }

private:
    static void normalize(std::vector<std::vector<float>>& samples) {
        if (samples.empty() || samples[0].empty()) {
            return;
        }
        
        int start, end;

        for (start = 0; start < samples[0].size(); start++) {
            if (std::abs(samples[0][start]) < 1e-7f && std::abs(samples[1][start]) < 1e-7f) {
                continue;
            } else {
                break;
            }
        }
        
        for (end = samples[0].size() - 1; end >= 0; end--) {
            if (std::abs(samples[0][end]) < 1e-7f && std::abs(samples[1][end]) < 1e-7f) {
                continue;
            } else {
                break;
            }
        }
        
        if (start >= end) {
            return;
        }

        samples[0].assign(samples[0].begin() + start, samples[0].begin() + end + 1);
        samples[1].assign(samples[1].begin() + start, samples[1].begin() + end + 1);

        double energy = 1e-6;
        for (size_t i = 0; i < samples[0].size(); i++) {
            energy += samples[0][i] * samples[0][i];
            energy += samples[1][i] * samples[1][i];
        }
        
        float gain = 1.0f / std::sqrt(energy);
        for (size_t i = 0; i < samples[0].size(); i++) {
            samples[0][i] *= gain;
            samples[1][i] *= gain;
        }
    }
};

}
