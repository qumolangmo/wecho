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
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
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
import android.os.Handler
import android.os.Looper
import org.json.JSONArray

class AudioCaptureService : Service() {

    companion object {
        const val TAG = "wecho-kotlin:AudioCaptureService"
        const val ACTION_START = "com.qumolangmo.wecho.action.START"
        const val ACTION_START_FROM_TILE = "com.qumolangmo.wecho.action.START_FROM_TILE"
        const val ACTION_STOP = "com.qumolangmo.wecho.action.STOP"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_RESULT_DATA = "resultData"
        const val PROCESS_CHUNK_SIZE_PER_CHANNEL = 512
        
        @Volatile
        var isCurrentlyCapturing = false
            private set

        @Volatile
        var processingLatencyMs = 0.0
            private set

        @Volatile
        var muteUntilNanos: Long = 0L
            private set

        fun startMutePeriod(durationMs: Long) {
            muteUntilNanos = System.nanoTime() + durationMs * 2_000_000L
        }

        private var latencySum = 0.0
        private var latencyCount = 0
    }

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null

    private var singleProcessThread: Thread? = null

    private var muteEffectFactory: MuteEffectFactory? = null
    private var isTileMode = false


    override fun onCreate() {
        super.onCreate()
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        muteEffectFactory = MuteEffectFactory(this, packageName)
        Log.i(TAG, "MuteEffectFactory initialized")

        MuteEffectFactory.sessionLostStateListener = { sid, pkgName ->
            Log.i(TAG, "Audio session lost: sid=$sid, package=$pkgName")
        }
    }

    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && ACTION_STOP == intent.action) {
            stopAudioCapture()
            return START_NOT_STICKY
        }

        if (isCurrentlyCapturing) {
            Log.w(TAG, "Already capturing, ignoring start request")
            return START_NOT_STICKY
        }

        if (intent != null && (ACTION_START == intent.action || ACTION_START_FROM_TILE == intent.action)) {
            val isFromTile = intent.getBooleanExtra("fromTile", false)
            
            if (isFromTile) {
                startForegroundWithNotification()
                startAudioCaptureFromTile(intent)
            } else {
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
                    Log.e(TAG, "No MediaProjection resultData provided")
                    stopSelf()
                }
            }

            return START_STICKY
        }
        return START_NOT_STICKY
    }

    private fun getBlacklistUids(): List<Int> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("flutter.appBlacklist", "[]") ?: "[]"
        val arr = JSONArray(json)
        val uids = mutableListOf<Int>()
        for (i in 0 until arr.length()) {
            try {
                uids.add(packageManager.getApplicationInfo(arr.getString(i), 0).uid)
            } catch (_: PackageManager.NameNotFoundException) {}
        }
        return uids
    }

    private fun getBlacklistPackageNames(): Set<String> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("flutter.appBlacklist", "[]") ?: "[]"
        val arr = JSONArray(json)
        val names = mutableSetOf<String>()
        for (i in 0 until arr.length()) {
            val name = arr.optString(i, null)
            if (name != null) names.add(name)
        }
        return names
    }

    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun startAudioCapture() {
        isCurrentlyCapturing = true

        /* init unmuteable packages */
        MuteEffectFactory.blacklistedPackages = getBlacklistPackageNames()

        val builder = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            /* Exclude our own app's audio to prevent feedback loop */
            .excludeUid(Process.myUid())
        for (uid in getBlacklistUids()) { builder.excludeUid(uid) }
        val config = builder.build()

        startAudioCaptureInternal(config)
    }

    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun startAudioCaptureFromTile(startIntent: Intent) {
        isCurrentlyCapturing = true
        isTileMode = true

        if (muteEffectFactory == null) {
            Log.e(TAG, "MuteEffectFactory not initialized")
            stopSelf()
            return
        }

        val resultCode = startIntent.getIntExtra(EXTRA_RESULT_CODE, 0)
        val resultData: Intent? = startIntent.getParcelableExtra(EXTRA_RESULT_DATA)

        Log.i(TAG, "Tile capture - resultCode=$resultCode, hasResultData=${resultData != null}")

        if (resultData == null) {
            Log.e(TAG, "No MediaProjection result data, cannot start capture from tile")
            stopSelf()
            return
        }

        mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, resultData)
        if (mediaProjection == null) {
            Log.e(TAG, "Failed to get MediaProjection from tile")
            stopSelf()
            return
        }

        Log.i(TAG, "MediaProjection obtained for tile capture")
        
        /* init unmuteable packages */
        MuteEffectFactory.blacklistedPackages = getBlacklistPackageNames()

        val builder = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .excludeUid(Process.myUid())
        for (uid in getBlacklistUids()) { builder.excludeUid(uid) }
        val config = builder.build()

        startAudioCaptureInternal(config)
    }

    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun startAudioCaptureInternal(config: AudioPlaybackCaptureConfiguration) {

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
                var nonMute = 1e-7f

                while (!Thread.currentThread().isInterrupted) {
                    audioRecord?.read(inBuffer, 0, samplesPerFrame, AudioRecord.READ_BLOCKING)

                    for (i in 0 until inBuffer.size step 2) {
                        inBuffer[i] += nonMute
                        inBuffer[i+1] += nonMute
                        nonMute = -nonMute
                    }

                    val t0 = System.nanoTime()
                    audioProcess.process(inBuffer, outBuffer, samplesPerFrame)
                    latencySum += (System.nanoTime() - t0) / 1_000_000.0
                    latencyCount++
                    if (latencyCount >= 10) {
                        processingLatencyMs = latencySum / latencyCount
                        latencySum = 0.0
                        latencyCount = 0
                    }

                    val currentTime = System.nanoTime()
                    if (currentTime < muteUntilNanos) {
                        for (i in outBuffer.indices) {
                            outBuffer[i] = 0.0f
                        }
                    }

                    audioTrack?.write(outBuffer, 0, samplesPerFrame, AudioTrack.WRITE_BLOCKING)
                }
            } catch (e: Exception) {
                Log.d(TAG, e.toString())
            }
        }, "singleProcessThread")

        audioRecord?.startRecording()
        audioTrack?.play()

        singleProcessThread?.start()

        if (muteEffectFactory != null) {
            muteEffectFactory?.registerPlaybackCallback()
            muteEffectFactory?.dumpAudioSessions { sessions -> muteEffectFactory?.muteOtherSessions(sessions) }
        }
    }

    private fun stopAudioCapture() {
        isCurrentlyCapturing = false
        
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.tileCapturing", false).apply()
        
        muteEffectFactory?.unregisterPlaybackCallback()
        muteEffectFactory?.releaseAll()
        muteEffectFactory = null

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

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopAudioCapture()
        Log.d(TAG, "onTaskRemoved")
        super.onTaskRemoved(rootIntent)
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
            .setSmallIcon(R.drawable.ic_wecho_tile)
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

    fun getAllAudioSessionIds(): Set<Int> {
        val ids = mutableSetOf<Int>()
        audioRecord?.audioSessionId?.let { if (it != 0) ids.add(it) }
        audioTrack?.audioSessionId?.let { if (it != 0) ids.add(it) }
        return ids
    }

}