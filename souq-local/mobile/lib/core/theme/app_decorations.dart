import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';

/// Reusable decoration builders for glassmorphism and surfaces.
class AppDecorations {
  AppDecorations._();

  static BoxDecoration glassCard({
    required BuildContext context,
    Color? tint,
    double radius = AppSpacing.cardRadius,
    bool showBorder = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? AppColors.darkCard.withValues(alpha: 0.75)
          : Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(radius),
      border: showBorder
          ? Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.6)
                  : AppColors.border.withValues(alpha: 0.8),
            )
          : null,
      boxShadow: AppShadows.card(isDark: isDark),
    );
  }

  static BoxDecoration roleCard({
    required BuildContext context,
    required Color accent,
    bool selected = false,
    double radius = AppSpacing.cardRadiusLg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: selected
          ? accent.withValues(alpha: isDark ? 0.18 : 0.08)
          : (isDark ? AppColors.darkCard : Colors.white),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: selected
            ? accent.withValues(alpha: 0.55)
            : (isDark ? AppColors.darkBorder : AppColors.borderLight),
        width: selected ? 1.5 : 1,
      ),
      boxShadow: selected ? AppShadows.soft(color: accent, blur: 20, y: 6) : AppShadows.card(isDark: isDark),
    );
  }

  static BoxDecoration pillButton(Color accent, {bool isDark = false}) {
    return BoxDecoration(
      color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
    );
  }

  static Widget frosted({
    required Widget child,
    double sigma = 12,
    double radius = AppSpacing.cardRadius,
    Color? fill,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill ?? Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}
