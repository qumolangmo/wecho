#ifndef __DEBUG_HPP__
#define __DEBUG_HPP__
#ifdef __ANDROID__
#include <android/log.h>

inline const char* get_filename(const char* path) {
    const char* filename = path;
    for (const char* p = path; *p; ++p) {
        if (*p == '/' || *p == '\\') {
            filename = p + 1;
        }
    }
    return filename;
}

#ifndef LOG_TAG
#define LOG_TAG "WEchoEngine"
#endif

#define LOG_D(fmt, ...) \
    __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, \
                        "[%s:%d] " fmt, \
                        get_filename(__FILE__), __LINE__, \
                        ##__VA_ARGS__)

#define LOG_E(fmt, ...) \
    __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, \
                        "[%s:%d] " fmt, \
                        get_filename(__FILE__), __LINE__, \
                        ##__VA_ARGS__)
#endif
#endif
