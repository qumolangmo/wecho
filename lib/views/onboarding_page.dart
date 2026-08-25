/// Flutter native onboarding page - no third-party dependencies
/// Uses PageView + SharedPreferences, safe with theme rebuilds
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../view_models/dsp_controller_view_model.dart';
import 'dsp_controller_android.dart';

class OnboardingPage extends StatefulWidget {
  final DSPControllerViewModel viewModel;
  const OnboardingPage({super.key, required this.viewModel});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wecho_onboarding_completed', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DSPController(viewModel: widget.viewModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final pages = [
      _OnboardingPageData(
        title: l10n.onboardingTitle,
        description: l10n.onboardingDesc,
        icon: Icons.graphic_eq,
      ),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _buildPageContent(pages[index], colorScheme);
                },
              ),
            ),
            _buildIndicator(pages.length, colorScheme),
            const SizedBox(height: 24),
            _buildBottomButtons(l10n, colorScheme, pages.length),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(_OnboardingPageData data, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.icon,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(int pageCount, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildBottomButtons(AppLocalizations l10n, ColorScheme colorScheme, int pageCount) {
    final isLastPage = _currentPage == pageCount - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          if (!isLastPage)
            TextButton(
              onPressed: _finishOnboarding,
              child: Text(
                l10n.onboardingSkip,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          const Spacer(),
          if (isLastPage)
            Expanded(
              child: FilledButton(
                onPressed: _finishOnboarding,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  l10n.onboardingSkip,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            FloatingActionButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Icon(Icons.arrow_forward),
            ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;

  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
  });
}
