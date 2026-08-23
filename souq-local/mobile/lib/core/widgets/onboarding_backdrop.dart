import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared cream gradient + Morocco skyline used on splash and onboarding.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({
    super.key,
    required this.child,
    this.showSkyline = true,
  });

  final Widget child;
  final bool showSkyline;

  static const _skylineAsset = 'assets/images/onboarding/onboarding_skyline.png';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final skylineHeight = width * 0.34;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.creamSoft,
            AppColors.cream,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showSkyline)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Image.asset(
                _skylineAsset,
                width: width,
                height: skylineHeight,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
            ),
          child,
        ],
      ),
    );
  }
}
