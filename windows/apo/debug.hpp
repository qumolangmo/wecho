#pragma once
#include <windows.h>
#include <string>
#include <utility>
#include <sstream>

template <typename T>
void DebugLogImpl(std::ostringstream& oss, T&& arg) {
    oss << std::forward<T>(arg);
}

template <typename T, typename... Args>
void DebugLogImpl(std::ostringstream& oss, T&& arg, Args&&... args) {
    oss << std::forward<T>(arg);
    DebugLogImpl(oss, std::forward<Args>(args)...);
}

template <typename... Args>
void DebugLog(Args&&... args) {
    static std::ostringstream oss;
    oss.str("");
    oss.clear();
    DebugLogImpl(oss, std::forward<Args>(args)...);
    OutputDebugStringA(oss.str().c_str());
}