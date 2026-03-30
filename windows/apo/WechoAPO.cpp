#include "WechoAPO.h"
#include <algorithm>

#include <cstring>
#include <handleapi.h>
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
    , receiver_should_exit(false)
    , ref_count(1) {

    if (pUnkOuter != nullptr) {
        outer_delegate = pUnkOuter;
    } else {
        outer_delegate = reinterpret_cast<IUnknown*>(static_cast<INonDelegatingUnknown*>(this));
    }

    // 初始化本地EffectData
    local_effect_data = std::make_unique<EffectData>();
    std::memset(local_effect_data.get(), 0, sizeof(EffectData));

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
    if (heartbeat_thread.joinable()) {
        heartbeat_thread.join();
    }

    disconnectSharedMemory();

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

    // 启动共享内存读取线程
    receiver = std::thread(&WechoAPO::sharedMemoryThreadFunc, this);

    // 启动心跳线程
    heartbeat_thread = std::thread(&WechoAPO::heartbeatThreadFunc, this);

    return hr;
}

// volatile bool 的原子读写（使用内存屏障保证原子性）
bool WechoAPO::atomicLoadVolatile(const volatile bool* ptr) {
    return *ptr;  // volatile保证每次从内存读取
}

void WechoAPO::atomicStoreVolatile(volatile bool* ptr, bool value) {
    *ptr = value;  // volatile保证直接写入内存
}

// volatile uint64_t 的原子读写
uint64_t WechoAPO::atomicLoadVolatile64(const volatile uint64_t* ptr) {
    // 使用InterlockedCompareExchange64保证64位原子读取
    return InterlockedCompareExchange64(const_cast<volatile LONG64*>(reinterpret_cast<const volatile LONG64*>(ptr)), 0, 0);
}

void WechoAPO::atomicStoreVolatile64(volatile uint64_t* ptr, uint64_t value) {
    // 使用InterlockedExchange64保证64位原子写入
    InterlockedExchange64(reinterpret_cast<volatile LONG64*>(ptr), static_cast<LONG64>(value));
}

// 连接共享内存
bool WechoAPO::connectSharedMemory() {
    map_handle = OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, SHARED_MEMORY_NAME);
    if (map_handle == NULL) {
        return false;
    }

    shared_data = static_cast<SharedData*>(MapViewOfFile(map_handle, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(SharedData)));
    if (shared_data == nullptr) {
        CloseHandle(map_handle);
        map_handle = INVALID_HANDLE_VALUE;
        return false;
    }

    shared_memory_connected.store(true, std::memory_order_release);
    DebugLog("[WechoAPO] Shared memory connected");
    return true;
}

// 断开共享内存连接
void WechoAPO::disconnectSharedMemory() {
    if (shared_data != nullptr) {
        UnmapViewOfFile(shared_data);
        shared_data = nullptr;
    }
    if (map_handle != INVALID_HANDLE_VALUE) {
        CloseHandle(map_handle);
        map_handle = INVALID_HANDLE_VALUE;
    }
    shared_memory_connected.store(false, std::memory_order_release);
}

// 比对并更新单个效果参数
bool WechoAPO::compareAndUpdateEffectParam(ParamID param_id, const EffectData* new_data) {
    bool updated = false;

    switch (param_id) {
        case GAIN_EFFECT_GAIN:
            if (local_effect_data->GAIN_EFFECT_GAIN != new_data->GAIN_EFFECT_GAIN) {
                local_effect_data->GAIN_EFFECT_GAIN = new_data->GAIN_EFFECT_GAIN;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->GAIN_EFFECT_GAIN);
                updated = true;
            }
            break;
        case BALANCE_EFFECT_BALANCE:
            if (local_effect_data->BALANCE_EFFECT_BALANCE != new_data->BALANCE_EFFECT_BALANCE) {
                local_effect_data->BALANCE_EFFECT_BALANCE = new_data->BALANCE_EFFECT_BALANCE;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->BALANCE_EFFECT_BALANCE);
                updated = true;
            }
            break;
        case BASS_EFFECT_Q:
            if (local_effect_data->BASS_EFFECT_Q != new_data->BASS_EFFECT_Q) {
                local_effect_data->BASS_EFFECT_Q = new_data->BASS_EFFECT_Q;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->BASS_EFFECT_Q);
                updated = true;
            }
            break;
        case CONVOLVE_EFFECT_MIX:
            if (local_effect_data->CONVOLVE_EFFECT_MIX != new_data->CONVOLVE_EFFECT_MIX) {
                local_effect_data->CONVOLVE_EFFECT_MIX = new_data->CONVOLVE_EFFECT_MIX;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->CONVOLVE_EFFECT_MIX);
                updated = true;
            }
            break;
        case SPEAKER_EFFECT_HP_GAIN:
            if (local_effect_data->SPEAKER_EFFECT_HP_GAIN != new_data->SPEAKER_EFFECT_HP_GAIN) {
                local_effect_data->SPEAKER_EFFECT_HP_GAIN = new_data->SPEAKER_EFFECT_HP_GAIN;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->SPEAKER_EFFECT_HP_GAIN);
                updated = true;
            }
            break;
        case SPEAKER_EFFECT_BP_GAIN:
            if (local_effect_data->SPEAKER_EFFECT_BP_GAIN != new_data->SPEAKER_EFFECT_BP_GAIN) {
                local_effect_data->SPEAKER_EFFECT_BP_GAIN = new_data->SPEAKER_EFFECT_BP_GAIN;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->SPEAKER_EFFECT_BP_GAIN);
                updated = true;
            }
            break;
        case SPEAKER_EFFECT_2_HARMONIC_COEFFS:
            if (local_effect_data->SPEAKER_EFFECT_2_HARMONIC_COEFFS != new_data->SPEAKER_EFFECT_2_HARMONIC_COEFFS) {
                local_effect_data->SPEAKER_EFFECT_2_HARMONIC_COEFFS = new_data->SPEAKER_EFFECT_2_HARMONIC_COEFFS;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->SPEAKER_EFFECT_2_HARMONIC_COEFFS);
                updated = true;
            }
            break;
        case SPEAKER_EFFECT_4_HARMONIC_COEFFS:
            if (local_effect_data->SPEAKER_EFFECT_4_HARMONIC_COEFFS != new_data->SPEAKER_EFFECT_4_HARMONIC_COEFFS) {
                local_effect_data->SPEAKER_EFFECT_4_HARMONIC_COEFFS = new_data->SPEAKER_EFFECT_4_HARMONIC_COEFFS;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->SPEAKER_EFFECT_4_HARMONIC_COEFFS);
                updated = true;
            }
            break;
        case SPEAKER_EFFECT_6_HARMONIC_COEFFS:
            if (local_effect_data->SPEAKER_EFFECT_6_HARMONIC_COEFFS != new_data->SPEAKER_EFFECT_6_HARMONIC_COEFFS) {
                local_effect_data->SPEAKER_EFFECT_6_HARMONIC_COEFFS = new_data->SPEAKER_EFFECT_6_HARMONIC_COEFFS;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->SPEAKER_EFFECT_6_HARMONIC_COEFFS);
                updated = true;
            }
            break;
        case BASS_EFFECT_GAIN:
            if (local_effect_data->BASS_EFFECT_GAIN != new_data->BASS_EFFECT_GAIN) {
                local_effect_data->BASS_EFFECT_GAIN = new_data->BASS_EFFECT_GAIN;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->BASS_EFFECT_GAIN);
                updated = true;
            }
            break;
        case BASS_EFFECT_CENTER_FREQ:
            if (local_effect_data->BASS_EFFECT_CENTER_FREQ != new_data->BASS_EFFECT_CENTER_FREQ) {
                local_effect_data->BASS_EFFECT_CENTER_FREQ = new_data->BASS_EFFECT_CENTER_FREQ;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->BASS_EFFECT_CENTER_FREQ);
                updated = true;
            }
            break;
        case CLARITY_EFFECT_GAIN:
            if (local_effect_data->CLARITY_EFFECT_GAIN != new_data->CLARITY_EFFECT_GAIN) {
                local_effect_data->CLARITY_EFFECT_GAIN = new_data->CLARITY_EFFECT_GAIN;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->CLARITY_EFFECT_GAIN);
                updated = true;
            }
            break;
        case EVEN_HARMONIC_EFFECT_GAIN:
            if (local_effect_data->EVEN_HARMONIC_EFFECT_GAIN != new_data->EVEN_HARMONIC_EFFECT_GAIN) {
                local_effect_data->EVEN_HARMONIC_EFFECT_GAIN = new_data->EVEN_HARMONIC_EFFECT_GAIN;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->EVEN_HARMONIC_EFFECT_GAIN);
                updated = true;
            }
            break;
        case LIMITER_EFFECT_THRESHOLD:
            if (local_effect_data->LIMITER_EFFECT_THRESHOLD != new_data->LIMITER_EFFECT_THRESHOLD) {
                local_effect_data->LIMITER_EFFECT_THRESHOLD = new_data->LIMITER_EFFECT_THRESHOLD;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->LIMITER_EFFECT_THRESHOLD);
                updated = true;
            }
            break;
        case LIMITER_EFFECT_RATIO:
            if (local_effect_data->LIMITER_EFFECT_RATIO != new_data->LIMITER_EFFECT_RATIO) {
                local_effect_data->LIMITER_EFFECT_RATIO = new_data->LIMITER_EFFECT_RATIO;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->LIMITER_EFFECT_RATIO);
                updated = true;
            }
            break;
        case LIMITER_EFFECT_MAKEUP_GAIN:
            if (local_effect_data->LIMITER_EFFECT_MAKEUP_GAIN != new_data->LIMITER_EFFECT_MAKEUP_GAIN) {
                local_effect_data->LIMITER_EFFECT_MAKEUP_GAIN = new_data->LIMITER_EFFECT_MAKEUP_GAIN;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->LIMITER_EFFECT_MAKEUP_GAIN);
                updated = true;
            }
            break;
        case LIMITER_EFFECT_ATTACK:
            if (local_effect_data->LIMITER_EFFECT_ATTACK != new_data->LIMITER_EFFECT_ATTACK) {
                local_effect_data->LIMITER_EFFECT_ATTACK = new_data->LIMITER_EFFECT_ATTACK;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->LIMITER_EFFECT_ATTACK);
                updated = true;
            }
            break;
        case LIMITER_EFFECT_RELEASE:
            if (local_effect_data->LIMITER_EFFECT_RELEASE != new_data->LIMITER_EFFECT_RELEASE) {
                local_effect_data->LIMITER_EFFECT_RELEASE = new_data->LIMITER_EFFECT_RELEASE;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->LIMITER_EFFECT_RELEASE);
                updated = true;
            }
            break;
        case BASS_EFFECT_ENABLED:
            if (local_effect_data->BASS_EFFECT_ENABLED != new_data->BASS_EFFECT_ENABLED) {
                local_effect_data->BASS_EFFECT_ENABLED = new_data->BASS_EFFECT_ENABLED;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->BASS_EFFECT_ENABLED);
                updated = true;
            }
            break;
        case CLARITY_EFFECT_ENABLED:
            if (local_effect_data->CLARITY_EFFECT_ENABLED != new_data->CLARITY_EFFECT_ENABLED) {
                local_effect_data->CLARITY_EFFECT_ENABLED = new_data->CLARITY_EFFECT_ENABLED;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->CLARITY_EFFECT_ENABLED);
                updated = true;
            }
            break;
        case EVEN_HARMONIC_EFFECT_ENABLED:
            if (local_effect_data->EVEN_HARMONIC_EFFECT_ENABLED != new_data->EVEN_HARMONIC_EFFECT_ENABLED) {
                local_effect_data->EVEN_HARMONIC_EFFECT_ENABLED = new_data->EVEN_HARMONIC_EFFECT_ENABLED;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->EVEN_HARMONIC_EFFECT_ENABLED);
                updated = true;
            }
            break;
        case CONVOLVE_EFFECT_ENABLED:
            if (local_effect_data->CONVOLVE_EFFECT_ENABLED != new_data->CONVOLVE_EFFECT_ENABLED) {
                local_effect_data->CONVOLVE_EFFECT_ENABLED = new_data->CONVOLVE_EFFECT_ENABLED;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->CONVOLVE_EFFECT_ENABLED);
                updated = true;
            }
            break;
        case LIMITER_EFFECT_ENABLED:
            if (local_effect_data->LIMITER_EFFECT_ENABLED != new_data->LIMITER_EFFECT_ENABLED) {
                local_effect_data->LIMITER_EFFECT_ENABLED = new_data->LIMITER_EFFECT_ENABLED;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->LIMITER_EFFECT_ENABLED);
                updated = true;
            }
            break;
        case SPEAKER_EFFECT_ENABLED:
            if (local_effect_data->SPEAKER_EFFECT_ENABLED != new_data->SPEAKER_EFFECT_ENABLED) {
                local_effect_data->SPEAKER_EFFECT_ENABLED = new_data->SPEAKER_EFFECT_ENABLED;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->SPEAKER_EFFECT_ENABLED);
                updated = true;
            }
            break;
        case LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED:
            if (local_effect_data->LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED != new_data->LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED) {
                local_effect_data->LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED = new_data->LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED;
                AudioProcessor::getInstance().setEffectParam(param_id, new_data->LOOK_AHEAD_SOFT_LIMIT_EFFECT_ENABLED);
                updated = true;
            }
            break;
        case CONVOLVE_EFFECT_IR_PATH: {
            std::string new_path(new_data->CONVOLVE_EFFECT_IR_PATH);
            if (last_ir_path != new_path) {
                last_ir_path = new_path;
                // IR_PATH变化时，读取IR_DATA数据
                if (shared_data->ir_length > 0) {
                    int sample_count = shared_data->ir_length / 2;
                    std::vector<std::vector<float>> ir_data(2);
                    ir_data[0].resize(sample_count);
                    ir_data[1].resize(sample_count);
                    for (int i = 0; i < sample_count; i++) {
                        ir_data[0][i] = new_data->CONVOLVE_EFFECT_IR_DATA[i * 2];
                        ir_data[1][i] = new_data->CONVOLVE_EFFECT_IR_DATA[i * 2 + 1];
                    }
                    AudioProcessor::getInstance().setEffectParam(ParamID::CONVOLVE_EFFECT_IR_PATH, std::move(ir_data));
                    updated = true;
                }
            }
            break;
        }
        default:
            break;
    }

    return updated;
}

// 处理共享内存数据
void WechoAPO::processSharedData() {
    if (shared_data == nullptr) {
        return;
    }

    // 检查flags是否为true（APO拥有读取权）
    bool flags = atomicLoadVolatile(&shared_data->flags);
    if (!flags) {
        return;
    }

    // 读取enabled_apo
    bool new_enabled = shared_data->enabled_apo;
    bool current_enabled = enabled_apo.load(std::memory_order_acquire);
    if (new_enabled != current_enabled) {
        enabled_apo.store(new_enabled, std::memory_order_release);
        DebugLog("[WechoAPO] enabled_apo changed to: ", new_enabled);
    }

    // 比对并更新所有效果参数
    const EffectData* new_effect_data = &shared_data->effect_data;

    // 遍历所有参数ID进行比对
    for (int param_id = 0; param_id < MAX_EFFECT_PARAM; param_id++) {
        compareAndUpdateEffectParam(static_cast<ParamID>(param_id), new_effect_data);
    }

    // 读取完成后，将flags设为false，表示UI可以写入
    atomicStoreVolatile(&shared_data->flags, false);
}

// 共享内存读取线程
void WechoAPO::sharedMemoryThreadFunc() {
    while (!receiver_should_exit.load(std::memory_order_acquire)) {
        // 如果未连接，尝试连接
        if (!shared_memory_connected.load(std::memory_order_acquire)) {
            if (!connectSharedMemory()) {
                // 连接失败，30ms后重试
                Sleep(30);
                continue;
            }
        }

        // 处理共享内存数据
        processSharedData();

        // 短暂休眠，避免CPU占用过高
        Sleep(1);
    }
}

// 心跳线程
void WechoAPO::heartbeatThreadFunc() {
    while (!receiver_should_exit.load(std::memory_order_acquire)) {
        if (shared_memory_connected.load(std::memory_order_acquire) && shared_data != nullptr) {
            // 每10ms更新一次心跳
            uint64_t current_time = GetTickCount64();
            atomicStoreVolatile64(&shared_data->last_heart_beat, current_time);
        }
        Sleep(10);
    }
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
