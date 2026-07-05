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

#include <jni.h>
#include <string>
#include "enum.h"
#include <android/log.h>

#define LOG_TAG "WEchoEngine"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#include "AudioProcessor.hpp"

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT void JNICALL
Java_com_qumolangmo_wecho_AudioProcess_nativeSetEffectParam(
        JNIEnv* env,
        jobject thiz,
        jint paramId,
        jobject value) {

    try {
        auto& audioProcessor = AudioProcessor::getInstance();

        jclass valueClass = env->GetObjectClass(value);
        jmethodID toStringMethod = env->GetMethodID(valueClass, "toString", "()Ljava/lang/String;");
        jstring valueStr = (jstring)env->CallObjectMethod(value, toStringMethod);
        const char* valueChars = env->GetStringUTFChars(valueStr, nullptr);

        switch (paramId) {
            case BASS_EFFECT_ENABLED:
            case CLARITY_EFFECT_ENABLED:
            case EVEN_HARMONIC_EFFECT_ENABLED:
            case CONVOLVE_EFFECT_ENABLED:
            case LIMITER_EFFECT_ENABLED:
            case LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED:
            case LOW_CAT_EFFECT_ENABLED:
            case IIR_EQUALIZER_EFFECT_ENABLED:
            case VIRTUALBASS_EFFECT_ENABLED:
            case REVERB_EFFECT_ENABLED:
            case SCRIPT_EFFECT_ENABLED:
            {
                
                bool boolValue = env->IsInstanceOf(value, env->FindClass("java/lang/Boolean"));
                if (boolValue) {
                    jmethodID booleanValueMethod = env->GetMethodID(valueClass, "booleanValue", "()Z");
                    jboolean jValue = env->CallBooleanMethod(value, booleanValueMethod);
                    audioProcessor.setEffectParam(static_cast<ParamID>(paramId), (bool)jValue);
                    if (paramId == VIRTUALBASS_EFFECT_ENABLED) {
                        LOGD("VirtualBassEffect set: %d", (int)jValue);
                    } else {
                        LOGD("set %d: %d", paramId, (int)jValue);
                    }
                }
                break;
            }
            case BASS_EFFECT_GAIN:
            case CLARITY_EFFECT_GAIN:
            case BASS_EFFECT_CENTER_FREQ:
            case LIMITER_EFFECT_THRESHOLD:
            case LIMITER_EFFECT_RATIO:
            case LIMITER_EFFECT_MAKEUP_GAIN:
            case LIMITER_EFFECT_ATTACK:
            case LIMITER_EFFECT_RELEASE:
            case LOW_CAT_EFFECT_CUTOFF_FREQ:
            case VIRTUALBASS_EFFECT_ENVELOPE_RATE:
            case REVERB_EFFECT_PRE_DELAY:
            case REVERB_EFFECT_MATRIX_TYPE:
            {
                bool intValue = env->IsInstanceOf(value, env->FindClass("java/lang/Integer"));
                if (intValue) {
                    jmethodID intValueMethod = env->GetMethodID(valueClass, "intValue", "()I");
                    jint jValue = env->CallIntMethod(value, intValueMethod);
                    audioProcessor.setEffectParam(static_cast<ParamID>(paramId), (int)jValue);
                    LOGD("set %d: %d", paramId, (int)jValue);
                }
                break;
            }
            case GAIN_EFFECT_GAIN:
            case BALANCE_EFFECT_BALANCE:
            case BASS_EFFECT_Q:
            case CONVOLVE_EFFECT_MIX:
            case EVEN_HARMONIC_EFFECT_BASE:
            case EVEN_HARMONIC_EFFECT_WARM:
            case EVEN_HARMONIC_EFFECT_SUGAR:
            case REVERB_EFFECT_ROOM_SIZE:
            case REVERB_EFFECT_DAMPING:
            case REVERB_EFFECT_MIX:
            case REVERB_EFFECT_STEREO_WIDTH:
            case REVERB_EFFECT_MOD_DEPTH:
            case REVERB_EFFECT_MOD_FREQ:
            case VIRTUALBASS_EFFECT_MID_GAIN:
            case VIRTUALBASS_EFFECT_HIGH_GAIN:
            case VIRTUALBASS_EFFECT_HARMONIC_GAIN:
            {
                bool isFloat = env->IsInstanceOf(value, env->FindClass("java/lang/Float"));
                bool isDouble = env->IsInstanceOf(value, env->FindClass("java/lang/Double"));
                
                if (isFloat) {                    
                    jmethodID floatValueMethod = env->GetMethodID(valueClass, "floatValue", "()F");
                    jfloat jValue = env->CallFloatMethod(value, floatValueMethod);
                    audioProcessor.setEffectParam(static_cast<ParamID>(paramId), (float)jValue);
                } else if (isDouble) {
                    jmethodID doubleValueMethod = env->GetMethodID(valueClass, "doubleValue", "()D");
                    jdouble jValue = env->CallDoubleMethod(value, doubleValueMethod);
                    audioProcessor.setEffectParam(static_cast<ParamID>(paramId), (float)jValue);

                    
                    LOGD("set %d: %f", paramId, (float)jValue);
                    
                } else {
                    LOGE("value is neither Float nor Double");
                }
                break;
            }
            case SCRIPT_EFFECT_CODE:
            {
                bool isString = env->IsInstanceOf(value, env->FindClass("java/lang/String"));
                if (isString) {
                    jmethodID stringValueMethod = env->GetMethodID(valueClass, "toString", "()Ljava/lang/String;");
                    jstring jValue = (jstring)env->CallObjectMethod(value, stringValueMethod);
                    const char* jValueChars = env->GetStringUTFChars(jValue, nullptr);
                    std::string code(jValueChars);
                    env->ReleaseStringUTFChars(jValue, jValueChars);
                    audioProcessor.setEffectParam(static_cast<ParamID>(paramId), code);
                    LOGD("set SCRIPT_EFFECT_CODE: %zu bytes", code.size());

                    /* send compile error info to Kotlin if any. */
                    std::string error = ScriptEffect::getLastError();
                    jclass apClass = env->GetObjectClass(thiz);
                    jmethodID notifyMethod = env->GetMethodID(apClass, "notifyScriptCompileError", "(Ljava/lang/String;)V");
                    if (notifyMethod) {
                        jstring jError = env->NewStringUTF(error.c_str());
                        env->CallVoidMethod(thiz, notifyMethod, jError);
                    }
                } else {
                    LOGE("value is not String");
                }
                break;
            }
            case SCRIPT_EFFECT_PARAMS:
            {
                jclass byteArrayClass = env->FindClass("[B");
                if (env->IsInstanceOf(value, byteArrayClass)) {
                    jbyteArray byteArray = (jbyteArray)value;
                    jsize len = env->GetArrayLength(byteArray);
                    if (len == 16 * (64 + 4)) { // name[64] + value(float, 4 bytes)
                        jbyte* bytes = env->GetByteArrayElements(byteArray, nullptr);

                        ScriptParamsArray params;
                        for (int i = 0; i < 16; i++) {
                            int offset = i * 68;
                            std::memcpy(params[i].name, bytes + offset, 64);
                            params[i].name[63] = '\0';
                            std::memcpy(&params[i].value, bytes + offset + 64, 4);
                        }

                        env->ReleaseByteArrayElements(byteArray, bytes, JNI_ABORT);

                        audioProcessor.setEffectParam(static_cast<ParamID>(paramId), params);
                    }
                }
                break;
            }
            case CONVOLVE_EFFECT_IR_PATH:
            {
                bool isString = env->IsInstanceOf(value, env->FindClass("java/lang/String"));
                if (isString) {
                    jmethodID stringValueMethod = env->GetMethodID(valueClass, "toString", "()Ljava/lang/String;");
                    jstring jValue = (jstring)env->CallObjectMethod(value, stringValueMethod);
                    const char* jValueChars = env->GetStringUTFChars(jValue, nullptr);
                    std::string ir_path(jValueChars);
                    env->ReleaseStringUTFChars(jValue, jValueChars);
                    audioProcessor.setEffectParam(static_cast<ParamID>(paramId), ir_path);
                }
                break;
            }
            case IIR_EQUALIZER_EFFECT_COEFFS:
            {
                jclass byteArrayClass = env->FindClass("[B");
                if (env->IsInstanceOf(value, byteArrayClass)) {
                    jbyteArray byteArray = (jbyteArray)value;
                    jsize len = env->GetArrayLength(byteArray);
                    if (len == 10 * 16) {
                        jbyte* bytes = env->GetByteArrayElements(byteArray, nullptr);

                        IIREqualizerCoeffs coeffs;
                        for (int i = 0; i < 10; i++) {
                            int offset = i * 16;
                            coeffs[i].index      = *reinterpret_cast<int32_t*>(bytes + offset);
                            coeffs[i].start_freq = *reinterpret_cast<int32_t*>(bytes + offset + 4);
                            coeffs[i].end_freq   = *reinterpret_cast<int32_t*>(bytes + offset + 8);
                            coeffs[i].gain       = *reinterpret_cast<int32_t*>(bytes + offset + 12);
                        }

                        env->ReleaseByteArrayElements(byteArray, bytes, JNI_ABORT);

                        audioProcessor.setEffectParam(static_cast<ParamID>(paramId), coeffs);
                    }
                }
                break;
            }
            default:
                LOGE("Unknown paramId: %d", paramId);
                break;
        }

        env->ReleaseStringUTFChars(valueStr, valueChars);
    } catch (const std::exception& e) {
        LOGE("Error in nativeSetEffectParam: %s", e.what());
    }
}

JNIEXPORT void JNICALL
Java_com_qumolangmo_wecho_AudioProcess_nativeInit(
        JNIEnv* env,
        jobject thiz,
        jobject context) {

    try {
        jclass contextClass = env->FindClass("android/content/Context");
        jmethodID getFilesDir = env->GetMethodID(contextClass, "getFilesDir", "()Ljava/io/File;");

        jobject file = env->CallObjectMethod(context, getFilesDir);

        jclass fileClass = env->FindClass("java/io/File");
        jmethodID getPath = env->GetMethodID(fileClass, "getPath", "()Ljava/lang/String;");
        jstring pathStr = (jstring)env->CallObjectMethod(file, getPath);
        
        const char* path = env->GetStringUTFChars(pathStr, nullptr);

        AudioProcessor::init(path);

        /* call all of the constructor to init res */
        auto& audioProcessor = AudioProcessor::getInstance();

        env->ReleaseStringUTFChars(pathStr, path);
    } catch (const std::exception& e) {
        LOGE("Error in nativeInit: %s", e.what());
    }
}

JNIEXPORT void JNICALL
Java_com_qumolangmo_wecho_AudioProcess_nativeProcess(
        JNIEnv* env,
        jobject thiz,
        jfloatArray inputArray,
        jfloatArray outputArray,
        jint length) {

    try {
        auto& audioProcessor = AudioProcessor::getInstance();

        jfloat* input = env->GetFloatArrayElements(inputArray, nullptr);
        if (input == nullptr) {
            LOGE("Failed to get input array elements");
            return;
        }

        jfloat* output = env->GetFloatArrayElements(outputArray, nullptr);
        if (output == nullptr) {
            LOGE("Failed to get output array elements");
            env->ReleaseFloatArrayElements(inputArray, input, 0);
            return;
        }

        audioProcessor.process(input, output, length);

        /* Check if script crashed during processing */
        if (ScriptEffect::consumeCrashFlag()) {
            std::string error = ScriptEffect::getLastError();
            jclass apClass = env->GetObjectClass(thiz);
            jmethodID notifyMethod = env->GetMethodID(apClass, "notifyScriptCompileError", "(Ljava/lang/String;)V");
            if (notifyMethod) {
                jstring jError = env->NewStringUTF(error.c_str());
                env->CallVoidMethod(thiz, notifyMethod, jError);
            }
        }

        env->ReleaseFloatArrayElements(inputArray, input, 0);
        env->ReleaseFloatArrayElements(outputArray, output, 0);
    } catch (const std::exception& e) {
        LOGE("Error in nativeProcess: %s", e.what());
    }
}

#ifdef __cplusplus
}
#endif
