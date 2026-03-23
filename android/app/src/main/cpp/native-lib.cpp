/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
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
        jobject /* this */,
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
            case SPEAKER_EFFECT_ENABLED:
            case LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED:
            {
                bool boolValue = env->IsInstanceOf(value, env->FindClass("java/lang/Boolean"));
                if (boolValue) {
                    jmethodID booleanValueMethod = env->GetMethodID(valueClass, "booleanValue", "()Z");
                    jboolean jValue = env->CallBooleanMethod(value, booleanValueMethod);
                    audioProcessor.setEffectParam(static_cast<ParamID>(paramId), (bool)jValue);
                }
                break;
            }
            case GAIN_EFFECT_GAIN:
            case BALANCE_EFFECT_BALANCE:
            case BASS_EFFECT_GAIN:
            case CLARITY_EFFECT_GAIN:
            case EVEN_HARMONIC_EFFECT_GAIN:
            case BASS_EFFECT_CENTER_FREQ:
            case LIMITER_EFFECT_THRESHOLD:
            case LIMITER_EFFECT_RATIO:
            case LIMITER_EFFECT_MAKEUP_GAIN:
            case LIMITER_EFFECT_ATTACK:
            case LIMITER_EFFECT_RELEASE:
            {
                bool intValue = env->IsInstanceOf(value, env->FindClass("java/lang/Integer"));
                if (intValue) {
                    jmethodID intValueMethod = env->GetMethodID(valueClass, "intValue", "()I");
                    jint jValue = env->CallIntMethod(value, intValueMethod);
                    audioProcessor.setEffectParam(static_cast<ParamID>(paramId), (int)jValue);
                }
                break;
            }
            case BASS_EFFECT_Q:
            case CONVOLVE_EFFECT_MIX:
            case SPEAKER_EFFECT_HP_GAIN:
            case SPEAKER_EFFECT_BP_GAIN:
            case SPEAKER_EFFECT_2_HARMONIC_COEFFS:
            case SPEAKER_EFFECT_4_HARMONIC_COEFFS:
            case SPEAKER_EFFECT_6_HARMONIC_COEFFS:
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
                } else {
                    LOGE("value is neither Float nor Double");
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

        std::string wisdom_path = std::string(path) + "/fftw_wisdom";
        AudioProcessor::init(wisdom_path);

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
        jobject /* this */,
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

        env->ReleaseFloatArrayElements(inputArray, input, 0);
        env->ReleaseFloatArrayElements(outputArray, output, 0);
    } catch (const std::exception& e) {
        LOGE("Error in nativeProcess: %s", e.what());
    }
}

#ifdef __cplusplus
}
#endif
