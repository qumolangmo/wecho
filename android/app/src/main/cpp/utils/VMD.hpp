#ifndef __VMD_HPP__
#define __VMD_HPP__

#include "convolver.hpp"
#include <vector>
#include <algorithm>
#include <complex>
#include <cmath>

class VMD {
private:
    static constexpr int N = 512;
    static constexpr int fs = 4096;
    static constexpr float alpha = 2000.0f;
    static constexpr float tau = 0.f;
    static constexpr int max_iter = 150;
    static constexpr float tol = 1e-6f;
    static constexpr int K = 3;

    FFTWFComplexArray fft_in, ifft_out;
    FFTWFPlan forward_plan, backward_plan;
    std::vector<std::vector<float>> modes;
    std::vector<float> omega, pre_build_omega;
    std::vector<FFTWFComplexArray> u_hat;
    FFTWFComplexArray f_hat;
    FFTWFComplexArray sum_hat;
    
    std::vector<float> w;

    std::vector<std::vector<float>> prev_modes;

public:
    VMD()
        : fft_in(N)
        , ifft_out(N)
        , forward_plan(N, FFTW_FORWARD, fft_in, f_hat, FFTW_ESTIMATE)
        , backward_plan(N, FFTW_BACKWARD, ifft_out, fft_in, FFTW_ESTIMATE)
        , modes(K, std::vector<float>(N))
        , prev_modes(K, std::vector<float>(N))
        , omega(K)
        , pre_build_omega(K)
        , u_hat(K)
        , f_hat(N)
        , sum_hat(N)
        , w(N) {

        for (int i = 0; i < N; i++) {
            w[i] = static_cast<float>(i) * fs / N;
        }

        for (int k = 0; k < K; ++k) {
            pre_build_omega[k] = static_cast<float>(k) / K * (fs / 2.0f);
        }

        for (int k = 0; k < K; ++k) {
            u_hat[k] = FFTWFComplexArray(N);
        }
    }

    void reset() {
        omega.assign(pre_build_omega.begin(), pre_build_omega.end());

        for (auto& mode: prev_modes) {
            mode.assign(N, 0.0f);
        }

        for (auto& mode: modes) {
            mode.assign(N, 0.0f);
        }

        for (auto& u : u_hat) {
            u.init(0);
        }
    }

    auto process(const std::vector<float>& input) -> const std::vector<std::vector<float>>& {
        reset();

        for (int i = 0; i < input.size(); i++) {
            fft_in[i][0] = input[i];
            fft_in[i][1] = 0.0f;
        }

        forward_plan.execute(fft_in, f_hat);

        for (int i = 1; i < N / 2; i++) {
            f_hat[i][0] *= 2.0f;
            f_hat[i][1] *= 2.0f;
        }

        for (int i = N/2+1; i < N; i++) {
            f_hat[i][0] = 0.0f;
            f_hat[i][1] = 0.0f;
        }

        float u_diff = tol + 1e-6f;
        int iter = 0;
        
        while (u_diff > tol && iter < max_iter) {

            sum_hat.init(0);

            for (int k = K - 1; k >= 0; k--) {
                for (int i = 0; i < N; i++) {
                    sum_hat[i][0] += u_hat[k][i][0];
                    sum_hat[i][1] += u_hat[k][i][1];
                }
            }

            for (int k = 0; k < K; k++) {
                for (int i = 0; i < N; i++) {
                    float divide = 1.0f + alpha * (w[i] - omega[k]) * (w[i] - omega[k]);
                    u_hat[k][i][0] = (f_hat[i][0] - sum_hat[i][0] + u_hat[k][i][0]) / divide;
                    u_hat[k][i][1] = (f_hat[i][1] - sum_hat[i][1] + u_hat[k][i][1]) / divide;
                }

                backward_plan.execute(u_hat[k], ifft_out);
                for (int i = 0; i < N; i++) {
                    prev_modes[k][i] = modes[k][i];
                    modes[k][i] = ifft_out[i][0] / N;
                }

                float numer = 0.0f, denom = 0.0f;
                for (int i = 0; i <= N / 2; i++) {
                    float mag = std::sqrt(u_hat[k][i][0] * u_hat[k][i][0] + u_hat[k][i][1] * u_hat[k][i][1]);
                    numer += w[i] * mag * mag;
                    denom += mag * mag;
                }
                omega[k] = numer / (denom + 1e-6f);
            }

            u_diff = 0.f;
            for (int k = 0; k < K; k++) {
                for (int i = 0; i < N; i++) {
                    u_diff += (modes[k][i] - prev_modes[k][i]) * (modes[k][i] - prev_modes[k][i]);
                }
            }
            u_diff /= N;
            iter++;
        }

        return modes;
    }
};

#endif
