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
          showLeadingIcon: true,
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: OnboardingBackdrop(
        showSkyline: false,
        showAccentBlob: true,
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
                              foregroundColor: AppColors.lavender,
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
                                fontWeight: FontWeight.w600,
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
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                              child: Image.asset(
                                slide.imageAsset,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                          if (slide.showLeadingIcon) ...[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.lavender.withValues(alpha: 0.45),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.lavender,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              height: 1.15,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant(context),
                              height: 1.45,
                            ),
                          ),
                          const Spacer(flex: 1),
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
                  trailingIcon: isLastPage
                      ? null
                      : Icons.arrow_forward_rounded,
                  onPressed: () => _next(slides.length),
                ),
              ),
              if (isLastPage)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.alreadyHaveAccount,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant(context),
                        ),
                      ),
                      TextButton(
                        onPressed: _completeOnboardingAndGoLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.lavender,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(44, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.logIn,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
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
    this.showLeadingIcon = false,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
  final bool showLeadingIcon;
}
