import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// MarGem brand logo — single transparent asset used across the app.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.variant = AppBrandLogoVariant.full,
    this.width,
    this.height,
    this.iconSize = 40,
  });

  final AppBrandLogoVariant variant;
  final double? width;
  final double? height;
  final double iconSize;

  static const _logoAsset = 'assets/images/margem_logo.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MarGem logo',
      child: switch (variant) {
        AppBrandLogoVariant.full => _LogoImage(
            asset: _logoAsset,
            width: width ?? 220,
            height: height,
          ),
        AppBrandLogoVariant.icon => _LogoImage(
            asset: _logoAsset,
            width: iconSize,
            height: iconSize,
          ),
        AppBrandLogoVariant.wordmark => _Wordmark(
            height: iconSize * 0.55,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
      },
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({
    required this.asset,
    this.width,
    this.height,
  });

  final String asset;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.location_on_rounded,
        size: width ?? height ?? 40,
        color: AppColors.primary,
      ),
    );
  }
}

enum AppBrandLogoVariant { full, icon, wordmark }

/// Backwards-compatible alias used across existing screens.
class AppLogoPlaceholder extends StatelessWidget {
  const AppLogoPlaceholder({
    super.key,
    this.size = 120,
    this.onPurpleBackground = false,
    this.showFullLogo = false,
  });

  final double size;
  final bool onPurpleBackground;
  final bool showFullLogo;

  @override
  Widget build(BuildContext context) {
    if (showFullLogo || size >= 100) {
      return AppBrandLogo(
        variant: AppBrandLogoVariant.full,
        width: size * 1.6,
        iconSize: size * 0.45,
      );
    }

    return AppBrandLogo(
      variant: AppBrandLogoVariant.icon,
      iconSize: size,
    );
  }
}

class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppBrandLogo(variant: AppBrandLogoVariant.icon, iconSize: size);
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.height, required this.isDark});

  final double height;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final marColor = isDark ? Colors.white : AppColors.charcoal;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: height,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(text: 'Mar', style: TextStyle(color: marColor)),
          const TextSpan(text: 'Gem', style: TextStyle(color: AppColors.primary)),
        ],
      ),
    );
  }
}
