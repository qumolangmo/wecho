#ifndef __FILTER_H__
#define __FILTER_H__
#include <algorithm>
#include <cmath>
#include <array>
#include "../enum.h"

#define PI 3.141592653589793

inline double omegaHalf(float fc, int sample_rate) {
    return PI * fc / sample_rate;
}

inline double omega(float fc, int sample_rate) {
    return 2.0 * PI * fc / sample_rate;
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

    float process(float input) {
        int read_pos = (write_pos - delay + MaxDelay) % MaxDelay;
        float out = buffer[read_pos];

        buffer[write_pos] = input;
        write_pos = (write_pos + 1) % MaxDelay;

        return out;
    }

    void reset() {
        buffer.fill(0.0);
        write_pos = 0;
    }
};

template<FilterType type>
class Biquad {
private:
    double x1, x2, y1, y2;
    double a1, a2, b0, b1, b2;

    double _x1, _x2, _y1, _y2;
    double _a1, _a2, _b0, _b1, _b2;

public:
    Biquad()
        : x1(0)
        , x2(0)
        , y1(0)
        , y2(0)
        , a1(0)
        , a2(0)
        , b0(1)
        , b1(0)
        , b2(0)
        
        ,_x1(0)
        , _x2(0)
        , _y1(0)
        , _y2(0)
        , _a1(0)
        , _a2(0)
        , _b0(1)
        , _b1(0)
        , _b2(0) {}

    float process(float input) {
        if constexpr (type == LOW_PASS || type == HIGH_PASS) {
            float out = input * b0 + b1 * x1 + b2 * x2
                + a1 * y1 + a2 * y2;

            x2 = x1;
            x1 = input;
            y2 = y1;
            y1 = out;

            return out;
        } else if constexpr (type == BAND_PASS) {
            float hp_out = input * b0 + b1 * x1 + b2 * x2
                + a1 * y1 + a2 * y2;

            x2 = x1;
            x1 = input;
            y2 = y1;
            y1 = hp_out;

            if (1 - std::abs(_b0) < 0.000001f) {
                return hp_out;
            }

            float lp_out = hp_out * _b0 + _b1 * _x1 + _b2 * _x2
                + _a1 * _y1 + _a2 * _y2;
            
            _x2 = _x1;
            _x1 = hp_out;
            _y2 = _y1;
            _y1 = lp_out;
            
            return lp_out;
        } else {
            static_assert(type == LOW_PASS || type == HIGH_PASS || type == BAND_PASS, "Invalid filter type");
        }
    }

    void reset() {
        x1 = x2 = y1 = y2 = 0;
        _x1 = _x2 = _y1 = _y2 = 0;
    }
    
    void setCoeffs(double a0, double a1, double a2, double b0, double b1, double b2) {
        this->a1 = -(a1 / a0);
        this->a2 = -(a2 / a0);
        this->b0 = b0 / a0;
        this->b1 = b1 / a0;
        this->b2 = b2 / a0;
    }

    template<FilterType = LOW_PASS>
    void setLowPass(float freq, float Q, int sample_rate) {
        double _omega = omega(freq, sample_rate);
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

    template<FilterType = BAND_PASS>
    void setBandPass(int low_fc, int high_fc, float Q, int sample_rate) {
        double _omega_low = omega(low_fc, sample_rate);
        double _omega_high = omega(high_fc, sample_rate);
        double sin_omega_low = std::sin(_omega_low);
        double cos_omega_low = std::cos(_omega_low);
        double sin_omega_high = std::sin(_omega_high);
        double cos_omega_high = std::cos(_omega_high);

        double alpha_low = sin_omega_low / (2.0 * Q);
        double alpha_high = sin_omega_high / (2.0 * Q);

        // high pass
        double a0 = 1.0 + alpha_low;
        double a1 = -2.0 * cos_omega_low;
        double a2 = 1.0 - alpha_low;
        double b0 = (1.0 + cos_omega_low) / 2.0;
        double b1 = -(1.0 + cos_omega_low);
        double b2 = (1.0 + cos_omega_low) / 2.0;

        setCoeffs(a0, a1, a2, b0, b1, b2);

        // low pass
        a0 = 1.0 + alpha_high;
        a1 = -2.0 * cos_omega_high;
        a2 = 1.0 - alpha_high;
        b0 = (1.0 - cos_omega_high) / 2.0;
        b1 = 1.0 - cos_omega_high;
        b2 = (1.0 - cos_omega_high) / 2.0;

        // setCoeffs
        this->_a1 = -(a1 / a0);
        this->_a2 = -(a2 / a0);
        this->_b0 = b0 / a0;
        this->_b1 = b1 / a0;
        this->_b2 = b2 / a0;

    }

    template<FilterType = BAND_PASS>
    void setBandPass(float freq, float Q, int sample_rate) {
        double _omega = omega(freq, sample_rate);
        double sin_omega = std::sin(_omega);
        double cos_omega = std::cos(_omega);

        double alpha = sin_omega / (2.0 * Q);

        double a0 = 1.0 + alpha;
        double a1 = -2.0 * cos_omega;
        double a2 = 1.0 - alpha;
        double b0 = sin_omega / 2.0;
        double b1 = 0.0;
        double b2 = -(sin_omega / 2.0);

        setCoeffs(a0, a1, a2, b0, b1, b2);
    }

    template<FilterType = HIGH_PASS>
    void setHighPass(float freq, float Q, int sample_rate) {
        double _omega = omega(freq, sample_rate);
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
};
#endif
