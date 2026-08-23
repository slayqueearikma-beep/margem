import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'margem_m_logo.dart';

/// Official MarGem logo sizes — use everywhere for consistent proportions.
class AppBrandSizes {
  AppBrandSizes._();

  /// Native splash — large centered icon only.
  static const double splash = 128;

  /// Login, register, forgot-password hero.
  static const double authHeader = 72;

  /// Onboarding welcome & account-type headers.
  static const double onboardingHeader = 64;

  /// Settings, language picker.
  static const double settingsBranding = 56;

  /// Large empty states.
  static const double emptyState = 88;

  /// Drawer header mark.
  static const double drawerHeader = 36;

  /// Top app bars, compact headers, navigation.
  static const double compact = 32;

  /// Tight inline placements.
  static const double compactSmall = 28;

  /// Minimum clear-space padding around the logo (each side).
  static const double clearSpace = 8;

  /// Clear space for hero / splash placements.
  static const double clearSpaceHero = 16;

  static double clearSpaceFor(AppBrandContext context) {
    return switch (context) {
      AppBrandContext.primaryBranding => clearSpaceHero,
      _ => clearSpace,
    };
  }
}

/// Where the logo appears — drives icon vs lockup per brand rules.
enum AppBrandContext {
  /// Splash — icon only, large.
  primaryBranding,

  /// Language picker, about.
  settingsBranding,

  /// Large empty states.
  emptyState,

  /// Top bars, drawers, tabs, cards.
  compactBranding,
}

/// MarGem brand logo — crisp vector mark with optional raster fallback.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.brandContext,
    this.variant,
    this.width,
    this.height,
    this.iconSize = 40,
    this.showWordmark = false,
    this.preferVector = true,
  }) : assert(
          brandContext != null || variant != null,
          'Provide either brandContext or variant',
        );

  /// Picks icon size & variant from [AppBrandContext] UX rules.
  factory AppBrandLogo.forContext(
    AppBrandContext brandContext, {
    Key? key,
    double? size,
    double? width,
    double? height,
    bool showWordmark = false,
    bool preferVector = true,
  }) {
    return AppBrandLogo(
      key: key,
      brandContext: brandContext,
      iconSize: size ?? _defaultSizeFor(brandContext),
      width: width,
      height: height,
      showWordmark: showWordmark,
      preferVector: preferVector,
    );
  }

  final AppBrandContext? brandContext;
  final AppBrandLogoVariant? variant;
  final double? width;
  final double? height;
  final double iconSize;
  final bool showWordmark;
  final bool preferVector;

  static const _iconAsset = 'assets/images/margem_logo.png';
  static const _iconAsset2x = 'assets/images/margem_logo@2x.png';
  static const _fullAsset = 'assets/images/margem_logo_full.png';

  static double _defaultSizeFor(AppBrandContext context) {
    return switch (context) {
      AppBrandContext.primaryBranding => AppBrandSizes.splash,
      AppBrandContext.settingsBranding => AppBrandSizes.settingsBranding,
      AppBrandContext.emptyState => AppBrandSizes.emptyState,
      AppBrandContext.compactBranding => AppBrandSizes.compact,
    };
  }

  AppBrandLogoVariant get _resolvedVariant {
    if (variant != null) return variant!;
    return switch (brandContext!) {
      AppBrandContext.primaryBranding ||
      AppBrandContext.settingsBranding ||
      AppBrandContext.emptyState ||
      AppBrandContext.compactBranding =>
        AppBrandLogoVariant.icon,
    };
  }

  double get _clearSpace {
    if (brandContext != null) {
      return AppBrandSizes.clearSpaceFor(brandContext!);
    }
    return AppBrandSizes.clearSpace;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedVariant;
    final logo = Semantics(
      label: 'MarGem logo',
      child: switch (resolved) {
        AppBrandLogoVariant.full => _FullLockup(
            width: width,
            height: height,
            iconSize: iconSize,
            showWordmark: showWordmark,
            preferVector: preferVector,
          ),
        AppBrandLogoVariant.icon => _LogoMark(
            size: iconSize,
            preferVector: preferVector,
          ),
        AppBrandLogoVariant.lockup => _HorizontalLockup(
            iconSize: iconSize,
            preferVector: preferVector,
          ),
        AppBrandLogoVariant.wordmark => _Wordmark(height: iconSize * 0.55),
      },
    );

    return Padding(
      padding: EdgeInsets.all(_clearSpace),
      child: logo,
    );
  }
}

class _FullLockup extends StatelessWidget {
  const _FullLockup({
    required this.width,
    required this.height,
    required this.iconSize,
    required this.showWordmark,
    required this.preferVector,
  });

  final double? width;
  final double? height;
  final double iconSize;
  final bool showWordmark;
  final bool preferVector;

  @override
  Widget build(BuildContext context) {
    if (preferVector) {
      return MargemMLogo(
        size: iconSize,
        showWordmark: true,
        wordmarkSize: iconSize * 0.22,
      );
    }
    return _LogoImage(
      asset: AppBrandLogo._fullAsset,
      width: width ?? iconSize * 1.15,
      height: height,
      fallback: MargemMLogo(
        size: iconSize,
        showWordmark: true,
        wordmarkSize: iconSize * 0.22,
      ),
    );
  }
}

class _HorizontalLockup extends StatelessWidget {
  const _HorizontalLockup({
    required this.iconSize,
    required this.preferVector,
  });

  final double iconSize;
  final bool preferVector;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoMark(size: iconSize, preferVector: preferVector),
        SizedBox(width: iconSize * 0.2),
        _Wordmark(height: iconSize * 0.55),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({
    required this.size,
    this.preferVector = true,
  });

  final double size;
  final bool preferVector;

  @override
  Widget build(BuildContext context) {
    if (preferVector) {
      return MargemMLogo(size: size);
    }
    return _LogoImage(
      asset: AppBrandLogo._iconAsset,
      width: size,
      height: size,
      fallback: MargemMLogo(size: size),
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({
    required this.asset,
    this.width,
    this.height,
    required this.fallback,
  });

  final String asset;
  final double? width;
  final double? height;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final assetPath = dpr >= 2.5
      ? AppBrandLogo._iconAsset2x
      : asset;

    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
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
    if (showFullLogo) {
      return AppBrandLogo(
        variant: AppBrandLogoVariant.full,
        iconSize: size,
        showWordmark: true,
      );
    }

    return AppBrandLogo(
      variant: AppBrandLogoVariant.icon,
      iconSize: size,
    );
  }
}

/// Compact nav/header mark — icon only.
class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key, this.size = AppBrandSizes.compact});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppBrandLogo.forContext(
      AppBrandContext.compactBranding,
      size: size,
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final marColor = isDark ? Colors.white : AppColors.navy;
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
          const TextSpan(
            text: 'Gem',
            style: TextStyle(color: AppColors.lavender),
          ),
        ],
      ),
    );
  }
}
