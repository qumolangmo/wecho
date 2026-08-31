/// Copyright (C) 2026 qumolangmo
///
/// This file is part of Wecho.
///
/// Wecho is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// Wecho is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with Wecho.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'models/app_theme.dart';
import 'models/app_theme_manager.dart';
import 'models/app_state.dart';
import 'models/ui_scale_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Edge-to-edge 全屏模式：状态栏透明，内容延伸到状态栏下方
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // 强制状态栏背景透明，防止部分机型上状态栏显示黑色Window背景
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      minimumSize: Size(300, 300),
      size: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  // Load saved theme preferences (dark mode, app theme) before first frame
  await AppThemeManager.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WEcho',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: [
        Locale('en'),
        Locale('zh')
      ],
      debugShowCheckedModeBanner: false,
      // MaterialApp 只创建一次，主题通过 builder 中的 Theme widget 动态注入
      theme: AppThemeManager.lightTheme,
      darkTheme: AppThemeManager.darkTheme,
      themeMode: AppThemeManager.themeMode,
      builder: (context, child) {
        // 全局UI自适应层：FittedBox + SizedBox 实际改变子树布局空间，再缩放填满屏幕
        // 以440dp为设计基准，自动等比缩放 × 用户手动缩放
        return ValueListenableBuilder<double>(
          valueListenable: UIScaleManager.userScale,
          builder: (context, _, __) {
            final mq = MediaQuery.of(context);
            return LayoutBuilder(
              builder: (context, constraints) {
                final autoScale = UIScaleManager.calculateAutoScale(constraints.maxWidth);
                final scaledWidth = constraints.maxWidth / autoScale;
                final scaledHeight = constraints.maxHeight / autoScale;

                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: scaledWidth,
                    height: scaledHeight,
                    child: MediaQuery(
                      data: mq.copyWith(size: Size(scaledWidth, scaledHeight)),
                      child: ValueListenableBuilder<AppTheme>(
                        valueListenable: AppThemeManager.currentTheme,
                        builder: (context, theme, _) {
                          return ValueListenableBuilder<ThemeMode>(
                            valueListenable: AppThemeManager.currentMode,
                            builder: (context, mode, _) {
                              final isDark = mode == ThemeMode.dark ||
                                  (mode == ThemeMode.system &&
                                      MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                              return Theme(
                                data: isDark ? AppThemeManager.darkTheme : AppThemeManager.lightTheme,
                                child: child!,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      home: AppState.home,
    );
  }
}
