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

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import rikka.shizuku.Shizuku

@RequiresApi(Build.VERSION_CODES.N)
class WechoTileService : TileService() {

    companion object {
        private const val TAG = "wecho-kotlin:WechoTileService"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TILE_CAPTURING = "flutter.tileCapturing"
    }

    enum class EffectParam {
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
        CONVOLVE_EFFECT_IR_DATA,
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
        IIR_EQUALIZER_EFFECT_COEFFS,
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
        SCRIPT_EFFECT_CODE
    }

    private lateinit var sharedPreferences: SharedPreferences
    private val audioProcess = AudioProcess.getInstance()
    private var audioDeviceMonitor: AudioDeviceMonitor? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "WechoTileService onCreate")
        sharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        audioDeviceMonitor = AudioDeviceMonitor.getInstance(this)
        audioProcess.init(this)
    }

    override fun onStartListening() {
        super.onStartListening()
        Log.i(TAG, "WechoTileService onStartListening")
        updateTileState()
    }

    override fun onClick() {
        super.onClick()
        Log.i(TAG, "WechoTileService onClick called")
        
        if (!checkShizukuPermission()) {
            Log.w(TAG, "Shizuku permission not granted, tile disabled")
            return
        }

        val isCapturing = sharedPreferences.getBoolean(KEY_TILE_CAPTURING, false)
        Log.i(TAG, "Current capturing state: $isCapturing")
        
        if (isCapturing) {
            stopCapture()
        } else {
            startCapture()
        }
    }

    private fun checkShizukuPermission(): Boolean {
        if (!Shizuku.pingBinder()) {
            Log.w(TAG, "Shizuku service not running")
            return false
        }
        
        return Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    }

    private fun startCapture() {
        Log.i(TAG, "Starting capture from tile")
        
        val currentOutput = audioDeviceMonitor?.getCurrentOutput() ?: "speaker"
        val configKey = when {
            currentOutput.contains("headphone", ignoreCase = true) || 
            currentOutput.contains("headset", ignoreCase = true) ||
            currentOutput.contains("bluetooth", ignoreCase = true) -> "flutter.config_headphone"
            else -> "flutter.config_speaker"
        }

        val configJson = sharedPreferences.getString(configKey, null)
        
        if (configJson != null) {
            applyConfigFromJson(configJson)
            Log.i(TAG, "Applied config for output: $currentOutput, key: $configKey")
        } else {
            Log.w(TAG, "No config found for key: $configKey, using default")
        }

        audioProcess.masterEnabled = true

        val activityIntent = Intent(this, TileCaptureActivity::class.java).apply {
            putExtra(TileCaptureActivity.EXTRA_ACTION, TileCaptureActivity.ACTION_START)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        startActivityAndCollapse(pendingIntent)

        sharedPreferences.edit().putBoolean(KEY_TILE_CAPTURING, true).apply()
        updateTileState()
    }

    private fun stopCapture() {
        Log.i(TAG, "Stopping capture from tile")
        
        val activityIntent = Intent(this, TileCaptureActivity::class.java).apply {
            putExtra(TileCaptureActivity.EXTRA_ACTION, TileCaptureActivity.ACTION_STOP)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 1, activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        startActivityAndCollapse(pendingIntent)

        sharedPreferences.edit().putBoolean(KEY_TILE_CAPTURING, false).apply()
        updateTileState()
    }

    private fun applyConfigFromJson(json: String) {
        try {
            val config = org.json.JSONObject(json)
            
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
            config.optString("convolveEffectIrData", "").let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_IR_DATA.ordinal, it, true) }
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
            
            config.optJSONArray("iirEqualizerEffectCoeffs")?.let { coeffs ->
                val buffer = java.nio.ByteBuffer.allocate(coeffs.length() * 16).apply {
                    order(java.nio.ByteOrder.LITTLE_ENDIAN)
                }
                for (i in 0 until coeffs.length()) {
                    val coeff = coeffs.getJSONObject(i)
                    buffer.putInt(coeff.optInt("index", 0))
                    buffer.putInt(coeff.optInt("start_freq", 0))
                    buffer.putInt(coeff.optInt("end_freq", 0))
                    buffer.putInt(coeff.optInt("gain", 0))
                }
                audioProcess.setEffectParam(EffectParam.IIR_EQUALIZER_EFFECT_COEFFS.ordinal, buffer.array(), true)
            }
            config.optBoolean("iirEqualizerEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.IIR_EQUALIZER_EFFECT_ENABLED.ordinal, it, true) }
            
            config.optDouble("virtualbassEffectMidGain", 0.5).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_MID_GAIN.ordinal, it, true) }
            config.optDouble("virtualbassEffectHighGain", 0.5).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_HIGH_GAIN.ordinal, it, true) }
            config.optDouble("virtualbassEffectHarmonicGain", 1.30).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_HARMONIC_GAIN.ordinal, it, true) }
            config.optInt("virtualbassEffectEnvelopeRate", 40).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_ENVELOPE_RATE.ordinal, it, true) }
            config.optBoolean("virtualbassEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.VIRTUALBASS_EFFECT_ENABLED.ordinal, it, true) }

            
            config.optInt("reverbEffectRoomSize", 30).let { audioProcess.setEffectParam(EffectParam.REVERB_EFFECT_ROOM_SIZE.ordinal, it, true) }
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
            
            Log.i(TAG, "Config applied successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply config from JSON", e)
        }
    }

    private fun updateTileState() {
        val isCapturing = sharedPreferences.getBoolean(KEY_TILE_CAPTURING, false)
        val isShizukuGranted = checkShizukuPermission()
        
        qsTile?.apply {
            state = when {
                !isShizukuGranted -> Tile.STATE_UNAVAILABLE
                isCapturing -> Tile.STATE_ACTIVE
                else -> Tile.STATE_INACTIVE
            }
            
            label = if (isCapturing) "Wecho (ON)" else "Wecho (OFF)"
            
            updateTile()
        }
        
        Log.d(TAG, "Tile state updated: capturing=$isCapturing, shizuku=$isShizukuGranted")
    }
}
