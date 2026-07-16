import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_logo_placeholder.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/onboarding_scaffold.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  State<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      title: 'Discover Local Businesses',
      subtitle: 'Find trusted shops, products, and services across Morocco — all in one place.',
      backgroundColor: AppColors.illustrationPurple,
      icon: Icons.storefront_rounded,
    ),
    _SlideData(
      title: 'Explore on the Map',
      subtitle: 'Browse nearby stores, filter by category, and get directions instantly.',
      backgroundColor: AppColors.illustrationGreen,
      icon: Icons.map_rounded,
    ),
    _SlideData(
      title: 'Trusted Reviews',
      subtitle: 'Read ratings from real buyers and discover the most trusted businesses in your city.',
      backgroundColor: AppColors.illustrationOrange,
      icon: Icons.star_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      context.push('/onboarding/account-type');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (_, index) {
                  final slide = _slides[index];
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
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (index == 0) ...[
                          const AppLogoPlaceholder(size: 48),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            AppConfig.appName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
            PageDots(count: _slides.length, currentIndex: _currentPage),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
              child: PrimaryButton(
                label: _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                onPressed: _next,
              ),
            ),
            LinkTextButton(label: 'Login', onPressed: () => context.go('/login')),
            const SizedBox(height: AppSpacing.lg),
          ],
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
  });

  final String title;
  final String subtitle;
  final Color backgroundColor;
  final IconData icon;
}
