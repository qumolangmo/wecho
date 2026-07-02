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

#ifndef __FILTER_H__
#define __FILTER_H__
#include <algorithm>
#include <cmath>
#include <array>
#include "../enum.h"

#ifndef M_PI
#define M_PI 3.141592653589793
#endif

inline double omegaHalf(float fc, int sample_rate) {
    return M_PI * fc / sample_rate;
}

inline double omega(float fc, int sample_rate) {
    return 2.0 * M_PI * fc / sample_rate;
}

template<int MaxDelay>
class DelayLine {
private:
    std::array<float, MaxDelay> buffer;
    int write_pos;
    int delay;

public:
    DelayLine()
        : write_pos(0)
        , delay(0) {

        buffer.fill(0.0);
    }

    void setDelay(int samples) {
        delay = std::max(0, std::min(MaxDelay - 1, samples));
    }

    int getDelay() const {
        return delay;
    }

    float process(float input) {
        float out;
        if constexpr ((MaxDelay & (MaxDelay - 1)) == 0) {
            int read_pos = (write_pos - delay + MaxDelay) & (MaxDelay - 1);
            out = buffer[read_pos];

            buffer[write_pos] = input;
            write_pos = (write_pos + 1) & (MaxDelay - 1);    
        } else {
            int read_pos = (write_pos - delay + MaxDelay) % MaxDelay;
            out = buffer[read_pos];

            buffer[write_pos] = input;
            write_pos = (write_pos + 1) % MaxDelay;
        }

        return out;
    }

    float read(int offset = 0) const {
        if constexpr ((MaxDelay & (MaxDelay - 1)) == 0) {
            int read_pos = (write_pos - delay - offset + MaxDelay) & (MaxDelay - 1);
            return buffer[read_pos];
        } else {
            int read_pos = (write_pos - delay - offset + MaxDelay) % MaxDelay;
            return buffer[read_pos];
        }
    }

    void write(float input) {
        if constexpr ((MaxDelay & (MaxDelay - 1)) == 0) {
            buffer[write_pos] = input;
            write_pos = (write_pos + 1) & (MaxDelay - 1);
        } else {
            buffer[write_pos] = input;
            write_pos = (write_pos + 1) % MaxDelay;
        }
    }

    void reset() {
        buffer.fill(0.0);
        write_pos = 0;
    }
};

class _Biquad {
private:
    static constexpr int SAMPLE_RATE = 48000;
    double x1, x2, y1, y2;
    double a1, a2, b0, b1, b2;

public:
    _Biquad()
        : x1(0)
        , x2(0)
        , y1(0)
        , y2(0)
        , a1(0)
        , a2(0)
        , b0(1)
        , b1(0)
        , b2(0) {}

    void setCoeffs(double a0, double a1, double a2, double b0, double b1, double b2) {
        this->a1 = -(a1 / a0);
        this->a2 = -(a2 / a0);
        this->b0 = b0 / a0;
        this->b1 = b1 / a0;
        this->b2 = b2 / a0;
    }

    void setLowPass(float freq, float Q) {
        double _omega = omega(freq, SAMPLE_RATE);
        double sin_omega = std::sin(_omega);
        double cos_omega = std::cos(_omega);

        double alpha = sin_omega / (2.0 * Q);

        double a0 = 1.0 + alpha;
        double a1 = -2.0 * cos_omega;
        double a2 = 1.0 - alpha;
        double b0 = (1.0 - cos_omega) / 2.0;
        double b1 = 1.0 - cos_omega;
        double b2 = (1.0 - cos_omega) / 2.0;

        setCoeffs(a0, a1, a2, b0, b1, b2);
    }

    void setHighPass(float freq, float Q) {
        double _omega = omega(freq, SAMPLE_RATE);
        double sin_omega = std::sin(_omega);
        double cos_omega = std::cos(_omega);

        double alpha = sin_omega / (2.0 * Q);

        double a0 = 1.0 + alpha;
        double a1 = -2.0 * cos_omega;
        double a2 = 1.0 - alpha;
        double b0 = (1.0 + cos_omega) / 2.0;
        double b1 = -(1.0 + cos_omega);
        double b2 = (1.0 + cos_omega) / 2.0;

        setCoeffs(a0, a1, a2, b0, b1, b2);
    }

    void setPeak(float freq, float Q, float gain) {
        double _omega = omega(freq, SAMPLE_RATE);
        double sin_omega = std::sin(_omega);
        double cos_omega = std::cos(_omega);

        double A = std::pow(10.0, gain / 40.0);
        double alpha = sin_omega / (2.0 * Q);

        double a0 = 1.0 + alpha / A;
        double a1 = -2.0 * cos_omega;
        double a2 = 1.0 - alpha / A;
        double b0 = 1.0 + alpha * A;
        double b1 = -2.0 * cos_omega;
        double b2 = 1.0 - alpha * A;
        
        setCoeffs(a0, a1, a2, b0, b1, b2);
    }

    void setLowShelf(float freq, float Q, float gain) {
        double _omega_half = omegaHalf(freq, SAMPLE_RATE);
        double _omega = omega(freq, SAMPLE_RATE);

        double cos_omega = std::cos(_omega);
        double alpha = std::sin(_omega) / (2.0 * Q);

        double A = std::pow(10.0, gain / 40.0);
        double beta = 2.0 * std::sqrt(A) * alpha;

        double ap = A + 1;
        double am = A - 1;

        double b0 = A * (ap - am * cos_omega + beta);
        double b1 = 2 * A * (am - ap * cos_omega);
        double b2 = A * (ap - am * cos_omega - beta);
        double a0 = ap + am * cos_omega + beta;
        double a1 = -2 * (am + ap * cos_omega);
        double a2 = ap + am * cos_omega - beta;

        setCoeffs(a0, a1, a2, b0, b1, b2);
    }

    void setHighShelf(float freq, float Q, float gain) {
        double _omega_half = omegaHalf(freq, SAMPLE_RATE);
        double _omega = omega(freq, SAMPLE_RATE);

        double cos_omega = std::cos(_omega);
        double alpha = std::sin(_omega) / (2.0 * Q);

        double A = std::pow(10.0, gain / 40.0);
        double beta = 2.0 * std::sqrt(A) * alpha;

        double ap = A + 1;
        double am = A - 1;

        double b0 = A * (ap + am * cos_omega + beta);
        double b1 = -2 * A * (am + ap * cos_omega);
        double b2 = A * (ap + am * cos_omega - beta);
        double a0 = ap - am * cos_omega + beta;
        double a1 = 2 * (am - ap * cos_omega);
        double a2 = ap - am * cos_omega - beta;

        setCoeffs(a0, a1, a2, b0, b1, b2);
    }

    void reset() {
        x1 = x2 = y1 = y2 = 0;
    }

    float process(float input) {
        double out = input * b0 + b1 * x1 + b2 * x2
            + a1 * y1 + a2 * y2;

        x2 = x1;
        x1 = input;
        y2 = y1;
        y1 = out;

        return out;
    }
};

template<int num>
class Biquad {
private:
    std::array<_Biquad, num> biquads;
public:
    Biquad() {}

    _Biquad& operator[](int index) {
        return biquads[index];
    }

    /* coeffs: {freq1, Q1}, {freq2, Q2}, ... */
    void setLowPass(const std::array<std::array<float, 2>, num>& coeffs) {
        for (int i = 0; i < num; i++) {
            biquads[i].setLowPass(coeffs[i][0], coeffs[i][1]);
        }
    }

    /* coeffs: {freq1, Q1}, {freq2, Q2}, ... */
    void setHighPass(const std::array<std::array<float, 2>, num>& coeffs) {
        for (int i = 0; i < num; i++) {
            biquads[i].setHighPass(coeffs[i][0], coeffs[i][1]);
        }
    }

    /* coeffs: {freq1, Q1, gain1}, {freq2, Q2, gain2}, ... */
    void setPeak(const std::array<std::array<float, 3>, num>& coeffs) {
        for (int i = 0; i < num; i++) {
            biquads[i].setPeak(coeffs[i][0], coeffs[i][1], coeffs[i][2]);
        }
    }

    /* coeffs: {freq1, Q1, gain1}, {freq2, Q2, gain2}, ... */
    void setLowShelf(const std::array<std::array<float, 3>, num>& coeffs) {
        for (int i = 0; i < num; i++) {
            biquads[i].setLowShelf(coeffs[i][0], coeffs[i][1], coeffs[i][2]);
        }
    }

    /* coeffs: {freq1, Q1, gain1}, {freq2, Q2, gain2}, ... */
    void setHighShelf(const std::array<std::array<float, 3>, num>& coeffs) {
        for (int i = 0; i < num; i++) {
            biquads[i].setHighShelf(coeffs[i][0], coeffs[i][1], coeffs[i][2]);
        }
    }

    void setCoeffs(const std::array<std::array<double, 6>, num>& coeffs) {
        for (int i = 0; i < num; i++) {
            biquads[i].setCoeffs(coeffs[i][0], coeffs[i][1], coeffs[i][2], coeffs[i][3], coeffs[i][4], coeffs[i][5]);
        }
    }

    float process(float input) {
        double out = input;

        for (auto& biquad: biquads) {
            out = biquad.process(out);
        }

        return out;
    }

    void reset() {
        for (auto& biquad: biquads) {
            biquad.reset();
        }
    }
};

template<FilterType type>
class LinkwitzRiley4Order {
private:
    Biquad<2> biquads;

public:
    LinkwitzRiley4Order() {}

    void setLowPass(float freq) requires (type == LOW_PASS) {
        std::array<std::array<float, 2>, 2> coeffs {};
        coeffs[0] = {freq, 0.7071};
        coeffs[1] = {freq, 0.7071};
        biquads.setLowPass(coeffs);
    }

    void setHighPass(float freq) requires (type == HIGH_PASS) {
        std::array<std::array<float, 2>, 2> coeffs {};
        coeffs[0] = {freq, 0.7071};
        coeffs[1] = {freq, 0.7071};
        biquads.setHighPass(coeffs);
    }

    float process(float input) {
        return biquads.process(input);
    }

    void reset() {
        biquads.reset();
    }
};

template<>
class LinkwitzRiley4Order<BAND_PASS> {
private:
    Biquad<2> biquads_lp;
    Biquad<2> biquads_hp;

public:
    LinkwitzRiley4Order() {}

    void setBandPass(float low_freq, float high_freq) {
        std::array<std::array<float, 2>, 2> coeffs{};
        coeffs[0] = {low_freq, 0.7071};
        coeffs[1] = {low_freq, 0.7071};
        biquads_hp.setHighPass(coeffs);
        coeffs[0] = {high_freq, 0.7071};
        coeffs[1] = {high_freq, 0.7071};
        biquads_lp.setLowPass(coeffs);
    }

    float process(float input) {
        double out = input;
        out = biquads_hp.process(out);
        out = biquads_lp.process(out);
        return out;
    }

    void reset() {
        biquads_lp.reset();
        biquads_hp.reset();
    }
};

#endif
