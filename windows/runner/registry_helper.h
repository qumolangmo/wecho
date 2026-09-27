// Copyright (C) 2026 qumolangmo
//
// This file is part of Wecho.
//
// Wecho is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Wecho is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Wecho.  If not, see <https://www.gnu.org/licenses/>.

#ifndef __RUNNER_REGISTRY_HELPER_H__
#define __RUNNER_REGISTRY_HELPER_H__

#include <atlbase.h>

#include <string>
#include <vector>

namespace wecho {

class RegistryHelper {
public:
    RegistryHelper() = default;
    ~RegistryHelper() { close(); }

    RegistryHelper(const RegistryHelper&) = delete;
    RegistryHelper& operator=(const RegistryHelper&) = delete;

    LSTATUS open(HKEY parent, const std::wstring& sub_key, REGSAM access = KEY_READ) {
        close();
        return key.Open(parent, sub_key.c_str(), access | KEY_WOW64_64KEY);
    }

    LSTATUS create(HKEY parent, const std::wstring& sub_key, REGSAM access = KEY_SET_VALUE | KEY_QUERY_VALUE) {
        close();
        return key.Create(parent, sub_key.c_str(), nullptr, 0, access | KEY_WOW64_64KEY);
    }

    LSTATUS setString(const std::wstring& name, const std::wstring& value) {
        return key.SetStringValue(name.c_str(), value.c_str());
    }

    LSTATUS setMultiString(const std::wstring& name, const std::vector<std::wstring>& values) {
        std::wstring joined;

        for (const auto& value : values) {
            joined.append(value).push_back(L'\0');
        }
        joined.push_back(L'\0');

        return key.SetValue(name.c_str(), REG_MULTI_SZ, joined.c_str(),
                            static_cast<DWORD>(joined.size() * sizeof(wchar_t)));
    }

    LSTATUS setDword(const std::wstring& name, DWORD value) {
        return key.SetDWORDValue(name.c_str(), value);
    }

    LSTATUS getDword(const std::wstring& name, DWORD& out) {
        return key.QueryDWORDValue(name.c_str(), out);
    }

    LSTATUS getString(const std::wstring& name, std::wstring& out) {
        ULONG chars = 0;
        LSTATUS r = key.QueryStringValue(name.c_str(), nullptr, &chars);

        if (r != ERROR_SUCCESS && r != ERROR_MORE_DATA) {
            return r;
        }
        out.resize(chars);
        r = key.QueryStringValue(name.c_str(), out.data(), &chars);
        if (r == ERROR_SUCCESS) {
            out.resize(wcsnlen(out.c_str(), out.size()));
        }
        return r;
    }

    LSTATUS deleteValue(const std::wstring& name) {
        return key.DeleteValue(name.c_str());
    }

    LSTATUS subkeyNames(std::vector<std::wstring>& out) {
        out.clear();
        for (DWORD i = 0;; ++i) {
            wchar_t name[256] = {};
            DWORD size = 256;
            LSTATUS r = RegEnumKeyW(key.m_hKey, i, name, size);
            if (r == ERROR_NO_MORE_ITEMS) {
                return ERROR_SUCCESS;
            }
            if (r != ERROR_SUCCESS) {
                out.clear();
                return r;
            }
            out.emplace_back(name);
        }
    }

    void close() { key.Close(); }

private:
    CRegKey key;
};

}  // namespace wecho

#endif  // __RUNNER_REGISTRY_HELPER_H__
