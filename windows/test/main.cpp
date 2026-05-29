#include "../../native/AudioProcessor.hpp"
#include "../../native/utils/AudioFile.hpp"
#include <iostream>

bool loadMusicFile(const std::string& path, std::vector<std::vector<float>>& samples) {
    static AudioFile<float> music;

    if (!music.load(path)) {
        std::cout << "failed to load music file: " << path << std::endl;
        return false;
    }

    if (samples.size() != 2) {
        std::cout << "samples.size() must equals 2!" << std::endl;
        return false;
    }

    if (samples[0].size() != 0) {
        std::cout << "samples[0].size() must equals 0!" << std::endl;
        return false;
    }

    if (music.getNumChannels() == 1) {
        int j;
        for (j = 0; j < music.getNumSamplesPerChannel(); j++) {
            samples[0].emplace_back(music.samples[0][j]);
            samples[1].emplace_back(music.samples[0][j]);
        }
        samples[0].resize(j);
        samples[1].resize(j);
    } else {
        // TODO: support multi-channel IR
        int i, j;
        for (int i = 0; i < 2; i++) {
            for (j = 0; j < music.getNumSamplesPerChannel(); j++) {
                samples[i].emplace_back(music.samples[i][j]);
            }
            samples[i].resize(j);
        }
    }
}

int main() {
    AudioProcessor& processor = AudioProcessor::getInstance();
    processor.setEffectParam(ParamID::GAIN_EFFECT_GAIN, -11.0f);
    processor.setEffectParam(ParamID::BASS_EFFECT_GAIN, 3);
    processor.setEffectParam(ParamID::BASS_EFFECT_CENTER_FREQ, 97);
    processor.setEffectParam(ParamID::BASS_EFFECT_Q, 0.6f);
    processor.setEffectParam(ParamID::BASS_EFFECT_ENABLED, true);

    processor.setEffectParam(ParamID::LOW_CAT_EFFECT_CUTOFF_FREQ, 169);
    processor.setEffectParam(ParamID::LOW_CAT_EFFECT_ENABLED, true);

    processor.setEffectParam(ParamID::SPEAKER_EFFECT_2_HARMONIC_COEFFS, 0.0f);
    processor.setEffectParam(ParamID::SPEAKER_EFFECT_4_HARMONIC_COEFFS, 0.0f);
    processor.setEffectParam(ParamID::SPEAKER_EFFECT_6_HARMONIC_COEFFS, 0.7f);
    processor.setEffectParam(ParamID::SPEAKER_EFFECT_BP_GAIN, 0.3f);
    processor.setEffectParam(ParamID::SPEAKER_EFFECT_HP_GAIN, 0.3f);
    processor.setEffectParam(ParamID::SPEAKER_EFFECT_ENABLED, true);

    std::vector<std::vector<float>> samples(2);
    loadMusicFile("./test1.wav", samples);
    std::vector<std::vector<float>> out(2, std::vector<float>(samples[0].size()));
    out[0].resize(0);
    out[1].resize(0);

    for (int i = 0; i < samples[0].size() / 480 + 1; i++) {
        float input[960], output[960];

        memset(input, 0, sizeof(float) * 960);
        memset(output, 0, sizeof(float) * 960);

        int idx = 0;
        for (int j = 0; j < 480 && i * 480 + j < samples[0].size(); j++) {
            input[idx++] = samples[0][i * 480 + j];
            input[idx++] = samples[1][i * 480 + j];
        }

        processor.process(input, output, 960);

        for (int j = 0; j < 480 && i * 480 + j < samples[0].size(); j++) {
            out[0].push_back(output[j * 2]);
            out[1].push_back(output[j * 2 + 1]);
        }
    }

    AudioFile<float> out_file;
    out_file.setAudioBuffer(out);
    out_file.setSampleRate(48000);
    out_file.setBitDepth(32);
    out_file.save("test.out_put.wav");

    return 0;
}