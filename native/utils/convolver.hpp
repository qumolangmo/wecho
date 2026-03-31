/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
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

static constexpr int FRAME_SIZE_PER_CHANNEL = 480;
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

        if (!std::filesystem::exists(wisdom_path)) {
            importWisdom();

            FFTWFComplexArray tmp(FFT_SIZE);
            FFTWFPlan plan(FFT_SIZE, FFTW_FORWARD, tmp, tmp, FFTW_MEASURE);
            FFTWFPlan backward_plan(FFT_SIZE, FFTW_BACKWARD, tmp, tmp, FFTW_MEASURE);

            exportWisdom();
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
        : samples(2, std::vector<float>(MAX_SAMPLES_PER_CHANNEL))
        , compute_cache_left(FFT_SIZE)
        , compute_cache_right(FFT_SIZE)
        , sliding_window_left(FFT_SIZE)
        , sliding_window_right(FFT_SIZE)
        , forward_plan(FFT_SIZE, FFTW_FORWARD, compute_cache_left, compute_cache_right)
        , backward_plan(FFT_SIZE, FFTW_BACKWARD, compute_cache_right, compute_cache_left)
        , ir_left(MAX_SAMPLES_PER_CHANNEL/FFT_SIZE)
        , ir_right(MAX_SAMPLES_PER_CHANNEL/FFT_SIZE)
        , delay_left(MAX_SAMPLES_PER_CHANNEL/FFT_SIZE)
        , delay_right(MAX_SAMPLES_PER_CHANNEL/FFT_SIZE) {

        reset();
    }

    ~Convolver() {}

    void reset() {
        sliding_window_left.init(0);
        sliding_window_right.init(0);
        
        for (auto& delay: delay_left) {
            delay.init(0);
        }
        for (auto& delay: delay_right) {
            delay.init(0);
        }

        compute_cache_left.init(0);
        compute_cache_right.init(0);
    }

    void normalize() {
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
        for (int i = 0; i < samples[0].size(); i++) {
            energy += samples[0][i] * samples[0][i];
            energy += samples[1][i] * samples[1][i];
        }

        float gain = 1 / std::sqrt(energy);
        for (int i = 0; i < samples[0].size(); i++) {
            samples[0][i] *= gain;
            samples[1][i] *= gain;
        }
    }

    void setIr(const std::vector<std::vector<float>>& ir) {
        auto& audio = ir;

        ir_left.resize(std::ceil(audio[0].size() / (float)FRAME_SIZE_PER_CHANNEL));
        ir_right.resize(ir_left.size());
        delay_left.resize(ir_left.size());
        delay_right.resize(ir_left.size());

        for (int i = 0; i < ir_left.size(); i++) {
            int j;

            for (j = 0; j < FRAME_SIZE_PER_CHANNEL && i * FRAME_SIZE_PER_CHANNEL + j < audio[0].size(); j++) {
                ir_left[i][j][0] = audio[0][i * FRAME_SIZE_PER_CHANNEL + j];
                ir_left[i][j][1] = 0.0f;
                ir_right[i][j][0] = audio[1][i * FRAME_SIZE_PER_CHANNEL + j];
                ir_right[i][j][1] = 0.0f;
            }

            memset(ir_left[i]. get() + j, 0, (FFT_SIZE - j) * sizeof(fftwf_complex));
            memset(ir_right[i].get() + j, 0, (FFT_SIZE - j) * sizeof(fftwf_complex));

            forward_plan.execute(ir_left[i],  ir_left[i]);
            forward_plan.execute(ir_right[i], ir_right[i]);

            delay_left[i]. init(0);
            delay_right[i].init(0);
        }
    }

    void setIr(const std::string& ir_path) {
        if (!loadAudioFile(ir_path, samples)) {
            return;
        }

        normalize();

        auto& audio = samples;

        ir_left.resize(std::ceil(audio[0].size() / (float)FRAME_SIZE_PER_CHANNEL));
        ir_right.resize(ir_left.size());
        delay_left.resize(ir_left.size());
        delay_right.resize(ir_left.size());

        for (int i = 0; i < ir_left.size(); i++) {
            int j;

            for (j = 0; j < FRAME_SIZE_PER_CHANNEL && i * FRAME_SIZE_PER_CHANNEL + j < audio[0].size(); j++) {
                ir_left[i][j][0] = audio[0][i * FRAME_SIZE_PER_CHANNEL + j];
                ir_left[i][j][1] = 0.0f;
                ir_right[i][j][0] = audio[1][i * FRAME_SIZE_PER_CHANNEL + j];
                ir_right[i][j][1] = 0.0f;
            }

            memset(ir_left[i]. get() + j, 0, (FFT_SIZE - j) * sizeof(fftwf_complex));
            memset(ir_right[i].get() + j, 0, (FFT_SIZE - j) * sizeof(fftwf_complex));

            forward_plan.execute(ir_left[i],  ir_left[i]);
            forward_plan.execute(ir_right[i], ir_right[i]);

            delay_left[i]. init(0);
            delay_right[i].init(0);
        }
    }

    void convolve(const std::vector<std::vector<float>>& input, std::vector<std::vector<float>>& output) {
        memmove(sliding_window_left.get(),
                sliding_window_left.get() + FRAME_SIZE_PER_CHANNEL,
                (FFT_SIZE - FRAME_SIZE_PER_CHANNEL) * sizeof(fftwf_complex));
        memmove(sliding_window_right.get(),
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

        for (int i = 0; i < ir_left.size(); i++) {
            for (int j = 0; j < FFT_SIZE; j++) {
                compute_cache_left[j][0] += 
                    delay_left[i][j][0] * ir_left[i][j][0] - delay_left[i][j][1] * ir_left[i][j][1];
                compute_cache_left[j][1] += 
                    delay_left[i][j][0] * ir_left[i][j][1] + delay_left[i][j][1] * ir_left[i][j][0];

                compute_cache_right[j][0] += 
                    delay_right[i][j][0] * ir_right[i][j][0] - delay_right[i][j][1] * ir_right[i][j][1];
                compute_cache_right[j][1] += 
                    delay_right[i][j][0] * ir_right[i][j][1] + delay_right[i][j][1] * ir_right[i][j][0];
            }
        }

        backward_plan.execute(compute_cache_left, compute_cache_left);
        backward_plan.execute(compute_cache_right, compute_cache_right);

        for (int i = 0; i < input[0].size(); i++) {
            output[0][i] = compute_cache_left[i + FRAME_SIZE_PER_CHANNEL][0] / FFT_SIZE;
            output[1][i] = compute_cache_right[i + FRAME_SIZE_PER_CHANNEL][0] / FFT_SIZE;
        }

        return;
    }

    void setMix(float mix) {
        this->mix = mix;
    }

private:
    static constexpr int MAX_SAMPLES_PER_CHANNEL = 65536;

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
        } else {
            // TODO: support multi-channel IR
            int i, j;

            for (i = 0; i < 2; i++) {
                for (j = 0; j < ir.getNumSamplesPerChannel() && j < MAX_SAMPLES_PER_CHANNEL; j++) {
                    samples[i][j] = ir.samples[i][j];
                }

                samples[i].resize(j);
            }
        }

        return true;
    }

    fftwf_complex cache[FFT_SIZE];

    AudioFile<float> ir_file;

    std::vector<std::vector<float>> samples;
    std::atomic<float> mix;

    FFTWFPlan forward_plan, backward_plan;

    FFTWFComplexArray compute_cache_left;
    FFTWFComplexArray compute_cache_right;

    FFTWFComplexArray sliding_window_left;
    FFTWFComplexArray sliding_window_right;

    std::vector<FFTWFComplexArray> ir_left;
    std::vector<FFTWFComplexArray> ir_right;

    std::vector<FFTWFComplexArray> delay_left;
    std::vector<FFTWFComplexArray> delay_right;
};

#endif
