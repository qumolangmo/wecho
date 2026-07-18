/*
 * Copyright (C) 2026 qumolangmo
 *
 * This file is part of Wecho.
 *
 * Wecho is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Wecho is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Wecho.  If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef __CONVOLVER_HPP__
#define __CONVOLVER_HPP__

#ifdef __WIN32__
#define FFTW_DLL
#endif

#include "../fftw/fftw3.h"

#include "../utils/AudioFile.hpp"
#include <memory>
#include <filesystem>
#include <algorithm>
#include <fstream>

static constexpr int FRAME_SIZE_PER_CHANNEL = 512;
static constexpr int FFT_SIZE = 2 * FRAME_SIZE_PER_CHANNEL;

class FFTWFComplexArray {
private:
    struct FFTWFMemoryDeleter {
        void operator()(fftwf_complex* ptr) {
            fftwf_free(ptr);
        }
    };

    std::unique_ptr<fftwf_complex[], FFTWFMemoryDeleter> data;
    int n;

public:
    explicit FFTWFComplexArray(int n = FFT_SIZE)
        : n(n)
        , data(nullptr) {

        data.reset(fftwf_alloc_complex(n));
    }

    FFTWFComplexArray(const FFTWFComplexArray&) = delete;
    FFTWFComplexArray& operator=(const FFTWFComplexArray&) = delete;

    FFTWFComplexArray(FFTWFComplexArray&& other)
        : n(other.n)
        , data(std::move(other.data)) {}

    FFTWFComplexArray& operator=(FFTWFComplexArray&& other) {
        n = other.n;
        data = std::move(other.data);
        return *this;
    }

    fftwf_complex& operator[](int i) {
        return data[i];
    }

    const fftwf_complex& operator[](int i) const {
        return data[i];
    }

    fftwf_complex* get() {
        return data.get();
    }

    const fftwf_complex* get() const {
        return data.get();
    }

    int size() const {
        return n;
    }

    void init(uint8_t value) {
        memset(data.get(), value, n * sizeof(fftwf_complex));
    }

    void init(uint8_t value, int start, int n) {
        memset(data.get() + start, value, n * sizeof(fftwf_complex));
    }

};

class FFTWFPlan {
private:
    struct FFTWFPlanDeleter {
        void operator()(fftwf_plan ptr) {
            fftwf_destroy_plan(ptr);
        }
    };

    std::unique_ptr<std::remove_pointer_t<fftwf_plan>, FFTWFPlanDeleter> plan;
    size_t n;
    int sign;
    unsigned int flags;

    static void importWisdom() {
        if (std::filesystem::exists(wisdom_path) && !wisdom_imported) {
            fftwf_import_wisdom_from_filename(wisdom_path.data());
            wisdom_imported = true;
        }
    }

    static void exportWisdom() {
        if (std::filesystem::exists(wisdom_path) && wisdom_imported) {
            fftwf_export_wisdom_to_filename(wisdom_path.data());
        }
    }

public:
    static void initWisdom(std::string_view _wisdom_path) {
        wisdom_path = _wisdom_path;

        std::filesystem::path wisdom_dir = std::filesystem::path(wisdom_path).parent_path();
        if (!std::filesystem::exists(wisdom_dir)) {
            std::filesystem::create_directories(wisdom_dir);
        }

        std::string version_path = std::string(wisdom_path) + ".version";

        if (std::filesystem::exists(wisdom_path)) {
            if (std::filesystem::exists(version_path)) {
                std::ifstream ver_file(version_path);
                int stored_fft_size = 0;
                if (ver_file >> stored_fft_size && stored_fft_size != FFT_SIZE) {
                    std::filesystem::remove(wisdom_path);
                    std::filesystem::remove(version_path);
                }
            } else {
                std::filesystem::remove(wisdom_path);
            }
        }

        if (!std::filesystem::exists(wisdom_path)) {
            importWisdom();

            FFTWFComplexArray tmp(FFT_SIZE);
            FFTWFPlan plan(FFT_SIZE, FFTW_FORWARD, tmp, tmp, FFTW_MEASURE);
            FFTWFPlan backward_plan(FFT_SIZE, FFTW_BACKWARD, tmp, tmp, FFTW_MEASURE);

            std::ofstream ver_file(version_path);
            ver_file << FFT_SIZE;
        } else {
            importWisdom();
        }
        
    }

    static std::string wisdom_path;

    static bool wisdom_imported;

    static void saveWisdom() {
        exportWisdom();
    }

    FFTWFPlan(size_t n, int sign, FFTWFComplexArray& in, FFTWFComplexArray& out, unsigned int flags = FFTW_WISDOM_ONLY)
        : n(n)
        , sign(sign)
        , flags(flags) {

        plan.reset(fftwf_plan_dft_1d(n, in.get(), out.get(), sign, flags));
    }

    int fftSize() const {
        return n;
    }

    void execute(FFTWFComplexArray& in, FFTWFComplexArray& out) {
        fftwf_execute_dft(plan.get(), in.get(), out.get());
    }
};

class Convolver {
public:
    Convolver()
        : samples(4, std::vector<float>(MAX_SAMPLES_PER_CHANNEL))
        , compute_cache_left(FFT_SIZE)
        , compute_cache_right(FFT_SIZE)
        , sliding_window_left(FFT_SIZE)
        , sliding_window_right(FFT_SIZE)
        , forward_plan(FFT_SIZE, FFTW_FORWARD, compute_cache_left, compute_cache_right, FFTW_ESTIMATE)
        , backward_plan(FFT_SIZE, FFTW_BACKWARD, compute_cache_right, compute_cache_left, FFTW_ESTIMATE)
        , ir(MAX_SAMPLES_PER_CHANNEL/FFT_SIZE)
        , delay_left(MAX_SAMPLES_PER_CHANNEL/FFT_SIZE)
        , delay_right(MAX_SAMPLES_PER_CHANNEL/FFT_SIZE)
        , valid_channels(0) {

        reset();
    }

    ~Convolver() {}

    void reset() {
        sliding_window_left.init(0);
        sliding_window_right.init(0);
        compute_cache_left.init(0);
        compute_cache_right.init(0);

        for (auto& delay: delay_left) {
            delay.init(0);
        }
        for (auto& delay: delay_right) {
            delay.init(0);
        }

        for (int i = 0; i < ir.size(); i++) {
            for (int j = 0; j < valid_channels; j++) {
                ir[i][j].init(0);
            }
        }

        valid_channels = 0;
    }

    void normalize() {
        double energy = 1e-13;

        for (int i = 0; i < valid_channels; i++) {
            for (int j = 0; j < samples[i].size(); j++) {
                energy += samples[i][j] * samples[i][j];
            }
        }

        float gain = 1 / std::sqrt(energy);

        for (int i = 0; i < valid_channels; i++) {
            for (int j = 0; j < samples[i].size(); j++) {
                samples[i][j] *= gain;
            }
        }
    }

    void setIr(const std::vector<std::vector<float>>& ir, int channels) {
        valid_channels = channels;

        for (int i = 0; i < ir.size() && i < samples.size(); i++) {
            samples[i] = ir[i];
        }

        normalize();

        this->ir.resize(std::ceil(samples[0].size() / (float)FRAME_SIZE_PER_CHANNEL));

        delay_left.resize(this->ir.size());
        delay_right.resize(this->ir.size());

        for (auto& delay: delay_left) {
            delay.init(0);
        }
        for (auto& delay: delay_right) {
            delay.init(0);
        }

        for (int i = 0; i < this->ir.size(); i++) {
            for (int j = 0; j < valid_channels; j++) {
                int k;

                for (k = 0; k < FRAME_SIZE_PER_CHANNEL && i * FRAME_SIZE_PER_CHANNEL + k < samples[j].size(); k++) {
                    this->ir[i][j][k][0] = samples[j][i * FRAME_SIZE_PER_CHANNEL + k];
                    this->ir[i][j][k][1] = 0.0f;
                }

                memset(this->ir[i][j].get() + k, 0, (FFT_SIZE - k) * sizeof(fftwf_complex));

                forward_plan.execute(this->ir[i][j], this->ir[i][j]);
            }
        }
    }

    void setIr(const std::string& ir_path) {
        if (!loadAudioFile(ir_path, samples)) {
            return;
        }

        setIr(samples, valid_channels);
    }

    void convolve(const std::vector<std::vector<float>>& input, std::vector<std::vector<float>>& output) {
        float mix_factor = mix.load(std::memory_order_relaxed);

        memcpy(sliding_window_left.get(),
                sliding_window_left.get() + FRAME_SIZE_PER_CHANNEL,
                (FFT_SIZE - FRAME_SIZE_PER_CHANNEL) * sizeof(fftwf_complex));
        memcpy(sliding_window_right.get(),
                sliding_window_right.get() + FRAME_SIZE_PER_CHANNEL,
                (FFT_SIZE - FRAME_SIZE_PER_CHANNEL) * sizeof(fftwf_complex));

        for (int i = FRAME_SIZE_PER_CHANNEL; i < FFT_SIZE; i++) {
            if ((i - FRAME_SIZE_PER_CHANNEL) < input[0].size()) {
                sliding_window_left[i][0] = input[0][i - FRAME_SIZE_PER_CHANNEL];
                sliding_window_right[i][0] = input[1][i - FRAME_SIZE_PER_CHANNEL];
                sliding_window_left[i][1] = 0.0f;
                sliding_window_right[i][1] = 0.0f;
            } else {
                sliding_window_left[i][0] = 0.0f;
                sliding_window_right[i][0] = 0.0f;
                sliding_window_left[i][1] = 0.0f;
                sliding_window_right[i][1] = 0.0f;
            }
        }

        std::rotate(delay_left.begin(), delay_left.end() - 1, delay_left.end());
        std::rotate(delay_right.begin(), delay_right.end() - 1, delay_right.end());

        forward_plan.execute(sliding_window_left, delay_left[0]);
        forward_plan.execute(sliding_window_right, delay_right[0]);

        compute_cache_left.init(0);
        compute_cache_right.init(0);

        if (valid_channels == 2) {
            multiply<2>();
        } else if (valid_channels == 4) {
            multiply<4>();
        }

        backward_plan.execute(compute_cache_left, compute_cache_left);
        backward_plan.execute(compute_cache_right, compute_cache_right);

        for (int i = 0; i < input[0].size(); i++) {
            output[0][i] = (compute_cache_left[i + FRAME_SIZE_PER_CHANNEL][0] / FFT_SIZE) 
                * mix_factor + (1.0f - mix_factor) * input[0][i];
            output[1][i] = (compute_cache_right[i + FRAME_SIZE_PER_CHANNEL][0] / FFT_SIZE) 
                * mix_factor + (1.0f - mix_factor) * input[1][i];
        }

        return;
    }

    void setMix(float mix) {
        this->mix.store(mix, std::memory_order_release);
    }

private:
    static constexpr int MAX_SAMPLES_PER_CHANNEL = 65536;

    template<int VALID_CHANNELS>
    void multiply() {
        fftwf_complex acc_left[FFT_SIZE] = {0};
        fftwf_complex acc_right[FFT_SIZE] = {0};

        for (int i = 0; i < this->ir.size(); i++) {
            const auto& dl = delay_left[i];
            const auto& dr = delay_right[i];
            const auto& ir0 = this->ir[i][0];
            const auto& ir1 = this->ir[i][1];
            const auto& ir2 = this->ir[i][2];
            const auto& ir3 = this->ir[i][3];

            for (int j = 0; j < FFT_SIZE; j++) {
                acc_left[j][0] +=
                    dl[j][0] * ir0[j][0] - dl[j][1] * ir0[j][1];
                acc_left[j][1] +=
                    dl[j][0] * ir0[j][1] + dl[j][1] * ir0[j][0];
                if constexpr (VALID_CHANNELS == 4) {
                    acc_left[j][0] +=
                        dl[j][0] * ir2[j][0] - dl[j][1] * ir2[j][1];
                    acc_left[j][1] +=
                        dl[j][0] * ir2[j][1] + dl[j][1] * ir2[j][0];
                }
            }

            for (int j = 0; j < FFT_SIZE; j++) {
                acc_right[j][0] +=
                    dr[j][0] * ir1[j][0] - dr[j][1] * ir1[j][1];
                acc_right[j][1] +=
                    dr[j][0] * ir1[j][1] + dr[j][1] * ir1[j][0];
                if constexpr (VALID_CHANNELS == 4) {
                    acc_right[j][0] +=
                        dr[j][0] * ir3[j][0] - dr[j][1] * ir3[j][1];
                    acc_right[j][1] +=
                        dr[j][0] * ir3[j][1] + dr[j][1] * ir3[j][0];
                }
            }
        }
        
        memcpy(compute_cache_left.get(), acc_left, sizeof(acc_left));
        memcpy(compute_cache_right.get(), acc_right, sizeof(acc_right));
    }

    /* max load 65536 samples per channel */
    bool loadAudioFile(const std::string& path, std::vector<std::vector<float>>& samples) {
        /* reserve 1MB date area default */
        static AudioFile<float> ir;

        if (!ir.load(path)) {
            return false;
        }

        if (ir.getNumChannels() == 1) {
            /* 128k samples = 128k * sizeof(float) = 512kB per cahnnel */
            int j;

            for (j = 0; j < ir.getNumSamplesPerChannel() && j < MAX_SAMPLES_PER_CHANNEL; j++) {
                samples[0][j] = ir.samples[0][j];
                samples[1][j] = ir.samples[0][j];
            }

            samples[0].resize(j);
            samples[1].resize(j);

            valid_channels = 2;
        } else if (ir.getNumChannels() == 2) {
            int i, j;

            for (i = 0; i < 2; i++) {
                for (j = 0; j < ir.getNumSamplesPerChannel() && j < MAX_SAMPLES_PER_CHANNEL; j++) {
                    samples[i][j] = ir.samples[i][j];
                }

                samples[i].resize(j);
            }

            valid_channels = 2;
        } else if (ir.getNumChannels() == 4) {
            int i, j;

            for (i = 0; i < 4; i++) {
                for (j = 0; j < ir.getNumSamplesPerChannel() && j < MAX_SAMPLES_PER_CHANNEL; j++) {
                    samples[i][j] = ir.samples[i][j];
                }

                samples[i].resize(j);
            }

            valid_channels = 4;
        }

        return true;
    }

    fftwf_complex cache[FFT_SIZE];

    AudioFile<float> ir_file;

    std::vector<std::vector<float>> samples;
    std::atomic<float> mix;
    int valid_channels;

    FFTWFPlan forward_plan, backward_plan;

    FFTWFComplexArray compute_cache_left;
    FFTWFComplexArray compute_cache_right;

    FFTWFComplexArray sliding_window_left;
    FFTWFComplexArray sliding_window_right;

    std::vector<std::array<FFTWFComplexArray, 4>> ir;

    std::vector<FFTWFComplexArray> delay_left;
    std::vector<FFTWFComplexArray> delay_right;
};

#endif
