import 'package:flutter/material.dart';

/// MarGem design tokens — lavender (customer) + peach (provider) brand palette.
class AppColors {
  AppColors._();

  // Brand accents
  static const lavender = Color(0xFF9B8AFB);
  static const lavenderDark = Color(0xFF7C6AE8);
  static const lavenderLight = Color(0xFFB8ACFC);
  static const lavenderMuted = Color(0xFFF3F0FF);
  static const lavenderSurface = Color(0xFFF8F6FF);

  static const peach = Color(0xFFFFA07A);
  static const peachDark = Color(0xFFFF8A5C);
  static const peachLight = Color(0xFFFFB896);
  static const peachMuted = Color(0xFFFFF4EE);
  static const peachSurface = Color(0xFFFFFAF7);

  /// Primary brand color — lavender (customer-facing default).
  static const primary = lavender;
  static const primaryLight = lavenderLight;
  static const secondary = peach;
  static const secondaryLight = peachLight;

  // Legacy aliases (mapped to new palette for gradual migration)
  static const illustrationBurgundy = lavenderDark;
  static const illustrationOrange = peach;
  static const illustrationBlue = lavender;
  static const illustrationGreen = Color(0xFF6BCB77);

  // Neutrals
  static const navy = Color(0xFF1A1D2E);
  static const charcoal = navy;
  static const textPrimary = navy;
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF9FAFB);
  static const cardUnselected = Color(0xFFFAFAFC);
  static const cardSelected = lavenderMuted;
  static const border = Color(0xFFE8EAEF);
  static const borderLight = Color(0xFFF0F1F5);

  static const splashBackground = surfaceLight;
  static const logoPlaceholder = lavenderMuted;
  static const logoInner = lavender;

  // Dark mode
  static const darkBackground = Color(0xFF0A0A0F);
  static const darkSurface = Color(0xFF14141C);
  static const darkCard = Color(0xFF1E1E28);
  static const darkBorder = Color(0xFF2A2A38);
  static const darkTextSecondary = Color(0xFF9CA3AF);

  // Semantic
  static const star = Color(0xFFFFB800);
  static const goldenCrown = Color(0xFFD4AF37);
  static const success = Color(0xFF34C759);
  static const successMuted = Color(0xFFE8F9ED);
  static const warning = Color(0xFFFF9500);
  static const warningMuted = Color(0xFFFFF4E5);
  static const danger = Color(0xFFFF3B30);
  static const dangerMuted = Color(0xFFFFEBEA);
  static const info = lavender;
  static const infoMuted = lavenderMuted;

  // Role-specific accents
  static const customerAccent = lavender;
  static const providerAccent = peach;

  // Glass overlays
  static Color glassLight(BuildContext context) =>
      surfaceLight.withValues(alpha: 0.72);
  static Color glassDark(BuildContext context) =>
      darkCard.withValues(alpha: 0.65);

  static Color roleAccent(bool isProvider) =>
      isProvider ? providerAccent : customerAccent;

  static Color roleMuted(bool isProvider) =>
      isProvider ? peachMuted : lavenderMuted;

  static Color roleSurface(bool isProvider) =>
      isProvider ? peachSurface : lavenderSurface;
}
