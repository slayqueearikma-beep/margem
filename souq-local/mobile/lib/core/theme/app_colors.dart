import 'package:flutter/material.dart';

/// MarGem design tokens — neutral surfaces with a blue primary accent.
///
/// Legacy names (`lavender`, `beige`, `cream`, etc.) are kept as aliases so
/// existing widgets pick up the new palette without wide refactors.
class AppColors {
  AppColors._();

  // ── Primary accent (buttons, links, selected states) ────────────────────
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primaryMuted = Color(0xFFEFF6FF);

  // ── Surfaces & neutrals (light theme) ───────────────────────────────────
  static const background = Color(0xFFF9FAFB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F4F6);
  static const ultraLight = Color(0xFFF9FAFB);

  // ── Secondary / muted accent ────────────────────────────────────────────
  static const secondary = Color(0xFF6B7280);
  static const secondaryLight = Color(0xFF9CA3AF);

  // Legacy aliases — warm palette names now map to neutral tokens
  static const beige = Color(0xFFE5E7EB);
  static const beigeLight = surfaceMuted;
  static const cream = surfaceLight;
  static const creamSoft = background;

  static const peach = secondaryLight;
  static const peachDark = secondary;
  static const peachLight = surfaceMuted;
  static const peachMuted = surfaceMuted;
  static const peachSurface = surfaceLight;

  static const lavender = primary;
  static const lavenderDark = primaryDark;
  static const lavenderLight = primaryLight;
  static const lavenderMuted = primaryMuted;
  static const lavenderSurface = primaryMuted;
  static const lavenderShadow = primaryDark;

  static const illustrationBurgundy = primaryDark;
  static const illustrationOrange = secondary;
  static const illustrationBlue = primary;
  static const illustrationGreen = Color(0xFF22C55E);

  // ── Text & borders ──────────────────────────────────────────────────────
  static const navy = Color(0xFF111827);
  static const charcoal = navy;
  static const textPrimary = navy;
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  static const cardUnselected = surfaceLight;
  static const cardSelected = surfaceMuted;
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);

  static const splashBackground = background;
  static const logoPlaceholder = surfaceMuted;
  static const logoInner = primary;

  // ── Dark theme ──────────────────────────────────────────────────────────
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkCard = Color(0xFF334155);
  static const darkBorder = Color(0xFF475569);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkPrimary = Color(0xFF60A5FA);
  static const darkPrimaryMuted = Color(0xFF1E3A5F);

  // ── Semantic ────────────────────────────────────────────────────────────
  static const star = Color(0xFFF59E0B);
  static const goldenCrown = Color(0xFFD97706);
  static const success = Color(0xFF22C55E);
  static const successMuted = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningMuted = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
  static const dangerMuted = Color(0xFFFEE2E2);
  static const info = primary;
  static const infoMuted = primaryMuted;

  // Role-specific accents
  static const customerAccent = primary;
  static const providerAccent = Color(0xFF059669);

  static Color accent(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimary : primary;

  static Color accentMuted(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimaryMuted : primaryMuted;

  static Color scaffold(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : background;

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : surfaceLight;

  static Color glassLight(BuildContext context) =>
      surfaceLight.withValues(alpha: 0.85);

  static Color glassDark(BuildContext context) =>
      darkCard.withValues(alpha: 0.65);

  static Color roleAccent(bool isProvider) =>
      isProvider ? providerAccent : customerAccent;

  static Color roleMuted(bool isProvider) =>
      isProvider ? const Color(0xFFD1FAE5) : primaryMuted;

  static Color roleSurface(bool isProvider) =>
      isProvider ? surfaceLight : ultraLight;
}
