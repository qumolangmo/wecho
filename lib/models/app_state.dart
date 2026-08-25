/// Global app state - viewModel singleton and cached home widget
import 'package:flutter/material.dart';
import '../view_models/dsp_controller_view_model.dart';
import '../views/dsp_controller_android.dart';
import '../views/loading_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppState {
  static final DSPControllerViewModel viewModel = DSPControllerViewModel();
  static Widget? _cachedHome;

  static Widget get home {
    if (_cachedHome != null) return _cachedHome!;
    if (kIsWeb) {
      _cachedHome = DSPController(viewModel: viewModel);
    } else {
      _cachedHome = LoadingScreen(viewModel: viewModel);
    }
    return _cachedHome!;
  }
}
