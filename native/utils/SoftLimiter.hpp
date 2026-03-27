#ifndef __LOOK_AHEAD_SOFT_LIMIT_EFFECT_HPP__
#define __LOOK_AHEAD_SOFT_LIMIT_EFFECT_HPP__

#include <deque>
#include "filter.hpp"
#include "debug.hpp"

template<int size>
class SlidingWindow {
private:
    std::deque<float> dq;
    std::array<float, size> buffer;
    int write_pos;

public:
    SlidingWindow() {
        buffer.fill(0);
    }

    void update(float input) {
        buffer[write_pos] = input;

        if (!dq.empty() && dq.front() == write_pos) {
            dq.pop_front();
        }

        while (!dq.empty() && buffer[dq.back()] <= input) {
            dq.pop_back();
        }

        dq.push_back(write_pos);

        if constexpr ((size & (size - 1)) == 0) {
            write_pos = (write_pos + 1) & (size - 1);
        } else {
            write_pos = (write_pos + 1) % size;
        }
    }

    float max() {
        if (dq.empty()) {
            return 0.0f;
        } else {
            return buffer[dq.front()];
        }
    }

    void reset() {
        dq.clear();
        buffer.fill(0);
    }
};

enum BandType {
    LOW,
    HIGH
};

template<BandType type>
class LookaheadLimiter {
private:
    static constexpr int DELAY_SIZE = 256;
    float attack_smooth = 0.1f;
    float release_smooth = 0.9f;

    float gate;
    float current_gain;
    float smoothed_gain;
    float beta;

    DelayLine<DELAY_SIZE> delay_l;
    DelayLine<DELAY_SIZE> delay_r;
    SlidingWindow<DELAY_SIZE> slidingWindow;

    int peak_hold_counter;
    bool limiting_active;

public:
    LookaheadLimiter()
        :gate(0.999f) {

        reset();
        delay_l.setDelay(DELAY_SIZE);
        delay_r.setDelay(DELAY_SIZE);
    }

    void setAttack(float attack_coeff) {
        attack_smooth = attack_coeff;
    }

    void setRelease(float release_coeff) {
        release_smooth = release_coeff;
    }

    void setLink(float link) {
        beta = link;
    }

    std::pair<float, float> process(float input_l, float input_r) {
        float abs_input_l = std::abs(input_l);
        float abs_input_r = std::abs(input_r);
        float abs_input = std::max(abs_input_l, abs_input_r);

        if (abs_input >= gate) {
            if (!limiting_active) {
                slidingWindow.reset();
                limiting_active = true;
            }

            peak_hold_counter = std::min(peak_hold_counter + 1, DELAY_SIZE);

            slidingWindow.update(abs_input);
            abs_input = slidingWindow.max();
        } else if (limiting_active) {
            peak_hold_counter = std::max(peak_hold_counter - 1, 0);
            limiting_active = (!!peak_hold_counter);
        }

        float target_gain = 1.0f;
        if (limiting_active && abs_input > gate) {
            target_gain = gate / abs_input;
        }

        if constexpr (type == LOW) {
            if (limiting_active) {
                smoothed_gain = target_gain * attack_smooth + smoothed_gain * (1 - attack_smooth);
            } else {
                smoothed_gain = target_gain * (1 - release_smooth) + smoothed_gain * release_smooth;
            }
            current_gain = smoothed_gain;
        } else {
            float min_gain = current_gain * 0.999f + 0.001f;
            smoothed_gain = target_gain * attack_smooth + smoothed_gain * release_smooth;
            current_gain = smoothed_gain < min_gain ? smoothed_gain: min_gain;
        }

        float delayed_sample_l = delay_l.process(input_l);
        float delayed_sample_r = delay_r.process(input_r);
        float output_l = delayed_sample_l * current_gain;
        float output_r = delayed_sample_r * current_gain;

        output_l = std::clamp(output_l, -gate, gate);
        output_r = std::clamp(output_r, -gate, gate);

        return {output_l, output_r};
    }

    void setGate(float gate_db) {
        gate = std::pow(10, gate_db / 20);
    }

    void reset() {
        delay_l.reset();
        delay_r.reset();
        slidingWindow.reset();
        peak_hold_counter = 0;
        current_gain = 1.0f;
        smoothed_gain = 1.0f;
        limiting_active = false;
    }
};

class MultiBandLimiter {
private:
    LinkwitzRiley4Order<LOW_PASS> lp_100[2];
    LinkwitzRiley4Order<BAND_PASS> bp_100_600[2];
    LinkwitzRiley4Order<HIGH_PASS> hp_600[2];
    LookaheadLimiter<LOW> lp;
    LookaheadLimiter<HIGH> hp;
    LookaheadLimiter<LOW> bp;
    LookaheadLimiter<HIGH> last;
    float prev_y_l, prev_y_r;
    float prev_x_l, prev_x_r;

public:
    MultiBandLimiter() {
        for (int i = 0; i < 2; i++) {
            lp_100[i].setLowPass(100);
            bp_100_600[i].setBandPass(100, 600);
            hp_600[i].setHighPass(600);
        }

        lp.setAttack(0.001f);
        lp.setRelease(0.999f);
        lp.setGate(-9.0f);

        bp.setAttack(0.001f);
        bp.setRelease(0.999f);
        bp.setGate(-6.0f);

        hp.setGate(-3.0f);
        last.setGate(-0.001f);

        prev_y_l = prev_y_r = prev_x_l = prev_x_r = 0;
    }

    std::pair<float, float> process(float input_l, float input_r) {
        float lp_l = lp_100[0].process(input_l);
        float lp_r = lp_100[1].process(input_r);
        float hp_l = hp_600[0].process(input_l);
        float hp_r = hp_600[1].process(input_r);
        float bp_l = bp_100_600[0].process(input_l);
        float bp_r = bp_100_600[1].process(input_r);

        auto [out_lp_l, out_lp_r] = lp.process(lp_l, lp_r);
        auto [out_bp_l, out_bp_r] = bp.process(bp_l, bp_r);
        auto [out_hp_l, out_hp_r] = hp.process(hp_l, hp_r);

        float out_l = out_lp_l + out_bp_l + out_hp_l;
        float out_r = out_lp_r + out_bp_r + out_hp_r;
    
        auto [l, r] = last.process(out_l, out_r);
        
        float cur_x_l = l;
        float cur_x_r = r;

        l = (cur_x_l - prev_x_l) + 0.999f * prev_y_l;
        r = (cur_x_r - prev_x_r) + 0.999f * prev_y_r;

        prev_x_l = cur_x_l;
        prev_x_r = cur_x_r;

        prev_y_l = l;
        prev_y_r = r;

        return {l, r};
    }

    void reset() {
        lp.reset();
        hp.reset();
        lp_100[0].reset();
        lp_100[1].reset();

        prev_y_l = prev_y_r = prev_x_l = prev_x_r = 0;
    }

};
#endif