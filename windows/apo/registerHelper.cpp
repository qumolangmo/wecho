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