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
            
            config.optDouble("gainEffectGain", 0.0).let { audioProcess.setEffectParam(0, it) }
            config.optDouble("balanceEffectBalance", 0.0).let { audioProcess.setEffectParam(1, it) }
            
            
            config.optInt("bassEffectGain", 0).let { audioProcess.setEffectParam(3, it) }
            config.optInt("bassEffectCenterFreq", 60).let { audioProcess.setEffectParam(4, it) }
            config.optDouble("bassEffectQ", 0.7).let { audioProcess.setEffectParam(5, it) }
            config.optBoolean("bassEffectEnabled", false).let { audioProcess.setEffectParam(2, it) }
            
            
            config.optInt("clarityEffectGain", 0).let { audioProcess.setEffectParam(7, it) }
            config.optBoolean("clarityEffectEnabled", false).let { audioProcess.setEffectParam(6, it) }
            
            
            config.optInt("evenHarmonicEffectGain", 0).let { audioProcess.setEffectParam(9, it) }
            config.optDouble("evenHarmonicEffectBase", 0.0).let { audioProcess.setEffectParam(10, it) }
            config.optDouble("evenHarmonicEffectWarm", 0.0).let { audioProcess.setEffectParam(11, it) }
            config.optDouble("evenHarmonicEffectSugar", 0.0).let { audioProcess.setEffectParam(12, it) }
            config.optBoolean("evenHarmonicEffectEnabled", false).let { audioProcess.setEffectParam(8, it) }
            
            
            config.optDouble("convolveEffectMix", 0.0).let { audioProcess.setEffectParam(14, it) }
            config.optString("convolveEffectIrPath", "").let { audioProcess.setEffectParam(15, it) }
            config.optString("convolveEffectIrData", "").let { audioProcess.setEffectParam(16, it) }
            config.optBoolean("convolveEffectEnabled", false).let { audioProcess.setEffectParam(13, it) }
            
            
            config.optInt("limiterEffectThreshold", 0).let { audioProcess.setEffectParam(18, it) }
            config.optInt("limiterEffectRatio", 0).let { audioProcess.setEffectParam(19, it) }
            config.optInt("limiterEffectMakeupGain", 0).let { audioProcess.setEffectParam(20, it) }
            config.optInt("limiterEffectAttack", 0).let { audioProcess.setEffectParam(21, it) }
            config.optInt("limiterEffectRelease", 0).let { audioProcess.setEffectParam(22, it) }
            config.optBoolean("limiterEffectEnabled", false).let { audioProcess.setEffectParam(17, it) }
            
            
            config.optDouble("speakerEffectHpGain", 0.0).let { audioProcess.setEffectParam(24, it) }
            config.optDouble("speakerEffectBpGain", 0.0).let { audioProcess.setEffectParam(25, it) }
            config.optDouble("speakerEffect2HarmonicCoeffs", 0.0).let { audioProcess.setEffectParam(26, it) }
            config.optDouble("speakerEffect4HarmonicCoeffs", 0.0).let { audioProcess.setEffectParam(27, it) }
            config.optDouble("speakerEffect6HarmonicCoeffs", 0.0).let { audioProcess.setEffectParam(28, it) }
            config.optBoolean("speakerEffectEnabled", false).let { audioProcess.setEffectParam(23, it) }
            
            config.optBoolean("lookAheadSoftLimitEffectEnabled", false).let { audioProcess.setEffectParam(29, it) }
            
            
            config.optInt("lowcatEffectCutoffFrequency", 0).let { audioProcess.setEffectParam(31, it) }
            config.optBoolean("lowcatEffectEnabled", false).let { audioProcess.setEffectParam(30, it) }
            
            
            config.optJSONArray("iirEqualizerEffectCoeffs")?.let { coeffs ->
                audioProcess.setEffectParam(33, coeffs.toString())
            }
            config.optBoolean("iirEqualizerEffectEnabled", false).let { audioProcess.setEffectParam(32, it) }
            
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
