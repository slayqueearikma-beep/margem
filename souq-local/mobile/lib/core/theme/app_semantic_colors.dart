import 'package:flutter/material.dart';

/// Semantic color roles consumed by UI components.
///
/// All interface colors must come from this extension — never hardcode hex
/// values in widgets or screens.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.primaryMuted,
    required this.onPrimary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.divider,
    required this.success,
    required this.successMuted,
    required this.warning,
    required this.warningMuted,
    required this.error,
    required this.errorMuted,
    required this.info,
    required this.infoMuted,
    required this.shadow,
    required this.overlay,
    required this.star,
    required this.highlight,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color primaryMuted;
  final Color onPrimary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color divider;
  final Color success;
  final Color successMuted;
  final Color warning;
  final Color warningMuted;
  final Color error;
  final Color errorMuted;
  final Color info;
  final Color infoMuted;
  final Color shadow;
  final Color overlay;
  final Color star;
  final Color highlight;

  static const light = AppSemanticColors(
    background: Color(0xFFF9FAFB),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF3F4F6),
    primary: Color(0xFF2563EB),
    primaryMuted: Color(0xFFEFF6FF),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF6B7280),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    border: Color(0xFFE5E7EB),
    divider: Color(0xFFF3F4F6),
    success: Color(0xFF16A34A),
    successMuted: Color(0xFFDCFCE7),
    warning: Color(0xFFD97706),
    warningMuted: Color(0xFFFEF3C7),
    error: Color(0xFFDC2626),
    errorMuted: Color(0xFFFEE2E2),
    info: Color(0xFF2563EB),
    infoMuted: Color(0xFFEFF6FF),
    shadow: Color(0xFF111827),
    overlay: Color(0xFF111827),
    star: Color(0xFFF59E0B),
    highlight: Color(0xFFD97706),
  );

  static const dark = AppSemanticColors(
    background: Color(0xFF0B0F14),
    surface: Color(0xFF151B23),
    surfaceVariant: Color(0xFF1F2937),
    primary: Color(0xFF3B82F6),
    primaryMuted: Color(0xFF1E3A5F),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF9CA3AF),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary: Color(0xFF6B7280),
    border: Color(0xFF374151),
    divider: Color(0xFF1F2937),
    success: Color(0xFF22C55E),
    successMuted: Color(0xFF14532D),
    warning: Color(0xFFF59E0B),
    warningMuted: Color(0xFF78350F),
    error: Color(0xFFEF4444),
    errorMuted: Color(0xFF7F1D1D),
    info: Color(0xFF60A5FA),
    infoMuted: Color(0xFF1E3A5F),
    shadow: Color(0xFF000000),
    overlay: Color(0xFF000000),
    star: Color(0xFFFBBF24),
    highlight: Color(0xFFF59E0B),
  );

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? primary,
    Color? primaryMuted,
    Color? onPrimary,
    Color? secondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? divider,
    Color? success,
    Color? successMuted,
    Color? warning,
    Color? warningMuted,
    Color? error,
    Color? errorMuted,
    Color? info,
    Color? infoMuted,
    Color? shadow,
    Color? overlay,
    Color? star,
    Color? highlight,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      primary: primary ?? this.primary,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      successMuted: successMuted ?? this.successMuted,
      warning: warning ?? this.warning,
      warningMuted: warningMuted ?? this.warningMuted,
      error: error ?? this.error,
      errorMuted: errorMuted ?? this.errorMuted,
      info: info ?? this.info,
      infoMuted: infoMuted ?? this.infoMuted,
      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      star: star ?? this.star,
      highlight: highlight ?? this.highlight,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      successMuted: Color.lerp(successMuted, other.successMuted, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningMuted: Color.lerp(warningMuted, other.warningMuted, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorMuted: Color.lerp(errorMuted, other.errorMuted, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoMuted: Color.lerp(infoMuted, other.infoMuted, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      star: Color.lerp(star, other.star, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
    );
  }
}
