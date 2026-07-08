#ifndef WECHO_DSP_C_API_H
#define WECHO_DSP_C_API_H

typedef struct scriptParams ScriptParams;
struct CBiquad;
typedef struct CBiquad* Biquad_;
struct CDelayLine;
typedef struct CDelayLine* DelayLine_;
struct CConvolver;
typedef struct CConvolver* Convolver_;
struct CHarmonic;
typedef struct CHarmonic* Harmonic_;

#ifdef __cplusplus
extern "C" {
#endif

enum StructureType {
    BiquadType,
    DelayLineType,
    ConvolverType,
    HarmonicType,
};

struct AllocatedStructure {
    void* data;
    enum StructureType type;
};

/****************************************************math function**************************************************** */
float _math_sin(float x);
float _math_sinh(float x);
float _math_cos(float x);
float _math_cosh(float x);
float _math_tan(float x);
float _math_tanh(float x);
float _math_atan(float x);
float _math_atanh(float x);
float _math_exp(float x);
float _math_log(float x);
float _math_log2(float x);
float _math_log10(float x);
float _math_pow(float x, float y);
float _math_sqrt(float x);
float _math_fabs(float x);
float _math_fmod(float x, float y);
float _math_floor(float x);
float _math_ceil(float x);
float _math_fmin(float x, float y);
float _math_fmax(float x, float y);

#ifdef TCC_MATH
/* Redirect standard names to inline implementations */
#define sin      _math_sin
#define sinh     _math_sinh
#define cos      _math_cos
#define cosh     _math_cosh
#define tan      _math_tan
#define tanh     _math_tanh
#define atan     _math_atan
#define atanh    _math_atanh
#define exp      _math_exp
#define log      _math_log
#define log2     _math_log2
#define log10    _math_log10
#define pow      _math_pow
#define sqrt     _math_sqrt
#define fabs     _math_fabs
#define fmod     _math_fmod
#define floor    _math_floor
#define ceil     _math_ceil
#define fmin     _math_fmin
#define fmax     _math_fmax

#define sinf     _math_sin
#define sinhf     _math_sinh
#define cosf     _math_cos
#define coshf     _math_cosh
#define tanf     _math_tan
#define tanhf     _math_tanh
#define atanf    _math_atan
#define atanhf   _math_atanh
#define expf     _math_exp
#define logf     _math_log
#define log2f    _math_log2
#define log10f   _math_log10
#define powf     _math_pow
#define sqrtf    _math_sqrt
#define fabsf    _math_fabs
#define fmodf    _math_fmod
#define floorf   _math_floor
#define ceilf    _math_ceil
#define fminf    _math_fmin
#define fmaxf    _math_fmax

#define SAMPLE_RATE 48000
#define SAMPLES_PER_CHANNEL 512
#define PARAM(name, min, max, step, value, display_name) float name = value;
#endif


/*
 * all utils working @48000hz
 * block processing size: 512 samples (an audio frame, captured from AudioRecord)
 */

struct scriptParams {
    char name[64];
    float value;
};

void _set_c_api_error(const char* error);
const char* _get_c_api_error();
void _clear_c_api_error();

/****************************************************Biquad**************************************************** */
Biquad_ new_biquad();
void biquad_reset(Biquad_ ctx);
void biquad_set_hp(Biquad_ ctx, float cutoff, float q);
void biquad_set_lp(Biquad_ ctx, float cutoff, float q);
void biquad_set_peak(Biquad_ ctx, float cutoff, float q, float gain);
void biquad_set_ls(Biquad_ ctx, float cutoff, float q, float gain);
void biquad_set_hs(Biquad_ ctx, float cutoff, float q, float gain);
void biquad_set_coeffs(Biquad_ ctx, double a0, double a1, double a2, double b0, double b1, double b2);
float biquad_process(Biquad_ ctx, float input);
void biquad_process_block(Biquad_ ctx, float* input, float* output);

/****************************************************DelayLine**************************************************** */
DelayLine_ new_delay_line();
void delay_line_reset(DelayLine_ ctx);
void delay_line_set_delay(DelayLine_ ctx, int samples); // max delay samples: 8192
float delay_line_process(DelayLine_ ctx, float input); // push and pop a sample from delay line
void delay_line_process_block(DelayLine_ ctx, float* input, float* output); // process a block of samples from delay line
float delay_line_read(DelayLine_ ctx); // just read a sample from delay line without push
void delay_line_read_block(DelayLine_ ctx, float* output); // just read a block of samples from delay line without push
void delay_line_write(DelayLine_ ctx, float input); // just write a sample to delay line without pop
void delay_line_write_block(DelayLine_ ctx, float* input); // just write a block of samples to delay line without pop

/****************************************************Convolver**************************************************** */
Convolver_ new_convolver();
void convolver_reset(Convolver_ ctx);
void convolver_set_ir(Convolver_ ctx, float* ir_l, float* ir_r, int samples);
void convolver_set_ir_path(Convolver_ ctx, const char* path);
void convolver_process_block(Convolver_ ctx, float* input_l, float* input_r, float* output_l, float* output_r);

/****************************************************Chebychev Harmonic Generator**************************************************** */
Harmonic_ new_harmonic();
void harmonic_reset(Harmonic_ ctx);
void harmonic_set_coeffs(Harmonic_ ctx, float base, float order2, float order3, float order4, float order5, float order6, float order7, float order8);
float harmonic_process(Harmonic_ ctx, float input);
void harmonic_process_block(Harmonic_ ctx, float* input, float* output);


/****************************************************for_loop**************************************************** */

#ifdef __cplusplus
}
#endif

#endif
