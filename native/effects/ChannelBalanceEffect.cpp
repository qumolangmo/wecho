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

#include "effect.hpp"

/**********************************************ChannelBalanceEffect***************************************************/
ChannelBalanceEffect::ChannelBalanceEffect(bool _enabled, float balance)
    : Effect(_enabled) {

    setBalance(balance);
    reset();
}
ChannelBalanceEffect::~ChannelBalanceEffect() {}

void ChannelBalanceEffect::reset() {}

Priority ChannelBalanceEffect::priority() const {
    return CHANNEL_BALANCE_EFFECT;
}

void ChannelBalanceEffect::setBalance(float balance) {
    if (std::abs(balance) < 0.0001f) {
        this->setEnabled(false);
        return;
    } else {
        this->setEnabled(true);
    }

    balance = std::max(-6.0f, std::min(6.0f, balance));

    if (std::abs(balance) < 0.0001f) return;

    if (balance < -0.0001f) {
        left_gain.store(std::pow(10.0f, -balance / 20.0f));
        right_gain.store(std::pow(10.0f, balance / 40.0f));
    } else {
        left_gain.store(std::pow(10.0f, -balance / 40.0f));
        right_gain.store(std::pow(10.0f, balance / 20.0f));
    }
}

void ChannelBalanceEffect::run(std::vector<std::vector<float>>& audio) {
    float _left_gain = left_gain.load(std::memory_order_relaxed);
    float _right_gain = right_gain.load(std::memory_order_relaxed);

    if (std::fabs(_left_gain) < 0.00001f && std::fabs(_right_gain) < 0.00001f) return;

    for (int i = 0; i < audio[0].size(); i++) {
        audio[0][i] *= _left_gain;
        audio[1][i] *= _right_gain;
    }
}
