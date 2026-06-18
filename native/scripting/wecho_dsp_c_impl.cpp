#include "wecho_dsp_c_api.h"
#include "../utils/filter.hpp"
#include "../utils/convolver.hpp"
#include "../utils/harmonic.hpp"
#include <array>

struct CBiquad {
    Biquad<1> biquad;
};

struct CDelayLine1024 {
    DelayLine<1024> delay_line;
};

struct CConvolver {
    Convolver convolver;
};

struct CHarmonic {
    Harmonic<10> harmonic;
};

std::array<CBiquad, 16> _biquads_;
std::array<CDelayLine1024, 8> _delay_lines_;
std::array<CConvolver, 4> _convolvers_;
std::array<CHarmonic, 4> _harmonics_;

std::vector<std::vector<float>> _ir_cache(2, std::vector<float>(65536));

#ifdef __cplusplus
extern "C" {
#endif

/****************************************************Biquad**************************************************** */
Biquad_ get_biquad(int index) {
    if (index < 0 || index >= 16) {
        return nullptr;
    }

    return &_biquads_[index];
}

void biquad_reset(Biquad_ ctx) {
    ctx->biquad.reset();
}

void biquad_set_hp(Biquad_ ctx, float cutoff, float q) {
    ctx->biquad.setHighPass({cutoff, q});
}

void biquad_set_lp(Biquad_ ctx, float cutoff, float q) {
    ctx->biquad.setLowPass({cutoff, q});
}

void biquad_set_peak(Biquad_ ctx, float cutoff, float q, float gain) {
    ctx->biquad.setPeak({cutoff, q, gain});
}

float biquad_process(Biquad_ ctx, float input) {
    return ctx->biquad.process(input);
}

void biquad_process_block(Biquad_ ctx, float* input, float* output) {
    for (int i = 0; i < 512; i++) {
        output[i] = ctx->biquad.process(input[i]);
    }
}

/****************************************************DelayLine1024**************************************************** */
DelayLine1024_ get_delay_line_1024(int index) {
    if (index < 0 || index >= 8) {
        return nullptr;
    }

    return &_delay_lines_[index];
}

void delay_line_1024_reset(DelayLine1024_ ctx) {
    ctx->delay_line.reset();
}

void delay_line_1024_set_delay(DelayLine1024_ ctx, int samples) {
    ctx->delay_line.setDelay(samples);
}

float delay_line_1024_read(DelayLine1024_ ctx) {
    return ctx->delay_line.read();
}

void delay_line_1024_read_block(DelayLine1024_ ctx, float* output) {
    for (int i = 0; i < 512; i++) {
        output[i] = ctx->delay_line.read();
    }
}

void delay_line_1024_write(DelayLine1024_ ctx, float input) {
    ctx->delay_line.write(input);
}

void delay_line_1024_write_block(DelayLine1024_ ctx, float* input) {
    for (int i = 0; i < 512; i++) {
        ctx->delay_line.write(input[i]);
    }
}

float delay_line_1024_process(DelayLine1024_ ctx, float input) {
    return ctx->delay_line.process(input);
}

void delay_line_1024_process_block(DelayLine1024_ ctx, float* input, float* output) {
    for (int i = 0; i < 512; i++) {
        output[i] = ctx->delay_line.process(input[i]);
    }
}

/****************************************************Convolver**************************************************** */
Convolver_ get_convolver(int index) {
    if (index < 0 || index >= 4) {
        return nullptr;
    }

    return &_convolvers_[index];
}

void convolver_reset(Convolver_ ctx) {
    ctx->convolver.reset();
}

void convolver_set_ir(Convolver_ ctx, float* ir_l, float* ir_r, int samples) {
    _ir_cache[0].assign(ir_l, ir_l + samples);
    _ir_cache[1].assign(ir_r, ir_r + samples);
    ctx->convolver.setIr(_ir_cache);
}

void convolver_set_ir_path(Convolver_ ctx, const char* path) {
    ctx->convolver.setIr(path);
}

void convolver_process_block(Convolver_ ctx, float* input_l, float* input_r, float* output_l, float* output_r) {
    _ir_cache[0].assign(input_l, input_l + 512);
    _ir_cache[1].assign(input_r, input_r + 512);
    ctx->convolver.convolve(_ir_cache, _ir_cache);
    for (int i = 0; i < 512; i++) {
        output_l[i] = _ir_cache[0][i];
        output_r[i] = _ir_cache[1][i];
    }
}

/****************************************************Chebychev Harmonic Generator**************************************************** */
Harmonic_ get_harmonic(int index) {
    if (index < 0 || index >= 4) {
        return nullptr;
    }

    return &_harmonics_[index];
}

void harmonic_reset(Harmonic_ ctx) {
    ctx->harmonic.reset();
}

void harmonic_set_coeffs(Harmonic_ ctx, float base, float order2, float order3, float order4, float order5, float order6, float order7, float order8) {
    ctx->harmonic.setCoeffs({base, order2, order3, order4, order5, order6, order7, order8});
}

float harmonic_process(Harmonic_ ctx, float input) {
    return ctx->harmonic.process(input);
}

void harmonic_process_block(Harmonic_ ctx, float* input, float* output) {
    for (int i = 0; i < 512; i++) {
        output[i] = ctx->harmonic.process(input[i]);
    }
}



#ifdef __cplusplus
}
#endif