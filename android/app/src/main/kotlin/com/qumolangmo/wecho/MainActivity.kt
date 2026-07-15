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

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "audio_capture"
    private val REQUEST_CODE_MEDIA_PROJECTION = 1001
    private val REQUEST_CODE_RUNTIME_PERMISSIONS = 1002
    
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var isCapturing = false
    private var channel: MethodChannel? = null
    private val audioProcess = AudioProcess.getInstance()
    
    private var audioDeviceMonitor: AudioDeviceMonitor? = null
    private var isAutoOutputSwitchEnabled = false
    
    private var isShizukuModeEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCapture" -> {
                    if (AudioCaptureService.isCurrentlyCapturing) {
                        Log.w(CHANNEL, "Already capturing, ignoring start request from Flutter")
                        result.success(null)
                    } else {
                        requestMediaProjection()
                        result.success(null)
                    }
                }
                "stopCapture" -> {
                    stopAudioCaptureService()
                    result.success(null)
                }
                "setEffectParam" -> {
                    try {
                        val paramId = call.argument<Int>("paramId")
                        val value = call.argument<Any>("value")
                        val initialize = call.argument<Boolean>("initialize") ?: false
                        if (paramId != null && value != null) {
                            audioProcess.setEffectParam(paramId, value, initialize)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "Missing paramId or value", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "setMasterEnabled" -> {
                    try {
                        val enabled = call.arguments as Boolean
                        audioProcess.masterEnabled = enabled
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, e)
                    }
                }
                "startMutePeriod" -> {
                    try {
                        val durationMs = call.arguments as Long
                        AudioCaptureService.startMutePeriod(durationMs)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, e)
                    }
                }
                "getAppVersion" -> {
                    try {
                        val packageInfo = packageManager.getPackageInfo(packageName, 0)
                        result.success(packageInfo.versionName)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "setShizukuMode" -> {
                    try {
                        val enabled = call.arguments as Boolean
                        isShizukuModeEnabled = enabled
                        if (enabled) {
                            ShizukuHelpMe.checkShizukuStatusAndExecute(this, onShizukuReady = {
                                requestMediaProjection()
                            })
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getShizukuStatus" -> {
                    try {
                        result.success(ShizukuHelpMe.isShizukuPermissionGranted())
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getCaptureStatus" -> {
                    try {
                        result.success(AudioCaptureService.isCurrentlyCapturing)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getProcessingLatency" -> {
                    try {
                        result.success(AudioCaptureService.processingLatencyMs)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "setAutoOutputSwitch" -> {
                    try {
                        val enabled = call.arguments as Boolean
                        isAutoOutputSwitchEnabled = enabled
                        if (enabled) {
                            audioDeviceMonitor?.register()
                        } else {
                            audioDeviceMonitor?.unregister()
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getAutoOutput" -> {
                    try {
                        result.success(audioDeviceMonitor?.getCurrentOutput())
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getInstalledApps" -> {
                    Thread {
                        try {
                            val pm = packageManager
                            val allApps = pm.getInstalledApplications(0)
                            val iconSize = 48
                            val apps = mutableListOf<Map<String, Any>>()
                            for (appInfo in allApps) {
                                if (appInfo.packageName == packageName) continue
                                try {
                                    val label = appInfo.loadLabel(pm)?.toString() ?: appInfo.packageName
                                    val isSystem = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0

                                    /* convert icon to png bytes */
                                    val iconBytes = try {
                                        val drawable = appInfo.loadIcon(pm)
                                        val bitmap = Bitmap.createBitmap(iconSize, iconSize, Bitmap.Config.ARGB_8888)
                                        val canvas = Canvas(bitmap)
                                        drawable.setBounds(0, 0, iconSize, iconSize)
                                        drawable.draw(canvas)
                                        val stream = java.io.ByteArrayOutputStream()
                                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                        bitmap.recycle()
                                        stream.toByteArray()
                                    } catch (_: Exception) { null }

                                    apps.add(mapOf(
                                        "packageName" to appInfo.packageName,
                                        "appName" to label,
                                        "uid" to appInfo.uid,
                                        "isSystem" to isSystem,
                                        "icon" to (iconBytes ?: ByteArray(0))
                                    ))
                                } catch (e: Exception) {
                                    Log.w(CHANNEL, "Failed to load label for ${appInfo.packageName}: ${e.message}")
                                }
                            }
                            apps.sortWith(compareBy<Map<String, Any>> { it["isSystem"] as Boolean }
                                .thenBy { (it["appName"] as String).lowercase() })
                            Log.d(CHANNEL, "getInstalledApps: count=${apps.size}")
                            Handler(Looper.getMainLooper()).post { result.success(apps) }
                        } catch (e: Exception) {
                            Log.e(CHANNEL, "getInstalledApps error: ${e.message}", e)
                            Handler(Looper.getMainLooper()).post { result.error("ERROR", e.message, null) }
                        }
                    }.start()
                }
                "openAppDetailSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.fromParts("package", packageName, null)
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        /* send compile error info from AudioProcess to JNI to Flutter. */
        audioProcess.onScriptCompileError = { error ->
            channel?.invokeMethod("onScriptCompileError", error)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        AudioProcess.getInstance().init(this)
        audioDeviceMonitor = AudioDeviceMonitor.getInstance(this)
        requestRuntimePermissions()
    }

    private fun requestRuntimePermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissionsToRequest = mutableListOf<String>()
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.RECORD_AUDIO)
            }
            if (permissionsToRequest.isNotEmpty()) {
                ActivityCompat.requestPermissions(this, permissionsToRequest.toTypedArray(), REQUEST_CODE_RUNTIME_PERMISSIONS)
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        audioDeviceMonitor?.unregister()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK) {
                startAudioCaptureService(resultCode, data)
            } else {
                updateUi(false)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun requestMediaProjection() {
        val intent = mediaProjectionManager?.createScreenCaptureIntent()
        startActivityForResult(intent, REQUEST_CODE_MEDIA_PROJECTION)
    }

    private fun startAudioCaptureService(resultCode: Int, data: Intent?) {
        val serviceIntent = Intent(this, AudioCaptureService::class.java).apply {
            action = AudioCaptureService.ACTION_START
            putExtra(AudioCaptureService.EXTRA_RESULT_CODE, resultCode)
            putExtra(AudioCaptureService.EXTRA_RESULT_DATA, data)
        }
        ContextCompat.startForegroundService(this, serviceIntent)
        updateUi(true)
    }

    private fun stopAudioCaptureService() {
        val serviceIntent = Intent(this, AudioCaptureService::class.java).apply {
            action = AudioCaptureService.ACTION_STOP
        }
        startService(serviceIntent)
        updateUi(false)
    }

    private fun updateUi(capturing: Boolean) {
        isCapturing = capturing
        channel?.invokeMethod("updateCaptureStatus", capturing)
    }
}
