import 'package:flutter/material.dart';

import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_context.dart';
import '../utils/directional_ui.dart';
import 'margem_background.dart';

class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: EdgeInsetsDirectional.only(
              end: index < totalSteps - 1 ? 6 : 0,
            ),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? context.colors.primary : context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? context.colors.primary : context.colors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    this.showBack = false,
    this.onBack,
    this.progressStep,
    this.progressTotal,
    this.bottom,
    this.showBackground = true,
  });

  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  final int? progressStep;
  final int? progressTotal;
  final Widget? bottom;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MargemBackground(
        showBlobs: showBackground,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  8,
                  AppSpacing.screenHorizontal,
                  0,
                ),
                child: Column(
                  children: [
                    if (showBack)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _GlassIconButton(
                          icon: DirectionalUi.backArrow(context),
                          onPressed:
                              onBack ?? () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    if (progressStep != null && progressTotal != null) ...[
                      StepProgressBar(
                        currentStep: progressStep!,
                        totalSteps: progressTotal!,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                    AppSpacing.screenHorizontal,
                    AppSpacing.lg,
                  ),
                  child: child,
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.lg,
                  ),
                  child: bottom!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? context.colors.surface.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? context.colors.border : context.colors.divider,
            ),
            boxShadow: AppShadows.soft(context, blur: 12, y: 2),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
