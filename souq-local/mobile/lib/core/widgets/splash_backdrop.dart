import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fixed splash illustration — always cream sky + skyline, never follows app theme.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key, required this.child});

  final Widget child;

  static const _skylineAsset = 'assets/images/onboarding/onboarding_skyline.png';

  static const _skyTop = Color(0xFFFDF6EE);
  static const _skyMid = Color(0xFFF8F1E9);
  static const _skyLow = Color(0xFFF3E6D8);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final skylineHeight = size.width * 0.42;

    return ColoredBox(
      color: AppColors.cream,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_skyTop, _skyMid, _skyLow],
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.06,
            left: -size.width * 0.12,
            child: _CloudBlob(diameter: size.width * 0.72, opacity: 0.34),
          ),
          Positioned(
            top: size.height * 0.16,
            right: -size.width * 0.14,
            child: _CloudBlob(diameter: size.width * 0.58, opacity: 0.26),
          ),
          Positioned(
            top: size.height * 0.30,
            left: size.width * 0.12,
            child: _CloudBlob(diameter: size.width * 0.46, opacity: 0.20),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Image.asset(
              _skylineAsset,
              width: size.width,
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

class _CloudBlob extends StatelessWidget {
  const _CloudBlob({required this.diameter, required this.opacity});

  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter * 0.55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(diameter),
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
