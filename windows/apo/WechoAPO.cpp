#include "WechoAPO.h"
#include "debug.hpp"
#include <algorithm>

#include <cstring>
#include <excpt.h>
#include <handleapi.h>
#include <minwinbase.h>
#include <windows.h>
#include <atlbase.h>


#pragma warning (disable: 4815)

const AVRT_DATA CRegAPOProperties<1> WechoAPO::register_properties(
    __uuidof(WechoAPO),
    L"CWechoAPO",
    L"qumolangmo",
    1,
    0,
    __uuidof(IWechoAPO)
);

LONG WechoAPO::instance_count = 0;

WechoAPO::WechoAPO(IUnknown* pUnkOuter)
    : CBaseAudioProcessingObject(register_properties)
    , enabled_apo(false)
    , shared_memory_connected(false)
    , outer_delegate(nullptr)
    , sample_rate(48000)
    , receiver_should_exit(false)
    , ir_data(2, std::vector<float>(65536, 0.0f))
    , last_ir_length(0)
    , last_ir_path("")
    , ref_count(1) {

    if (pUnkOuter != nullptr) {
        outer_delegate = pUnkOuter;
    } else {
        outer_delegate = reinterpret_cast<IUnknown*>(static_cast<INonDelegatingUnknown*>(this));
    }

    effect_data = std::make_unique<EffectData>();

    InterlockedIncrement(&instance_count);
    DebugLog("[WechoAPO] WechoAPO created");
}

WechoAPO::~WechoAPO() {
    DebugLog("[WechoAPO] WechoAPO destorying...");
    receiver_should_exit.store(true, std::memory_order_release);

    sleeper.interrupted();
    if (receiver.joinable()) {
        receiver.join();
    }
    if (heartbeat_thread.joinable()) {
        heartbeat_thread.join();
    }

    if (shared_data != nullptr) {
        shared_data->flags.store(true, std::memory_order_release);
    }
    
    closeSharedMemory();

    InterlockedDecrement(&instance_count);
    DebugLog("[WechoAPO] WechoAPO destored");
}

inline std::string WString2String(const wchar_t* wstr) {
    if (wstr == nullptr) {
        return std::string();
    }

    int len = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, nullptr, 0, nullptr, nullptr);
    if (len <= 0) {
        return std::string();
    }

    std::string result(len - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wstr, -1, &result[0], len, nullptr, nullptr);

    return result;
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::Initialize(UINT32 cb_data_size, BYTE* byte_data) {
    HRESULT hr = S_OK;

    if ((NULL == byte_data) && (0 != cb_data_size)) {
        return E_INVALIDARG;
    }
    if ((NULL != byte_data) && (0 == cb_data_size)) {
        return E_POINTER;
    }
    if (cb_data_size != sizeof(APOInitSystemEffects)) {
        return E_INVALIDARG;
    }

    openSharedMemory();

    if (shared_data == nullptr) {
        DebugLog("[WechoAPO] Shared memory not connected");
        return E_FAIL;
    }


    AudioProcessor::init("C:\\Windows\\System32\\WechoAPO\\fftwf_wisdom");
    AudioProcessor::getInstance();

    memcpy(effect_data.get(), &shared_data->effect_data, sizeof(EffectData));
    compareAndUpdateEffectParam(&shared_data->effect_data, true);
    enabled_apo.store(shared_data->enabled_apo, std::memory_order_release);
    last_ir_length = shared_data->ir_length.load(std::memory_order_acquire);

    receiver = std::thread(&WechoAPO::sharedMemoryThread, this);
    heartbeat_thread = std::thread(&WechoAPO::heartbeatThread, this);
    DebugLog("[WechoAPO] WechoAPO initialized");

    return hr;
}

void WechoAPO::openSharedMemory() {
    if (map_handle == INVALID_HANDLE_VALUE) {
        map_handle = OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, SHARED_MEMORY_NAME);

        if (map_handle == INVALID_HANDLE_VALUE) {
            return;
        }
    }

    if (shared_data == nullptr) {
        shared_data = reinterpret_cast<SharedData*>(MapViewOfFile(map_handle, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(SharedData)));

        if (shared_data == nullptr) {
            return;
        }
    }

    shared_memory_connected.store(true, std::memory_order_release);
    DebugLog("[WechoAPO] Shared memory opened");
    return;
}

void WechoAPO::closeSharedMemory() {
    if (shared_data != nullptr) {
        UnmapViewOfFile(shared_data);
        shared_data = nullptr;
    }
    if (map_handle != INVALID_HANDLE_VALUE) {
        CloseHandle(map_handle);
        map_handle = INVALID_HANDLE_VALUE;
    }
    shared_memory_connected.store(false, std::memory_order_release);
    DebugLog("[WechoAPO] Shared memory closed");
    return;
}

/* ENABLED must be the last parameter to set */
bool WechoAPO::compareAndUpdateEffectParam(const EffectData* new_data, bool init) {
#define X(name)\
    if (init) {\
        AudioProcessor::getInstance().setEffectParam(name, effect_data->name);\
    } else if (effect_data->name != new_data->name) {\
        effect_data->name = new_data->name;\
        AudioProcessor::getInstance().setEffectParam(name, new_data->name);\
    }

    X(GAIN_EFFECT_GAIN)
    X(BALANCE_EFFECT_BALANCE)
    
    X(BASS_EFFECT_GAIN)
    X(BASS_EFFECT_CENTER_FREQ)
    X(BASS_EFFECT_Q)
    X(BASS_EFFECT_ENABLED)

    X(CLARITY_EFFECT_GAIN)
    X(CLARITY_EFFECT_ENABLED)

    X(EVEN_HARMONIC_EFFECT_GAIN)
    X(EVEN_HARMONIC_EFFECT_ENABLED)
    
    X(CONVOLVE_EFFECT_MIX)
    X(CONVOLVE_EFFECT_ENABLED)
    
    X(LIMITER_EFFECT_THRESHOLD)
    X(LIMITER_EFFECT_RATIO)
    X(LIMITER_EFFECT_MAKEUP_GAIN)
    X(LIMITER_EFFECT_ATTACK)
    X(LIMITER_EFFECT_RELEASE)
    X(LIMITER_EFFECT_ENABLED)
    
    X(SPEAKER_EFFECT_HP_GAIN)
    X(SPEAKER_EFFECT_BP_GAIN)
    X(SPEAKER_EFFECT_2_HARMONIC_COEFFS)
    X(SPEAKER_EFFECT_4_HARMONIC_COEFFS)
    X(SPEAKER_EFFECT_6_HARMONIC_COEFFS)
    X(SPEAKER_EFFECT_ENABLED)

    X(LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED)

#undef X

    std::string new_path;
    const float* data = nullptr;
    int ir_length = 0;

    if (init) {
        new_path = std::string(effect_data->CONVOLVE_EFFECT_IR_PATH);
        data = effect_data->CONVOLVE_EFFECT_IR_DATA;
        ir_length = last_ir_length;
    } else {
        new_path = std::string(new_data->CONVOLVE_EFFECT_IR_PATH);
        data = new_data->CONVOLVE_EFFECT_IR_DATA;
        ir_length = shared_data->ir_length.load(std::memory_order_acquire);
    }

    if (last_ir_path != new_path) {
        last_ir_path = new_path;

        if (ir_length > 0) {
            int samples_count = ir_length / 2;

            ir_data[0].resize(samples_count);
            ir_data[1].resize(samples_count);

            memcpy(ir_data[0].data(), data, samples_count * sizeof(float));
            memcpy(ir_data[1].data(), data + samples_count, samples_count * sizeof(float));

            AudioProcessor::getInstance().setEffectParam(ParamID::CONVOLVE_EFFECT_IR_DATA, ir_data);
        }

    }

    return true;
}

void WechoAPO::processSharedData() {
    if (shared_data == nullptr) {
        return;
    }

    __try {
        bool flags = shared_data->flags.load(std::memory_order_acquire);
        if (!flags) {
            return;
        }

        bool new_enabled = shared_data->enabled_apo;
        bool current_enabled = enabled_apo.load(std::memory_order_acquire);
        if (new_enabled != current_enabled) {
            enabled_apo.store(new_enabled, std::memory_order_release);
            DebugLog("[WechoAPO] enabled_apo changed to: ", new_enabled);
        }

        const EffectData* new_effect_data = &shared_data->effect_data;

        compareAndUpdateEffectParam(new_effect_data);

        shared_data->flags.store(false, std::memory_order_release);
    } __except(GetExceptionCode() == EXCEPTION_ACCESS_VIOLATION ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH) {
        DebugLog("[WechoAPO] Exception in processSharedData");

        shared_data = nullptr;
        map_handle = INVALID_HANDLE_VALUE;
        /* start reconnect phase */
        closeSharedMemory();
    }
    
}

uint64_t WechoAPO::current_time_ms() {
    return (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()
    ).count();
}

void WechoAPO::sharedMemoryThread() {
    DebugLog("[WechoAPO] sharedMemoryThread started");
    while (!receiver_should_exit.load(std::memory_order_acquire)) {
        if (!shared_memory_connected.load(std::memory_order_acquire)) {
            openSharedMemory();

            if (!shared_memory_connected.load(std::memory_order_acquire)) {
                Sleep(30);
                continue;
            }
        }

        processSharedData();

        Sleep(30);
    }
    DebugLog("[WechoAPO] sharedMemoryThread exited");
}

void WechoAPO::printAllEffectParams() {
    DebugLog("[WechoAPO] master enabled: ", shared_data->enabled_apo, ", local: ", enabled_apo.load(std::memory_order_acquire));

    DebugLog("[WechoAPO] GAIN_EFFECT_GAIN: ", shared_data->effect_data.GAIN_EFFECT_GAIN, ", local: ", effect_data->GAIN_EFFECT_GAIN);
    DebugLog("[WechoAPO] BALANCE_EFFECT_BALANCE: ", shared_data->effect_data.BALANCE_EFFECT_BALANCE, ", local: ", effect_data->BALANCE_EFFECT_BALANCE);

    DebugLog("[WechoAPO] BASS_EFFECT_ENABLED: ", shared_data->effect_data.BASS_EFFECT_ENABLED, ", local: ", effect_data->BASS_EFFECT_ENABLED);
    DebugLog("[WechoAPO] BASS_EFFECT_GAIN: ", shared_data->effect_data.BASS_EFFECT_GAIN, ", local: ", effect_data->BASS_EFFECT_GAIN);
    DebugLog("[WechoAPO] BASS_EFFECT_CENTER_FREQ: ", shared_data->effect_data.BASS_EFFECT_CENTER_FREQ, ", local: ", effect_data->BASS_EFFECT_CENTER_FREQ);
    DebugLog("[WechoAPO] BASS_EFFECT_Q: ", shared_data->effect_data.BASS_EFFECT_Q, ", local: ", effect_data->BASS_EFFECT_Q);

    DebugLog("[WechoAPO] CLARITY_EFFECT_ENABLED: ", shared_data->effect_data.CLARITY_EFFECT_ENABLED, ", local: ", effect_data->CLARITY_EFFECT_ENABLED);
    DebugLog("[WechoAPO] CLARITY_EFFECT_GAIN: ", shared_data->effect_data.CLARITY_EFFECT_GAIN, ", local: ", effect_data->CLARITY_EFFECT_GAIN);

    DebugLog("[WechoAPO] EVEN_HARMONIC_EFFECT_ENABLED: ", shared_data->effect_data.EVEN_HARMONIC_EFFECT_ENABLED, ", local: ", effect_data->EVEN_HARMONIC_EFFECT_ENABLED);
    DebugLog("[WechoAPO] EVEN_HARMONIC_EFFECT_GAIN: ", shared_data->effect_data.EVEN_HARMONIC_EFFECT_GAIN, ", local: ", effect_data->EVEN_HARMONIC_EFFECT_GAIN);
    DebugLog("[WechoAPO] CONVOLVE_EFFECT_ENABLED: ", shared_data->effect_data.CONVOLVE_EFFECT_ENABLED, ", local: ", effect_data->CONVOLVE_EFFECT_ENABLED);
    DebugLog("[WechoAPO] CONVOLVE_EFFECT_IR_PATH: ", shared_data->effect_data.CONVOLVE_EFFECT_IR_PATH);

    DebugLog("[WechoAPO] LIMITER_EFFECT_ENABLED: ", shared_data->effect_data.LIMITER_EFFECT_ENABLED, ", local: ", effect_data->LIMITER_EFFECT_ENABLED);
    DebugLog("[WechoAPO] LIMITER_EFFECT_THRESHOLD: ", shared_data->effect_data.LIMITER_EFFECT_THRESHOLD, ", local: ", effect_data->LIMITER_EFFECT_THRESHOLD);
    DebugLog("[WechoAPO] LIMITER_EFFECT_RATIO: ", shared_data->effect_data.LIMITER_EFFECT_RATIO, ", local: ", effect_data->LIMITER_EFFECT_RATIO);
    DebugLog("[WechoAPO] LIMITER_EFFECT_ATTACK: ", shared_data->effect_data.LIMITER_EFFECT_ATTACK, ", local: ", effect_data->LIMITER_EFFECT_ATTACK);
    DebugLog("[WechoAPO] LIMITER_EFFECT_RELEASE: ", shared_data->effect_data.LIMITER_EFFECT_RELEASE, ", local: ", effect_data->LIMITER_EFFECT_RELEASE);
    DebugLog("[WechoAPO] LIMITER_EFFECT_MAKEUP_GAIN: ", shared_data->effect_data.LIMITER_EFFECT_MAKEUP_GAIN, ", local: ", effect_data->LIMITER_EFFECT_MAKEUP_GAIN);

    DebugLog("[WechoAPO] SPEAKER_EFFECT_ENABLED: ", shared_data->effect_data.SPEAKER_EFFECT_ENABLED, ", local: ", effect_data->SPEAKER_EFFECT_ENABLED);
    DebugLog("[WechoAPO] SPEAKER_EFFECT_HP_GAIN: ", shared_data->effect_data.SPEAKER_EFFECT_HP_GAIN, ", local: ", effect_data->SPEAKER_EFFECT_HP_GAIN);
    DebugLog("[WechoAPO] SPEAKER_EFFECT_BP_GAIN: ", shared_data->effect_data.SPEAKER_EFFECT_BP_GAIN, ", local: ", effect_data->SPEAKER_EFFECT_BP_GAIN);
    DebugLog("[WechoAPO] SPEAKER_EFFECT_2_HARMONIC_COEFFS: ", shared_data->effect_data.SPEAKER_EFFECT_2_HARMONIC_COEFFS, ", local: ", effect_data->SPEAKER_EFFECT_2_HARMONIC_COEFFS);
    DebugLog("[WechoAPO] SPEAKER_EFFECT_4_HARMONIC_COEFFS: ", shared_data->effect_data.SPEAKER_EFFECT_4_HARMONIC_COEFFS, ", local: ", effect_data->SPEAKER_EFFECT_4_HARMONIC_COEFFS);
    DebugLog("[WechoAPO] SPEAKER_EFFECT_6_HARMONIC_COEFFS: ", shared_data->effect_data.SPEAKER_EFFECT_6_HARMONIC_COEFFS, ", local: ", effect_data->SPEAKER_EFFECT_6_HARMONIC_COEFFS);
    DebugLog("[WechoAPO] LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED: ", shared_data->effect_data.LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED, ", local: ", effect_data->LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED);
}

void WechoAPO::heartbeatThread() {
    DebugLog("[WechoAPO] heartbeatThread started");
    uint64_t last_check_time = current_time_ms();

    while (!receiver_should_exit.load(std::memory_order_acquire)) {
        if (shared_memory_connected.load(std::memory_order_acquire) && shared_data != nullptr) {
            uint64_t current_time = current_time_ms();
            __try {
                shared_data->last_heart_beat.store(current_time, std::memory_order_release);
                // if (current_time - last_check_time > 5000) {
                //     last_check_time = current_time;

                //     printAllEffectParams();
                // }
            } __except(GetExceptionCode() == EXCEPTION_ACCESS_VIOLATION ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH) {
                DebugLog("[WechoAPO] Exception in heartbeatThread");

                shared_data = nullptr;
                map_handle = INVALID_HANDLE_VALUE;
                closeSharedMemory();
            }
            
        }
        Sleep(10);
    }
    DebugLog("[WechoAPO] heartbeatThread exited");
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::LockForProcess(
    UINT32 input_connections_num, APO_CONNECTION_DESCRIPTOR** input_connections,
    UINT32 output_connections_num, APO_CONNECTION_DESCRIPTOR** output_connections) {

    DebugLog("[WechoAPO] LockForProcess called");
    HRESULT result = S_OK;

    if (input_connections == NULL || output_connections == NULL) {
        DebugLog("[WechoAPO] LockForProcess failed: NULL connection pointers");
        return E_POINTER;
    }

    const WAVEFORMATEX* input_format = input_connections[0]->pFormat->GetAudioFormat();
    DebugLog("[WechoAPO] LockForProcess: sample_rate=", sample_rate, ", input_sample_rate=", input_format->nSamplesPerSec);

    if (sample_rate != input_format->nSamplesPerSec) {
        DebugLog("[WechoAPO] LockForProcess failed: sample rate mismatch");
        return E_INVALIDARG;
    }

    result = CBaseAudioProcessingObject::LockForProcess(
        input_connections_num, input_connections,
        output_connections_num, output_connections);

    DebugLog("[WechoAPO] LockForProcess result=", result);
    return result;
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::UnlockForProcess() {
    return CBaseAudioProcessingObject::UnlockForProcess();
}

#pragma AVRT_CODE_BEGIN
STDMETHODIMP_(void) WechoAPO::APOProcess(
    UINT32 input_connections_num, APO_CONNECTION_PROPERTY** input_connections,
    UINT32 output_connections_num, APO_CONNECTION_PROPERTY** output_connections
) {
    UNREFERENCED_PARAMETER(input_connections_num);
    UNREFERENCED_PARAMETER(output_connections_num);

    FLOAT32* input_frames, * output_frames;

    ATLASSERT(m_bIsLocked);
    ATLASSERT(m_pRegProperties->u32MinInputConnections <= input_connections_num);
    ATLASSERT(m_pRegProperties->u32MaxInputConnections >= input_connections_num);
    ATLASSERT(m_pRegProperties->u32MinOutputConnections <= output_connections_num);
    ATLASSERT(m_pRegProperties->u32MaxOutputConnections >= output_connections_num);

    switch (input_connections[0]->u32BufferFlags) {
    case BUFFER_INVALID: {
        break;
    }
    case BUFFER_VALID:
    case BUFFER_SILENT: {
        input_frames = reinterpret_cast<FLOAT32*>(input_connections[0]->pBuffer);
        output_frames = reinterpret_cast<FLOAT32*>(output_connections[0]->pBuffer);

        if (input_frames == nullptr || output_frames == nullptr) {
            break;
        }

        int samples = input_connections[0]->u32ValidFrameCount * GetSamplesPerFrame();

        if (input_connections[0]->u32BufferFlags == BUFFER_SILENT) {
            memset(output_frames, 0, samples * sizeof(FLOAT32));
        }
        
        bool enabled = enabled_apo.load(std::memory_order_acquire);

        if (enabled && (m_u32SamplesPerFrame > 1)) {
            AudioProcessor::getInstance().process(input_frames, output_frames, samples);
        } else {
            memcpy(output_frames, input_frames, samples * sizeof(FLOAT32));
        }
        
        output_connections[0]->u32BufferFlags = input_connections[0]->u32BufferFlags;
        output_connections[0]->u32ValidFrameCount = input_connections[0]->u32ValidFrameCount;
    }
    }
}
#pragma AVRT_CODE_END

STDMETHODIMP_(HRESULT) WechoAPO::IsInputFormatSupported(
    IAudioMediaType* output_format,
    IAudioMediaType* requested_input_format,
    IAudioMediaType** supported_input_format) {

    DebugLog("[WechoAPO] IsInputFormatSupported called");
    ASSERT_NONREALTIME();

    HRESULT result;

    if (!requested_input_format) {
        DebugLog("[WechoAPO] IsInputFormatSupported failed: E_POINTER");
        return E_POINTER;
    }

    UNCOMPRESSEDAUDIOFORMAT in_format, out_format;
    result = requested_input_format->GetUncompressedAudioFormat(&in_format);
    if (FAILED(result)) {
        return result;
    }

    result = output_format->GetUncompressedAudioFormat(&out_format);
    if (FAILED(result)) {
        return result;
    }

    result = CBaseAudioProcessingObject::IsInputFormatSupported(
        output_format, requested_input_format, supported_input_format);

    if ((result == S_OK)
        && (in_format.dwSamplesPerFrame != 2
        || std::abs(48000.f - in_format.fFramesPerSecond) > 0.001f)) {

        out_format.dwSamplesPerFrame = 2;
        out_format.fFramesPerSecond = 48000;

        CreateAudioMediaTypeFromUncompressedAudioFormat(&out_format, supported_input_format);

        DebugLog("[WechoAPO] WechoAPO::IsInputFormatSupported, unsupported: ", in_format.dwSamplesPerFrame, " ", in_format.fFramesPerSecond);

        result = S_FALSE;
    }

    return result;
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::setEffectParam(int param_id, VARIANT param_value) {
    return E_NOTIMPL;
}

STDMETHODIMP_(HRESULT) WechoAPO::QueryInterface(REFIID riid, void** ppv) {
    return outer_delegate->QueryInterface(riid, ppv);
}

STDMETHODIMP_(ULONG) WechoAPO::AddRef() {
    return outer_delegate->AddRef();
}

STDMETHODIMP_(ULONG) WechoAPO::Release() {
    return outer_delegate->Release();
}

STDMETHODIMP_(HRESULT) WechoAPO::NonDelegatingQueryInterface(const IID& iid, LPVOID* ppv) {
    if (iid == __uuidof(IUnknown)) {
        *ppv = static_cast<INonDelegatingUnknown*>(this);
    } else if (iid == __uuidof(IAudioProcessingObject)) {
        *ppv = static_cast<IAudioProcessingObject*>(this);
    } else if (iid == __uuidof(IAudioProcessingObjectRT)) {
        *ppv = static_cast<IAudioProcessingObjectRT*>(this);
    } else if (iid == __uuidof(IAudioProcessingObjectConfiguration)) {
        *ppv = static_cast<IAudioProcessingObjectConfiguration*>(this);
    } else if (iid == __uuidof(IAudioSystemEffects)) {
        *ppv = static_cast<IAudioSystemEffects*>(this);
    } else if (iid == __uuidof(IWechoAPO)) {
        *ppv = static_cast<IWechoAPO*>(this);
    } else {
        *ppv = nullptr;
        return E_NOINTERFACE;
    }
    
    reinterpret_cast<IUnknown*>(*ppv)->AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) WechoAPO::NonDelegatingAddRef() {
    return InterlockedIncrement(&ref_count);
}

STDMETHODIMP_(ULONG) WechoAPO::NonDelegatingRelease() {
    LONG new_ref = InterlockedDecrement(&ref_count);
    if (new_ref == 0) {
        delete this;
    }
    return new_ref;
}
