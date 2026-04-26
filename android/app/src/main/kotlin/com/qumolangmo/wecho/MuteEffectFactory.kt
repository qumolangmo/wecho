/**
 * Copyright (c) 2026 qumolangmo
 *
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 *
 * For commercial use, please contact: qumolangmo@gmail.com
 */

package com.qumolangmo.wecho

import android.content.Context
import android.media.AudioManager
import android.media.AudioManager.AudioPlaybackCallback
import android.media.AudioPlaybackConfiguration
import android.media.AudioRecord
import android.media.audiofx.AudioEffect
import android.media.audiofx.DynamicsProcessing
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

class MuteEffectFactory(private val context: Context, private val packageName: String) {
    companion object {
        private const val TAG = "MuteEffectFactory"

        private val sessionRegex = """Session Id:\s*(\d+)\s+UID:\s*(\d+)[\S\s]*?Attributes:[\S\s]*?Content type:\s*(\w+)\s*Usage:\s*(\w+)""".toRegex()
        private val sessionRegex33 = """Session ID:\s*(\d+);\s*uid \s*(\d+);[\S\s]*?Attributes:[\S\s]*?Content type:\s*(\w+)\s*Usage:\s*(\w+)""".toRegex()

        var sessionLostStateListener: ((sid: Int, pkgName: String) -> Unit)? = null
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isCallbackRegistered = false

    private var currentAppSessionIds: Set<Int> = emptySet()

    private val muteEffects = ConcurrentHashMap<Int, DynamicsProcessing>()

    private val knownSessions = ConcurrentHashMap<Int, SessionInfo>()

    private val playbackCallback = object: AudioPlaybackCallback() {
        override fun onPlaybackConfigChanged(configs: List<AudioPlaybackConfiguration?>?) {
            super.onPlaybackConfigChanged(configs)
            
            dumpAudioSessionsViaShizuku{ sessions ->
                run {
                    muteOtherSessions(sessions)
                }
            }
        }
    }

    data class SessionInfo(
        val sessionId: Int,
        val uid: Int,
        val usage: String,
        val content: String,
        val packageName: String
    )

    private fun updateCurrentAppSessionIds() {
        if (context is AudioCaptureService) {
            currentAppSessionIds = (context as AudioCaptureService).getAllAudioSessionIds()
        }
    }

    fun dumpAudioSessionsViaShizuku(callback: (List<SessionInfo>) -> Unit) {
        if (!ShizukuHelpMe.isShizukuPermissionGranted()) {
            callback(emptyList())
            return
        }
        
        try {
            val output = ShizukuHelpMe.dumpAll2(context)
            if (output == null) {
                callback(emptyList())
                return
            }
            
            val sessions = parseAudioConfigurations(output)
            callback(sessions)
        } catch (e: Exception) {
            callback(emptyList())
        }
    }

    private fun parseAudioConfigurations(output: String): List<SessionInfo> {
        val sessions = mutableListOf<SessionInfo>()
        
        var matches = sessionRegex.findAll(output).toList()
        
        if (matches.isEmpty()) {
            matches = sessionRegex33.findAll(output).toList()
        }

        for (match in matches) {
            try {
                val sessionId = match.groupValues[1].toIntOrNull()
                val uid = match.groupValues[2].toIntOrNull()
                val content = match.groupValues[3]
                val usage = match.groupValues[4]

                if (sessionId == null || uid == null) {
                    continue
                }

                val pkgName = getPackageNameForUid(uid) ?: "Unknown"

                sessions.add(SessionInfo(sessionId, uid, usage, content, pkgName))
            } catch (e: Exception) {
                Log.w(TAG, "Error parsing audio config match", e)
            }
        }

        return sessions
    }

    private fun getPackageNameForUid(uid: Int): String? {
        try {
            val packages = context.packageManager.getPackagesForUid(uid)
            return packages?.firstOrNull()
        } catch (e: Exception) {
            Log.w(TAG, "Error getting package name for uid: $uid", e)
            return null
        }
    }

    fun muteOtherSessions(sessions: List<SessionInfo>) {
        updateCurrentAppSessionIds()
        
        val currentSessionIds = sessions.map { it.sessionId }.toSet()

        val removedSessions = knownSessions.keys.filter { it !in currentSessionIds }
        for (sid in removedSessions) {
            val info = knownSessions.remove(sid)
            muteEffects[sid]?.let { effect ->
                try {
                    effect.release()
                    Log.d(TAG, "Released muted effect for removed session: $sid")
                } catch (e: Exception) {
                    Log.w(TAG, "Error releasing muted effect for session: $sid", e)
                }
            }
            muteEffects.remove(sid)
            
            info?.let { sessionLostStateListener?.invoke(sid, it.packageName) }
        }

        for (session in sessions) {
            if (session.packageName == packageName) {
                knownSessions[session.sessionId] = session
                continue
            }

            if (session.sessionId in currentAppSessionIds) {
                knownSessions[session.sessionId] = session
                continue
            }
            
            if (muteEffects.containsKey(session.sessionId)) {
                knownSessions[session.sessionId] = session
                continue
            }

            val u = session.usage.uppercase().trim()

            if (!u.contains("USAGE_MEDIA") && !u.contains("USAGE_GAME") && !u.contains("USAGE_UNKNOWN")) {
                knownSessions[session.sessionId] = session
                continue
            }

            try {
                val muteEffect = makeMuteEffect(session.sessionId, session.packageName)
                if (muteEffect != null) {
                    muteEffects[session.sessionId] = muteEffect
                    knownSessions[session.sessionId] = session
                } else {
                    Log.w(TAG, "Failed to create mute effect for session: ${session.sessionId}, package: ${session.packageName}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error creating mute effect for session: ${session.sessionId}", e)
            }
        }
    }

    fun makeMuteEffect(sid: Int, pkgName: String): DynamicsProcessing? {
        val effect: DynamicsProcessing
        try {
            effect = DynamicsProcessing(Int.MAX_VALUE, sid, null)
            effect.setInputGainAllChannelsTo(-144f)
        } catch (e: Exception) {
            Log.e(TAG, "Error creating DynamicsProcessing effect for session $sid", e)
            throw e
        }
        
        effect.enabled = true
        setupEffectListeners(effect, sid, pkgName)

        return effect
    }

    private fun setupEffectListeners(effect: DynamicsProcessing, sid: Int, pkgName: String) {
        try {
            try {
                val listenerInterface = Class.forName("android.media.audiofx.AudioEffect\$OnEnableStatusChangeListener")
                val setEnableStatusListenerMethod = AudioEffect::class.java.getMethod(
                    "setEnableStatusListener",
                    listenerInterface
                )
                
                val listener = java.lang.reflect.Proxy.newProxyInstance(
                    listenerInterface.classLoader,
                    arrayOf(listenerInterface)
                ) { _, method, args ->
                    if (method.name == "onEnableStatusChange") {
                        val enabled = args[1] as Boolean
                        if (!enabled) {
                            Log.w(TAG, "DynamicsProcessing effect disabled for session: $sid, re-enabling")
                            try {
                                effect.setInputGainAllChannelsTo(-144f)
                                effect.enabled = true
                            } catch (reError: Exception) {
                                Log.e(TAG, "Failed to re-enable DynamicsProcessing for session: $sid", reError)
                                sessionLostStateListener?.invoke(sid, pkgName)
                            }
                        }
                    }
                    null
                }
                setEnableStatusListenerMethod.invoke(effect, listener)
            } catch (e: NoSuchMethodException) {
                Log.d(TAG, "setEnableStatusListener not available on this API level")
            }

            try {
                val listenerInterface = Class.forName("android.media.audiofx.AudioEffect\$OnControlStatusChangeListener")
                val setControlStatusListenerMethod = AudioEffect::class.java.getMethod(
                    "setControlStatusListener",
                    listenerInterface
                )
                
                val listener = java.lang.reflect.Proxy.newProxyInstance(
                    listenerInterface.classLoader,
                    arrayOf(listenerInterface)
                ) { _, method, args ->
                    if (method.name == "onControlStatusChange") {
                        val controlGranted = args[1] as Boolean
                        if (!controlGranted) {
                            Log.w(TAG, "DynamicsProcessing control lost for session: $sid, package: $pkgName")
                            postReacquireControl(sid, pkgName)
                        } else {
                            Log.d(TAG, "DynamicsProcessing control regained for session: $sid")
                            try {
                                effect.setInputGainAllChannelsTo(-200f)
                                effect.enabled = true
                            } catch (e: Exception) {
                                Log.w(TAG, "Failed to regain control over DynamicsProcessing (session $sid)")
                                sessionLostStateListener?.invoke(sid, pkgName)
                            }
                        }
                    }
                    null
                }
                setControlStatusListenerMethod.invoke(effect, listener)
            } catch (e: NoSuchMethodException) {
                Log.d(TAG, "setControlStatusListener not available on this API level")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error setting up effect listeners for session: $sid", e)
        }
    }

    private fun postReacquireControl(sid: Int, pkgName: String) {
        Handler(Looper.getMainLooper()).post {
            try {
                muteEffects[sid]?.release()
                muteEffects.remove(sid)
                
                val newEffect = makeMuteEffect(sid, pkgName)
                if (newEffect != null) {
                    muteEffects[sid] = newEffect
                    Log.d(TAG, "Successfully reacquired control for session: $sid")
                } else {
                    sessionLostStateListener?.invoke(sid, pkgName)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to reacquire control for session: $sid", e)
                sessionLostStateListener?.invoke(sid, pkgName)
            }
        }
    }

    fun registerPlaybackCallback() {
        if (isCallbackRegistered) {
            Log.d(TAG, "PlaybackCallback already registered")
            return
        }
        audioManager.registerAudioPlaybackCallback(playbackCallback, mainHandler)
        isCallbackRegistered = true
        Log.i(TAG, "PlaybackCallback registered")
    }

    fun unregisterPlaybackCallback() {
        if (!isCallbackRegistered) {
            return
        }
        audioManager.unregisterAudioPlaybackCallback(playbackCallback)
        isCallbackRegistered = false
        Log.i(TAG, "PlaybackCallback unregistered")
    }

    fun releaseAll() {
        unregisterPlaybackCallback()
        for ((sid, effect) in muteEffects) {
            try {
                effect.release()
                Log.d(TAG, "Released mute effect for session: $sid")
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing mute effect for session: $sid", e)
            }
        }
        muteEffects.clear()
        knownSessions.clear()
    }
}
