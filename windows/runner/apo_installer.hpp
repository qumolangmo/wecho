#ifndef __RUNNER_APO_INSTALLER_HPP__
#define __RUNNER_APO_INSTALLER_HPP__

#include <windows.h>
#include <mmdeviceapi.h>
#include <initguid.h>
#include <functiondiscoverykeys_devpkey.h>
#include <propvarutil.h>
#include <shellapi.h>

#include <flutter/encodable_value.h>
#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <filesystem>
#include <memory>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

#include "registry_helper.h"

namespace wecho {

// APO installation / maintenance, exposed to Dart over the "apo_installer"
// MethodChannel. The app itself runs elevated (requireAdministrator manifest),
// so mutating ops execute directly on a worker thread - no UAC re-launch is
// involved. Header-only: every member is inline, nothing lives in a .cpp.
//   getStatus      -> {installed, installDir, devices:[{guid,name,state,bound}]}
//                     (registry reads + MMDevice enumeration, runs inline)
//   install        -> stop audiosrv, std::filesystem::copy <exe>\apo\* into
//                     <System32>\WechoAPO, DllRegisterServer, start audiosrv
//   uninstall      -> clear bindings, DllUnregisterServer, stop audiosrv,
//                     remove install dir, start audiosrv
//   bindDevice     -> write FxProperties EFX binding for the guid argument
//   unbindDevice   -> remove FxProperties binding for the guid argument
//   restart        -> net stop/start audiosrv
// Mutating ops run on a worker thread; the reply is posted back to the
// platform thread through a message-only window. Every op returns
// {success, cancelled, error, log:[...]}.
class WechoAPOInstaller {
public:
    static void Register(flutter::FlutterEngine* engine) {
        WNDCLASSW wc = {};
        wc.lpfnWndProc = wndProc;
        wc.lpszClassName = L"WechoApoInstallerMsg";
        wc.hInstance = GetModuleHandleW(nullptr);
        RegisterClassW(&wc);
        msg_window = CreateWindowExW(0, wc.lpszClassName, nullptr, 0, 0, 0, 0, 0, HWND_MESSAGE,
                                      nullptr, wc.hInstance, nullptr);

        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), "apo_installer", &flutter::StandardMethodCodec::GetInstance());

        channel->SetMethodCallHandler(
            [] (const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

                const std::string& method = call.method_name();
                if (method == "getStatus") {
                    result->Success(buildStatusValue());
                    return;
                }

                std::wstring op;
                std::wstring guid;
                if (method == "install"
                    || method == "uninstall"
                    || method == "restart"
                    || method == "bindDevice"
                    || method == "unbindDevice") {

                    op = utf8ToWide(method);
                    guid = guidFromCall(call.arguments());

                    const bool needs_guid = method == "bindDevice" || method == "unbindDevice";
                    if (needs_guid && guid.empty()) {
                        OpResult missing;
                        missing.error = L"bindDevice/unbindDevice requires a guid argument";
                        result->Success(buildOpValue(missing));
                        return;
                    }
                } else {
                    result->NotImplemented();
                    return;
                }

                if (!msg_window) {
                    OpResult failed;
                    failed.error = L"Internal error: message window unavailable";
                    result->Success(buildOpValue(failed));
                    return;
                }
                if (pending) {
                    OpResult busy;
                    busy.error = L"Another operation is already running";
                    result->Success(buildOpValue(busy));
                    return;
                }

                pending = std::make_unique<PendingOp>();
                pending->result = std::move(result);

                std::thread([op, guid]() {
                    auto* res = new OpResult();
                    if (!isProcessElevated()) {
                        res->error = L"Wecho is not running as administrator; restart it elevated.";
                    } else {
                        *res = runOp(op, guid);
                    }
                    PostMessageW(msg_window, msgOpDone, reinterpret_cast<WPARAM>(res), 0);
                }).detach();
            });

        // Keep the channel alive for the lifetime of the process.
        channel.release();
    }

private:
    WechoAPOInstaller() = delete;

    static constexpr std::wstring_view apoClsid = L"{F1955965-CD9C-4D97-9B02-3FB0FDCF0936}";
    static constexpr std::wstring_view installDirName = L"WechoAPO";
    static constexpr std::wstring_view mmDevicesRenderPath =
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio\\Render";
    static constexpr std::wstring_view efxClsid = L"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},7";
    static constexpr std::wstring_view disableSysFx = L"{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5";
    static constexpr std::wstring_view efxProcessingModes = L"{d3993a3f-99c2-4402-b5ec-a92a0367664b},7";
    static constexpr std::wstring_view renderProcessingModes[] = {
        L"{C18E2F7E-933D-4965-B7D1-1EEF228D2AF3}",  // DEFAULT
        L"{98951333-B9CD-48B1-A0A3-FF40682D73F7}",  // COMMUNICATIONS
        L"{FC1CFC9B-B9D6-4CFA-B5E0-4BB2166878B2}",  // SPEECH
        L"{9CF2A70B-F377-403B-BD6B-360863E0355C}",  // NOTIFICATION
        L"{4780004E-7133-41D8-8C74-660DADD2C0EE}",  // MEDIA
        L"{B26FEB0D-EC94-477C-9494-D1AB8E753F6E}",  // MOVIE
    };

    static constexpr DWORD defaultCmdTimeoutMs = 30000;
    static constexpr UINT msgOpDone = WM_APP + 0x1A0;

    struct OpResult {
        bool success = false;
        bool cancelled = false;  // Kept for the Dart protocol; always false here.
        std::wstring error;
        std::vector<std::wstring> log;

        void addLog(const std::wstring& msg) { log.push_back(msg); }
    };

    struct PendingOp {
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
    };

    static inline HWND msg_window = nullptr;
    static inline std::unique_ptr<PendingOp> pending;


    static std::wstring utf8ToWide(const std::string& s) {
        if (s.empty()) {
            return std::wstring();
        }
        int len = MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
        std::wstring out(static_cast<size_t>(len), L'\0');
        if (len > 0) {
            MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), len);
        }
        return out;
    }

    static std::string WideToUtf8(const std::wstring& s) {
        if (s.empty()) {
            return std::string();
        }
        int len = WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0, nullptr, nullptr);
        std::string out(static_cast<size_t>(len), '\0');
        if (len > 0) {
            WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), len, nullptr, nullptr);
        }
        return out;
    }

    static std::filesystem::path getInstallDir() {
        wchar_t sys[MAX_PATH] = {};
        UINT n = GetSystemDirectoryW(sys, MAX_PATH);

        if (n > 0 && n < MAX_PATH) {
            return std::filesystem::path(sys) / installDirName;
        } else {
            return std::filesystem::path(L"C:\\Windows\\System32") / installDirName;
        }
    }

    static std::filesystem::path getStagingDir() {
        wchar_t path[MAX_PATH] = {};
        GetModuleFileNameW(nullptr, path, MAX_PATH);

        return std::filesystem::path(path).parent_path() / L"apo";
    }

    static int runCommand(const std::wstring& command,
                          DWORD timeout_ms = defaultCmdTimeoutMs,
                          const std::wstring& workdir = std::wstring()) {
        std::vector<wchar_t> buf(command.begin(), command.end());
        buf.push_back(L'\0');

        STARTUPINFOW si = {};
        si.cb = sizeof(si);
        PROCESS_INFORMATION pi = {};
        DWORD exit_code = 0xFFFFFFFF;
        if (CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr,
                           workdir.empty() ? nullptr : workdir.c_str(), &si, &pi)) {

            if (WaitForSingleObject(pi.hProcess, timeout_ms) == WAIT_OBJECT_0) {
                GetExitCodeProcess(pi.hProcess, &exit_code);
            } else {
                TerminateProcess(pi.hProcess, 1);
            }

            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
        }

        return static_cast<int>(exit_code);
    }

    static bool runRegsvr32(const wchar_t* what, const wchar_t* flags, OpResult& res) {
        const std::wstring dir = getInstallDir().wstring();
        std::wstring cmd = std::wstring(L"regsvr32 ") + flags + L" \"" + (std::filesystem::path(dir) / L"apo.dll").wstring() + L"\"";

        int rc = runCommand(cmd, defaultCmdTimeoutMs, dir);
        if (rc != 0) {
            res.error = std::wstring(what) + L" failed: regsvr32 exited with " +
                        std::to_wstring(rc) +
                        L" (2 = LoadLibrary failed; VC++ 2015-2022 x64 Redistributable or "
                        L"sibling dependencies may be missing)";
            return false;
        }

        res.addLog(std::wstring(what) + L" OK - COM class + APO metadata updated");
        return true;
    }

    static bool registerApo(OpResult& res) {
        return runRegsvr32(L"DllRegisterServer", L"/s", res);
    }

    static bool unregisterApo(OpResult& res) {
        std::error_code ec;
        if (!std::filesystem::exists(getInstallDir() / L"apo.dll", ec)) {
            res.addLog(L"apo.dll not present - skipping unregister");
            return true;
        }
        return runRegsvr32(L"DllUnregisterServer", L"/s /u", res);
    }

    static bool writeFxProperty(const std::wstring& guid, OpResult& res) {
        if (guid.empty()) {
            res.error = L"writeFxProperty: empty guid";
            return false;
        }
        RegistryHelper key;
        LSTATUS r = key.create(
            HKEY_LOCAL_MACHINE,
            std::wstring(mmDevicesRenderPath) + L"\\" + guid + L"\\FxProperties");
        if (r != ERROR_SUCCESS) {
            res.error = L"RegCreateKeyEx failed: " + std::to_wstring(r);
            return false;
        }

        // 1. PKEY_FX_EndpointEffectClsid = {clsid} (REG_SZ).
        r = key.setString(std::wstring(efxClsid), std::wstring(apoClsid));
        // 2. PKEY_AudioDevice_ProcessingModes (EFX slot) as REG_MULTI_SZ.
        if (r == ERROR_SUCCESS) {
            std::vector<std::wstring> modes;
            for (const auto& mode : renderProcessingModes) {
                modes.emplace_back(mode);
            }
            r = key.setMultiString(std::wstring(efxProcessingModes), modes);
        }
        // 3. Force PKEY_AudioEndpoint_Disable_SysFx = 0 so the engine loads APOs.
        if (r == ERROR_SUCCESS) {
            r = key.setDword(std::wstring(disableSysFx), 0);
        }
        if (r != ERROR_SUCCESS) {
            res.error = L"RegSetValueEx failed: " + std::to_wstring(r);
            return false;
        }
        return true;
    }

    static bool deleteFxProperty(const std::wstring& guid, OpResult& res) {
        if (guid.empty()) {
            res.error = L"deleteFxProperty: empty guid";
            return false;
        }
        RegistryHelper key;
        if (key.open(HKEY_LOCAL_MACHINE, std::wstring(mmDevicesRenderPath) + L"\\" + guid + L"\\FxProperties", KEY_SET_VALUE) != ERROR_SUCCESS) {
            return true;  // Key doesn't exist - nothing to delete.
        }
        const LSTATUS deleted[] = {
            key.deleteValue(std::wstring(efxClsid)),
            key.deleteValue(std::wstring(efxProcessingModes)),
            key.deleteValue(std::wstring(disableSysFx)),
        };
        for (LSTATUS s : deleted) {
            if (s != ERROR_SUCCESS && s != ERROR_FILE_NOT_FOUND) {
                res.error = L"RegDeleteValue failed: " + std::to_wstring(s);
                return false;
            }
        }
        return true;
    }

    static bool clearAllBindings(OpResult& res) {
        RegistryHelper render_key;
        if (render_key.open(HKEY_LOCAL_MACHINE, std::wstring(mmDevicesRenderPath)) !=
            ERROR_SUCCESS) {
            return true;  // No render devices - nothing to clear.
        }

        std::vector<std::wstring> guids;
        LSTATUS r = render_key.subkeyNames(guids);
        if (r != ERROR_SUCCESS) {
            res.error = L"RegEnumKey failed: " + std::to_wstring(r);
            return false;
        }

        bool all_ok = true;
        for (const auto& guid : guids) {
            if (!deleteFxProperty(guid, res)) {
                all_ok = false;
            }
        }
        return all_ok;
    }

    static bool isApoInstalled() {
        std::error_code ec;
        const std::filesystem::path dll = getInstallDir() / L"apo.dll";
        if (!std::filesystem::exists(dll, ec)) {
            return false;
        }

        RegistryHelper key;
        if (key.open(HKEY_LOCAL_MACHINE,std::wstring(L"SOFTWARE\\Classes\\CLSID\\") + apoClsid.data() + L"\\InProcServer32") != ERROR_SUCCESS) {
            return false;
        }

        std::wstring server;
        if (key.getString(L"", server) != ERROR_SUCCESS) {
            return false;
        }
        return _wcsicmp(server.c_str(), dll.wstring().c_str()) == 0;
    }

    static bool isDeviceBound(const std::wstring& guid) {
        RegistryHelper key;
        if (key.open(HKEY_LOCAL_MACHINE,std::wstring(mmDevicesRenderPath) + L"\\" + guid + L"\\FxProperties") != ERROR_SUCCESS) {
            return false;
        }
        std::wstring bound;
        if (key.getString(std::wstring(efxClsid), bound) != ERROR_SUCCESS) {
            return false;
        }
        return _wcsicmp(bound.c_str(), std::wstring(apoClsid).c_str()) == 0;
    }

    struct DeviceEntry {
        std::wstring guid;
        std::wstring name;
        std::wstring state;
        bool bound = false;
    };

    static std::wstring stateToString(DWORD state) {
        switch (state) {
            case DEVICE_STATE_ACTIVE:
                return L"active";
            case DEVICE_STATE_DISABLED:
                return L"disabled";
            case DEVICE_STATE_UNPLUGGED:
                return L"unplugged";
            case DEVICE_STATE_NOTPRESENT:
                return L"notpresent";
            default:
                return L"unknown";
        }
    }

    static std::wstring guidFromEndpointId(const std::wstring& endpoint_id) {
        /* MMDevice id format: "{0.0.1.00000000}.{guid}" */
        size_t idx = endpoint_id.find_last_of(L'.');
        if (idx == std::wstring::npos || idx + 1 >= endpoint_id.size()) {
            return endpoint_id;
        }
        return endpoint_id.substr(idx + 1);
    }

    static std::vector<DeviceEntry> enumerateRenderDevices() {
        std::vector<DeviceEntry> devices;

        IMMDeviceEnumerator* enumerator = nullptr;
        HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL, __uuidof(IMMDeviceEnumerator), reinterpret_cast<void**>(&enumerator));

        if (FAILED(hr) || !enumerator) {
            return devices;
        }

        IMMDeviceCollection* collection = nullptr;
        hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE | DEVICE_STATE_DISABLED | DEVICE_STATE_UNPLUGGED, &collection);
        if (FAILED(hr) || !collection) {
            enumerator->Release();
            return devices;
        }

        UINT count = 0;
        collection->GetCount(&count);
        for (UINT i = 0; i < count; ++i) {
            IMMDevice* device = nullptr;
            if (FAILED(collection->Item(i, &device)) || !device) {
                continue;
            }

            LPWSTR id_str = nullptr;
            if (FAILED(device->GetId(&id_str)) || !id_str) {
                device->Release();
                continue;
            }

            std::wstring endpoint_id(id_str);
            CoTaskMemFree(id_str);

            DWORD state = 0;
            device->GetState(&state);

            IPropertyStore* props = nullptr;
            std::wstring friendly;
            if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &props)) && props) {
                PROPVARIANT pv;
                PropVariantInit(&pv);

                if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &pv)) && pv.vt == VT_LPWSTR) {
                    friendly = pv.pwszVal;
                }

                PropVariantClear(&pv);
                props->Release();
            }
            device->Release();

            DeviceEntry entry;
            entry.guid = guidFromEndpointId(endpoint_id);
            entry.name = friendly.empty() ? L"(unnamed)" : friendly;
            entry.state = stateToString(state);
            entry.bound = isDeviceBound(entry.guid);
            devices.push_back(std::move(entry));
        }
        collection->Release();
        enumerator->Release();
        return devices;
    }

    static void opInstall(OpResult& res) {
        namespace fs = std::filesystem;
        const fs::path src = getStagingDir();
        const fs::path dir = getInstallDir();
        std::error_code ec;
        if (!fs::exists(src / L"apo.dll", ec)) {
            res.error = L"Staged apo\\ directory not found: " + src.wstring();
            return;
        }

        res.addLog(L"Stopping Audiosrv to release file locks");
        runCommand(L"net stop audiosrv");

        auto restart_service = [&res]() {
            res.addLog(L"Starting Audiosrv");
            int rc = runCommand(L"net start audiosrv");
            if (rc != 0) {
                res.addLog(L"Warning: net start audiosrv exited with " + std::to_wstring(rc));
            }
        };

        fs::create_directories(dir, ec);

        // Drop stale subdirectory layouts from previous installs.
        fs::remove_all(dir / L"fftw", ec);
        fs::remove_all(dir / L"tcc", ec);

        res.addLog(L"Copying " + src.wstring() + L" -> " + dir.wstring());
        for (fs::recursive_directory_iterator it(src, ec), end; !ec && it != end; ++it) {
            if (it->is_directory(ec)) {
                continue;
            }
            const fs::path rel = fs::relative(it->path(), src, ec);
            if (ec) {
                break;
            }
            fs::path dst = dir / rel.filename();
            if (rel.wstring().rfind(L"tcc\\include\\", 0) == 0) {
                dst = dir / L"include" / rel.filename();
            }
            fs::create_directories(dst.parent_path(), ec);
            fs::copy_file(it->path(), dst, fs::copy_options::overwrite_existing, ec);
        }
        if (ec) {
            res.error = L"Failed to copy staged files: " + utf8ToWide(ec.message());
            restart_service();
            return;
        }

        if (!registerApo(res)) {
            restart_service();
            return;
        }

        restart_service();
        res.success = true;
    }

    static void opUninstall(OpResult& res) {
        namespace fs = std::filesystem;
        const fs::path dir = getInstallDir();

        res.addLog(L"Clearing device bindings");
        if (!clearAllBindings(res)) {
            res.addLog(L"warning: " + res.error);
            res.error.clear();
        }

        if (!unregisterApo(res)) {
            res.addLog(L"warning: " + res.error);
            res.error.clear();
        }

        res.addLog(L"Stopping Audiosrv");
        runCommand(L"net stop audiosrv");

        res.addLog(L"Removing install directory " + dir.wstring());
        std::error_code ec;
        fs::remove_all(dir, ec);
        bool removed = !fs::exists(dir, ec);

        res.addLog(L"Starting Audiosrv");
        int rc = runCommand(L"net start audiosrv");
        if (rc != 0) {
            res.addLog(L"Warning: net start audiosrv exited with " + std::to_wstring(rc));
        }

        if (!removed) {
            res.error = L"Failed to remove " + dir.wstring() + L": " + utf8ToWide(ec.message());
            return;
        }
        res.success = true;
    }

    static OpResult runOp(const std::wstring& op, const std::wstring& guid) {
        OpResult res;
        if (op == L"install") {
            opInstall(res);
        } else if (op == L"uninstall") {
            opUninstall(res);
        } else if (op == L"bindDevice") {
            if (writeFxProperty(guid, res)) {
                res.addLog(L"Bind OK. Restart Audiosrv to take effect.");
                res.success = true;
            }
        } else if (op == L"unbindDevice") {
            if (deleteFxProperty(guid, res)) {
                res.addLog(L"Unbind OK. Restart Audiosrv to take effect.");
                res.success = true;
            }
        } else if (op == L"restart") {
            res.addLog(L"Stopping Audiosrv");
            res.addLog(L"net stop audiosrv exited with " + std::to_wstring(runCommand(L"net stop audiosrv")));
            res.addLog(L"Starting Audiosrv");
            res.addLog(L"net start audiosrv exited with " + std::to_wstring(runCommand(L"net start audiosrv")));
            res.success = true;
        } else {
            res.error = L"Unknown op: " + op;
        }
        return res;
    }

    static flutter::EncodableValue buildOpValue(const OpResult& res) {
        flutter::EncodableMap m;
        m[flutter::EncodableValue("success")] = flutter::EncodableValue(res.success);
        m[flutter::EncodableValue("cancelled")] = flutter::EncodableValue(res.cancelled);
        m[flutter::EncodableValue("error")] = flutter::EncodableValue(WideToUtf8(res.error));
        flutter::EncodableList log;
        for (const auto& line : res.log) {
            log.emplace_back(WideToUtf8(line));
        }
        m[flutter::EncodableValue("log")] = flutter::EncodableValue(std::move(log));
        return flutter::EncodableValue(std::move(m));
    }

    static flutter::EncodableValue buildStatusValue() {
        flutter::EncodableMap m;
        m[flutter::EncodableValue("installed")] = flutter::EncodableValue(isApoInstalled());
        m[flutter::EncodableValue("installDir")] =
            flutter::EncodableValue(WideToUtf8(getInstallDir().wstring()));

        flutter::EncodableList devices;
        for (const auto& d : enumerateRenderDevices()) {
            flutter::EncodableMap dm;
            dm[flutter::EncodableValue("guid")] = flutter::EncodableValue(WideToUtf8(d.guid));
            dm[flutter::EncodableValue("name")] = flutter::EncodableValue(WideToUtf8(d.name));
            dm[flutter::EncodableValue("state")] = flutter::EncodableValue(WideToUtf8(d.state));
            dm[flutter::EncodableValue("bound")] = flutter::EncodableValue(d.bound);
            devices.push_back(std::move(dm));
        }
        m[flutter::EncodableValue("devices")] = flutter::EncodableValue(std::move(devices));
        return flutter::EncodableValue(std::move(m));
    }

    static LRESULT CALLBACK wndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
        if (msg == msgOpDone) {
            auto* res = reinterpret_cast<OpResult*>(wparam);
            if (pending) {
                pending->result->Success(buildOpValue(*res));
                pending.reset();
            }
            delete res;
            return 0;
        }
        return DefWindowProcW(hwnd, msg, wparam, lparam);
    }

    static std::wstring guidFromCall(const flutter::EncodableValue* args) {
        if (args && std::holds_alternative<std::string>(*args)) {
            return utf8ToWide(std::get<std::string>(*args));
        }
        return L"";
    }

    static bool isProcessElevated() {
        BOOL elevated = FALSE;
        HANDLE token = nullptr;
        if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
            TOKEN_ELEVATION info = {};
            DWORD size = sizeof(info);

            if (GetTokenInformation(token, TokenElevation, &info, sizeof(info), &size)) {
                elevated = info.TokenIsElevated;
            }

            CloseHandle(token);
        }
        return elevated != FALSE;
    }
};

// Entry point used by flutter_window.cpp.
inline void RegisterApoInstaller(flutter::FlutterEngine* engine) {
    WechoAPOInstaller::Register(engine);
}

}  // namespace wecho

#endif  // __RUNNER_APO_INSTALLER_H__
