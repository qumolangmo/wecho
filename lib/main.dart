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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Edge-to-edge 全屏模式：状态栏透明，内容延伸到状态栏下方
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
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
        return ValueListenableBuilder<AppTheme>(
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
        );
      },
      home: AppState.home,
    );
  }
}
