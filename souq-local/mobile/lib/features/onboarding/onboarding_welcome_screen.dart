import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/margem_background.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../l10n/app_localizations.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  /// Order requested: former 3rd → 1st, former 1st → 2nd, former middle → 3rd.
  List<_SlideData> _slides(AppStrings l10n) => [
        _SlideData(
          title: l10n.discoverTitle,
          subtitle: l10n.discoverSubtitle,
          backgroundColor: AppColors.lavenderMuted,
          icon: Icons.lightbulb_outline_rounded,
          imageAsset: null,
          imageFit: BoxFit.contain,
        ),
        _SlideData(
          title: l10n.exploreMapTitle,
          subtitle: l10n.exploreMapSubtitle,
          backgroundColor: AppColors.lavender.withValues(alpha: 0.12),
          icon: Icons.map_outlined,
          imageAsset: 'assets/images/onboarding/onboarding_02_support.png',
        ),
        _SlideData(
          title: l10n.trustedReviewsTitle,
          subtitle: l10n.trustedReviewsSubtitle,
          backgroundColor: AppColors.peachMuted,
          icon: Icons.volunteer_activism_rounded,
          imageAsset: 'assets/images/onboarding/onboarding_03_community.png',
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next(int slideCount) {
    if (_currentPage < slideCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      context.push('/onboarding/account-type');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = _slides(l10n);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MargemBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (_, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        AppSpacing.lg,
                        AppSpacing.screenHorizontal,
                        0,
                      ),
                      child: Column(
                        children: [
                          OnboardingIllustration(
                            backgroundColor: slide.backgroundColor,
                            icon: slide.icon,
                            imageAsset: slide.imageAsset,
                            imageFit: slide.imageFit,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              PageDots(count: slides.length, currentIndex: _currentPage),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: PrimaryButton(
                  label: _currentPage == slides.length - 1
                      ? l10n.getStarted
                      : l10n.next,
                  onPressed: () => _next(slides.length),
                ),
              ),
              LinkTextButton(
                label: l10n.login,
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.icon,
    this.imageAsset,
    this.imageFit = BoxFit.cover,
  });

  final String title;
  final String subtitle;
  final Color backgroundColor;
  final IconData icon;
  final String? imageAsset;
  final BoxFit imageFit;
}
