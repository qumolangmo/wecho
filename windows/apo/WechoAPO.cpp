#include "WechoAPO.h"
#include <algorithm>

#include <cstring>
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
    , outer_delegate(nullptr)
    , receiver_should_exit(false)
    , ref_count(1) {
    
    if (pUnkOuter != nullptr) {
        outer_delegate = pUnkOuter;
    } else {
        outer_delegate = reinterpret_cast<IUnknown*>(static_cast<INonDelegatingUnknown*>(this));
    }
    
    DebugLog("[WechoAPO] WechoAPO created");
    InterlockedIncrement(&instance_count);
}

WechoAPO::~WechoAPO() {
    DebugLog("[WechoAPO] WechoAPO destorying...");
    receiver_should_exit.store(true, std::memory_order_release);

    sleeper.interrupted();
    if (receiver.joinable()) {
        receiver.join();
    }
    DebugLog("[WechoAPO] WechoAPO destored");
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
    DebugLog("[WechoAPO] WechoAPO::Initialize called");
    
    if ((NULL == byte_data) && (0 != cb_data_size)) {
        return E_INVALIDARG;
    }
    if ((NULL != byte_data) && (0 == cb_data_size)) {
        return E_POINTER;
    }
    if (cb_data_size != sizeof(APOInitSystemEffects)) {
        return E_INVALIDARG;
    }

    receiver = std::thread([this]() {
        EffectData last_effect{}, cur_effect{};
        const wchar_t* shared_memory_name = L"Global\\WechoAPO_SharedData";
        const int buf_size = 2 * 1024 * 1024;

        HANDLE map = nullptr;
        void* buffer = nullptr;
        bool is_first = true;

        while (!receiver_should_exit.load(std::memory_order_acquire)) {
            if (map == nullptr) {
                map = OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, shared_memory_name);
                if (map == nullptr) {
                    sleeper.wait(std::chrono::milliseconds(30));
                    continue;
                }
            }

            if (buffer == nullptr) {
                buffer = MapViewOfFile(map, FILE_MAP_ALL_ACCESS, 0, 0, buf_size);
                if (buffer == nullptr) {
                    sleeper.wait(std::chrono::milliseconds(30));
                    continue;
                }
            }

            SharedData* tmp = reinterpret_cast<SharedData*>(buffer);

            bool has_data = tmp->flags.load(std::memory_order_acquire);

            if (!has_data && !is_first) {
                sleeper.wait(std::chrono::milliseconds(30));
                continue;
            }

            memcpy(&cur_effect, &tmp->effect_data, sizeof(EffectData));

            for (int i = 0; i < ParamID::MAX_EFFECT_PARAM; i++) {

                if (static_cast<ParamID>(i) == ParamID::CONVOLVE_EFFECT_IR_PATH) {
                    if (wcscmp(last_effect.CONVOLVE_EFFECT_IR_PATH,
                        cur_effect.CONVOLVE_EFFECT_IR_PATH) != 0) {

                        std::string tmp = WString2String(cur_effect.CONVOLVE_EFFECT_IR_PATH);
                        DebugLog("[WechoAPO] WechoAPO receiver thread, convolve_effect param: ", tmp);
                        AudioProcessor::getInstance().setEffectParam(static_cast<ParamID>(i), tmp);
                    }
                    continue;
                }

                switch (i) {
#define X(name, type) \
    case ParamID::name: \
        if (last_effect.name != cur_effect.name) { \
            AudioProcessor::getInstance().setEffectParam(static_cast<ParamID>(i), cur_effect.name); \
        } \
        break;

                    EFFECT_PARAMS
#undef X
                default:
                    break;
                }
            }

            tmp->flags.store(false, std::memory_order_release);
            is_first = false;

            memcpy(&last_effect, &cur_effect, sizeof(EffectData));
        }

        if (buffer) {
            UnmapViewOfFile(buffer);
            buffer = nullptr;
        }
        if (map) {
            CloseHandle(map);
            map = nullptr;
        }
    });

    return hr;
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::LockForProcess(
    UINT32 input_connections_num, APO_CONNECTION_DESCRIPTOR** input_connections,
    UINT32 output_connections_num, APO_CONNECTION_DESCRIPTOR** output_connections) {
    
    HRESULT result = S_OK;
    ATLASSERT(input_connections != NULL);
    ATLASSERT(output_connections != NULL);

    ATLASSERT(sample_rate == input_connections[0]->pFormat->GetAudioFormat()->nSamplesPerSec);

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
        int samples_per_frame = GetSamplesPerFrame();

        if (input_connections[0]->u32BufferFlags == BUFFER_SILENT) {
            memset(output_frames, 0, samples * sizeof(FLOAT32));
        }
        
        bool enabled = enabled_apo.load(std::memory_order_acquire);

        if (enabled && (m_u32SamplesPerFrame > 1)) {
            int count = input_connections[0]->u32ValidFrameCount;
            
            for (int i = 0; i < count; i++) {
                AudioProcessor::getInstance().process(
                    input_frames + i * samples_per_frame, 
                    output_frames + i * samples_per_frame, 
                    samples_per_frame);
            }
            
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
    
    ASSERT_NONREALTIME();
    HRESULT result;

    if (!requested_input_format) {
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
        && (in_format.dwSamplesPerFrame % (441 * 2) != 0 
        || std::abs(44100.f - in_format.fFramesPerSecond) > 0.001f)) {

        out_format.dwSamplesPerFrame = (441 * 2);
        out_format.fFramesPerSecond = 44100;

        CreateAudioMediaTypeFromUncompressedAudioFormat(&out_format, supported_input_format);

        DebugLog("[WechoAPO] WechoAPO::IsInputFormatSupported, unsupported: ", in_format.dwSamplesPerFrame, " ", in_format.fFramesPerSecond);

        result = S_FALSE;
    }

    return result;
}

//HRESULT WechoAPO::ValidateAndCacheConnectionInfo(
//    UINT32 input_connections_num, APO_CONNECTION_DESCRIPTOR** input_connections,
//    UINT32 output_connections_num, APO_CONNECTION_DESCRIPTOR** output_connections) {
//    
//    ASSERT_NONREALTIME();
//    HRESULT result = S_OK;
//    UNCOMPRESSEDAUDIOFORMAT in_format, out_format;
//
//    ATLASSERT(!m_bIsLocked);
//    ATLASSERT(input_connections_num != 0);
//    ATLASSERT(output_connections_num != 0);
//    ATLASSERT(input_connections != nullptr);
//    ATLASSERT(output_connections != nullptr);
//
//    EnterCriticalSection(&m_CritSec);
//
//    result = input_connections[0]->pFormat->GetUncompressedAudioFormat(&in_format);
//    if (FALSE(result)) {
//        goto Exit;
//    }
//
//    result = output_connections[0]->pFormat->GetUncompressedAudioFormat(&out_format);
//    if (FALSE(result)) {
//        goto Exit;
//    }
//
//    _ASSERT(in_format.fFramesPerSecond == out_format.fFramesPerSecond);
//    _ASSERT(in_format.dwSamplesPerFrame == out_format.dwSamplesPerFrame);
//
//Exit:
//    LeaveCriticalSection(&m_CritSec);
//    return result;
//}

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
    
    AddRef();
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
