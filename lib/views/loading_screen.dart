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
import 'dart:io';
import 'package:smooth_onboarding/smooth_onboarding.dart';
import '../l10n/app_localizations.dart';
import '../view_models/dsp_controller_view_model.dart';
import 'dsp_controller_android.dart';

class LoadingScreen extends StatefulWidget {
  final DSPControllerViewModel viewModel;

  const LoadingScreen({super.key, required this.viewModel});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _waitForSettings();
    _waitForInitialization();
  }

  Future<void> _waitForSettings() async {
    await widget.viewModel.settingsLoaded;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _waitForInitialization() async {
    await widget.viewModel.initialized;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _buildOnboardingGate(),
          ),
        );
      });
    }
  }

  Widget _buildOnboardingGate() {
    final l10n = AppLocalizations.of(context)!;
    return OnboardingGate(
      storageKey: 'wecho_onboarding',
      pages: [
        OnboardingPage(
          title: l10n.onboardingTitle,
          body: Column(
            children: [
              const SizedBox(height: 144),
              Text(
                l10n.onboardingDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ],
          ),
          buttonLabel: l10n.onboardingSkip,
        ),
      ],
      child: const DSPController(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surface;

    return Scaffold(
      backgroundColor: baseColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Expanded(
              child: Center(
                child: _buildLogo(colorScheme),
              ),
            ),
            const SizedBox(height: 32),
            _buildLoadingIndicator(colorScheme),
            const SizedBox(height: 24),
            _buildLoadingText(colorScheme),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(ColorScheme colorScheme) {
    final imagePath = widget.viewModel.loadingImagePath;

    if (imagePath != null && imagePath.isNotEmpty) {
      return Image.file(
        File(imagePath),
        height: 120,
        width: 120,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildDefaultLogo(colorScheme),
      );
    }

    return _buildDefaultLogo(colorScheme);
  }

  Widget _buildDefaultLogo(ColorScheme colorScheme) {
    return Image.asset(
      'assets/ic_wecho.png',
      height: 120,
      width: 120,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          Icons.equalizer,
          color: Colors.white,
          size: 64,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ColorScheme colorScheme) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        color: colorScheme.primary,
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildLoadingText(ColorScheme colorScheme) {
    return Text(
      'Initializing...',
      style: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}