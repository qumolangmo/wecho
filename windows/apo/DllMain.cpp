#include <windows.h>
#include "WechoAPOFactory.h"
#include "WechoAPO.h"
#include "registerHelper.hpp"
#include <string>

HINSTANCE _dll_instance;

static std::wstring GuidToString(const GUID& guid) {
    wchar_t buffer[128];
    StringFromGUID2(guid, buffer, 128);
    return std::wstring(buffer);
}

BOOL WINAPI DllMain(HINSTANCE dll_instance, DWORD what_do_you_want, LPVOID) {
    if (what_do_you_want == DLL_PROCESS_ATTACH) {
        _dll_instance = dll_instance;
    }
    return TRUE;
}

STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, LPVOID* ppv) {
    if (rclsid != __uuidof(WechoAPO)) {
        return CLASS_E_CLASSNOTAVAILABLE;
    }

    WechoAPOFactory* factory = new(std::nothrow) WechoAPOFactory();
    if (factory == nullptr) {
        return E_OUTOFMEMORY;
    }

    HRESULT result = factory->QueryInterface(riid, ppv);
    factory->Release();
    return result;
}

STDAPI DllCanUnloadNow() {
    if (WechoAPO::instance_count == 0 && WechoAPOFactory::lock_count == 0) {
        return S_OK;
    } else {
        return S_FALSE;
    }
}

STDAPI DllRegisterServer() {
    wchar_t file_name[1024];
    GetModuleFileNameW(_dll_instance, file_name, 1024);

    HRESULT hr = RegisterAPO(WechoAPO::register_properties);
    if (FAILED(hr)) {
        UnregisterAPO(WECHOAPO_GUID);
        return hr;
    }

    std::wstring apo_clsid = GuidToString(WECHOAPO_GUID);
    std::wstring clsid_key = L"SOFTWARE\\Classes\\CLSID\\" + apo_clsid;
    std::wstring inproc_key = clsid_key + L"\\InprocServer32";

    RegisterHelper::createKey(HKEY_LOCAL_MACHINE, clsid_key);
    RegisterHelper::setStringValue(L"", L"WechoAPO Class");
    
    RegisterHelper::createKey(HKEY_LOCAL_MACHINE, inproc_key);
    RegisterHelper::setStringValue(L"", file_name);
    RegisterHelper::setStringValue(L"ThreadingModel", L"Both");

    return S_OK;
}

STDAPI DllUnregisterServer() {
    std::wstring apo_clsid = GuidToString(WECHOAPO_GUID);
    std::wstring clsidKey = L"SOFTWARE\\Classes\\CLSID\\" + apo_clsid;
    std::wstring inprocKey = clsidKey + L"\\InprocServer32";

    RegisterHelper::deleteKeyRecursive(HKEY_LOCAL_MACHINE, inprocKey);
    RegisterHelper::deleteKeyRecursive(HKEY_LOCAL_MACHINE, clsidKey);
    HRESULT hr = UnregisterAPO(WECHOAPO_GUID);
    
    return hr;
}
