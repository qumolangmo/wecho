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

#pragma once

#include <thread>
#include <chrono>
#include <condition_variable>
#include <atomic>

class InterruptedSleep {
private:
    std::condition_variable cv;
    std::mutex mtx;
    std::atomic<bool> is_interrupted{ false };

public:
    void interrupted() {
        is_interrupted.store(true, std::memory_order_release);
        cv.notify_one();
    }

    bool wait(std::chrono::milliseconds duration) {
        is_interrupted.store(false, std::memory_order_release);
        std::unique_lock<std::mutex> lock(mtx);

        bool completed = cv.wait_for(lock, duration, [this]() {
            return is_interrupted.load(std::memory_order_acquire);
        });

        return completed;
    }

    void reset() {
        is_interrupted.store(false, std::memory_order_release);
    }
};