import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/onboarding_backdrop.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../l10n/app_localizations.dart';

class OnboardingWelcomeScreen extends ConsumerStatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  ConsumerState<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState
    extends ConsumerState<OnboardingWelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  List<_SlideData> _slides(AppStrings l10n) => [
        _SlideData(
          title: l10n.discoverTitle,
          subtitle: l10n.discoverSubtitle,
          imageAsset: 'assets/images/onboarding/onboarding_02_discover.png',
        ),
        _SlideData(
          title: l10n.connectTitle,
          subtitle: l10n.connectSubtitle,
          imageAsset: 'assets/images/onboarding/onboarding_03_connect.png',
        ),
        _SlideData(
          title: l10n.growTitle,
          subtitle: l10n.growSubtitle,
          imageAsset: 'assets/images/onboarding/onboarding_04_grow.png',
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboardingAndGoLogin() async {
    final storage = ref.read(appStorageProvider);
    if (storage != null) {
      await storage.completeOnboarding();
    }
    if (!mounted) return;
    context.go('/login');
  }

  void _next(int slideCount) {
    if (_currentPage < slideCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboardingAndGoLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = _slides(l10n);
    final isLastPage = _currentPage == slides.length - 1;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OnboardingBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: isLastPage
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: AppSpacing.screenHorizontal,
                          ),
                          child: TextButton(
                            onPressed: _completeOnboardingAndGoLogin,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(44, 44),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.skip,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (_, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                              child: Image.asset(
                                slide.imageAsset,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                  height: 1.2,
                                ),
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
                  label: isLastPage ? l10n.getStarted : l10n.next,
                  onPressed: () => _next(slides.length),
                ),
              ),
              if (isLastPage)
                LinkTextButton(
                  label: l10n.logIn,
                  onPressed: _completeOnboardingAndGoLogin,
                )
              else
                const SizedBox(height: AppSpacing.lg),
              SizedBox(height: AppSpacing.md + bottomInset),
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
    required this.imageAsset,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
}
