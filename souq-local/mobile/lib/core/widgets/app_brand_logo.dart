import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// MarGem brand logo — raster lockup and icon variants.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.variant = AppBrandLogoVariant.full,
    this.width,
    this.height,
    this.iconSize = 40,
    this.showTagline = false,
  });

  final AppBrandLogoVariant variant;
  final double? width;
  final double? height;
  final double iconSize;
  final bool showTagline;

  static const _iconAsset = 'assets/images/margem_logo.png';
  static const _fullAsset = 'assets/images/margem_logo_full.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MarGem logo',
      child: switch (variant) {
        AppBrandLogoVariant.full => _FullLockup(
            width: width,
            height: height,
            iconSize: iconSize,
          ),
        AppBrandLogoVariant.lockup => _HorizontalLockup(iconSize: iconSize),
        AppBrandLogoVariant.icon => _LogoImage(
            asset: _iconAsset,
            width: iconSize,
            height: iconSize,
          ),
        AppBrandLogoVariant.wordmark => _Wordmark(height: iconSize * 0.55),
      },
    );
  }
}

class _FullLockup extends StatelessWidget {
  const _FullLockup({
    required this.width,
    required this.height,
    required this.iconSize,
  });

  final double? width;
  final double? height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final displayWidth = width ?? iconSize * 1.15;

    return _LogoImage(
      asset: AppBrandLogo._fullAsset,
      width: displayWidth,
      height: height,
    );
  }
}

class _HorizontalLockup extends StatelessWidget {
  const _HorizontalLockup({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoImage(
          asset: AppBrandLogo._iconAsset,
          width: iconSize,
          height: iconSize,
        ),
        SizedBox(width: iconSize * 0.22),
        _Wordmark(height: iconSize * 0.52),
      ],
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

enum AppBrandLogoVariant { full, lockup, icon, wordmark }

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
        iconSize: size,
        showTagline: true,
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
    return AppBrandLogo(variant: AppBrandLogoVariant.lockup, iconSize: size);
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final marColor = isDark ? Colors.white : AppColors.charcoal;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: height,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.05,
        ),
        children: [
          TextSpan(text: 'Mar', style: TextStyle(color: marColor)),
          const TextSpan(text: 'Gem', style: TextStyle(color: AppColors.primary)),
        ],
      ),
    );
  }
}
