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