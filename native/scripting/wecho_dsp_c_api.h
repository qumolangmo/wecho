#ifndef WECHO_DSP_C_API_H
#define WECHO_DSP_C_API_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * all utils working @48000hz
 * block processing size: 512 samples (an audio frame, captured from AudioRecord)
 */

struct scriptParams {
    char name[64];
    float value;
};

typedef struct scriptParams ScriptParams;
struct CBiquad;
typedef struct CBiquad* Biquad_;
struct CDelayLine1024;
typedef struct CDelayLine1024* DelayLine1024_;
struct CConvolver;
typedef struct CConvolver* Convolver_;
struct CHarmonic;
typedef struct CHarmonic* Harmonic_;

/****************************************************Biquad**************************************************** */
/* index: [0-15] */
Biquad_ get_biquad(int index);
void biquad_reset(Biquad_ ctx);
void biquad_set_hp(Biquad_ ctx, float cutoff, float q);
void biquad_set_lp(Biquad_ ctx, float cutoff, float q);
void biquad_set_peak(Biquad_ ctx, float cutoff, float q, float gain);
float biquad_process(Biquad_ ctx, float input);
void biquad_process_block(Biquad_ ctx, float* input, float* output);

/****************************************************DelayLine1024**************************************************** */
/* index: [0-7] */
DelayLine1024_ get_delay_line_1024(int index);
void delay_line_1024_reset(DelayLine1024_ ctx);
void delay_line_1024_set_delay(DelayLine1024_ ctx, int samples);
/*
 * push and pop a sample from delay line
*/
float delay_line_1024_process(DelayLine1024_ ctx, float input);
/*
 * process a block of samples from delay line
*/
void delay_line_1024_process_block(DelayLine1024_ ctx, float* input, float* output);
/*
 * just read a sample from delay line without push
 */
float delay_line_1024_read(DelayLine1024_ ctx);
void delay_line_1024_read_block(DelayLine1024_ ctx, float* output);
/*
 * just write a sample to delay line without pop
 */
void delay_line_1024_write(DelayLine1024_ ctx, float input);
void delay_line_1024_write_block(DelayLine1024_ ctx, float* input);

/****************************************************Convolver**************************************************** */
/* index: [0-3] */
Convolver_ get_convolver(int index);
void convolver_reset(Convolver_ ctx);
void convolver_set_ir(Convolver_ ctx, float* ir_l, float* ir_r, int samples);
void convolver_set_ir_path(Convolver_ ctx, const char* path);
void convolver_process_block(Convolver_ ctx, float* input_l, float* input_r, float* output_l, float* output_r);

/****************************************************Chebychev Harmonic Generator**************************************************** */
/* index: [0-3] */
Harmonic_ get_harmonic(int index);
void harmonic_reset(Harmonic_ ctx);
void harmonic_set_coeffs(Harmonic_ ctx, float base, float order2, float order3, float order4, float order5, float order6, float order7, float order8);
float harmonic_process(Harmonic_ ctx, float input);
void harmonic_process_block(Harmonic_ ctx, float* input, float* output);


/****************************************************for_loop**************************************************** */

#ifdef __cplusplus
}
#endif

#endif
