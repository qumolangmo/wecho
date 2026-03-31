#pragma once

#include <string>
#include <vector>
#include <cmath>
#include <algorithm>
#include "../../native/utils/AudioFile.hpp"

namespace wecho {

class IrLoader {
public:
    static constexpr int MAX_SAMPLES_PER_CHANNEL = 65536;
    static bool loadAndNormalize(const std::string& path, std::vector<std::vector<float>>& out_samples) {        
        static AudioFile<float> ir;
        
        if (!ir.load(path)) {
            return false;
        }
        
        if (ir.getNumChannels() == 1) {
            int j;

            for (j = 0; j < ir.getNumSamplesPerChannel() && j < 65536; j++) {
                out_samples[0].push_back(ir.samples[0][j]);
                out_samples[1].push_back(ir.samples[0][j]);
            }

            out_samples[0].resize(j);
            out_samples[1].resize(j);
        } else {
            int i, j;

            for (i = 0; i < 2; i++) {
                for (j = 0; j < ir.getNumSamplesPerChannel() && j < 65536; j++) {
                    out_samples[i][j] = ir.samples[i][j];
                }

                out_samples[i].resize(j);
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
        samples[0].resize(end - start + 1);
        samples[1].resize(end - start + 1);

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
