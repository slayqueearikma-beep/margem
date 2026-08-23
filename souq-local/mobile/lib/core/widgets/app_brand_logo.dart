import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'margem_m_logo.dart';

/// Where the logo appears — drives full lockup vs icon-only per brand rules.
enum AppBrandContext {
  /// Splash, onboarding hero, login/sign-up welcome.
  primaryBranding,

  /// Language picker, about, marketing with room to breathe.
  settingsBranding,

  /// Large empty states with no competing title.
  emptyState,

  /// Top bars, drawers, tabs, cards, loading spinners.
  compactBranding,
}

/// MarGem brand logo — vector M mark or raster lockup.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.brandContext,
    this.variant,
    this.width,
    this.height,
    this.iconSize = 40,
    this.showTagline = false,
  }) : assert(
          brandContext != null || variant != null,
          'Provide either brandContext or variant',
        );

  /// Picks full lockup or icon from [AppBrandContext] UX rules.
  factory AppBrandLogo.forContext(
    AppBrandContext brandContext, {
    Key? key,
    double? size,
    double? width,
    double? height,
    bool showTagline = false,
  }) {
    return AppBrandLogo(
      key: key,
      brandContext: brandContext,
      iconSize: size ?? _defaultSizeFor(brandContext),
      width: width,
      height: height,
      showTagline: showTagline,
    );
  }

  final AppBrandContext? brandContext;
  final AppBrandLogoVariant? variant;
  final double? width;
  final double? height;
  final double iconSize;
  final bool showTagline;

  static const _iconAsset = 'assets/images/margem_logo.png';
  static const _fullAsset = 'assets/images/margem_logo_full.png';

  static double _defaultSizeFor(AppBrandContext context) {
    return switch (context) {
      AppBrandContext.primaryBranding => 120,
      AppBrandContext.settingsBranding => 96,
      AppBrandContext.emptyState => 88,
      AppBrandContext.compactBranding => 28,
    };
  }

  AppBrandLogoVariant get _resolvedVariant {
    if (variant != null) return variant!;
    return switch (brandContext!) {
      AppBrandContext.primaryBranding ||
      AppBrandContext.settingsBranding ||
      AppBrandContext.emptyState =>
        AppBrandLogoVariant.full,
      AppBrandContext.compactBranding => AppBrandLogoVariant.icon,
    };
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedVariant;
    return Semantics(
      label: 'MarGem logo',
      child: switch (resolved) {
        AppBrandLogoVariant.full => _FullLockup(
            width: width,
            height: height,
            iconSize: iconSize,
            showTagline: showTagline,
          ),
        AppBrandLogoVariant.icon => _LogoMark(size: iconSize),
        AppBrandLogoVariant.lockup => _HorizontalLockup(iconSize: iconSize),
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
    required this.showTagline,
  });

  final double? width;
  final double? height;
  final double iconSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
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
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
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
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
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
    if (showFullLogo || size >= 100) {
      return AppBrandLogo.forContext(
        AppBrandContext.primaryBranding,
        size: size,
        showTagline: true,
      );
    }

    return AppBrandLogo.forContext(
      AppBrandContext.compactBranding,
      size: size,
    );
  }
}

/// Compact nav/header mark — icon only.
class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key, this.size = 36});

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
          const TextSpan(text: 'Gem', style: TextStyle(color: AppColors.lavender)),
        ],
      ),
    );
  }
}
