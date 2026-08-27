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
            config.optDouble("bassEffectQ", 0.7).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_Q.ordinal, it, true) }
            config.optBoolean("bassEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_ENABLED.ordinal, it, true) }

            config.optInt("clarityEffectGain", 0).let { audioProcess.setEffectParam(EffectParam.CLARITY_EFFECT_GAIN.ordinal, it, true) }
            config.optBoolean("clarityEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.CLARITY_EFFECT_ENABLED.ordinal, it, true) }

            config.optDouble("evenHarmonicEffectBase", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_BASE.ordinal, it, true) }
            config.optDouble("evenHarmonicEffectWarm", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_WARM.ordinal, it, true) }
            config.optDouble("evenHarmonicEffectSugar", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_SUGAR.ordinal, it, true) }
            config.optBoolean("evenHarmonicEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_ENABLED.ordinal, it, true) }

            config.optDouble("convolveEffectMix", 0.0).let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_MIX.ordinal, it, true) }
            config.optString("convolveEffectIrPath", "").let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_IR_PATH.ordinal, it, true) }
            config.optBoolean("convolveEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_ENABLED.ordinal, it, true) }

            config.optInt("compressorEffectThreshold", 0).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_THRESHOLD.ordinal, it, true) }
            config.optInt("compressorEffectRatio", 0).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_RATIO.ordinal, it, true) }
            config.optInt("compressorEffectMakeupGain", 0).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_MAKEUP_GAIN.ordinal, it, true) }
            config.optInt("compressorEffectAttack", 0).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_ATTACK.ordinal, it, true) }
            config.optInt("compressorEffectRelease", 0).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_RELEASE.ordinal, it, true) }
            config.optBoolean("compressorEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.COMPRESSOR_EFFECT_ENABLED.ordinal, it, true) }

            config.optBoolean("lookAheadSoftLimitEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED.ordinal, it, true) }

            config.optInt("lowcatEffectCutoffFrequency", 0).let { audioProcess.setEffectParam(EffectParam.LOWCUT_EFFECT_CUTOFF_FREQUENCY.ordinal, it, true) }
            config.optBoolean("lowcatEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.LOWCUT_EFFECT_ENABLED.ordinal, it, true) }

            config.optString("iirEqualizerEffectConfig", "").let { audioProcess.setEffectParam(EffectParam.IIR_EQUALIZER_EFFECT_CONFIG.ordinal, it, true) }
            config.optBoolean("iirEqualizerEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.IIR_EQUALIZER_EFFECT_ENABLED.ordinal, it, true) }

            config.optDouble("virtualbassEffectMidGain", 0.5).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_MID_GAIN.ordinal, it, true) }
            config.optDouble("virtualbassEffectHighGain", 0.5).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_HIGH_GAIN.ordinal, it, true) }
            config.optDouble("virtualbassEffectHarmonicGain", 1.30).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_HARMONIC_GAIN.ordinal, it, true) }
            config.optInt("virtualbassEffectEnvelopeRate", 40).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_ENVELOPE_RATE.ordinal, it, true) }
            config.optBoolean("virtualbassEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_ENABLED.ordinal, it, true) }


            config.optDouble("reverbEffectRoomSize", 0.54).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_ROOM_SIZE.ordinal, it, true) }
            config.optDouble("reverbEffectDamping", 0.5).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_DAMPING.ordinal, it, true) }
            config.optDouble("reverbEffectMix", 0.5).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_MIX.ordinal, it, true) }
            config.optDouble("reverbEffectStereoWidth", 0.5).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_STEREO_WIDTH.ordinal, it, true) }
            config.optDouble("reverbEffectModDepth", 0.5).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_MOD_DEPTH.ordinal, it, true) }
            config.optDouble("reverbEffectModFreq", 0.5).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_MOD_FREQ.ordinal, it, true) }
            config.optInt("reverbEffectPreDelay", 0).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_PRE_DELAY.ordinal, it, true) }
            config.optInt("reverbEffectMatrixType", 0).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_MATRIX_TYPE.ordinal, it, true) }
            config.optBoolean("reverbEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_ENABLED.ordinal, it, true) }

            config.optString("scriptEffectCode", "").let { audioProcess.setEffectParam(EffectParam.SCRIPT_EFFECT_CODE.ordinal, it, true) }
            config.optJSONArray("scriptEffectParams")?.let { params ->
                val buffer = java.nio.ByteBuffer.allocate(params.length() * 68).apply {
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

            config.optInt("diffSurroundingEffectDelayMs", 0).let { audioProcess.setEffectParam(EffectParam.DIFF_SURROUNDING_EFFECT_DELAY_MS.ordinal, it, true) }
            config.optBoolean("diffSurroundingEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.DIFF_SURROUNDING_EFFECT_ENABLED.ordinal, it, true) }

            config.optString("deviceSimulationEffectConfig", "").let { audioProcess.setEffectParam(EffectParam.DEVICE_SIMULATION_EFFECT_CONFIG.ordinal, it, true) }
            config.optBoolean("deviceSimulationEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.DEVICE_SIMULATION_EFFECT_ENABLED.ordinal, it, true) }

            Log.i(TAG, "Config applied successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply config from JSON", e)
        }
    }
}
