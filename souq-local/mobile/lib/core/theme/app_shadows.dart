import 'package:flutter/material.dart';

import 'theme_context.dart';

/// Subtle elevation tokens — prefer borders and spacing over heavy shadows.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft(
    BuildContext context, {
    double blur = 12,
    double y = 2,
  }) {
    final shadow = context.colors.shadow;
    return [
      BoxShadow(
        color: shadow.withValues(alpha: context.isDark ? 0.24 : 0.06),
        blurRadius: blur,
        offset: Offset(0, y),
        spreadRadius: -2,
      ),
    ];
  }

  static List<BoxShadow> card(BuildContext context) {
    final shadow = context.colors.shadow;
    return [
      BoxShadow(
        color: shadow.withValues(alpha: context.isDark ? 0.28 : 0.04),
        blurRadius: 12,
        offset: const Offset(0, 2),
        spreadRadius: -2,
      ),
    ];
  }

  static List<BoxShadow> elevated(BuildContext context) {
    final shadow = context.colors.shadow;
    return [
      BoxShadow(
        color: shadow.withValues(alpha: context.isDark ? 0.36 : 0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
        spreadRadius: -4,
      ),
    ];
  }

  static List<BoxShadow> focus(BuildContext context) => warm(context, blur: 10, y: 2, alpha: 0.06);

  /// Soft warm-beige shadow — no cool or primary-tinted glow.
  static List<BoxShadow> warm(
    BuildContext context, {
    double blur = 14,
    double y = 3,
    double alpha = 0.07,
  }) {
    const warmBeige = Color(0xFFBCA98C);
    final resolvedAlpha = context.isDark ? alpha * 1.4 : alpha;
    return [
      BoxShadow(
        color: warmBeige.withValues(alpha: resolvedAlpha),
        blurRadius: blur,
        offset: Offset(0, y),
        spreadRadius: -3,
      ),
    ];
  }
}
