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
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class WechoTileService : TileService() {

    companion object {
        private const val TAG = "wecho-kotlin:WechoTileService"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TILE_CAPTURING = "flutter.tileCapturing"
        private const val TILE_CLICK_DEBOUNCE_MS = 1200L
    }

    private var lastClickTimeMs = 0L

    private lateinit var sharedPreferences: SharedPreferences
    private val audioProcess = AudioProcess.getInstance()
    private var audioDeviceMonitor: AudioDeviceMonitor? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "WechoTileService onCreate")
        sharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        audioDeviceMonitor = AudioDeviceMonitor.getInstance(this)
        audioProcess.init(48000, 512, 2, this)

        sharedPreferences.edit()
            .putBoolean(KEY_TILE_CAPTURING, AudioCaptureService.isCurrentlyCapturing)
            .apply()
    }

    override fun onStartListening() {
        super.onStartListening()
        Log.i(TAG, "WechoTileService onStartListening")
        updateTileState()
    }

    override fun onClick() {
        super.onClick()

        if (isLocked()) {
            unlockAndRun { handleTileClick() }
        } else {
            handleTileClick()
        }
    }

    private fun handleTileClick() {
        val now = System.currentTimeMillis()
        if (now - lastClickTimeMs < TILE_CLICK_DEBOUNCE_MS) {
            Log.d(TAG, "onClick debounced, ignoring")
            return
        }
        lastClickTimeMs = now

        Log.i(TAG, "WechoTileService onClick called")

        val isCapturing = isActuallyCapturing()

        if (isCapturing) {
            stopCapture()
        } else {
            startCapture()
        }
    }

    private fun startCapture() {
        Log.i(TAG, "Starting capture from tile")

        val activityIntent = Intent(this, TileCaptureActivity::class.java).apply {
            putExtra(TileCaptureActivity.EXTRA_ACTION, TileCaptureActivity.ACTION_START)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        startActivityAndCollapse(pendingIntent)

        applyTileUi(true)
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

        applyTileUi(false)
    }

    private fun isActuallyCapturing(): Boolean {
        return AudioCaptureService.isCurrentlyCapturing
    }

    private fun updateTileState() {
        val isCapturing = isActuallyCapturing()

        sharedPreferences.edit().putBoolean(KEY_TILE_CAPTURING, isCapturing).apply()

        applyTileUi(isCapturing)

        Log.d(TAG, "Tile state updated: capturing=$isCapturing")
    }

    private fun applyTileUi(capturing: Boolean) {
        qsTile?.apply {
            state = if (capturing) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            label = if (capturing) "Wecho (ON)" else "Wecho (OFF)"
            updateTile()
        }
    }
}
