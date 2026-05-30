/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
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
        private const val TAG = "WechoTileService"
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
        LIMITER_EFFECT_ENABLED,
        LIMITER_EFFECT_THRESHOLD,
        LIMITER_EFFECT_RATIO,
        LIMITER_EFFECT_MAKEUP_GAIN,
        LIMITER_EFFECT_ATTACK,
        LIMITER_EFFECT_RELEASE,
        SPEAKER_EFFECT_ENABLED,
        SPEAKER_EFFECT_HP_GAIN,
        SPEAKER_EFFECT_BP_GAIN,
        SPEAKER_EFFECT_2_HARMONIC_COEFFS,
        SPEAKER_EFFECT_4_HARMONIC_COEFFS,
        SPEAKER_EFFECT_6_HARMONIC_COEFFS,
        LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED,
        LOWCUT_EFFECT_ENABLED,
        LOWCUT_EFFECT_CUTOFF_FREQUENCY,
        IIR_EQUALIZER_EFFECT_ENABLED,
        IIR_EQUALIZER_EFFECT_COEFFS
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
            
            config.optDouble("gainEffectGain", 0.0).let { audioProcess.setEffectParam(EffectParam.GAIN_EFFECT_GAIN.ordinal, it) }
            config.optDouble("balanceEffectBalance", 0.0).let { audioProcess.setEffectParam(EffectParam.BALANCE_EFFECT_BALANCE.ordinal, it) }
            
            config.optInt("bassEffectGain", 0).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_GAIN.ordinal, it) }
            config.optInt("bassEffectCenterFreq", 60).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_CENTER_FREQ.ordinal, it) }
            config.optDouble("bassEffectQ", 0.7).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_Q.ordinal, it) }
            config.optBoolean("bassEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.BASS_EFFECT_ENABLED.ordinal, it) }
            
            config.optInt("clarityEffectGain", 0).let { audioProcess.setEffectParam(EffectParam.CLARITY_EFFECT_GAIN.ordinal, it) }
            config.optBoolean("clarityEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.CLARITY_EFFECT_ENABLED.ordinal, it) }
            
            config.optDouble("evenHarmonicEffectBase", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_BASE.ordinal, it) }
            config.optDouble("evenHarmonicEffectWarm", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_WARM.ordinal, it) }
            config.optDouble("evenHarmonicEffectSugar", 0.0).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_SUGAR.ordinal, it) }
            config.optBoolean("evenHarmonicEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.EVEN_HARMONIC_EFFECT_ENABLED.ordinal, it) }
            
            config.optDouble("convolveEffectMix", 0.0).let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_MIX.ordinal, it) }
            config.optString("convolveEffectIrPath", "").let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_IR_PATH.ordinal, it) }
            config.optString("convolveEffectIrData", "").let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_IR_DATA.ordinal, it) }
            config.optBoolean("convolveEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.CONVOLVE_EFFECT_ENABLED.ordinal, it) }
            
            config.optInt("limiterEffectThreshold", 0).let { audioProcess.setEffectParam(EffectParam.LIMITER_EFFECT_THRESHOLD.ordinal, it) }
            config.optInt("limiterEffectRatio", 0).let { audioProcess.setEffectParam(EffectParam.LIMITER_EFFECT_RATIO.ordinal, it) }
            config.optInt("limiterEffectMakeupGain", 0).let { audioProcess.setEffectParam(EffectParam.LIMITER_EFFECT_MAKEUP_GAIN.ordinal, it) }
            config.optInt("limiterEffectAttack", 0).let { audioProcess.setEffectParam(EffectParam.LIMITER_EFFECT_ATTACK.ordinal, it) }
            config.optInt("limiterEffectRelease", 0).let { audioProcess.setEffectParam(EffectParam.LIMITER_EFFECT_RELEASE.ordinal, it) }
            config.optBoolean("limiterEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.LIMITER_EFFECT_ENABLED.ordinal, it) }
            
            config.optDouble("speakerEffectHpGain", 0.0).let { audioProcess.setEffectParam(EffectParam.SPEAKER_EFFECT_HP_GAIN.ordinal, it) }
            config.optDouble("speakerEffectBpGain", 0.0).let { audioProcess.setEffectParam(EffectParam.SPEAKER_EFFECT_BP_GAIN.ordinal, it) }
            config.optDouble("speakerEffect2HarmonicCoeffs", 0.0).let { audioProcess.setEffectParam(EffectParam.SPEAKER_EFFECT_2_HARMONIC_COEFFS.ordinal, it) }
            config.optDouble("speakerEffect4HarmonicCoeffs", 0.0).let { audioProcess.setEffectParam(EffectParam.SPEAKER_EFFECT_4_HARMONIC_COEFFS.ordinal, it) }
            config.optDouble("speakerEffect6HarmonicCoeffs", 0.0).let { audioProcess.setEffectParam(EffectParam.SPEAKER_EFFECT_6_HARMONIC_COEFFS.ordinal, it) }
            config.optBoolean("speakerEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.SPEAKER_EFFECT_ENABLED.ordinal, it) }
            
            config.optBoolean("lookAheadSoftLimitEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED.ordinal, it) }
            
            config.optInt("lowcatEffectCutoffFrequency", 0).let { audioProcess.setEffectParam(EffectParam.LOWCUT_EFFECT_CUTOFF_FREQUENCY.ordinal, it) }
            config.optBoolean("lowcatEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.LOWCUT_EFFECT_ENABLED.ordinal, it) }
            
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
                audioProcess.setEffectParam(EffectParam.IIR_EQUALIZER_EFFECT_COEFFS.ordinal, buffer.array())
            }
            config.optBoolean("iirEqualizerEffectEnabled", false).let { audioProcess.setEffectParam(EffectParam.IIR_EQUALIZER_EFFECT_ENABLED.ordinal, it) }
            
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
