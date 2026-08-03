import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'margem_m_logo.dart';

/// Visual hierarchy for the official MarGem mark.
enum AppLogoTier {
  /// Splash — primary focal point, largest.
  splash,

  /// Language, login, register, forgot password, OTP, onboarding headers.
  header,

  /// Drawers, app bars, compact inline placements.
  compact,
}

/// Responsive logo sizing and spacing — no hardcoded per-screen magic numbers.
class AppLogoLayout {
  AppLogoLayout._();

  static double sizeFor(BuildContext context, AppLogoTier tier) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;
    final isLargePhone = width >= 400;
    final isSmallPhone = width < 360;

    return switch (tier) {
      AppLogoTier.splash => switch ((isTablet, isLargePhone, isSmallPhone)) {
          (true, _, _) => 168.0,
          (_, _, true) => 152.0,
          (_, true, _) => 184.0,
          _ => 176.0,
        },
      AppLogoTier.header => switch ((isTablet, isLargePhone, isSmallPhone)) {
          (true, _, _) => 136.0,
          (_, _, true) => 84.0,
          (_, true, _) => 104.0,
          _ => 96.0,
        },
      AppLogoTier.compact => switch ((isTablet, isLargePhone, isSmallPhone)) {
          (true, _, _) => 40.0,
          (_, _, true) => 28.0,
          (_, true, _) => 36.0,
          _ => 32.0,
        },
    };
  }

  /// Top inset from the safe-area edge to the logo (60–80 px).
  static double topFromSafeArea(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    if (height < 640) return AppSpacing.logoTopFromSafeAreaMin;
    if (height > 820) return AppSpacing.logoTopFromSafeAreaMax;
    return 72.0;
  }
}

/// @deprecated Use [AppLogoLayout.sizeFor] with [AppLogoTier].
class AppBrandSizes {
  AppBrandSizes._();

  static const double splash = 164;
  static const double authHeader = 88;
  static const double onboardingHeader = 88;
  static const double settingsBranding = 88;
  static const double emptyState = 88;
  static const double drawerHeader = 36;
  static const double compact = 32;
  static const double compactSmall = 28;
  static const double clearSpace = 8;
  static const double clearSpaceHero = 16;

  static double clearSpaceFor(AppBrandContext context) {
    return switch (context) {
      AppBrandContext.primaryBranding => clearSpaceHero,
      _ => clearSpace,
    };
  }
}

/// Where the logo appears — drives compact placements in navigation chrome.
enum AppBrandContext {
  primaryBranding,
  settingsBranding,
  emptyState,
  compactBranding,
}

/// Reusable header block: centered logo + optional title/subtitle with
/// consistent spacing across language, auth, and onboarding screens.
class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader({
    super.key,
    this.tier = AppLogoTier.header,
    this.title,
    this.subtitle,
    this.topSpacing,
    this.logoToTitleGap,
    this.includeTopSpacing = true,
    this.titleStyle,
    this.subtitleStyle,
  });

  final AppLogoTier tier;
  final String? title;
  final String? subtitle;
  final double? topSpacing;
  final double? logoToTitleGap;
  final bool includeTopSpacing;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gap = logoToTitleGap ?? AppSpacing.logoToTitle;
    final top = topSpacing ??
        (includeTopSpacing ? AppLogoLayout.topFromSafeArea(context) : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (top > 0) SizedBox(height: top),
        Center(
          child: SizedBox(
            width: AppLogoLayout.sizeFor(context, tier),
            height: AppLogoLayout.sizeFor(context, tier),
            child: AppBrandLogo(
              tier: tier,
              includeClearSpace: false,
            ),
          ),
        ),
        if (title != null) ...[
          SizedBox(height: gap),
          Text(
            title!,
            textAlign: TextAlign.center,
            style: titleStyle ??
                theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: subtitleStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
      ],
    );
  }
}

/// Official MarGem logo — single vector mark, aspect ratio preserved.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.brandContext,
    this.variant,
    this.tier,
    this.width,
    this.height,
    this.iconSize = 40,
    this.showWordmark = false,
    this.preferVector = true,
    this.includeClearSpace = true,
  }) : assert(
          tier != null || brandContext != null || variant != null,
          'Provide tier, brandContext, or variant',
        );

  factory AppBrandLogo.forContext(
    AppBrandContext brandContext, {
    Key? key,
    double? size,
    double? width,
    double? height,
    bool showWordmark = false,
    bool preferVector = true,
    bool includeClearSpace = true,
  }) {
    return AppBrandLogo(
      key: key,
      brandContext: brandContext,
      iconSize: size ?? _defaultSizeFor(brandContext),
      width: width,
      height: height,
      showWordmark: showWordmark,
      preferVector: preferVector,
      includeClearSpace: includeClearSpace,
    );
  }

  final AppBrandContext? brandContext;
  final AppBrandLogoVariant? variant;
  final AppLogoTier? tier;
  final double? width;
  final double? height;
  final double iconSize;
  final bool showWordmark;
  final bool preferVector;
  final bool includeClearSpace;

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
    return AppBrandLogoVariant.icon;
  }

  AppLogoTier? get _resolvedTier {
    if (tier != null) return tier;
    return switch (brandContext) {
      AppBrandContext.primaryBranding => AppLogoTier.splash,
      AppBrandContext.settingsBranding => AppLogoTier.header,
      AppBrandContext.emptyState => AppLogoTier.header,
      AppBrandContext.compactBranding => AppLogoTier.compact,
      null => null,
    };
  }

  double _clearSpaceForTier(AppLogoTier resolvedTier) {
    if (!includeClearSpace) return 0;
    return resolvedTier == AppLogoTier.splash
        ? AppBrandSizes.clearSpaceHero
        : AppBrandSizes.clearSpace;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTier = _resolvedTier;
    final resolvedSize = resolvedTier != null
        ? AppLogoLayout.sizeFor(context, resolvedTier)
        : iconSize;
    final clearSpace = resolvedTier != null
        ? _clearSpaceForTier(resolvedTier)
        : (includeClearSpace ? AppBrandSizes.clearSpace : 0);

    final resolved = _resolvedVariant;
    final logo = Semantics(
      label: 'MarGem logo',
      child: switch (resolved) {
        AppBrandLogoVariant.full => _FullLockup(
            width: width,
            height: height,
            iconSize: resolvedSize,
            showWordmark: showWordmark,
            preferVector: preferVector,
          ),
        AppBrandLogoVariant.icon => _LogoMark(
            size: resolvedSize,
            preferVector: preferVector,
          ),
        AppBrandLogoVariant.lockup => _HorizontalLockup(
            iconSize: resolvedSize,
            preferVector: preferVector,
          ),
        AppBrandLogoVariant.wordmark => _Wordmark(height: resolvedSize * 0.55),
      },
    );

    if (clearSpace <= 0) {
      return SizedBox(
        width: resolvedSize,
        height: resolvedSize,
        child: Center(child: logo),
      );
    }

    return Padding(
      padding: EdgeInsets.all(clearSpace.toDouble()),
      child: SizedBox(
        width: resolvedSize,
        height: resolvedSize,
        child: Center(child: logo),
      ),
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
    final assetPath =
        dpr >= 2.5 ? AppBrandLogo._iconAsset2x : asset;

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
  const AppLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBrandLogo(
      tier: AppLogoTier.compact,
      includeClearSpace: false,
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
