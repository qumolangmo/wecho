/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'views/dsp_controller_android.dart';
import 'views/dsp_controller_windows.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D4FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: _getPlatformHome(),
    );
  }

  Widget _getPlatformHome() {
    if (kIsWeb) {
      return const DSPController();
    }
    
    if (Platform.isWindows) {
      return const DSPControllerWindows();
    }
    
    return const DSPController();
  }
}
