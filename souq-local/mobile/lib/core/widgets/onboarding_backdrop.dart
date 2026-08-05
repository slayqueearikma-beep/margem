import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared backdrop for splash (skyline) and onboarding (clean white + accent).
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({
    super.key,
    required this.child,
    this.showSkyline = true,
    this.showAccentBlob = false,
  });

  final Widget child;
  final bool showSkyline;
  final bool showAccentBlob;

  static const _skylineAsset = 'assets/images/onboarding/onboarding_skyline.png';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final skylineHeight = width * 0.34;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.scaffold(context),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showAccentBlob)
            Positioned(
              top: -48,
              left: -56,
              child: IgnorePointer(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.lavender.withValues(alpha: 0.14),
                        AppColors.lavender.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (showSkyline)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Image.asset(
                _skylineAsset,
                width: width,
                height: skylineHeight,
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          child,
        ],
      ),
    );
  }
}
