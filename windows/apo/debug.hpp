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