import 'package:flutter/material.dart';

/// MarGem design tokens — warm beige primary surfaces + lavender accents.
class AppColors {
  AppColors._();

  // ── Beige / warm neutrals (60% — primary surfaces) ──────────────────────
  static const beige = Color(0xFFF6D7B8);
  static const beigeLight = Color(0xFFFAF3EC);
  static const cream = Color(0xFFF8F1E9);
  static const creamSoft = Color(0xFFFFF9F3);
  static const ultraLight = Color(0xFFFAF8FF);

  // Aliases used across the codebase
  static const peach = Color(0xFFF6D7B6);
  static const peachDark = Color(0xFFE8C49A);
  static const peachLight = beigeLight;
  static const peachMuted = beigeLight;
  static const peachSurface = cream;

  // ── Lavender / purple (40% — accents & CTAs only) ───────────────────────
  static const lavender = Color(0xFF9A87F6);
  static const lavenderDark = Color(0xFF7E6BE7);
  static const lavenderLight = Color(0xFFB9A9FF);
  static const lavenderMuted = Color(0xFFF5F2FF);
  static const lavenderSurface = Color(0xFFF5F2FF);
  static const lavenderShadow = Color(0xFF7E6BE7);

  /// Primary brand accent — lavender (buttons, links, selected states).
  static const primary = lavender;
  static const primaryLight = lavenderLight;
  static const secondary = beige;
  static const secondaryLight = beigeLight;

  // Legacy aliases
  static const illustrationBurgundy = lavenderDark;
  static const illustrationOrange = beige;
  static const illustrationBlue = lavender;
  static const illustrationGreen = Color(0xFF6BCB77);

  // ── Neutrals ────────────────────────────────────────────────────────────
  static const navy = Color(0xFF1A1D2E);
  static const charcoal = navy;
  static const textPrimary = navy;
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  static const surfaceLight = cream;
  static const surfaceMuted = beigeLight;
  static const cardUnselected = cream;
  static const cardSelected = beigeLight;
  static const border = Color(0xFFE8E0D6);
  static const borderLight = Color(0xFFF0EBE4);

  static const splashBackground = cream;
  static const logoPlaceholder = beigeLight;
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
  static const providerAccent = beige;

  static Color glassLight(BuildContext context) =>
      cream.withValues(alpha: 0.85);
  static Color glassDark(BuildContext context) =>
      darkCard.withValues(alpha: 0.65);

  static Color roleAccent(bool isProvider) =>
      isProvider ? providerAccent : customerAccent;

  static Color roleMuted(bool isProvider) =>
      isProvider ? beigeLight : lavenderMuted;

  static Color roleSurface(bool isProvider) =>
      isProvider ? cream : ultraLight;

  // ── Theme-aware resolvers (use instead of hard-coded light tokens) ─────

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffold(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkSurface : surfaceLight;

  static Color mutedSurface(BuildContext context) =>
      isDark(context) ? darkCard : beigeLight;

  static Color cardSurface(BuildContext context) =>
      isDark(context) ? darkCard : cream;

  static Color elevatedCard(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color onSurfaceVariant(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color outline(BuildContext context) =>
      Theme.of(context).colorScheme.outline;

  static Color outlineSubtle(BuildContext context) =>
      isDark(context) ? darkBorder : borderLight;

  static Color drawerBackground(BuildContext context) =>
      isDark(context) ? darkSurface : beigeLight;

  static Color drawerTile(BuildContext context) =>
      isDark(context) ? darkCard : cream;

  static Color navBar(BuildContext context) =>
      isDark(context) ? darkSurface : cream;

  static Color searchBar(BuildContext context) =>
      isDark(context) ? darkCard : cream;

  static Color segmentedTrack(BuildContext context) =>
      isDark(context) ? darkCard : beigeLight;

  static Color segmentedThumb(BuildContext context) =>
      isDark(context) ? darkSurface : cream;

  static Color iconCircle(BuildContext context) =>
      isDark(context) ? darkCard : beigeLight;

  static Color promoGradientStart(BuildContext context) =>
      isDark(context) ? darkCard : beigeLight;

  static Color promoGradientEnd(BuildContext context) =>
      isDark(context) ? darkSurface : creamSoft;

  static Color badgeBorder(BuildContext context) =>
      isDark(context) ? darkSurface : cream;

  static Color favoriteButton(BuildContext context) =>
      isDark(context) ? darkCard : cream;

  static Color selectedCardSurface(BuildContext context) =>
      isDark(context) ? lavender.withValues(alpha: 0.15) : cardSelected;

  static Color filterChip(BuildContext context) =>
      isDark(context) ? darkSurface : beigeLight;

  static Color destructiveIconBg(BuildContext context) =>
      isDark(context) ? danger.withValues(alpha: 0.15) : dangerMuted;

  static Color emptyStateCircle(BuildContext context) =>
      isDark(context) ? darkCard : beigeLight;

  static List<Color> promoBannerGradient(BuildContext context) => [
        promoGradientStart(context),
        promoGradientEnd(context),
      ];
}
