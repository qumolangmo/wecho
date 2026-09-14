/*
 * Copyright (C) 2026 qumolangmo
 *
 * This file is part of Wecho.
 *
 * Wecho is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Wecho is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Wecho.  If not, see <https://www.gnu.org/licenses/>.
 */
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
    , outer_delegate(nullptr)
    , sample_rate(48000)
    , ref_count(1) {

    if (pUnkOuter != nullptr) {
        LOG_D("pUnkOuter not null, run as aggregation object");
        outer_delegate = pUnkOuter;
    } else {
        LOG_D("pUnkOuter is null, run as a single object");
        outer_delegate = reinterpret_cast<IUnknown*>(static_cast<INonDelegatingUnknown*>(this));
    }

    LOG_D("WechoAPO constructured");
    InterlockedIncrement(&instance_count);
}

WechoAPO::~WechoAPO() {
    if (InterlockedDecrement(&instance_count) == 0) {
        PipeServer::instance().stop();
    }

    LOG_D("WechoAPO destructured");
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::Initialize(UINT32 cb_data_size, BYTE* byte_data) {
    HRESULT hr = S_OK;

    if ((NULL == byte_data) && (0 != cb_data_size)) {
        LOG_D("byte_data invalid");
        return E_INVALIDARG;
    }
    if ((NULL != byte_data) && (0 == cb_data_size)) {
        LOG_D("cb_data_size invalid");
        return E_POINTER;
    }
    if (cb_data_size != sizeof(APOInitSystemEffects)) {
        LOG_D("cb_data_size != sizeof(APOInitSystemEffects)");
        return E_INVALIDARG;
    }

    LOG_D("Initialize success");

    return hr;
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::LockForProcess(
    UINT32 input_connections_num, APO_CONNECTION_DESCRIPTOR** input_connections,
    UINT32 output_connections_num, APO_CONNECTION_DESCRIPTOR** output_connections) {

    HRESULT result = S_OK;

    if (input_connections == NULL || output_connections == NULL) {
        LOG_D("input_connections or output_connections == null");
        return E_POINTER;
    }

    const WAVEFORMATEX* input_format = input_connections[0]->pFormat->GetAudioFormat();
    const WAVEFORMATEX* output_format = output_connections[0]->pFormat->GetAudioFormat();
    
    if (sample_rate != input_format->nSamplesPerSec && sample_rate != output_format->nSamplesPerSec) {
        LOG_D("LocakForProcess sample rate invalid");
        return E_INVALIDARG;
    }

    result = CBaseAudioProcessingObject::LockForProcess(
        input_connections_num, input_connections,
        output_connections_num, output_connections);

    LOG_D("LockForProcess success");

    return result;
}

STDMETHODIMP_(HRESULT __stdcall) WechoAPO::UnlockForProcess() {
    LOG_D("called UnlockForProcess");
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

        if (input_connections[0]->u32BufferFlags == BUFFER_SILENT) {
            memset(output_frames, 0, samples * sizeof(FLOAT32));
        } else {
            if (m_u32SamplesPerFrame > 1) {
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
        LOG_D("query input GetUncompressedAudioFormat failed");
        return result;
    }

    result = output_format->GetUncompressedAudioFormat(&out_format);
    if (FAILED(result)) {
        LOG_D("query output GetUncompressedAudioFormat failed");
        return result;
    }

    result = CBaseAudioProcessingObject::IsInputFormatSupported(
        output_format, requested_input_format, supported_input_format);

    if ((result == S_OK) && (in_format.dwSamplesPerFrame != 2)) {
        out_format.dwSamplesPerFrame = 2;
        out_format.fFramesPerSecond = in_format.fFramesPerSecond;

        CreateAudioMediaTypeFromUncompressedAudioFormat(&out_format, supported_input_format);

        LOG_D("WechoAPO::IsInputFormatSupported, unsupported: %d, %f", in_format.dwSamplesPerFrame, in_format.fFramesPerSecond);

        result = S_FALSE;
    }

    sample_rate = out_format.fFramesPerSecond;

    AudioProcessor::init("C:\\Windows\\System32\\WechoAPO", sample_rate, sample_rate / 100, 2);
    AudioProcessor::getInstance();
    PipeServer::instance().start();

    // 在 LOG_D("input format supported!"); 之前加：
    LOG_D("IsInputFormatSupported result=0x%08x, in_ch=%d", result, in_format.dwSamplesPerFrame);
    LOG_D("input format supported!");
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
        LOG_D("query IUnknown");
        *ppv = static_cast<INonDelegatingUnknown*>(this);
    } else if (iid == __uuidof(IAudioProcessingObject)) {
        LOG_D("query IAudioProcessingObject");
        *ppv = static_cast<IAudioProcessingObject*>(this);
    } else if (iid == __uuidof(IAudioProcessingObjectRT)) {
        LOG_D("query IAudioProcessingObjectRT");
        *ppv = static_cast<IAudioProcessingObjectRT*>(this);
    } else if (iid == __uuidof(IAudioProcessingObjectConfiguration)) {
        LOG_D("query IAudioProcessingObjectConfiguration");
        *ppv = static_cast<IAudioProcessingObjectConfiguration*>(this);
    } else if (iid == __uuidof(IAudioSystemEffects)) {
        LOG_D("query IAudioSystemEffects");
        *ppv = static_cast<IAudioSystemEffects*>(this);
    } else if (iid == __uuidof(IWechoAPO)) {
        LOG_D("query IWechoAPO");
        *ppv = static_cast<IWechoAPO*>(this);
    } else {
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    reinterpret_cast<IUnknown*>(*ppv)->AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) WechoAPO::NonDelegatingAddRef() {
    LOG_D("called NonDelegatingAddRef");
    return InterlockedIncrement(&ref_count);
}

STDMETHODIMP_(ULONG) WechoAPO::NonDelegatingRelease() {
    LOG_D("called NonDelegatingRelease");
    LONG new_ref = InterlockedDecrement(&ref_count);
    if (new_ref == 0) {
        LOG_D("ref_count == 0, delete WechoAPO");
        delete this;
    }
    return new_ref;
}