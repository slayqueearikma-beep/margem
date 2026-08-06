import 'package:flutter/material.dart';

import 'app_shadows.dart';
import 'app_spacing.dart';
import 'theme_context.dart';

/// Reusable decoration builders for surfaces.
class AppDecorations {
  AppDecorations._();

  static BoxDecoration surfaceCard({
    required BuildContext context,
    double radius = AppSpacing.cardRadius,
    bool showBorder = true,
    Color? color,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      color: color ?? colors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: showBorder ? Border.all(color: colors.border) : null,
    );
  }

  static BoxDecoration roleCard({
    required BuildContext context,
    required Color accent,
    bool selected = false,
    double radius = AppSpacing.cardRadiusLg,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      color: selected ? colors.primaryMuted : colors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: selected ? accent : colors.border,
        width: selected ? 1.5 : 1,
      ),
    );
  }

  static BoxDecoration pill({
    required BuildContext context,
    Color? background,
    Color? border,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      color: background ?? colors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      border: Border.all(color: border ?? colors.border),
    );
  }

  static BoxDecoration searchField(BuildContext context) {
    final colors = context.colors;
    return BoxDecoration(
      color: colors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      border: Border.all(color: colors.border),
    );
  }

  static BoxDecoration selectedChip(BuildContext context) {
    final colors = context.colors;
    return BoxDecoration(
      color: colors.primaryMuted,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
    );
  }

  static BoxDecoration unselectedChip(BuildContext context) {
    final colors = context.colors;
    return BoxDecoration(
      color: colors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      border: Border.all(color: colors.border),
    );
  }

  static BoxDecoration iconContainer(BuildContext context) {
    final colors = context.colors;
    return BoxDecoration(
      color: colors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      border: Border.all(color: colors.border),
    );
  }
}
