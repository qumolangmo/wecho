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
import java.io.File

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

    private external fun nativeSetEffectParam(paramId: Int, value: Any): Unit
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

    fun setEffectParam(paramId: Int, value: Any) {
        nativeSetEffectParam(paramId, value)
    }

    /* send compile error info to Flutter if any. */
    fun notifyScriptCompileError(error: String) {
        onScriptCompileError?.invoke(error)
    }
}
