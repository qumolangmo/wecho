#include "wecho_dsp_c_api.h"
#include "../utils/filter.hpp"
#include "../utils/convolver.hpp"
#include "../utils/harmonic.hpp"
#include <vector>
#include <string>
#include <cstring>
#include <cmath>

#define likely(x) __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)

static std::string g_last_error;
static thread_local std::vector<AllocatedStructure>* t_current_allocations = nullptr;

void _wecho_dsp_begin_allocations(std::vector<AllocatedStructure>* allocations) {
    t_current_allocations = allocations;
}

void _wecho_dsp_end_allocations() {
    t_current_allocations = nullptr;
}

struct CBiquad {
    Biquad<1> biquad;
};

struct CDelayLine {
    DelayLine<8192> delay_line;
};

struct CConvolver {
    Convolver convolver;
};

struct CHarmonic {
    Harmonic<10> harmonic;
};

std::vector<std::vector<float>> _ir_cache(2, std::vector<float>(65536));
std::array<float, SAMPLES_LENGTH_PER_FRAME> _io_cache;

#ifdef __cplusplus
extern "C" {
#endif

float _math_fabs(float x) { return std::fabsf(x); }
float _math_fmod(float x, float y) { return std::fmodf(x, y); }
float _math_floor(float x) { return std::floorf(x); }
float _math_ceil(float x) { return std::ceilf(x); }
float _math_sin(float x) { return std::sinf(x); }
float _math_sinh(float x) { return std::sinhf(x); }
float _math_cos(float x) { return std::cosf(x); }
float _math_cosh(float x) { return std::coshf(x); }
float _math_tan(float x) { return std::tanf(x); }
float _math_tanh(float x) { return std::tanhf(x); }
float _math_atan(float x) { return std::atanf(x); }
float _math_atanh(float x) { return std::atanhf(x); }
float _math_exp(float x) { return std::expf(x); }
float _math_log(float x) { return std::logf(x); }
float _math_log2(float x) { return std::log2f(x); }
float _math_log10(float x) { return std::log10f(x); }
float _math_pow(float x, float y) { return std::powf(x, y); }
float _math_sqrt(float x) { return std::sqrtf(x); }
float _math_fabsf(float x) { return std::fabsf(x); }
float _math_fmodf(float x, float y) { return std::fmodf(x, y); }
float _math_floorf(float x) { return std::floorf(x); }
float _math_ceilf(float x) { return std::ceilf(x); }
float _math_fmin(float x, float y) { return std::fminf(x, y); }
float _math_fmax(float x, float y) { return std::fmaxf(x, y); }

void _set_c_api_error(const char* error) {
    g_last_error = error;
}

const char* _get_c_api_error() {
    return g_last_error.c_str();
}

void _clear_c_api_error() {
    g_last_error.clear();
}

/****************************************************Biquad**************************************************** */
Biquad_ new_biquad() {
    void* data = nullptr;

    if (likely(t_current_allocations)) {
        data = new CBiquad();
        t_current_allocations->push_back({data, BiquadType});
    } else {
        _set_c_api_error("new_biquad: not allow biquad allocation outside setParams.");
        return nullptr;
    }

    return (Biquad_)(data);
}

void biquad_reset(Biquad_ ctx) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_reset: ctx is null pointer"); return; }
    ctx->biquad.reset();
}

void biquad_set_hp(Biquad_ ctx, float cutoff, float q) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_set_hp: ctx is null pointer"); return; }
    ctx->biquad.setHighPass({cutoff, q});
}

void biquad_set_lp(Biquad_ ctx, float cutoff, float q) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_set_lp: ctx is null pointer"); return; }
    ctx->biquad.setLowPass({cutoff, q});
}

void biquad_set_peak(Biquad_ ctx, float cutoff, float q, float gain) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_set_peak: ctx is null pointer"); return; }
    ctx->biquad.setPeak({cutoff, q, gain});
}

void biquad_set_ls(Biquad_ ctx, float cutoff, float q, float gain) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_set_ls: ctx is null pointer"); return; }
    ctx->biquad.setLowShelf({cutoff, q, gain});
}

void biquad_set_hs(Biquad_ ctx, float cutoff, float q, float gain) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_set_hs: ctx is null pointer"); return; }
    ctx->biquad.setHighShelf({cutoff, q, gain});
}

void biquad_set_coeffs(Biquad_ ctx, double a0, double a1, double a2, double b0, double b1, double b2) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_set_coeffs: ctx is null pointer"); return; }
    ctx->biquad.setCoeffs({a0, a1, a2, b0, b1, b2});
}

float biquad_process(Biquad_ ctx, float input) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_process: ctx is null pointer"); return input; }
    return ctx->biquad.process(input);
}

void biquad_process_block(Biquad_ ctx, float* input, float* output) {
    if (unlikely(!ctx)) { _set_c_api_error("biquad_process_block: ctx is null pointer"); return; }
    for (int i = 0; i < 512; i++) {
        output[i] = ctx->biquad.process(input[i]);
    }
}

/****************************************************DelayLine**************************************************** */
DelayLine_ new_delay_line() {
    void* data = nullptr;

    if (likely(t_current_allocations)) {
        data = new CDelayLine();
        t_current_allocations->push_back({data, DelayLineType});
    } else {
        _set_c_api_error("new_delay_line: not allow delay line allocation outside setParams.");
        return nullptr;
    }

    return (DelayLine_)(data);
}

void delay_line_reset(DelayLine_ ctx) {
    if (unlikely(!ctx)) { _set_c_api_error("delay_line_reset: ctx is null pointer"); return; }
    ctx->delay_line.reset();
}

void delay_line_set_delay(DelayLine_ ctx, int samples) {
    if (unlikely(!ctx)) { _set_c_api_error("delay_line_set_delay: ctx is null pointer"); return; }
    ctx->delay_line.setDelay(samples);
}

float delay_line_read(DelayLine_ ctx) {
    if (unlikely(!ctx)) { _set_c_api_error("delay_line_read: ctx is null pointer"); return 0.0f; }
    return ctx->delay_line.read();
}

void delay_line_read_block(DelayLine_ ctx, float* output) {
    if (unlikely(!ctx)) { _set_c_api_error("delay_line_read_block: ctx is null pointer"); return; }
    for (int i = 0; i < 512; i++) {
        output[i] = ctx->delay_line.read();
    }
}

void delay_line_write(DelayLine_ ctx, float input) {
    if (unlikely(!ctx)) { _set_c_api_error("delay_line_write: ctx is null pointer"); return; }
    ctx->delay_line.write(input);
}

void delay_line_write_block(DelayLine_ ctx, float* input) {
    if (unlikely(!ctx)) { _set_c_api_error("delay_line_write_block: ctx is null pointer"); return; }
    for (int i = 0; i < 512; i++) {
        ctx->delay_line.write(input[i]);
    }
}

float delay_line_process(DelayLine_ ctx, float input) {
    if (unlikely(!ctx)) { _set_c_api_error("delay_line_process: ctx is null pointer"); return input; }
    return ctx->delay_line.process(input);
}

void delay_line_process_block(DelayLine_ ctx, float* input, float* output) {
    if (unlikely(!ctx)) { _set_c_api_error("delay_line_process_block: ctx is null pointer"); return; }
    for (int i = 0; i < 512; i++) {
        output[i] = ctx->delay_line.process(input[i]);
    }
}

/****************************************************Convolver**************************************************** */
Convolver_ new_convolver() {
    void* data = nullptr;

    if (likely(t_current_allocations)) {
        data = new CConvolver();
        t_current_allocations->push_back({data, ConvolverType});
    } else {
        _set_c_api_error("new_convolver: not allow convolver allocation outside setParams.");
        return nullptr;
    }

    return (Convolver_)(data);
}

void convolver_reset(Convolver_ ctx) {
    if (unlikely(!ctx)) { _set_c_api_error("convolver_reset: ctx is null pointer"); return; }
    ctx->convolver.reset();
}

void convolver_set_ir(Convolver_ ctx, float* ir_l, float* ir_r, int samples) {
    if (unlikely(!ctx)) { _set_c_api_error("convolver_set_ir: ctx is null pointer"); return; }
    _ir_cache[0].assign(ir_l, ir_l + samples);
    _ir_cache[1].assign(ir_r, ir_r + samples);
    ctx->convolver.setIr(_ir_cache, 2);
}

void convolver_set_ir_path(Convolver_ ctx, const char* path) {
    if (unlikely(!ctx)) { _set_c_api_error("convolver_set_ir_path: ctx is null pointer"); return; }
    ctx->convolver.setIr(path);
}

void convolver_process_block(Convolver_ ctx, float* input_l, float* input_r, float* output_l, float* output_r) {
    if (unlikely(!ctx)) {
        _set_c_api_error("convolver_process_block: ctx is null pointer");
        return;
    }
    memcpy(_io_cache.begin(), input_l, 512);
    memcpy(_io_cache.begin() + 512, input_r, 512);
    
    ctx->convolver.convolve(_io_cache, _io_cache);
    std::memcpy(output_l, _io_cache.begin(), sizeof(float) * 512);
    std::memcpy(output_r, _io_cache.begin() + 512, sizeof(float) * 512);
}

/****************************************************Chebychev Harmonic Generator**************************************************** */
Harmonic_ new_harmonic() {
    void* data = nullptr;

    if (likely(t_current_allocations)) {
        data = new CHarmonic();
        t_current_allocations->push_back({data, HarmonicType});
    } else {
        _set_c_api_error("new_harmonic: not allow harmonic allocation outside setParams.");
        return nullptr;
    }

    return (Harmonic_)(data);
}

void harmonic_reset(Harmonic_ ctx) {
    if (unlikely(!ctx)) { _set_c_api_error("harmonic_reset: ctx is null pointer"); return; }
    ctx->harmonic.reset();
}

void harmonic_set_coeffs(Harmonic_ ctx, float base, float order2, float order3, float order4, float order5, float order6, float order7, float order8) {
    if (unlikely(!ctx)) { _set_c_api_error("harmonic_set_coeffs: ctx is null pointer"); return; }
    ctx->harmonic.setCoeffs({base, order2, order3, order4, order5, order6, order7, order8});
}

float harmonic_process(Harmonic_ ctx, float input) {
    if (unlikely(!ctx)) { _set_c_api_error("harmonic_process: ctx is null pointer"); return input; }
    return ctx->harmonic.process(input);
}

void harmonic_process_block(Harmonic_ ctx, float* input, float* output) {
    if (unlikely(!ctx)) { _set_c_api_error("harmonic_process_block: ctx is null pointer"); return; }
    for (int i = 0; i < 512; i++) {
        output[i] = ctx->harmonic.process(input[i]);
    }
}



#ifdef __cplusplus
}
#endif