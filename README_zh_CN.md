# WEcho
[![MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE-MIT)
[![Commons Clause](https://img.shields.io/badge/License-Commons%20Clause-orange)](LICENSE-COMMONS-CLAUSE)
[![Platform](https://img.shields.io/badge/platform-Android-green)](https://developer.android.com)
[![API](https://img.shields.io/badge/API-29%2B-blue.svg?style=flat)](https://developer.android.com/about/versions/10)

**[English](README.md)**

## 项目简介

WEcho 是一款功能丰富的 **Android 全局音效处理器**，无需 root 或 adb 权限，开箱即用。

底层采用 **Native C++ 实现 DSP 算法**，上层使用 Flutter 构建现代化交互界面，为现代 Android 设备带来清晰、高质量的全局音频增强体验。

## 安装要求

- Android 10 (API level 29+), 开始支持 `RECORD_AUDIO` 权限
- CPU 是 arm-v8a 架构
- 设备需支持应用音量独立调节（国内厂商从 Android 10 开始陆续支持, 但安装前还是需要确认你的OEM Android是否支持）

## 核心功能

- **声道平衡**：精确调节左右声道音量，控制立体声场
- **全局增益**：统一调整整体输出音量电平
- **Limiter 限幅器**：限制音频峰值，避免削波失真
- **瞬态增强**：提升声音细节、清晰度与冲击力
- **低频质感增强**：可调增益、中心频率、品质因子，强化低音表现
- **谐波生成**：生成偶次谐波，赋予声音温暖的模拟设备质感
- **卷积混响**：基于脉冲响应文件(IR)，模拟真实空间声学效果
- **扬声器优化器**：针对扬声器场景优化音频输出，提升低音性能

## 技术栈

Dart(Flutter) + Kotlin + C++

## 安装指南

### 从源码构建

1. **克隆仓库**
   ```bash
   git clone https://github.com/qumolangmo/wecho.git
   cd wecho
   ```
2. **安装依赖**
   ```bash
   flutter pub get
   ```
3. **构建项目**
   ```bash
   flutter build apk
   ```
4. **安装到设备**
   ```bash
   flutter install
   ```

### 从发布版安装

前往 [Releases](https://github.com/qumolangmo/wecho/releases) 页面下载最新的 APK 文件，然后直接安装到设备。

## 使用方法

1. **点击右上角捕获按钮**：选择任意应用即可，捕获全局音频流（Android 10开始，所有app的音频流都默认可以被捕获，除非其显式的拒绝了捕获权限）
2. **目标应用静音**：在音量管理中把目标应用的音量降到0
3. **启用/禁用效果**：使用开关控制每个效果的启用状态
4. **调整效果**：通过界面上的控制卡片调整各种音效参数
5. **查看效果描述**：点击每个卡片的图标查看详细的功能描述

## 依赖

### C++:

- **AudioFile**：用来读取冲激响应
- **fftw3**：借助FFT和IFFT来进行卷积

### flutter:

- **flutter**：跨平台 UI 框架
- **file\_picker**: 文件选择器
- **shared\_preferences**: 本地存储临时配置

## 贡献

欢迎提交Issue！

## 待完善功能

- 延迟改善
- AAudio代替AudioTrack
- 预设功能
- 均衡器
- 更多音频效果插件

## 联系方式

- 项目地址：<https://github.com/qumolangmo/wecho>
- 问题反馈：<https://github.com/qumolangmo/wecho/issues>
- 邮箱：<qumolangmo@gmail.com>

***

**享受更好的听觉体验！** 🎵

喜欢这个项目就点个Star吧！

## 许可声明 (License)

本软件的采用**MIT 许可证 + Commons Clause 商用限制**，属于**源可用 (Source Available)**，并非OSI认证的开源协议

### 基础许可

本软件基于**MIT License**授权，完整协议见LICENSE-MIT文件

### 附加商业限制 (Commons Clause Condition v1.0)

在MIT许可基础上，禁止商业使用，包括但不限于：

**禁止将本软件（包括其修改版、衍生版）用于任何商业目的**，包括但不限于：

- 出售本软件或其修改/衍生版
- 集成本软件或其修改版到商业产品/服务中
- 直接或间接以本软件核心功能牟利

如需商业使用、定制或分发授权，请联系作者获取商业许可。
