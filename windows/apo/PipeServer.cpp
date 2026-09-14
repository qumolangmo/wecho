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

#include <cstring>
#include <string>
#include <any>

#include "../../native/AudioProcessor.hpp"
#include "../../native/utils/debug.hpp"
#include "PipeServer.hpp"
#include <Sddl.h>

PipeServer& PipeServer::instance() {
    static PipeServer s;
    return s;
}

PipeServer::PipeServer() = default;

PipeServer::~PipeServer() {
    std::lock_guard<std::mutex> lock(mtx);
    stopLocked();
}

void PipeServer::start() {
    std::lock_guard<std::mutex> lock(mtx);
    if (ref_count == 0) {
        shutdown_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        if (!shutdown_event) {
            LOG_D("pipe: CreateEvent(shutdown) failed, err=%lu", GetLastError());
            return;
        }

        running.store(true, std::memory_order_release);
        worker = std::thread([this] { run(); });
    }
    ++ref_count;
}

void PipeServer::stop() {
    std::lock_guard<std::mutex> lock(mtx);

    if (ref_count == 0) {
        return;
    }
    
    if (--ref_count == 0) {
        stopLocked();
    }
}

void PipeServer::stopLocked() {
    running.store(false, std::memory_order_release);
    if (shutdown_event) {
        SetEvent(shutdown_event);
    }

    if (worker.joinable()) {
        worker.join();
    }

    if (shutdown_event) {
        CloseHandle(shutdown_event);
        shutdown_event = nullptr;
    }
}

HANDLE PipeServer::createPipeInstance() {
    SECURITY_ATTRIBUTES sa{};
    sa.nLength = sizeof(sa);
    sa.bInheritHandle = FALSE;
    PSECURITY_DESCRIPTOR pSD = nullptr;
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
            L"D:(A;;GA;;;WD)(A;;GA;;;BA)", SDDL_REVISION_1, &pSD, nullptr)) {
        LOG_D("pipe: ConvertSDDL failed, err=%lu", GetLastError());
    } else {
        sa.lpSecurityDescriptor = pSD;
    }

    HANDLE pipe = CreateNamedPipeW(
        PIPE_NAME,
        PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
        PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
        1,               // nMaxInstances
        PIPE_BUFFER,     // nOutBufferSize
        PIPE_BUFFER,     // nInBufferSize
        0,               // nDefaultTimeOut
        &sa);

    if (pSD) LocalFree(pSD);

    if (pipe == INVALID_HANDLE_VALUE) {
        LOG_D("pipe: CreateNamedPipe failed, err=%lu", GetLastError());
    }

    return pipe;
}

HANDLE PipeServer::waitForClient(HANDLE pipe, HANDLE io_event) {
    OVERLAPPED ov{};
    ov.hEvent = io_event;
    ResetEvent(io_event);

    if (ConnectNamedPipe(pipe, &ov)) {
        return pipe;
    }

    DWORD err = GetLastError();
    if (err == ERROR_PIPE_CONNECTED) {
        return pipe;
    }

    if (err == ERROR_IO_PENDING) {
        HANDLE waits[2] = { io_event, shutdown_event };
        DWORD w = WaitForMultipleObjects(2, waits, FALSE, INFINITE);
        
        if (w == WAIT_OBJECT_0 + 1) {
            CancelIoEx(pipe, &ov);
            DWORD tmp = 0;
            GetOverlappedResult(pipe, &ov, &tmp, TRUE);
            return nullptr;
        }
        
        DWORD bytes = 0;
        if (GetOverlappedResult(pipe, &ov, &bytes, FALSE)) {
            return pipe;
        }
        
        LOG_D("pipe: ConnectNamedPipe completion err=%lu", GetLastError());
        return nullptr;
    }

    LOG_D("pipe: ConnectNamedPipe failed, err=%lu", err);
    return nullptr;
}

PipeServer::IoResult PipeServer::overlappedRead(
    HANDLE pipe, HANDLE io_event, void* buf, DWORD len, DWORD& got) {
    got = 0;
    OVERLAPPED ov{};
    ov.hEvent = io_event;
    ResetEvent(io_event);

    DWORD bytes = 0;
    if (ReadFile(pipe, buf, len, &bytes, &ov)) {
        got = bytes;
        return IoResult::Ok;
    }

    DWORD err = GetLastError();
    if (err == ERROR_IO_PENDING) {
        HANDLE waits[2] = { io_event, shutdown_event };
        DWORD w = WaitForMultipleObjects(2, waits, FALSE, INFINITE);
        if (w == WAIT_OBJECT_0 + 1) {
            CancelIoEx(pipe, &ov);
            DWORD tmp = 0;
            GetOverlappedResult(pipe, &ov, &tmp, TRUE);
            return IoResult::Shutdown;
        }

        if (GetOverlappedResult(pipe, &ov, &bytes, FALSE)) {
            got = bytes;
            return IoResult::Ok;
        }

        err = GetLastError();
    }

    if (err == ERROR_MORE_DATA) {
        return IoResult::Error;
    }

    return IoResult::Disconnected;
}

bool PipeServer::readMessage(HANDLE pipe, HANDLE io_event) {
    DWORD got = 0;
    IoResult r = overlappedRead(pipe, io_event, buffer.data(),
                                static_cast<DWORD>(buffer.size()), got);
    if (r != IoResult::Ok) {
        return false;
    }

    if (got < sizeof(PipeMessageHeader)) {
        LOG_D("pipe: short read %lu", got);
        return false;
    }

    PipeMessageHeader hdr;
    std::memcpy(&hdr, buffer.data(), sizeof(hdr));
    if (hdr.magic != PipeMessageHeader::MAGIC) {
        LOG_D("pipe: bad magic 0x%08x", hdr.magic);
        return false;
    }
    if (hdr.value_size > MAX_PAYLOAD) {
        LOG_D("pipe: payload too large %u", hdr.value_size);
        return false;
    }
    if (got != sizeof(hdr) + hdr.value_size) {
        LOG_D("pipe: size mismatch got=%lu header+value=%zu",
              got, sizeof(hdr) + hdr.value_size);
        return false;
    }

    dispatch(hdr, buffer.data() + sizeof(hdr));
    return true;
}

void PipeServer::dispatch(const PipeMessageHeader& hdr, const uint8_t* p) {
    auto& ap = AudioProcessor::getInstance();
    auto id = static_cast<ParamID>(hdr.param_id);
    const bool initialize = (hdr.flags & PipeMessageHeader::FLAG_INITIALIZE) != 0;

    switch (hdr.value_type) {
    case PARAM_TYPE_BOOL: {
        if (hdr.value_size != 1) { LOG_D("pipe: bad bool size %u", hdr.value_size); return; }
        ap.setEffectParam(id, std::any(static_cast<bool>(p[0] != 0)), initialize);
        break;
    }
    case PARAM_TYPE_INT: {
        if (hdr.value_size != sizeof(int32_t)) { LOG_D("pipe: bad int size %u", hdr.value_size); return; }
        int32_t v;
        std::memcpy(&v, p, sizeof(v));
        ap.setEffectParam(id, std::any(static_cast<int>(v)), initialize);
        break;
    }
    case PARAM_TYPE_FLOAT: {
        if (hdr.value_size != sizeof(float)) { LOG_D("pipe: bad float size %u", hdr.value_size); return; }
        float v;
        std::memcpy(&v, p, sizeof(v));
        ap.setEffectParam(id, std::any(v), initialize);
        break;
    }
    case PARAM_TYPE_STRING: {
        std::string s(reinterpret_cast<const char*>(p), hdr.value_size);
        ap.setEffectParam(id, std::any(std::move(s)), initialize);
        break;
    }
    case PARAM_TYPE_SCRIPT_PARAMS: {
        if (hdr.value_size != sizeof(ScriptParamsArray)) {
            LOG_D("pipe: bad script params size %u", hdr.value_size); return;
        }

        static thread_local ScriptParamsArray buf;
        std::memcpy(&buf, p, sizeof(buf));
        ap.setEffectParam(id, std::any(static_cast<ScriptParams*>(buf)), initialize);
        break;
    }
    default:
        LOG_D("pipe: unknown value_type %u", hdr.value_type);
        break;
    }
}

void PipeServer::run() {
    buffer.assign(MAX_PAYLOAD + sizeof(PipeMessageHeader), 0);

    HANDLE io_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!io_event) {
        LOG_D("pipe: CreateEvent(io) failed, err=%lu", GetLastError());
        return;
    }

    LOG_D("pipe: server started, name=%ws", PIPE_NAME);

    while (running.load(std::memory_order_acquire)) {
        HANDLE pipe = createPipeInstance();
        if (pipe == INVALID_HANDLE_VALUE) {
            if (WaitForSingleObject(shutdown_event, 1000) == WAIT_OBJECT_0) break;
            continue;
        }

        HANDLE client = waitForClient(pipe, io_event);
        if (client == nullptr) {
            CloseHandle(pipe);
            break;
        }

        while (running.load(std::memory_order_acquire)) {
            if (!readMessage(client, io_event)) {
                break;
            }
        }

        FlushFileBuffers(client);
        DisconnectNamedPipe(client);
        CloseHandle(client);
    }

    CloseHandle(io_event);
    LOG_D("pipe: server stopped");
}
