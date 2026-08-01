import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';

/// MarGem brand logo — icon, wordmark, and lockup variants.
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

  static const _logoAsset = 'assets/images/margem_logo.png';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'MarGem logo',
      child: switch (variant) {
        AppBrandLogoVariant.full => _FullLockup(
            iconSize: width != null ? width! * 0.55 : 120,
            showTagline: showTagline,
            isDark: isDark,
          ),
        AppBrandLogoVariant.lockup => _HorizontalLockup(
            iconSize: iconSize,
            isDark: isDark,
          ),
        AppBrandLogoVariant.icon => _LogoImage(
            asset: _logoAsset,
            width: iconSize,
            height: iconSize,
          ),
        AppBrandLogoVariant.wordmark => _Wordmark(
            height: iconSize * 0.55,
            isDark: isDark,
          ),
      },
    );
  }
}

class _FullLockup extends StatelessWidget {
  const _FullLockup({
    required this.iconSize,
    required this.showTagline,
    required this.isDark,
  });

  final double iconSize;
  final bool showTagline;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final taglineColor =
        (isDark ? Colors.white : AppColors.charcoal).withValues(alpha: 0.72);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoImage(asset: AppBrandLogo._logoAsset, width: iconSize, height: iconSize),
        SizedBox(height: iconSize * 0.18),
        _Wordmark(height: iconSize * 0.28, isDark: isDark),
        if (showTagline) ...[
          SizedBox(height: iconSize * 0.1),
          Text(
            AppConfig.appTagline.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: iconSize * 0.09,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: taglineColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _HorizontalLockup extends StatelessWidget {
  const _HorizontalLockup({
    required this.iconSize,
    required this.isDark,
  });

  final double iconSize;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoImage(
          asset: AppBrandLogo._logoAsset,
          width: iconSize,
          height: iconSize,
        ),
        SizedBox(width: iconSize * 0.22),
        _Wordmark(height: iconSize * 0.52, isDark: isDark),
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
