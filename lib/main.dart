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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wecho/view_models/dsp_controller_view_model.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'models/app_theme.dart';
import 'models/app_theme_manager.dart';
import 'models/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window setup (Windows only).
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 860),
      minimumSize: Size(960, 640),
      center: true,
      title: 'WECHO',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // edge-to-edge: full screen mode.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // force transparent status bar.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  // Load saved theme preferences (dark mode, app theme) before first frame
  await AppThemeManager.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final DSPControllerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DSPControllerViewModel();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: AppThemeManager.currentTheme,
      builder: (context, _, __) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppThemeManager.currentMode,
        builder: (context, _, ___) => MaterialApp(
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

          theme: AppThemeManager.lightTheme,
          darkTheme: AppThemeManager.darkTheme,
          themeMode: AppThemeManager.themeMode,
          home: AppState.home(_viewModel),
        ),
      ),
    );
  }
}
