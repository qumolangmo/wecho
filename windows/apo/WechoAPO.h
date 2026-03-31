#pragma once

#include <audioenginebaseapo.h>
#include <audioengineextensionapo.h>
#include <baseaudioprocessingobject.h>
#include "WechoAPOInterface_h.h"
#include "WechoAPODll_h.h"

#include <atomic>
#include <string>
#include <thread>
#include <memory>
#include <cstring>

#ifdef min
#undef min
#endif

#ifdef max
#undef max
#endif

#include "../../native/AudioProcessor.hpp"
#include "../../native/enum.h"
#include "interruptedSleep.hpp"
#include "debug.hpp"

// HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{79f3b685-7ce1-4664-ab8d-5bab7d850e70}\FxProperties
_Analysis_mode_(_Analysis_code_type_user_driver_)

class INonDelegatingUnknown {
    STDMETHOD(NonDelegatingQueryInterface)(const IID& iid, LPVOID* ppv) = 0;
    STDMETHOD_(ULONG, NonDelegatingAddRef)() = 0;
    STDMETHOD_(ULONG, NonDelegatingRelease)() = 0;
};

#pragma AVRT_VTABLES_BEGIN
class WechoAPO :
    public CBaseAudioProcessingObject,
    public IAudioSystemEffects,
    public IWechoAPO,
    public INonDelegatingUnknown
{
public:
    static LONG instance_count;
    LONG ref_count;
    static const CRegAPOProperties<1> register_properties;
    
private:
    int sample_rate;

    IUnknown* outer_delegate;
    std::atomic<bool> enabled_apo;
    std::atomic<bool> shared_memory_connected;

    InterruptedSleep sleeper;
    std::thread receiver;
    std::thread heartbeat_thread;
    std::atomic<bool> receiver_should_exit;

    std::unique_ptr<EffectData> effect_data;
    std::string last_ir_path;

    HANDLE map_handle = INVALID_HANDLE_VALUE;
    SharedData* shared_data = nullptr;

    static constexpr const wchar_t* SHARED_MEMORY_NAME = L"Global\\WechoAPO_SharedData";

    void sharedMemoryThread();

    void heartbeatThread();

    void openSharedMemory();
    void closeSharedMemory();

    uint64_t current_time_ms();

    bool compareAndUpdateEffectParam(ParamID param_id, const EffectData* new_data);

    void processSharedData();

    void printAllEffectParams();

public:
    WechoAPO(IUnknown* pUnkOuter);
    virtual ~WechoAPO();

public:
    STDMETHOD(Initialize)(UINT32 cb_data_size, BYTE* byte_data) override;

    STDMETHOD(LockForProcess)(
        UINT32 input_connections_num, APO_CONNECTION_DESCRIPTOR** input_connections,
        UINT32 output_connections_num, APO_CONNECTION_DESCRIPTOR** output_connections) override;
    STDMETHOD(UnlockForProcess)() override;

    STDMETHOD_(void, APOProcess)(
        UINT32 input_connections_num, APO_CONNECTION_PROPERTY** input_connections,
        UINT32 output_connections_num, APO_CONNECTION_PROPERTY** output_connections) override;

    STDMETHOD(IsInputFormatSupported)(IAudioMediaType* output_format, IAudioMediaType* requested_input_format, IAudioMediaType** supported_input_format) override;

    STDMETHOD(setEffectParam)(int param_id, VARIANT param_value) override;

    STDMETHOD(QueryInterface)(REFIID riid, void** ppv) override;
    STDMETHOD_(ULONG, AddRef)() override;
    STDMETHOD_(ULONG, Release)() override;
    
    STDMETHOD(NonDelegatingQueryInterface)(const IID& iid, LPVOID* ppv) override;
    STDMETHOD_(ULONG, NonDelegatingAddRef)() override;
    STDMETHOD_(ULONG, NonDelegatingRelease)() override;
};
#pragma AVRT_VTABLES_END

#define WECHOAPO_GUID __uuidof(WechoAPO)
