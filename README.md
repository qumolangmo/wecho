# WEcho

[![GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-green)](https://developer.android.com)
[![API](https://img.shields.io/badge/API-29%2B-blue.svg?style=flat)](https://developer.android.com/about/versions/10)

**[中文](README_zh_CN.md)**

## Project Introduction

WEcho is a feature-rich **Android Global Audio Effect Processor** that works out-of-the-box without requiring root. With Shizuku support, compatibility is even stronger.

It uses **Native C++ for DSP algorithms** at the core and Flutter for the modern interactive interface, bringing clear, high-quality global audio enhancement to modern Android devices.

## Beta Testing & Community
- **Tencent QQ**: 1087859913
- **Discord**: https://discord.gg/RZcXwhmUNt

## System Requirements

- Android 10 (API level 29+)
- CPU arm-v8a architecture

## Core Features

### Capture Settings
- **Speaker/Headphone Profile Adaptive**: Off for unified configuration, on for automatic profile switching based on current device. 
- **Blacklist**: Exclude certain devices from capture, useful for troubleshooting.

### Audio Effects
- **Channel Balance**: Adjust left/right channel volume balance for stereo field control
- **Global Gain**: Adjust overall volume level affecting all audio signals
- **Port Compressor**: Compress dynamic range, helpful when tracks have large loudness variations
  - Threshold, Knee, Ratio, Makeup Gain, Attack, Release
- **Diff Surrounding**: extend the stereo 
- **Transient Enhancement**: Enhance mid-high frequency transient response for clarity and detail
- **Bass Enhancement**: Boost low-frequency signals for better bass effect
  - Gain controls intensity, center frequency determines enhancement range, Q factor affects bass elasticity
- **Even Harmonic Generator**: Generate even harmonics for warm analog device texture
  - Base, Warm, Sugar three-level adjustment
- **Convolution Reverb**: Use impulse response files to simulate real-space acoustics
  - Supports up to 65536 samples/channel
- **Virtual Bass**: Optimized for speaker playback, enhance bass perception
- **Multi-Band Limiter**: Automatic limiting, significantly improves distortion
- **Low Cut**: Speaker mode only, cut low frequencies below cutoff to allow louder output
- **IIR Equalizer**: Simple IIR equalizer with fixed 10-band adjustment
- **FDN Reverb**: FDN reverb effect with adjustable parameters
- **WEcho DSP**: Generate custom audio effects with C language

##### Tech Stack

Dart(Flutter) + Kotlin + C++

## Installation Guide

### Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/qumolangmo/wecho.git
   cd wecho
   ```
2. **Install dependencies**
   ```bash
   flutter pub get
   ```
3. **Build the project**
   ```bash
   flutter build apk
   ```
4. **Install to device**
   ```bash
   flutter install
   ```

### Install from Release

Go to the [Releases](https://github.com/qumolangmo/wecho/releases) page to download the latest APK file, then install it directly to your device.

## Usage

1. install WEcho, install Shizuku(optional)
2. WEcho will query shizuku permission when shizuku installed. just allow it.
3. if no shizuku, you can grant WEcho permission by executing adb commands:
   ```bash
   adb shell pm grant com.qumolangmo.wecho android.permission.DUMP
   adb shell appops set com.qumolangmo.wecho PROJECT_MEDIA allow
   ```

## Dependencies

### C++:

- **AudioFile**: Used to read impulse responses
- **fftw3**: FFT and IFFT for convolution

### Flutter:

- **flutter**: Cross-platform UI framework
- **file_picker**: File picker
- **shared_preferences**: Local storage for temporary configuration
- **path_provider**: Get application document directory
- **smooth_onboarding**: Onboarding screen for new users
- **window_manager**: Window management
- **flutter_staggered_grid_view**: Staggered grid view component
- **dartz**: Functional programming, eliminate try-catch
- **flutter_code_editer**: Code editor for Flutter
- **flutter_highlight**: Code highlighting for Flutter

## Contribution

Welcome to submit Issues!

## Features to be Improved

- Replace AudioTrack with AAudio
- AI tuning
- Hi-Ending system
- More audio effect plugins

## Contact

- Project address: <https://github.com/qumolangmo/wecho>
- Issue feedback: <https://github.com/qumolangmo/wecho/issues>
- Email: <qumolangmo@gmail.com>

***

**Enjoy better audio experience!** 🎵

If you like this project, please give it a Star!

## License

This software is licensed under the **GNU General Public License v3.0**.

See the [LICENSE](LICENSE) file for the complete agreement.
