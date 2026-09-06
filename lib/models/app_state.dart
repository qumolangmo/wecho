/// Copyright (C) 2026 jiangjie977
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
import '../view_models/dsp_controller_view_model.dart';
import '../views/loading_screen.dart';

/// Global application state and navigation helpers.
class AppState {
  /// The home widget of the application.
  static Widget home(DSPControllerViewModel viewModel) =>
      LoadingScreen(viewModel: viewModel);
}
