import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_semantic_colors.dart';

/// Typography scale — Inter, clean geometric hierarchy.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(
    Brightness brightness,
    AppSemanticColors semantic, {
    String? languageCode,
  }) {
    final base = languageCode == 'ar'
        ? GoogleFonts.notoSansArabicTextTheme()
        : GoogleFonts.interTextTheme();

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.1,
        color: semantic.textPrimary,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.15,
        color: semantic.textPrimary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: semantic.textPrimary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
        color: semantic.textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: semantic.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: semantic.textPrimary,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: semantic.textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: semantic.textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: semantic.textPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: semantic.textSecondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: semantic.textPrimary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        height: 1.2,
        color: semantic.textSecondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        height: 1.2,
        color: semantic.textSecondary,
      ),
    );
  }

  static TextStyle sectionLabel(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>() ??
        AppSemanticColors.light;
    return Theme.of(context).textTheme.labelMedium!.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: semantic.textTertiary,
        );
  }

  static TextStyle wordmark(BuildContext context, {double size = 28}) {
    final semantic = Theme.of(context).extension<AppSemanticColors>() ??
        AppSemanticColors.light;
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.05,
      color: semantic.textPrimary,
    );
  }
}
