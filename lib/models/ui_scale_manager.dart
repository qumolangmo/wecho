/// Global UI auto-scale manager - scales entire app UI based on 440dp design base
/// Completely automatic, not exposed to user
import 'package:flutter/material.dart';

class UIScaleManager {
  /// 设计基准宽度（dp）：对应 1216×2688 物理分辨率，DPR≈2.76
  static const double baseWidth = 440.0;

  /// 自动缩放范围限制，防止在平板/超宽屏上过度放大
  static const double autoScaleMin = 0.85;
  static const double autoScaleMax = 1.3;

  /// 用户手动设置的缩放倍数（默认1.0，即不额外缩放）
  /// 由设置页的界面缩放滑块控制，全局生效
  static final ValueNotifier<double> userScale = ValueNotifier<double>(1.0);

  /// 根据实际屏幕宽度计算自动缩放比例
  /// 以 baseWidth(440dp) 为基准，等比缩放，保证UI和字体不变形
  /// 最终缩放 = 自动缩放 × 用户手动缩放
  static double calculateAutoScale(double screenWidth) {
    final auto = (screenWidth / baseWidth).clamp(autoScaleMin, autoScaleMax);
    return (auto * userScale.value).clamp(autoScaleMin * 0.8, autoScaleMax * 1.3);
  }
}
