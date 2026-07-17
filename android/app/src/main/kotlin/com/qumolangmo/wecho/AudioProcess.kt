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
import android.util.Log
import java.io.BufferedReader
import java.io.InputStreamReader

class AudioProcess private constructor() {

    companion object {
        @Volatile
        private var instance: AudioProcess? = null

        fun getInstance(): AudioProcess {
            return instance ?: synchronized(this) {
                instance ?: AudioProcess().also { instance = it }
            }
        }

        init {
            System.loadLibrary("wecho")
        }
    }

    private var _masterEnabled: Boolean = false
    var masterEnabled: Boolean
        get() = _masterEnabled
        set(value) {
            _masterEnabled = value
        }

    private external fun nativeSetEffectParam(paramId: Int, value: Any, initialize: Boolean): Unit
    private external fun nativeProcess(input: FloatArray, output: FloatArray, length: Int): Unit
    private external fun nativeInit(context: Context): Unit

    var onScriptCompileError: ((String) -> Unit)? = null

    fun init(context: Context) {
        nativeInit(context)
    }

    fun process(audioBuffer: FloatArray, outputBuffer: FloatArray, read: Int) {
        if (!_masterEnabled) {
            System.arraycopy(audioBuffer, 0, outputBuffer, 0, read)
            return
        }

        nativeProcess(audioBuffer, outputBuffer, read)
    }

    fun setEffectParam(paramId: Int, value: Any, initialize: Boolean = false) {
        nativeSetEffectParam(paramId, value, initialize)
    }

    fun notifyScriptCompileError(error: String) {
        onScriptCompileError?.invoke(error)
    }

    fun getLogs(tags: List<String>?, maxCount: Int): List<List<Any>> {
        val wantNative = tags == null || tags.contains("wecho-native")
        val wantKotlin = tags == null || tags.contains("wecho-kotlin")
        val wantFramework = tags == null || tags.contains("framework")

        Log.i("wecho-kotlin", "tags: $tags")
        if (!wantNative && !wantKotlin && !wantFramework) return emptyList()

        val result = mutableListOf<List<Any>>()

        val myPid = android.os.Process.myPid()
        val command = arrayOf("logcat", "--pid", myPid.toString(), "-d", "-t", maxCount.toString(), "-v", "threadtime")

        try {
            val proc = Runtime.getRuntime().exec(command)
            BufferedReader(InputStreamReader(proc.inputStream), 8192).use { reader ->
                reader.forEachLine { line ->

                    val parsed = parseLogLine(line) ?: return@forEachLine
                    val category = parsed[0] as String

                    val keep = when (category) {
                        "wecho-native" -> wantNative
                        "wecho-kotlin" -> wantKotlin
                        "framework" -> wantFramework
                        else -> false
                    }
                    if (keep) result.add(parsed)
                }
            }
            proc.waitFor()

        } catch (e: Exception) {
            Log.e("wecho-kotlin", "getLogs error", e)
        }

        return result
    }

    private fun parseLogLine(line: String): List<Any>? {
        val parts = line.split(" ", limit = 6)
        if (parts.size < 6) return null

        val tagAndMsg = parts[5]
        val colonIdx = tagAndMsg.indexOf(": ")
        if (colonIdx < 0) return null

        val rawTag = tagAndMsg.substring(0, colonIdx)
        val message = if (colonIdx + 2 < tagAndMsg.length) tagAndMsg.substring(colonIdx + 2) else ""

        var category = "framework"
        if (tagAndMsg.contains("wecho-native")) {
            category = "wecho-native"
        } else if (tagAndMsg.contains("wecho-kotlin")) {
            category = "wecho-kotlin"
        }

        val timeStr = "${parts[0]} ${parts[1]}"
        val timestamp = parseLogcatTimestamp(timeStr)
        if (timestamp <= 0L) return null

        return listOf(category, "$rawTag: $message", timestamp)
    }

    private fun parseLogcatTimestamp(timeStr: String): Long {
        try {
            val spaceIdx = timeStr.indexOf(' ')
            if (spaceIdx <= 0) return 0L

            val timePart = timeStr.substring(spaceIdx + 1)
            val timeParts = timePart.split(":", limit = 3)
            if (timeParts.size == 3) {
                val hours = timeParts[0].toInt()
                val minutes = timeParts[1].toInt()
                val secParts = timeParts[2].split(".")
                if (secParts.size == 2) {
                    val seconds = secParts[0].toInt()
                    val ms = secParts[1].toInt()
                    val now = System.currentTimeMillis()
                    val today = now - (now % (24 * 60 * 60 * 1000))
                    return today + hours * 3600000L + minutes * 60000L + seconds * 1000L + ms
                }
            }
        } catch (_: Exception) {
        }
        return 0L
    }
}
