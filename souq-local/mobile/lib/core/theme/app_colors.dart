import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';

/// Legacy color constants retained only for splash screens and brand assets.
///
/// All other UI must use [ThemeContext.colors] semantic tokens.
@Deprecated('Use context.colors semantic tokens instead')
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primaryMuted = Color(0xFFEFF6FF);
  static const lavender = primary;
  static const lavenderDark = primaryDark;
  static const lavenderLight = primaryLight;
  static const lavenderMuted = primaryMuted;
  static const lavenderSurface = primaryMuted;
  static const lavenderShadow = primaryDark;

  static const background = Color(0xFFF9FAFB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F4F6);
  static const cream = Color(0xFFF8F1E9);
  static const creamSoft = background;
  static const beige = Color(0xFFE5E7EB);
  static const beigeLight = surfaceMuted;
  static const ultraLight = background;

  static const peach = Color(0xFF6B7280);
  static const peachDark = peach;
  static const peachLight = surfaceMuted;
  static const peachMuted = surfaceMuted;
  static const peachSurface = surfaceLight;

  static const secondary = peach;
  static const secondaryLight = Color(0xFF9CA3AF);

  static const navy = Color(0xFF111827);
  static const charcoal = navy;
  static const textPrimary = navy;
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  static const cardUnselected = surfaceLight;
  static const cardSelected = surfaceMuted;
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);

  static const splashBackground = cream;
  static const logoPlaceholder = surfaceMuted;
  static const logoInner = primary;

  static const darkBackground = Color(0xFF0B0F14);
  static const darkSurface = Color(0xFF1F2937);
  static const darkCard = Color(0xFF151B23);
  static const darkBorder = Color(0xFF374151);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkPrimary = Color(0xFF3B82F6);
  static const darkPrimaryMuted = Color(0xFF1E3A5F);

  static const star = Color(0xFFF59E0B);
  static const goldenCrown = Color(0xFFD97706);
  static const success = Color(0xFF16A34A);
  static const successMuted = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningMuted = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626);
  static const dangerMuted = Color(0xFFFEE2E2);
  static const info = primary;
  static const infoMuted = primaryMuted;

  static const customerAccent = primary;
  static const providerAccent = Color(0xFF059669);

  static const illustrationBurgundy = primaryDark;
  static const illustrationOrange = secondary;
  static const illustrationBlue = primary;
  static const illustrationGreen = success;

  static Color accent(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimary : primary;

  static Color accentMuted(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimaryMuted : primaryMuted;

  static Color scaffold(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : background;

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : surfaceLight;

  static Color glassLight(BuildContext context) =>
      surfaceLight.withValues(alpha: 0.85);

  static Color glassDark(BuildContext context) =>
      darkCard.withValues(alpha: 0.65);

  static Color roleAccent(bool isProvider) =>
      isProvider ? providerAccent : customerAccent;

  static Color roleMuted(bool isProvider) =>
      isProvider ? const Color(0xFFD1FAE5) : primaryMuted;

  static Color roleSurface(bool isProvider) =>
      isProvider ? surfaceLight : background;
}
