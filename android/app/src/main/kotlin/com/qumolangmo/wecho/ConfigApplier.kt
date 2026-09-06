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

package com.qumolangmo.wecho

import android.content.Context
import android.util.Log

/**
 * Shared config-application logic used by both the quick-settings tile and
 * the capture service's device watcher, so speaker/headphone configs are
 * applied identically from every entry point.
 */
object ConfigApplier {
    private const val TAG = "wecho-kotlin:ConfigApplier"

    private const val DEFAULT_IIR_EQ_PARAM_STRING = """Preamp: 0.0 dB
Filter 1: ON PK Fc 31 Hz Gain 0.0 dB Q 1.00
Filter 2: ON PK Fc 62 Hz Gain 0.0 dB Q 1.00
Filter 3: ON PK Fc 125 Hz Gain 0.0 dB Q 1.00
Filter 4: ON PK Fc 250 Hz Gain 0.0 dB Q 1.00
Filter 5: ON PK Fc 500 Hz Gain 0.0 dB Q 1.00
Filter 6: ON PK Fc 1000 Hz Gain 0.0 dB Q 1.00
Filter 7: ON PK Fc 2000 Hz Gain 0.0 dB Q 1.00
Filter 8: ON PK Fc 4000 Hz Gain 0.0 dB Q 1.00
Filter 9: ON PK Fc 8000 Hz Gain 0.0 dB Q 1.00
Filter 10: ON PK Fc 16000 Hz Gain 0.0 dB Q 1.00"""

    private const val DEFAULT_SCRIPT_CODE = """// @desc: wecho dsp template code (don't override this code)
float ll = 0, rr = 0;

PARAM(gain, 0, 1.8, 0.1, 1.0, "增益");

Biquad_ hp_l, hp_r;

const int sample_rate = SAMPLE_RATE;
const int samples_per_channel = SAMPLES_PER_CHANNEL;

void setParams(ScriptParams* params) {
    gain = params[0].value;
    // init filter state here.

    hp_l = new_biquad();
    hp_r = new_biquad();
    biquad_reset(hp_l);
    biquad_reset(hp_r);
    biquad_set_lp(hp_l, 10000.0, 0.7071);
    biquad_set_lp(hp_r, 10000.0, 0.7071);
}

void run(float* in_l, float* in_r, float* out_l, float* out_r) {
    for (int i = 0; i < samples_per_channel; i++) {
        float l = in_l[i];
        float r = in_r[i];

        float l_hp = biquad_process(hp_l, l);
        float r_hp = biquad_process(hp_r, r);

        float dl = l_hp - ll;
        float dr = r_hp - rr;
        ll = l_hp;
        rr = r_hp;

        out_l[i] = dl * gain + l;
        out_r[i] = dr * gain + r;
    }
}

/* readme first:
  1. this script must begin with "// @desc: script name".
  2. all adjustable params must be defined with macro PARAM(). flutter will match the regex to set the ui state. SAMPLE_RATE and SAMPLES_PER_CHANNEL are per-defined macros.
  3. you must init all filter state and other params in setParams(). (max 16 PARAM())
  4. memcpy, memset are safe to use. other lib functions are not tested.
  5. (warning for llm) all the getter functions are focus on mono channel(convolver for stereo channel). so you must use at least 2 items to process stereo audio.
  6. (warning for llm) do not apply your soft limiter code in this script.
  7. new_biquad/new_delay_line/new_convolver/new_harmonic must only be called from setParams(). Calling them from run() causes memory leak. Allocated objects are managed by GC, no need to free them manually.
*/

/* valid api functions

  float sinf(float x);
  float sinhf(float x);
  float cosf(float x);
  float coshf(float x);
  float tanf(float x);
  float tanhf(float x);
  float atanf(float x);
  float atanhf(float x);
  float expf(float x);
  float logf(float x);
  float log2f(float x);
  float log10f(float x);
  float powf(float x, float y);
  float sqrtf(float x);
  float fabsf(float x);
  float fmodf(float x, float y);
  float floorf(float x);
  float ceilf(float x);
  float fminf(float x, float y);
  float fmaxf(float x, float y);

  Biquad_ new_biquad();
  void biquad_reset(Biquad_ ctx);
  void biquad_set_hp(Biquad_ ctx, float cutoff, float q);
  void biquad_set_lp(Biquad_ ctx, float cutoff, float q);
  void biquad_set_ls(Biquad_ ctx, float cutoff, float q, float gain);
  void biquad_set_hs(Biquad_ ctx, float cutoff, float q, float gain);
  void biquad_set_peak(Biquad_ ctx, float cutoff, float q, float gain);
  void biquad_set_coeffs(Biquad_ ctx, double a0, double a1, double a2, double b0, double b1, double b2);
  float biquad_process(Biquad_ ctx, float input);
  void biquad_process_block(Biquad_ ctx, float* input, float* output);

  DelayLine_ new_delay_line();
  void delay_line_reset(DelayLine_ ctx);
  void delay_line_set_delay(DelayLine_ ctx, int samples); // max delay samples: 8192
  float delay_line_process(DelayLine_ ctx, float input); // push and pop a sample from delay line
  void delay_line_process_block(DelayLine_ ctx, float* input, float* output); // process a block of samples from delay line
  float delay_line_read(DelayLine_ ctx); // just read a sample from delay line without push
  void delay_line_read_block(DelayLine_ ctx, float* output); // just read a block of samples from delay line without push
  void delay_line_write(DelayLine_ ctx, float input); // just write a sample to delay line without pop
  void delay_line_write_block(DelayLine_ ctx, float* input); // just write a block of samples to delay line without pop

  Convolver_ new_convolver();
  void convolver_reset(Convolver_ ctx);
  void convolver_set_ir(Convolver_ ctx, float* ir_l, float* ir_r, int samples);
  void convolver_set_ir_path(Convolver_ ctx, const char* path);
  void convolver_process_block(Convolver_ ctx, float* input_l, float* input_r, float* output_l, float* output_r);

  Harmonic_ new_harmonic();
  void harmonic_reset(Harmonic_ ctx);
  void harmonic_set_coeffs(Harmonic_ ctx, float base, float order2, float order3, float order4, float order5, float order6, float order7, float order8);
  float harmonic_process(Harmonic_ ctx, float input);
  void harmonic_process_block(Harmonic_ ctx, float* input, float* output);
*/"""

    enum class EffectParam {
        MASTER_ENABLED,
        GAIN_EFFECT_GAIN,
        BALANCE_EFFECT_BALANCE,
        BASS_EFFECT_ENABLED,
        BASS_EFFECT_GAIN,
        BASS_EFFECT_CENTER_FREQ,
        BASS_EFFECT_Q,
        CLARITY_EFFECT_ENABLED,
        CLARITY_EFFECT_GAIN,
        EVEN_HARMONIC_EFFECT_ENABLED,
        EVEN_HARMONIC_EFFECT_BASE,
        EVEN_HARMONIC_EFFECT_WARM,
        EVEN_HARMONIC_EFFECT_SUGAR,
        CONVOLVE_EFFECT_ENABLED,
        CONVOLVE_EFFECT_MIX,
        CONVOLVE_EFFECT_IR_PATH,
        COMPRESSOR_EFFECT_ENABLED,
        COMPRESSOR_EFFECT_THRESHOLD,
        COMPRESSOR_EFFECT_RATIO,
        COMPRESSOR_EFFECT_MAKEUP_GAIN,
        COMPRESSOR_EFFECT_ATTACK,
        COMPRESSOR_EFFECT_RELEASE,
        LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED,
        LOWCUT_EFFECT_ENABLED,
        LOWCUT_EFFECT_CUTOFF_FREQUENCY,
        IIR_EQUALIZER_EFFECT_ENABLED,
        IIR_EQUALIZER_EFFECT_CONFIG,
        VIRTUALBASS_EFFECT_ENABLED,
        VIRTUALBASS_EFFECT_ENVELOPE_RATE,
        VIRTUALBASS_EFFECT_MID_GAIN,
        VIRTUALBASS_EFFECT_HIGH_GAIN,
        VIRTUALBASS_EFFECT_HARMONIC_GAIN,
        REVERB_EFFECT_ENABLED,
        REVERB_EFFECT_ROOM_SIZE,
        REVERB_EFFECT_DAMPING,
        REVERB_EFFECT_MIX,
        REVERB_EFFECT_STEREO_WIDTH,
        REVERB_EFFECT_MOD_DEPTH,
        REVERB_EFFECT_MOD_FREQ,
        REVERB_EFFECT_PRE_DELAY,
        REVERB_EFFECT_MATRIX_TYPE,
        SCRIPT_EFFECT_ENABLED,
        SCRIPT_EFFECT_PARAMS,
        SCRIPT_EFFECT_CODE,
        DIFF_SURROUNDING_EFFECT_ENABLED,
        DIFF_SURROUNDING_EFFECT_DELAY_MS,
        DEVICE_SIMULATION_EFFECT_ENABLED,
        DEVICE_SIMULATION_EFFECT_CONFIG
    }

    /* reads the Flutter-side "auto output switch" setting. Defaults to true. */
    fun isAutoOutputSwitchEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.autoOutputSwitch", true)
    }

    fun sanitizeDeviceName(deviceName: String): String {
        return deviceName.lowercase().replace(Regex("[^a-z0-9]"), "_")
    }

    fun applyConfigForDevice(context: Context, deviceName: String) {
        val sanitized = sanitizeDeviceName(deviceName)
        val configKey = "flutter.config_$sanitized"

        val configJson = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString(configKey, null)

        if (configJson != null) {
            applyConfigFromJson(configJson)
            Log.i(TAG, "Applied config for device: $deviceName, key: $configKey")
        } else {
            Log.w(TAG, "No config found for device: $deviceName, key: $configKey, using default")
        }
    }

    /* applies the stored config for the given output mode name (disabled). */
    fun applyConfigForMode(context: Context, mode: String) {
        val configKey = when (mode) {
            "disabled" -> "flutter.config_disabled"
            else -> {
                Log.w(TAG, "Unknown mode: $mode")
                return
            }
        }

        val configJson = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString(configKey, null)

        if (configJson != null) {
            applyConfigFromJson(configJson)
            Log.i(TAG, "Applied config for mode: $mode, key: $configKey")
        } else {
            Log.w(TAG, "No config found for mode: $mode, key: $configKey, using default")
        }
    }

    private fun applyConfigFromJson(json: String) {
        val audioProcess = AudioProcess.getInstance()
        try {
            val config = org.json.JSONObject(json)
            config.optBoolean("dspEnabled", true).let { audioProcess.setEffectParam(EffectParam.MASTER_ENABLED.ordinal, it, true) }
            config.optDouble("gainEffectGain", 0.0).let { audioProcess.setEffectParam(EffectParam.GAIN_EFFECT_GAIN.ordinal, it, true) }
            config.optDouble("balanceEffectBalance", 0.0).let { audioProcess.setEffectParam(EffectParam.BALANCE_EFFECT_BALANCE.ordinal, it, true) }

            config.optInt("bassEffectGain", 0).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_GAIN.ordinal, it, true) }
            config.optInt("bassEffectCenterFreq", 60).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_CENTER_FREQ.ordinal, it, true) }
            config.optDouble("bassEffectQ", 0.6).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_Q.ordinal, it, true) }
            config.optBoolean("bassEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_ENABLED.ordinal, it, true) }

            config.optInt("clarityEffectGain", 0).let { audioProcess.setEffectParam(EffectParam.CLARITY_EFFECT_GAIN.ordinal, it, true) }
            config.optBoolean("clarityEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.CLARITY_EFFECT_ENABLED.ordinal, it, true) }

            config.optDouble("evenHarmonicEffectBase", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_BASE.ordinal, it, true) }
            config.optDouble("evenHarmonicEffectWarm", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_WARM.ordinal, it, true) }
            config.optDouble("evenHarmonicEffectSugar", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_SUGAR.ordinal, it, true) }
            config.optBoolean("evenHarmonicEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_ENABLED.ordinal, it, true) }

            config.optDouble("convolveEffectMix", 0.5).let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_MIX.ordinal, it, true) }
            config.optString("convolveEffectIrPath", "").let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_IR_PATH.ordinal, it, true) }
            config.optBoolean("convolveEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_ENABLED.ordinal, it, true) }

            config.optInt("compressorEffectThreshold", 0).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_THRESHOLD.ordinal, it, true) }
            config.optInt("compressorEffectRatio", 1).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_RATIO.ordinal, it, true) }
            config.optInt("compressorEffectMakeupGain", 1).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_MAKEUP_GAIN.ordinal, it, true) }
            config.optInt("compressorEffectAttack", 2).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_ATTACK.ordinal, it, true) }
            config.optInt("compressorEffectRelease", 2).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_RELEASE.ordinal, it, true) }
            config.optBoolean("compressorEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_ENABLED.ordinal, it, true) }

            config.optBoolean("lookAheadSoftLimitEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED.ordinal, it, true) }

            config.optInt("lowcatEffectCutoffFrequency", 120).let { audioProcess.setEffectParam(EffectParam.LOWCUT_EFFECT_CUTOFF_FREQUENCY.ordinal, it, true) }
            config.optBoolean("lowcatEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.LOWCUT_EFFECT_ENABLED.ordinal, it, true) }

            config.optString("iirEqualizerEffectConfig", DEFAULT_IIR_EQ_PARAM_STRING).let { audioProcess.setEffectParam(EffectParam.IIR_EQUALIZER_EFFECT_CONFIG.ordinal, it, true) }
            config.optBoolean("iirEqualizerEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.IIR_EQUALIZER_EFFECT_ENABLED.ordinal, it, true) }

            config.optDouble("virtualbassEffectMidGain", 0.5).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_MID_GAIN.ordinal, it, true) }
            config.optDouble("virtualbassEffectHighGain", 0.5).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_HIGH_GAIN.ordinal, it, true) }
            config.optDouble("virtualbassEffectHarmonicGain", 1.30).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_HARMONIC_GAIN.ordinal, it, true) }
            config.optInt("virtualbassEffectEnvelopeRate", 40).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_ENVELOPE_RATE.ordinal, it, true) }
            config.optBoolean("virtualbassEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_ENABLED.ordinal, it, true) }


            config.optDouble("reverbEffectRoomSize", 0.54).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_ROOM_SIZE.ordinal, it, true) }
            config.optDouble("reverbEffectDamping", 0.25).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_DAMPING.ordinal, it, true) }
            config.optDouble("reverbEffectMix", 0.5).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_MIX.ordinal, it, true) }
            config.optDouble("reverbEffectStereoWidth", 1.0).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_STEREO_WIDTH.ordinal, it, true) }
            config.optDouble("reverbEffectModDepth", 0.57).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_MOD_DEPTH.ordinal, it, true) }
            config.optDouble("reverbEffectModFreq", 4.3).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_MOD_FREQ.ordinal, it, true) }
            config.optInt("reverbEffectPreDelay", 20).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_PRE_DELAY.ordinal, it, true) }
            config.optInt("reverbEffectMatrixType", 0).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_MATRIX_TYPE.ordinal, it, true) }
            config.optBoolean("reverbEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_ENABLED.ordinal, it, true) }

            config.optString("scriptEffectCode", DEFAULT_SCRIPT_CODE).let { audioProcess.setEffectParam(EffectParam.SCRIPT_EFFECT_CODE.ordinal, it, true) }
            config.optJSONArray("scriptEffectParams")?.let { params ->
                val buffer = java.nio.ByteBuffer.allocate(16 * 68).apply {
                    order(java.nio.ByteOrder.LITTLE_ENDIAN)
                }
                for (i in 0 until params.length()) {
                    val param = params.getJSONObject(i)
                    val name = param.optString("name", "")
                    val nameBytes = name.toByteArray(Charsets.UTF_8)
                    val nameLen = minOf(nameBytes.size, 63)
                    buffer.put(nameBytes, 0, nameLen)
                    for (j in nameLen until 64) buffer.put(0)
                    buffer.putFloat(param.optDouble("value", 0.0).toFloat())
                }
                audioProcess.setEffectParam(EffectParam.SCRIPT_EFFECT_PARAMS.ordinal, buffer.array(), true)
            }
            config.optBoolean("scriptEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.SCRIPT_EFFECT_ENABLED.ordinal, it, true) }

            config.optInt("diffSurroundingEffectDelayMs", 3).let { audioProcess.setEffectParam(EffectParam.DIFF_SURROUNDING_EFFECT_DELAY_MS.ordinal, it, true) }
            config.optBoolean("diffSurroundingEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.DIFF_SURROUNDING_EFFECT_ENABLED.ordinal, it, true) }

            config.optString("deviceSimulationEffectConfig", "").let { audioProcess.setEffectParam(EffectParam.DEVICE_SIMULATION_EFFECT_CONFIG.ordinal, it, true) }
            config.optBoolean("deviceSimulationEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.DEVICE_SIMULATION_EFFECT_ENABLED.ordinal, it, true) }

            Log.i(TAG, "Config applied successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply config from JSON", e)
        }
    }
}
