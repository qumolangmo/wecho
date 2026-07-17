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

#ifndef __DEBUG_HPP__
#define __DEBUG_HPP__

inline const char* get_filename(const char* path) {
    const char* filename = path;
    for (const char* p = path; *p; ++p) {
        if (*p == '/' || *p == '\\') {
            filename = p + 1;
        }
    }
    return filename;
}

#ifdef __ANDROID__
#include <android/log.h>

#define LOG_TAG_NATIVE "wecho-native"

#define LOG_D(fmt, ...) \
    __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG_NATIVE, \
                        "[%s:%d] " fmt, \
                        get_filename(__FILE__), __LINE__, \
                        ##__VA_ARGS__)

#define LOG_E(fmt, ...) \
    __android_log_print(ANDROID_LOG_ERROR, LOG_TAG_NATIVE, \
                        "[%s:%d] " fmt, \
                        get_filename(__FILE__), __LINE__, \
                        ##__VA_ARGS__)
#define LOG_I(fmt, ...) \
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG_NATIVE, \
                        "[%s:%d] " fmt, \
                        get_filename(__FILE__), __LINE__, \
                        ##__VA_ARGS__)
#endif

#ifdef _WIN32
#include <windows.h>
#define LOG_TAG_NATIVE "wecho-native"

#define LOG_D(fmt, ...)\
    do {\
        char __tmp_buffer[2048];\
        sprintf_s(__tmp_buffer, 2048, "[%s] [%s:%d] " fmt "\n", \
                        LOG_TAG_NATIVE, get_filename(__FILE__), __LINE__, \
                        ##__VA_ARGS__);\
        OutputDebugStringA(__tmp_buffer);\
    } while(0);

#define LOG_E(fmt, ...) LOG_D(fmt, ##__VA_ARGS__)
#define LOG_I(fmt, ...) LOG_D(fmt, ##__VA_ARGS__)
    
#endif

#define LOG_REALTIME(fmt, ...) ((void)0)

#endif
