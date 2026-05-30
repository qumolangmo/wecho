# WEcho

[![GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-green)](https://developer.android.com)
[![API](https://img.shields.io/badge/API-29%2B-blue.svg?style=flat)](https://developer.android.com/about/versions/10)

**[English](README.md)**

## 项目简介

WEcho 是一款功能丰富的 **Android 全局音效处理器**，无需 root，开箱即用。配合shizuku兼容性更强

底层采用 **Native C++ 实现 DSP 算法**，上层使用 Flutter 构建现代化交互界面，为现代 Android 设备带来清晰、高质量的全局音频增强体验。

## Beta测试交流

- **QQ**: 1087859913

## 安装要求

- Android 10 (API level 29+)
- CPU 为 arm-v8a/v7a 架构

## 核心功能

### 捕获设置
- **Shizuku 模式**：关闭使用原生捕获，开启使用 Shizuku 辅助捕获
- **扬声器/耳机配置文件自适应**：关闭则使用统一配置，开启则根据当前设备自动切换配置文件

### 音效处理
- **声道平衡**：调整左右声道的音量平衡，实现立体声场的偏移控制
- **全局增益**：调整整体音量大小，影响所有音频信号的输出电平
- **Limiter 限幅器**：压缩动态范围，多首曲目响度跨度大时很有帮助
  - 阈值、拐点、压缩比、补偿增益、Attack、Release
- **瞬态增强**：增强中高频信号的瞬态响应，提升音频的清晰度和细节表现
- **低频质感**：增强低频信号，提升低音效果
  - 增益控制强度、中心频率决定增强范围、品质因子影响低频弹性和宽度
- **wecho 女毒**：生成偶次谐波，为音频添加温暖的模拟设备质感
  - 声底、暖味、女毒 三档调节
- **卷积混响**：使用冲激响应文件模拟真实空间或设备的声学特性
  - 最高支持 65536 samples/channel
- **wecho 虚拟低音**：针对扬声器外放场景优化，提升低频下潜
  - 高通增益、带通增益、2/4/6次谐波系数调节
  - 谐波比例建议典型值：0.6 0.2 0.2
- **多频段 Limiter**：自动进行限幅，大幅改善破音情况
- **低频切除**：扬声器模式专用，切除截止频率以下的低频，留出余量驱动更大响度
- **IIR 均衡器**：简单的 IIR 均衡器实现，支持固定 10 段调节

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

原生捕获模式：
1. **点击右上角捕获按钮**：选择任意应用即可，捕获全局音频流
2. **目标应用静音**：在音量管理中把目标应用的音量降到 0
Shizuku模式：
1. **设置里打开shizuku模式**：授予全部权限
2. **重启wecho**

3. **启用/禁用效果**：使用开关控制每个效果的启用状态
4. **调整效果**：通过界面上的控制卡片调整各种音效参数
5. **查看效果描述**：点击每个卡片的图标查看详细的功能描述

## 依赖

### C++:

- **AudioFile**：用来读取冲激响应
- **fftw3**：借助 FFT 和 IFFT 来进行卷积

### Flutter:

- **flutter**：跨平台 UI 框架
- **file_picker**: 文件选择器
- **shared_preferences**: 本地存储临时配置
- **window_manager**: 窗口管理
- **flutter_staggered_grid_view**: 网格视图组件
- **dartz**: 干掉烦人的 try-catch

## 贡献

欢迎提交 Issue！

## 待完善功能

- AAudio 代替 AudioTrack
- 预设功能
- 虚拟低音改造
- AI调音
- 混响支持
- 差分环绕支持
- Hi-Ending system
- 更多音频效果插件

## 联系方式

- 项目地址：<https://github.com/qumolangmo/wecho>
- 问题反馈：<https://github.com/qumolangmo/wecho/issues>
- 邮箱：<qumolangmo@gmail.com>

***

**享受更好的听觉体验！** 🎵

喜欢这个项目就点个 Star 吧！

## 许可声明 (License)

本软件采用 **GNU General Public License v3.0** 授权。

完整协议见 [LICENSE](LICENSE) 文件。
