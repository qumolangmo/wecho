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