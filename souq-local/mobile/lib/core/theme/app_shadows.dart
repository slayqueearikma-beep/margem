import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft, diffused elevation tokens for the MarGem design system.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft({Color? color, double blur = 24, double y = 8}) {
    return [
      BoxShadow(
        color: (color ?? AppColors.navy).withValues(alpha: 0.06),
        blurRadius: blur,
        offset: Offset(0, y),
        spreadRadius: -4,
      ),
    ];
  }

  static List<BoxShadow> card({bool isDark = false}) => [
        BoxShadow(
          color: (isDark ? Colors.black : AppColors.navy)
              .withValues(alpha: isDark ? 0.35 : 0.05),
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: -6,
        ),
      ];

  static List<BoxShadow> elevated({bool isDark = false}) => [
        BoxShadow(
          color: (isDark ? Colors.black : AppColors.navy)
              .withValues(alpha: isDark ? 0.45 : 0.08),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: -8,
        ),
      ];

  static List<BoxShadow> iconCircle(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> glow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.25),
          blurRadius: 28,
          spreadRadius: -4,
        ),
      ];
}
