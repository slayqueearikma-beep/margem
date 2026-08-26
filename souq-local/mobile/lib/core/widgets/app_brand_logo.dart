import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Visual hierarchy for the official MarGem mark.
enum AppLogoTier {
  /// Splash — primary focal point, largest.
  splash,

  /// Language, login, register, forgot password, OTP, onboarding headers.
  header,

  /// Centered toolbar / app-bar mark (buyer header, seller shell, MarGemAppBar).
  navbar,

  /// Drawers and small inline placements.
  compact,
}

/// Responsive logo sizing and spacing — no hardcoded per-screen magic numbers.
class AppLogoLayout {
  AppLogoLayout._();

  /// Uniform scale applied to the raster mark inside its layout box.
  /// Compensates for transparent margins in PNG assets (BoxFit.contain letterboxing)
  /// without changing aspect ratio or recoloring the artwork.
  static const double markFillScale = 1.28;

  /// Target rendered mark height for centered toolbar headers (28–34 dp).
  static const double navbarLogoHeight = 32;

  static double markFillScaleFor(AppLogoTier tier) {
    return switch (tier) {
      // Zoom into PNG padding so the orange mark reads ~24 dp tall in headers.
      AppLogoTier.navbar => 1.72,
      AppLogoTier.compact => 1.16,
      AppLogoTier.header || AppLogoTier.splash => markFillScale,
    };
  }

  /// Shared toolbar row height used by [MarGemAppBar] and [BuyerShellHeader].
  static const double toolbarHeight = kToolbarHeight;

  static double sizeFor(BuildContext context, AppLogoTier tier) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 600;
    final isLargePhone = width >= 400;
    final isSmallPhone = width < 360;

    return switch (tier) {
      AppLogoTier.splash => switch ((isTablet, isLargePhone, isSmallPhone)) {
          (true, _, _) => 280.0,
          (_, _, true) => 228.0,
          (_, true, _) => 264.0,
          _ => 248.0,
        },
      AppLogoTier.header => switch ((isTablet, isLargePhone, isSmallPhone)) {
          (true, _, _) => 184.0,
          (_, _, true) => 124.0,
          (_, true, _) => 148.0,
          _ => 140.0,
        },
      AppLogoTier.navbar => switch ((isTablet, isLargePhone, isSmallPhone)) {
          (true, _, _) => 34.0,
          (_, _, true) => 28.0,
          (_, true, _) => navbarLogoHeight,
          _ => navbarLogoHeight,
        },
      AppLogoTier.compact => switch ((isTablet, isLargePhone, isSmallPhone)) {
          (true, _, _) => 48.0,
          (_, _, true) => 40.0,
          (_, true, _) => 44.0,
          _ => 42.0,
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

  static const double splash = 248;
  static const double authHeader = 140;
  static const double onboardingHeader = 140;
  static const double settingsBranding = 140;
  static const double emptyState = 140;
  static const double drawerHeader = 42;
  static const double navbar = 32;
  static const double compact = 42;
  static const double compactSmall = 40;
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
          child: AppBrandLogo(
            tier: tier,
            includeClearSpace: false,
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

/// Official MarGem logo — always renders [assets/images/margem_logo.png].
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
    bool includeClearSpace = true,
  }) {
    return AppBrandLogo(
      key: key,
      brandContext: brandContext,
      iconSize: size ?? _defaultSizeFor(brandContext),
      width: width,
      height: height,
      showWordmark: showWordmark,
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
  final bool includeClearSpace;

  static const _iconAsset1x = 'assets/images/margem_logo.png';
  static const _iconAsset2x = 'assets/images/margem_logo@2x.png';
  static const _iconAsset3x = 'assets/images/margem_logo@3x.png';
  static const _fullAsset = 'assets/images/margem_logo_full.png';

  static List<String> _iconAssetCandidatesForDpr(double dpr) {
    if (dpr >= 3) {
      return [_iconAsset3x, _iconAsset2x, _iconAsset1x];
    }
    if (dpr >= 2) {
      return [_iconAsset2x, _iconAsset1x];
    }
    return [_iconAsset1x];
  }

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

  double _resolveDisplaySize(BuildContext context) {
    if (width != null || height != null) {
      return width ?? height ?? iconSize;
    }

    if (tier != null) {
      return AppLogoLayout.sizeFor(context, tier!);
    }

    if (brandContext != null) {
      final defaultForContext = _defaultSizeFor(brandContext!);
      if (iconSize != defaultForContext) {
        return iconSize;
      }
      final mappedTier = _resolvedTier;
      if (mappedTier != null) {
        return AppLogoLayout.sizeFor(context, mappedTier);
      }
    }

    return iconSize;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTier = _resolvedTier;
    final resolvedSize = _resolveDisplaySize(context);
    final clearSpace = resolvedTier != null
        ? _clearSpaceForTier(resolvedTier)
        : (includeClearSpace ? AppBrandSizes.clearSpace : 0);

    final resolved = _resolvedVariant;
    final effectiveTier = tier ?? resolvedTier;
    final logo = Semantics(
      label: '${AppConfig.appName} logo',
      child: switch (resolved) {
        AppBrandLogoVariant.full => _FullLockup(
            width: width,
            height: height,
            iconSize: resolvedSize,
            showWordmark: showWordmark,
          ),
        AppBrandLogoVariant.icon => _LogoMark(
            size: resolvedSize,
            fillScale: effectiveTier != null
                ? AppLogoLayout.markFillScaleFor(effectiveTier)
                : AppLogoLayout.markFillScale,
            clipToBounds: effectiveTier == AppLogoTier.navbar,
          ),
        AppBrandLogoVariant.lockup => _HorizontalLockup(iconSize: resolvedSize),
        AppBrandLogoVariant.wordmark => _Wordmark(height: resolvedSize * 0.55),
      },
    );

    final box = SizedBox(
      width: resolvedSize,
      height: resolvedSize,
      child: Center(child: logo),
    );

    if (clearSpace <= 0) return box;

    return Padding(
      padding: EdgeInsets.all(clearSpace.toDouble()),
      child: box,
    );
  }
}

class _FullLockup extends StatelessWidget {
  const _FullLockup({
    required this.width,
    required this.height,
    required this.iconSize,
    required this.showWordmark,
  });

  final double? width;
  final double? height;
  final double iconSize;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    if (showWordmark) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LogoMark(size: iconSize),
          SizedBox(height: iconSize * 0.1),
          _Wordmark(height: iconSize * 0.22),
        ],
      );
    }

    return _LogoImage(
      asset: AppBrandLogo._fullAsset,
      width: width ?? iconSize * 1.15,
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
        _LogoMark(size: iconSize),
        SizedBox(width: iconSize * 0.2),
        _Wordmark(height: iconSize * 0.55),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({
    required this.size,
    this.fillScale = AppLogoLayout.markFillScale,
    this.clipToBounds = false,
  });

  final double size;
  final double fillScale;
  final bool clipToBounds;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final renderSize = size * fillScale;
    Widget image = _LogoImage(
      asset: AppBrandLogo._iconAsset1x,
      assetCandidates: AppBrandLogo._iconAssetCandidatesForDpr(dpr),
      width: renderSize,
      height: renderSize,
    );
    if (clipToBounds) {
      image = ClipRect(child: image);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: image),
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({
    required this.asset,
    this.width,
    this.height,
    this.assetCandidates = const [],
  });

  final String asset;
  final double? width;
  final double? height;
  final List<String> assetCandidates;

  @override
  Widget build(BuildContext context) {
    final candidates = assetCandidates.isEmpty ? [asset] : assetCandidates;

    return _LogoAssetImage(
      assetPath: candidates.first,
      fallbackPaths: candidates.skip(1).toList(),
      width: width,
      height: height,
    );
  }
}

class _LogoAssetImage extends StatelessWidget {
  const _LogoAssetImage({
    required this.assetPath,
    required this.fallbackPaths,
    this.width,
    this.height,
  });

  final String assetPath;
  final List<String> fallbackPaths;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: fallbackPaths.isEmpty
          ? null
          : (_, __, ___) => _LogoAssetImage(
                assetPath: fallbackPaths.first,
                fallbackPaths: fallbackPaths.skip(1).toList(),
                width: width,
                height: height,
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

/// Toolbar / app-bar mark — use [MarGemAppBarLogo] or this alias.
class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBrandLogo(
      tier: AppLogoTier.navbar,
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
