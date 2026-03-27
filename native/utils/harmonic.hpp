#ifndef __HARMONIC_HPP__
#define __HARMONIC_HPP__

#include <array>
#include <map>
#include <numeric>
#include <algorithm>

template<int order>
class Harmonic {
    static_assert(order >= 2, "Harmonic order must be >= 2");
private:
    std::array<double, order + 1> coeffs;

    double last_processed;
    double prev_out;

    std::map<int, std::array<double, order + 1>> cache;

public:
    Harmonic()
        : last_processed(0.0)
        , prev_out(0.0) {

        coeffs.fill(0);

        cache[0] = {1.0, 0.0};
        cache[1] = {0.0, 1.0};

        chebychevRecursive(order);
    }

    void reset() {
        last_processed = 0.0;
        prev_out = 0.0;
    }

    auto chebychevRecursive(int n) -> const std::array<double, order + 1>& {
        if (n == 0) {
            return cache[0];
        } else if (n == 1) {
            return cache[1];
        }

        if (cache.find(n) != cache.end()) {
            return cache[n];
        }

        const auto& Tn_1 = chebychevRecursive(n - 1);
        const auto& Tn_2 = chebychevRecursive(n - 2);

        std::array<double, order + 1> tmp{0};

        for (int i = 0; i < order; i++) {
            tmp[i+1] = 2.0 * Tn_1[i] - Tn_2[i+1];
        }

        tmp[0] = -Tn_2[0];

        cache[n] = tmp;

        return cache[n];
    }

    void setCoeffs(const std::array<double, order>& _gain_array) {
        coeffs.fill(0.0);

        std::array<double, order + 1> tmp;
        tmp.fill(0);

        double abs_sum = std::accumulate(_gain_array.begin(), _gain_array.end(), 0.0, [] (double acc, double gain) {
            return acc + std::abs(gain);
        });

        double scale = 1;
        if (abs_sum > 1.0) {
            scale = 1.0 / abs_sum;
        }

        std::transform(_gain_array.begin(), _gain_array.end(), tmp.begin() + 1, [scale] (double gain) { 
            return gain * scale;
        });

        for (int i = 0; i < order + 1; i++) {
            for (int j = 0; j < order + 1; j++) {
                coeffs[j] += cache[i][j] * tmp[i];
            }
        }

        reset();
    }

    float process(float input) {
        double prev_last = last_processed;

        last_processed = coeffs.back();
        for (int i = order; i > 0; i--) {
            last_processed = last_processed * input + coeffs[i-1];
        }

        prev_out = (last_processed - prev_last) + prev_out * 0.999;

        return prev_out;
    }
};

#endif
