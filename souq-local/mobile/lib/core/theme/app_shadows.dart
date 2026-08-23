import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Subtle elevation shadows from the MarGem design system.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card({bool isDark = false}) {
    if (isDark) return const [];
    return [
      BoxShadow(
        color: AppColors.scrimLight,
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> elevated({bool isDark = false}) {
    if (isDark) return const [];
    return [
      BoxShadow(
        color: AppColors.scrimMedium,
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static List<BoxShadow> bottomBar({bool isDark = false}) {
    if (isDark) return const [];
    return [
      BoxShadow(
        color: AppColors.shadowColor,
        blurRadius: 12,
        offset: const Offset(0, -4),
      ),
    ];
  }

  static List<BoxShadow> searchBar({bool isDark = false}) {
    if (isDark) return const [];
    return [
      BoxShadow(
        color: AppColors.scrimLight,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
