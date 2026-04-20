/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

package com.qumolangmo.wecho

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "audio_capture"
    private val REQUEST_CODE_MEDIA_PROJECTION = 1001
    private val REQUEST_CODE_NOTIFICATION_PERMISSION = 1002
    
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
                    requestMediaProjection()
                    result.success(null)
                }
                "stopCapture" -> {
                    stopAudioCaptureService()
                    result.success(null)
                }
                "setEffectParam" -> {
                    try {
                        val paramId = call.argument<Int>("paramId")
                        val value = call.argument<Any>("value")
                        if (paramId != null && value != null) {
                            audioProcess.setEffectParam(paramId, value)
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
                        result.error("ERROR", e.message, null)
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
                            ShizukuHelpMe.checkShizukuStatusAndExecute()
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        AudioProcess.getInstance().init(this)
        
        // Initialize audio device monitor
        audioDeviceMonitor = AudioDeviceMonitor.getInstance(this)
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
        if (requestCode == REQUEST_CODE_NOTIFICATION_PERMISSION) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                requestMediaProjection()
            } else {
                updateUi(false)
            }
        }
    }

    private fun requestMediaProjection() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_CODE_NOTIFICATION_PERMISSION
                )
                return
            }
        }
        
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
