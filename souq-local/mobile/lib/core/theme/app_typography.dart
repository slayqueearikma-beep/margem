import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography scale — Inter, clean geometric hierarchy.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Brightness brightness, {String? languageCode}) {
    final base = languageCode == 'ar'
        ? GoogleFonts.notoSansArabicTextTheme()
        : GoogleFonts.interTextTheme();
    final onSurface =
        brightness == Brightness.dark ? Colors.white : AppColors.textPrimary;
    final secondary = brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.1,
        color: onSurface,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.15,
        color: onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
        color: onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: secondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: onSurface,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        height: 1.2,
        color: secondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        height: 1.2,
        color: secondary,
      ),
    );
  }

  static TextStyle sectionLabel(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium!.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        );
  }

  static TextStyle wordmark(BuildContext context, {double size = 28}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final fontFactory =
        isAr ? GoogleFonts.notoSansArabic : GoogleFonts.inter;
    return fontFactory(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.05,
      color: isDark ? Colors.white : AppColors.navy,
    );
  }
}
