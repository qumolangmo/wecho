﻿/*
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

#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>
#include <thread>
#include <vector>
#include <windows.h>

#include "../native/enum.h"

/*
 * Wire protocol header (20 bytes, little-endian, no padding).
 *
 *   +----------+------------+--------------+--------------+---------+---------------------+
 *   | magic(4) | param_id(4)| value_type(4)| value_size(4)| flags(4)| payload(value_size) |
 *   +----------+------------+--------------+--------------+---------+---------------------+
 *
 * value_type : ParamType (BOOL/INT/FLOAT/STRING/ARRAY), see native/enum.h.
 * flags      : bitmask; bit 0 (FLAG_INITIALIZE) marks an init-batch write so
 *              the receiver passes initialize=true to setEffectParam (triggers
 *              instant effect switching instead of crossfade).
 *
 * payload layout by ParamType:
 *   BOOL    : uint8_t (1 byte)
 *   INT     : int32_t (4 bytes)
 *   FLOAT   : float   (4 bytes)
 *   STRING  : UTF-8 bytes, no trailing '\0', length given by value_size
 *   ARRAY   : raw struct memory (validated by param_id in dispatch)
 */
struct PipeMessageHeader {
    static constexpr uint32_t MAGIC = 0x57454348u;          // 'W''E''C''H'
    static constexpr uint32_t FLAG_INITIALIZE = 0x00000001u; // flags bit 0
    uint32_t magic;
    int32_t  param_id;     // ParamID
    uint32_t value_type;   // ParamType
    uint32_t value_size;   // payload byte count (excluding header)
    uint32_t flags;        // bitmask (FLAG_INITIALIZE, ...)
};
static_assert(sizeof(PipeMessageHeader) == 20, "PipeMessageHeader must be 20 bytes");

class PipeServer {
public:
    static PipeServer& instance();

    void start();
    void stop();

private:
    PipeServer();
    ~PipeServer();
    PipeServer(const PipeServer&) = delete;
    PipeServer& operator=(const PipeServer&) = delete;

    enum class IoResult { Ok, Shutdown, Disconnected, Error };

    void run();
    void stopLocked();
    HANDLE createPipeInstance();
    HANDLE waitForClient(HANDLE pipe, HANDLE io_event);
    IoResult overlappedRead(HANDLE pipe, HANDLE io_event, void* buf, DWORD len, DWORD& got);
    bool readMessage(HANDLE pipe, HANDLE io_event);
    void dispatch(const PipeMessageHeader& hdr, const uint8_t* payload);

    static constexpr const wchar_t* PIPE_NAME   = L"\\\\.\\pipe\\WechoAPO";
    static constexpr size_t MAX_PAYLOAD = 1u << 20;
    static constexpr DWORD PIPE_BUFFER = 1u << 20;

    std::thread worker;
    std::mutex mtx;
    int ref_count = 0;
    std::atomic<bool> running{false};
    HANDLE shutdown_event = nullptr;
    std::vector<uint8_t> buffer;
};