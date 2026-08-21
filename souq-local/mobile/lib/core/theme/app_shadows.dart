import 'package:flutter/material.dart';

/// Subtle elevation shadows from the MarGem reference design.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card({bool isDark = false}) {
    if (isDark) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> elevated({bool isDark = false}) {
    if (isDark) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static List<BoxShadow> bottomBar({bool isDark = false}) {
    if (isDark) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 12,
        offset: const Offset(0, -4),
      ),
    ];
  }

  static List<BoxShadow> searchBar({bool isDark = false}) {
    if (isDark) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
