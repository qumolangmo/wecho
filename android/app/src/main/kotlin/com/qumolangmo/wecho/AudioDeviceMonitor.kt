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
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioDeviceCallback
import android.util.Log

/**
 * Audio device monitor for detecting speaker/headphone switching
 */
class AudioDeviceMonitor private constructor(private val context: Context) {

    private val audioManager: AudioManager by lazy {
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private var deviceCallback: AudioDeviceCallback? = null
    private var isRegistered = false

    fun register() {
        if (isRegistered) return

        deviceCallback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(devices: Array<AudioDeviceInfo>) {
                Log.d(TAG, "Devices added: ${devices.size}")
            }

            override fun onAudioDevicesRemoved(devices: Array<AudioDeviceInfo>) {
                Log.d(TAG, "Devices removed: ${devices.size}")
            }
        }

        audioManager.registerAudioDeviceCallback(deviceCallback, null)
        isRegistered = true
    }

    fun unregister() {
        if (!isRegistered) return

        deviceCallback?.let { callback ->
            audioManager.unregisterAudioDeviceCallback(callback)
        }
        deviceCallback = null
        isRegistered = false
    }

    fun getCurrentOutput(): String {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

        val hasHeadphones = devices.any { device ->
            when (device.type) {
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_USB_HEADSET,
                AudioDeviceInfo.TYPE_BLE_HEADSET -> true
                else -> false
            }
        }

        return if (hasHeadphones) "headphones" else "speaker"
    }

    companion object {
        private const val TAG = "AudioDeviceMonitor"

        @Volatile
        private var instance: AudioDeviceMonitor? = null

        fun getInstance(context: Context): AudioDeviceMonitor {
            return instance ?: synchronized(this) {
                instance ?: AudioDeviceMonitor(context.applicationContext).also { instance = it }
            }
        }
    }
}
