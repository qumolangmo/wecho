#include "WechoAPO.h"

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
}

WechoAPO::~WechoAPO() {
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
        return E_FAIL;
    }


    AudioProcessor::init("C:\\Windows\\System32\\WechoAPO\\fftwf_wisdom");
    AudioProcessor::getInstance().reset();

    memcpy(effect_data.get(), &shared_data->effect_data, sizeof(EffectData));
    compareAndUpdateEffectParam(&shared_data->effect_data, true);
    enabled_apo.store(shared_data->enabled_apo, std::memory_order_release);
    last_ir_length = shared_data->ir_length.load(std::memory_order_acquire);

    receiver = std::thread(&WechoAPO::sharedMemoryThread, this);
    heartbeat_thread = std::thread(&WechoAPO::heartbeatThread, this);

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
    return;
}

/* ENABLED must be the last parameter to set */
bool WechoAPO::compareAndUpdateEffectParam(const EffectData* new_data, bool init) {
    auto& processor = AudioProcessor::getInstance();
#define X(name)\
    if (init) {\
        processor.setEffectParam(name, effect_data->name);\
    } else if (effect_data->name != new_data->name) {\
        effect_data->name = new_data->name;\
        processor.setEffectParam(name, new_data->name);\
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

    X(LOW_CAT_EFFECT_CUTOFF_FREQ)
    X(LOW_CAT_EFFECT_ENABLED)

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

            processor.setEffectParam(ParamID::CONVOLVE_EFFECT_IR_DATA, ir_data);
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
        }

        const EffectData* new_effect_data = &shared_data->effect_data;

        compareAndUpdateEffectParam(new_effect_data);

        shared_data->flags.store(false, std::memory_order_release);
    } __except(GetExceptionCode() == EXCEPTION_ACCESS_VIOLATION ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH) {
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
}

void WechoAPO::printAllEffectParams() {
    LOG_D("-------------------------------------------------------------------------------------------------");
    LOG_D("master enabled: %d, local: %d", shared_data->enabled_apo.load(), enabled_apo.load(std::memory_order_acquire));

    LOG_D("GAIN_EFFECT_GAIN: %f, local: %f", shared_data->effect_data.GAIN_EFFECT_GAIN, effect_data->GAIN_EFFECT_GAIN);
    LOG_D("BALANCE_EFFECT_BALANCE: %f, local: %f", shared_data->effect_data.BALANCE_EFFECT_BALANCE, effect_data->BALANCE_EFFECT_BALANCE);

    LOG_D("BASS_EFFECT_ENABLED: %d, local: %d", shared_data->effect_data.BASS_EFFECT_ENABLED, effect_data->BASS_EFFECT_ENABLED);
    LOG_D("BASS_EFFECT_GAIN: %d, local: %d", shared_data->effect_data.BASS_EFFECT_GAIN, effect_data->BASS_EFFECT_GAIN);
    LOG_D("BASS_EFFECT_CENTER_FREQ: %d, local: %d", shared_data->effect_data.BASS_EFFECT_CENTER_FREQ, effect_data->BASS_EFFECT_CENTER_FREQ);
    LOG_D("BASS_EFFECT_Q: %f, local: %f", shared_data->effect_data.BASS_EFFECT_Q, effect_data->BASS_EFFECT_Q);

    LOG_D("CLARITY_EFFECT_ENABLED: %d, local: %d", shared_data->effect_data.CLARITY_EFFECT_ENABLED, effect_data->CLARITY_EFFECT_ENABLED);
    LOG_D("CLARITY_EFFECT_GAIN: %d, local: %d", shared_data->effect_data.CLARITY_EFFECT_GAIN, effect_data->CLARITY_EFFECT_GAIN);

    LOG_D("EVEN_HARMONIC_EFFECT_ENABLED: %d, local: %d", shared_data->effect_data.EVEN_HARMONIC_EFFECT_ENABLED, effect_data->EVEN_HARMONIC_EFFECT_ENABLED);
    LOG_D("EVEN_HARMONIC_EFFECT_GAIN: %d, local: %d", shared_data->effect_data.EVEN_HARMONIC_EFFECT_GAIN, effect_data->EVEN_HARMONIC_EFFECT_GAIN);
    LOG_D("CONVOLVE_EFFECT_ENABLED: %d, local: %d", shared_data->effect_data.CONVOLVE_EFFECT_ENABLED, effect_data->CONVOLVE_EFFECT_ENABLED);
    LOG_D("CONVOLVE_EFFECT_IR_PATH: %s", shared_data->effect_data.CONVOLVE_EFFECT_IR_PATH);

    LOG_D("LIMITER_EFFECT_ENABLED: %d, local: %d", shared_data->effect_data.LIMITER_EFFECT_ENABLED, effect_data->LIMITER_EFFECT_ENABLED);
    LOG_D("LIMITER_EFFECT_THRESHOLD: %d, local: %d", shared_data->effect_data.LIMITER_EFFECT_THRESHOLD, effect_data->LIMITER_EFFECT_THRESHOLD);
    LOG_D("LIMITER_EFFECT_RATIO: %d, local: %d", shared_data->effect_data.LIMITER_EFFECT_RATIO, effect_data->LIMITER_EFFECT_RATIO);
    LOG_D("LIMITER_EFFECT_ATTACK: %d, local: %d", shared_data->effect_data.LIMITER_EFFECT_ATTACK, effect_data->LIMITER_EFFECT_ATTACK);
    LOG_D("LIMITER_EFFECT_RELEASE: %d, local: %d", shared_data->effect_data.LIMITER_EFFECT_RELEASE, effect_data->LIMITER_EFFECT_RELEASE);
    LOG_D("LIMITER_EFFECT_MAKEUP_GAIN: %d, local: %d", shared_data->effect_data.LIMITER_EFFECT_MAKEUP_GAIN, effect_data->LIMITER_EFFECT_MAKEUP_GAIN);

    LOG_D("SPEAKER_EFFECT_ENABLED: %d, local: %d", shared_data->effect_data.SPEAKER_EFFECT_ENABLED, effect_data->SPEAKER_EFFECT_ENABLED);
    LOG_D("SPEAKER_EFFECT_HP_GAIN: %f, local: %f", shared_data->effect_data.SPEAKER_EFFECT_HP_GAIN, effect_data->SPEAKER_EFFECT_HP_GAIN);
    LOG_D("SPEAKER_EFFECT_BP_GAIN: %f, local: %f", shared_data->effect_data.SPEAKER_EFFECT_BP_GAIN, effect_data->SPEAKER_EFFECT_BP_GAIN);
    LOG_D("SPEAKER_EFFECT_2_HARMONIC_COEFFS: %f, local: %f", shared_data->effect_data.SPEAKER_EFFECT_2_HARMONIC_COEFFS, effect_data->SPEAKER_EFFECT_2_HARMONIC_COEFFS);
    LOG_D("SPEAKER_EFFECT_4_HARMONIC_COEFFS: %f, local: %f", shared_data->effect_data.SPEAKER_EFFECT_4_HARMONIC_COEFFS, effect_data->SPEAKER_EFFECT_4_HARMONIC_COEFFS);
    LOG_D("SPEAKER_EFFECT_6_HARMONIC_COEFFS: %f, local: %f", shared_data->effect_data.SPEAKER_EFFECT_6_HARMONIC_COEFFS, effect_data->SPEAKER_EFFECT_6_HARMONIC_COEFFS);
   
    LOG_D("LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED: %d, local: %d", shared_data->effect_data.LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED, effect_data->LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED);
   
    LOG_D("LOW_CAT_EFFECT_ENABLED: %d, local: %d", shared_data->effect_data.LOW_CAT_EFFECT_ENABLED, effect_data->LOW_CAT_EFFECT_ENABLED);
    LOG_D("LOW_CAT_EFFECT_CUTOFF_FREQ: %d, local: %d", shared_data->effect_data.LOW_CAT_EFFECT_CUTOFF_FREQ, effect_data->LOW_CAT_EFFECT_CUTOFF_FREQ);
    LOG_D("-------------------------------------------------------------------------------------------------");
}

void WechoAPO::heartbeatThread() {
    while (!receiver_should_exit.load(std::memory_order_acquire)) {
        if (shared_memory_connected.load(std::memory_order_acquire) && shared_data != nullptr) {
            uint64_t current_time = current_time_ms();
            __try {
                shared_data->last_heart_beat.store(current_time, std::memory_order_release);
            } __except(GetExceptionCode() == EXCEPTION_ACCESS_VIOLATION ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH) {

                shared_data = nullptr;
                map_handle = INVALID_HANDLE_VALUE;
                closeSharedMemory();
            }
            
        }
        Sleep(10);
    }
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::LockForProcess(
    UINT32 input_connections_num, APO_CONNECTION_DESCRIPTOR** input_connections,
    UINT32 output_connections_num, APO_CONNECTION_DESCRIPTOR** output_connections) {

    HRESULT result = S_OK;

    if (input_connections == NULL || output_connections == NULL) {
        return E_POINTER;
    }

    const WAVEFORMATEX* input_format = input_connections[0]->pFormat->GetAudioFormat();

    if (sample_rate != input_format->nSamplesPerSec) {
        return E_INVALIDARG;
    }

    result = CBaseAudioProcessingObject::LockForProcess(
        input_connections_num, input_connections,
        output_connections_num, output_connections);

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
    auto& processor = AudioProcessor::getInstance();

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

        bool enabled = enabled_apo.load(std::memory_order_acquire);

        if (input_connections[0]->u32BufferFlags == BUFFER_SILENT) {
            memset(output_frames, 0, samples * sizeof(FLOAT32));
        } else {
            if (enabled && (m_u32SamplesPerFrame > 1)) {
                processor.process(input_frames, output_frames, samples);
            } else {
                memcpy(output_frames, input_frames, samples * sizeof(FLOAT32));
            }
        }

        if (fade_in > 0) {
            output_connections[0]->u32BufferFlags = BUFFER_SILENT;
            output_connections[0]->u32ValidFrameCount = 0;
            fade_in--;
        } else {
            output_connections[0]->u32BufferFlags = input_connections[0]->u32BufferFlags;
            output_connections[0]->u32ValidFrameCount = input_connections[0]->u32ValidFrameCount;
        }
    }
    }
}
#pragma AVRT_CODE_END

STDMETHODIMP_(HRESULT) WechoAPO::IsInputFormatSupported(
    IAudioMediaType* output_format,
    IAudioMediaType* requested_input_format,
    IAudioMediaType** supported_input_format) {

    ASSERT_NONREALTIME();

    HRESULT result;

    if (!requested_input_format) {
        LOG_D("IsInputFormatSupported failed: E_POINTER");
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

        LOG_D("WechoAPO::IsInputFormatSupported, unsupported: %d, %f", in_format.dwSamplesPerFrame, in_format.fFramesPerSecond);

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
