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

#include <atlbase.h>
#include <atlcom.h>
#include <string>

class RegisterHelper {
public:
    static HRESULT openKey(HKEY key, const std::wstring& sub_key);
    static HRESULT createKey(HKEY key, const std::wstring& sub_key);
    static HRESULT setStringValue(const std::wstring& value_name, const std::wstring& value);
    static HRESULT deleteKeyRecursive(HKEY key, const std::wstring& sub_key);

private:
    static CRegKey inner_key;
};