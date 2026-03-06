/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

#include "effect.hpp"

/**********************************************ChannelBalanceEffect***************************************************/
ChannelBalanceEffect::ChannelBalanceEffect(bool _enabled, int balance)
    : Effect(_enabled) {

    setBalance(balance);
}
ChannelBalanceEffect::~ChannelBalanceEffect() {}

void ChannelBalanceEffect::reset() {}

Priority ChannelBalanceEffect::priority() const {
    return CHANNEL_BALANCE_EFFECT;
}

void ChannelBalanceEffect::setBalance(int balance) {
    if (balance == 0) {
        this->enabled.store(false, std::memory_order_release);
        return;
    } else {
        this->enabled.store(true, std::memory_order_release);
    }

    balance = std::max(-6, std::min(6, balance));

    if (balance == 0) return;

    if (balance < 0) {
        left_gain.store(std::pow(10.0f, -balance / 20.0f));
        right_gain.store(std::pow(10.0f, balance / 40.0f));
    } else {
        left_gain.store(std::pow(10.0f, -balance / 40.0f));
        right_gain.store(std::pow(10.0f, balance / 20.0f));
    }
}

void ChannelBalanceEffect::run(std::vector<std::vector<float>>& audio) {
    float _left_gain = left_gain.load(std::memory_order_acquire);
    float _right_gain = right_gain.load(std::memory_order_acquire);

    if (std::fabs(_left_gain) < 0.00001f && std::fabs(_right_gain) < 0.00001f) return;

    for (int i = 0; i < audio[0].size(); i++) {
        audio[0][i] *= _left_gain;
        audio[1][i] *= _right_gain;
    }
}
