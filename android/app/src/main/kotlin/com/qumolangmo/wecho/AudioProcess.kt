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
}
