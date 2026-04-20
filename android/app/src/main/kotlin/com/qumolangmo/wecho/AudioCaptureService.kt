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
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import android.os.Process
import android.util.Log
import androidx.annotation.RequiresPermission
import androidx.core.app.NotificationCompat
import java.util.concurrent.ArrayBlockingQueue

class AudioCaptureService : Service() {

    companion object {
        const val TAG = "AudioCaptureService"
        const val ACTION_START = "com.qumolangmo.wecho.action.START"
        const val ACTION_STOP = "com.qumolangmo.wecho.action.STOP"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_RESULT_DATA = "resultData"
        const val PROCESS_CHUNK_SIZE_PER_CHANNEL = 480
    }

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null

    private var singleProcessThread: Thread? = null

    private val PROCESSING_TIME_LOG_INTERVAL_US = 2000000L
    private var lastProcessingTimeLogUs: Long = 0
    private var processingTimeSumUs: Long = 0
    private var processingFrameCount: Int = 0


    override fun onCreate() {
        super.onCreate()
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && ACTION_START == intent.action) {
            startForegroundWithNotification()

            val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
            val resultData: Intent? = intent.getParcelableExtra(EXTRA_RESULT_DATA)

            if (resultData != null) {
                mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, resultData)
                if (mediaProjection != null) {
                    startAudioCapture()
                } else {
                    Log.e(TAG, "Failed to get MediaProjection.")
                    stopSelf()
                }
            } else {
                Log.e(TAG, "Result data for MediaProjection is null.")
                stopSelf()
            }

            return START_STICKY
        } else if (intent != null && ACTION_STOP == intent.action) {
            stopAudioCapture()
            return START_NOT_STICKY
        }
        return START_NOT_STICKY
    }

    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun startAudioCapture() {
        val config = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            /* Exclude our own app's audio to prevent feedback loop */
            .excludeUid(Process.myUid())
            .build()

        /* build an audioFormat with 48000hz, 2 channels, float data per samples */
        val audioFormat = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setSampleRate(48000)
            .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
            .build()

        /* calculate record and playback min buffer unit size */
        val recordBufferSizeInBytes = AudioRecord.getMinBufferSize(48000, AudioFormat.CHANNEL_IN_STEREO, AudioFormat.ENCODING_PCM_FLOAT)
        val playbackBufferSizeInBytes = AudioTrack.getMinBufferSize(48000, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_FLOAT)

        Log.d(TAG, "AudioRecord minBufferSize: $recordBufferSizeInBytes")
        Log.d(TAG, "AudioTrack minBufferSize: $playbackBufferSizeInBytes")

        try {
            /* build audio recorder */
            audioRecord = AudioRecord.Builder()
                .setAudioFormat(audioFormat)
                .setBufferSizeInBytes(recordBufferSizeInBytes * 2)
                .setAudioPlaybackCaptureConfig(config)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AudioRecord", e)
            return
        }

        /* set play stream attributes */
        val playbackAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        /* use the same param with recorder */
        val playbackFormat = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setSampleRate(48000)
            .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
            .build()

        try {
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(playbackAttributes)
                .setAudioFormat(playbackFormat)
                .setBufferSizeInBytes(playbackBufferSizeInBytes)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AudioTrack", e)
            audioRecord?.release()
            return
        }

        val audioProcess = com.qumolangmo.wecho.AudioProcess.getInstance()
        audioProcess.masterEnabled = true

        val samplesPerFrame = PROCESS_CHUNK_SIZE_PER_CHANNEL * 2

        singleProcessThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            try {
                val inBuffer = FloatArray(samplesPerFrame)
                val outBuffer = FloatArray(samplesPerFrame)
                while (!Thread.currentThread().isInterrupted) {
                    audioRecord?.read(inBuffer, 0, samplesPerFrame, AudioRecord.READ_BLOCKING)
                    val startTimeUs = System.nanoTime() / 1000
                    audioProcess.process(inBuffer, outBuffer, samplesPerFrame)
                    val endTimeUs = System.nanoTime() / 1000
                    audioTrack?.write(outBuffer, 0, samplesPerFrame, AudioTrack.WRITE_BLOCKING)

                    val processingTimeUs = endTimeUs - startTimeUs
                    processingTimeSumUs += processingTimeUs
                    processingFrameCount++
                    
                    val currentTimeUs = System.nanoTime() / 1000
                    if (currentTimeUs - lastProcessingTimeLogUs > PROCESSING_TIME_LOG_INTERVAL_US) {
                        if (processingFrameCount > 0) {
                            val averageProcessingTimeUs = processingTimeSumUs / processingFrameCount
                            Log.i(TAG, "Processing time - Current: ${processingTimeUs}us, Average: ${averageProcessingTimeUs}us, Frames: $processingFrameCount")
                        }
                        processingTimeSumUs = 0
                        processingFrameCount = 0
                        lastProcessingTimeLogUs = currentTimeUs
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, e.toString())
            }
        }, "singleProcessThread")

        audioRecord?.startRecording()
        audioTrack?.play()

        singleProcessThread?.start()

        forceRemoteSubmixFullVolume(true)
    }

    private fun stopAudioCapture() {
        val audioProcess = AudioProcess.getInstance()
        audioProcess.masterEnabled = false

        singleProcessThread?.interrupt()
        singleProcessThread = null

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null

        mediaProjection?.stop()
        mediaProjection = null

        stopForeground(true)
        stopSelf()
    }

    private fun startForegroundWithNotification() {
        val channelId = "audio_capture_channel"
        val channel = NotificationChannel(
            channelId, 
            "Audio Capture", 
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Audio capture service notification"
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Audio Capture")
            .setContentText("Capturing audio from other apps.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()

        startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun forceRemoteSubmixFullVolume(enable: Boolean) {
        try {
            val serviceManager = Class.forName("android.os.ServiceManager")
            val getService = serviceManager.getMethod("getService", String::class.java)
            val binder = getService.invoke(null, "audio") as IBinder

            val audioServiceClass = Class.forName("android.media.IAudioService\$Stub")
            val asInterface = audioServiceClass.getMethod("asInterface", IBinder::class.java)
            val audioService = asInterface.invoke(null, binder)

            val forceMethod = audioService.javaClass.getMethod(
                "forceRemoteSubmixFullVolume",
                Boolean::class.javaPrimitiveType,
                IBinder::class.java
            )

            forceMethod.invoke(audioService, enable, null)
            Log.d("MainActivity", "forceRemoteSubmixFullVolume called successfully")

        } catch (e: Exception) {
            Log.e("MainActivity", "forceRemoteSubmixFullVolume failed: ${e.message}", e)
        }
    }
}