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

#include "registerHelper.hpp"

CRegKey RegisterHelper::inner_key = CRegKey();

HRESULT RegisterHelper::openKey(HKEY key, const std::wstring& sub_key) {
    HRESULT hr = S_OK;
    LSTATUS res;

    res = inner_key.Open(key, sub_key.c_str(), KEY_READ | KEY_WRITE);
    if (res != ERROR_SUCCESS) {
        hr = HRESULT_FROM_WIN32(res);
    }

    return hr;
}

HRESULT RegisterHelper::createKey(HKEY key, const std::wstring& sub_key) {
    HRESULT hr = S_OK;
    LSTATUS res;

    res = inner_key.Create(key, sub_key.c_str());
    if (res != ERROR_SUCCESS) {
        hr = HRESULT_FROM_WIN32(res);
    }

    return hr;
}

HRESULT RegisterHelper::setStringValue(const std::wstring& value_name, const std::wstring& value) {
    HRESULT hr = S_OK;
    LSTATUS res;

    res = inner_key.SetStringValue(value_name.c_str(), value.c_str());
    if (res != ERROR_SUCCESS) {
        hr = HRESULT_FROM_WIN32(res);
    }

    return hr;
}

HRESULT RegisterHelper::deleteKeyRecursive(HKEY key, const std::wstring& sub_key) {
    HRESULT hr = S_OK;
    LSTATUS res;

    res = RegDeleteTreeW(key, sub_key.c_str());
    if (res != ERROR_SUCCESS) {
        hr = HRESULT_FROM_WIN32(res);
    }

    return hr;
}