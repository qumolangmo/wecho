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
import android.content.SharedPreferences
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class CustomUiTileService : TileService() {

    companion object {
        private const val TAG = "wecho-kotlin:CustomUiTileService"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_CUSTOM_UI_ENABLED = "flutter.custom_ui_enabled"
    }

    private lateinit var sharedPreferences: SharedPreferences

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "CustomUiTileService onCreate")
        sharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()

        if (isLocked()) {
            unlockAndRun { disableCustomUi() }
        } else {
            disableCustomUi()
        }
    }

    /* Escape hatch: one click restores the native UI when a script breaks it. */
    private fun disableCustomUi() {
        Log.i(TAG, "Custom UI disabled from quick settings tile")
        sharedPreferences.edit()
            .putBoolean(KEY_CUSTOM_UI_ENABLED, false)
            .apply()
        applyTileUi(false)
    }

    private fun updateTileState() {
        val enabled = sharedPreferences.getBoolean(KEY_CUSTOM_UI_ENABLED, false)
        applyTileUi(enabled)
    }

    private fun applyTileUi(enabled: Boolean) {
        qsTile?.apply {
            state = if (enabled) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            updateTile()
        }
    }
}
