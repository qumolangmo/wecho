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

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat

class TileCaptureActivity : Activity() {

    companion object {
        const val TAG = "TileCaptureActivity"
        const val EXTRA_ACTION = "action"
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
        const val REQUEST_CODE_MEDIA_PROJECTION = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val action = intent?.getStringExtra(EXTRA_ACTION)
        
        if (action == ACTION_STOP) {
            val serviceIntent = Intent(this, AudioCaptureService::class.java).apply {
                this.action = AudioCaptureService.ACTION_STOP
            }
            startService(serviceIntent)
            finish()
        } else {
            Log.i(TAG, "Requesting MediaProjection")
            val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
            startActivityForResult(captureIntent, REQUEST_CODE_MEDIA_PROJECTION)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        Log.i(TAG, "onActivityResult: requestCode=$requestCode, resultCode=$resultCode, data=${data != null}")
        
        if (requestCode == REQUEST_CODE_MEDIA_PROJECTION && resultCode == RESULT_OK && data != null) {
            Log.i(TAG, "MediaProjection granted, starting service")
            val serviceIntent = Intent(this, AudioCaptureService::class.java).apply {
                this.action = AudioCaptureService.ACTION_START_FROM_TILE
                putExtra("fromTile", true)
                putExtra(AudioCaptureService.EXTRA_RESULT_CODE, resultCode)
                putExtra(AudioCaptureService.EXTRA_RESULT_DATA, data)
            }
            ContextCompat.startForegroundService(this, serviceIntent)
        } else {
            Log.e(TAG, "MediaProjection denied or cancelled: resultCode=$resultCode, data=${data != null}")
        }
        
        finish()
    }
}
