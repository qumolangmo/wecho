# WEcho

[![MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE-MIT)
[![Commons Clause](https://img.shields.io/badge/License-Commons%20Clause-orange)](LICENSE-COMMONS-CLAUSE)
[![Platform](https://img.shields.io/badge/platform-Android-green)](https://developer.android.com)
[![API](https://img.shields.io/badge/API-29%2B-blue.svg?style=flat)](https://developer.android.com/about/versions/10)

**[中文](README_zh_CN.md)**

## Project Introduction

WEcho is a feature-rich **Android Global Audio Effect Processor** that works out-of-the-box without requiring root or adb permissions.

It uses **Native C++ for DSP algorithms** at the core and Flutter for the modern interactive interface, bringing clear, high-quality global audio enhancement to modern Android devices.

## System Requirements

- Android 10 (API level 29+), Requires `RECORD_AUDIO` permission for audio capture
- CPU arm-v8a
- Device must support independent app volume control

## Core Features

- **Channel Balance**：Precisely adjust left/right channel volume to control stereo field
- **Global Gain**：Unify and adjust overall output volume level
- **Limiter**：Limits audio peaks to avoid clipping distortion
- **Transient Enhancement**：Improves sound details, clarity, and impact
- **Bass Enhancement**：Adjustable gain, center frequency, and quality factor to enhance bass performance
- **Harmonic Generation**：Generates even harmonics for warm analog device
- **Convolution Reverb**：Simulates real-space acoustic effects based on impulse response (IR) files
- **Speaker Optimizer**：Optimizes audio output for speaker scenarios, enhancing bass performance



## Tech Stack

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

1. **Click the capture button in the upper right corner**：Select any app, it will capture the global audio stream (Starting from Android 10, all app audio streams can be captured by default unless they explicitly reject capture permission)
2. **Mute the target app**：Set the target app's volume to 0 in volume management
3. **Enable/Disable effects**：Use switches to control the enabled state of each effect
4. **Adjust effects**：Adjust various audio effect parameters through the control cards on the interface
5. **View effect descriptions**：Click each card's icon to view detailed feature descriptions

## Dependencies

### C++:

- **AudioFile**：Used to read impulse responses
- **fftw3**：Used for FFT and IFFT in convolution

### Flutter:

- **flutter**：Cross-platform UI framework
- **file\_picker**: File picker
- **shared\_preferences**: Local storage for temporary configuration

## Contribution

Welcome to submit Issues !

## Features to be Improved

- Latency improvement
- Replace AudioTrack with AAudio
- Preset functionality
- Equalizer
- More audio effect plugins

## Contact

- Project address：<https://github.com/qumolangmo/wecho>
- Issue feedback：<https://github.com/qumolangmo/wecho/issues>
- Email：<qumolangmo@gmail.com>

***

**Enjoy better audio experience!** 🎵

If you like this project, please give it a Star!

## License

This software uses **MIT License + Commons Clause commercial restriction** and is **Source Available**, not an OSI-certified open source license.

### Basic License

This software is licensed under the **MIT License**, see the LICENSE-MIT file for the complete agreement.

### Additional Commercial Restriction (Commons Clause Condition v1.0)

Based on the MIT license, commercial use is prohibited, including but not limited to:

**Prohibited to use this software (including modified or derivative versions) for any commercial purpose**, including but not limited to:

- Selling this software or its modified/derivative versions
- Integrating this software or its modified versions into commercial products/services
- Directly or indirectly profiting from the core functionality of this software

For commercial use, customization, or distribution authorization, please contact the author for a commercial license.
