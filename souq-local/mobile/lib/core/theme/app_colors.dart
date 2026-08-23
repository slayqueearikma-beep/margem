import 'package:flutter/material.dart';

/// MarGem production color system — premium burgundy marketplace identity.
///
/// Every color has a defined purpose. Use [AppColorExtension] via
/// `Theme.of(context).extension<AppColorExtension>()` for theme-aware tokens.
class AppColors {
  AppColors._();

  // ── Primary brand (burgundy) ──────────────────────────────────────────────
  static const primary = Color(0xFF8B1E2D);
  static const primaryDark = Color(0xFF6E1824); // pressed / emphasis
  static const primaryLight = Color(0xFFA43544);
  static const primaryLighter = Color(0xFFC45A66);
  static const primaryTint = Color(0xFFF5E8EA);
  static const primaryContainer = Color(0xFFF9EDEF);

  // ── Accent gold (VIP, premium, verified, featured — use sparingly) ────────
  static const gold = Color(0xFFD4AF37);
  static const goldDark = Color(0xFFB8941F);
  static const goldLight = Color(0xFFE5C76B);

  // ── Neutral scale (warm, marketplace-friendly) ────────────────────────────
  static const neutral50 = Color(0xFFFAFAF9);
  static const neutral100 = Color(0xFFF5F4F3);
  static const neutral200 = Color(0xFFE8E6E4);
  static const neutral300 = Color(0xFFD4D1CE);
  static const neutral400 = Color(0xFFA8A5A1);
  static const neutral500 = Color(0xFF7C7975);
  static const neutral600 = Color(0xFF5C5956);
  static const neutral700 = Color(0xFF444240);
  static const neutral800 = Color(0xFF2C2A28);
  static const neutral900 = Color(0xFF1A1918);

  // ── Backgrounds (light) ───────────────────────────────────────────────────
  static const backgroundPrimary = Color(0xFFFFFFFF);
  static const backgroundSecondary = neutral100;
  static const backgroundCard = Color(0xFFFFFFFF);
  static const backgroundModal = Color(0xFFFFFFFF);
  static const backgroundBottomSheet = Color(0xFFFFFFFF);
  static const backgroundSearch = neutral100;

  // ── Text (light) ────────────────────────────────────────────────────────
  static const textPrimary = neutral900;
  static const textSecondary = neutral700;
  static const textTertiary = neutral500;
  static const textHint = neutral500;
  static const textMuted = neutral400;
  static const textDisabled = neutral400;
  static const textInverse = Color(0xFFFFFFFF);

  // ── Surfaces & borders (light) ──────────────────────────────────────────
  static const border = neutral200;
  static const divider = neutral200;
  static const cardSelected = primaryTint;
  static const cardUnselected = neutral100;
  static const heroBackground = primaryTint;

  // ── Dark mode (purpose-built, not inverted) ───────────────────────────────
  static const darkBackground = Color(0xFF121014);
  static const darkSurface = Color(0xFF1A181E);
  static const darkCard = Color(0xFF242228);
  static const darkBorder = Color(0xFF333138);
  static const darkTextPrimary = Color(0xFFF5F4F3);
  static const darkTextSecondary = Color(0xFFB8B5B2);
  static const darkTextHint = Color(0xFF7C7975);
  static const darkSearchBackground = Color(0xFF1E1C22);
  static const darkModalBackground = Color(0xFF1A181E);
  static const darkBottomSheetBackground = Color(0xFF1A181E);
  static const darkPrimaryContainer = Color(0xFF3A2228);
  static const darkSecondaryContainer = Color(0xFF3D3520);
  static const darkTertiaryContainer = Color(0xFF1E2E22);
  static const darkOnTertiaryContainer = Color(0xFFB8D4BE);
  static const darkError = Color(0xFFEF4444);
  static const darkErrorContainer = Color(0xFF3D1A1A);
  static const darkOnErrorContainer = Color(0xFFFCA5A5);
  static const darkOutlineVariant = Color(0xFF2A2830);
  static const darkCardSelected = Color(0xFF3A2228);
  static const darkHeroBackground = Color(0xFF2A1A1E);
  static const darkSuccess = Color(0xFF4CAF50);
  static const darkSuccessLight = Color(0xFF1B3D1E);
  static const darkWarning = Color(0xFFF59E0B);
  static const darkWarningLight = Color(0xFF3D2E14);
  static const darkErrorLight = Color(0xFF3D1A1A);
  static const darkInfo = Color(0xFF60A5FA);
  static const darkInfoLight = Color(0xFF1A2A3D);
  static const darkScrimLight = Color(0x1AFFFFFF);
  static const darkScrimMedium = Color(0x33FFFFFF);
  static const darkOverlayLight = Color(0xEB1A181E);
  static const darkFavoriteOverlay = Color(0xEB242228);

  // ── Light mode containers ─────────────────────────────────────────────────
  static const secondaryContainer = Color(0xFFFFF8E1);
  static const tertiaryContainer = Color(0xFFE8F2EA);
  static const onTertiaryContainer = Color(0xFF2E5A38);

  // ── Status (WCAG AA on white / dark surfaces) ───────────────────────────
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const warning = Color(0xFFB45309);
  static const warningLight = Color(0xFFFFF7ED);
  static const danger = Color(0xFFB91C1C);
  static const error = danger;
  static const errorLight = Color(0xFFFEF2F2);
  static const info = Color(0xFF1D4ED8);
  static const infoLight = Color(0xFFEFF6FF);
  static const pending = Color(0xFF6B7280);
  static const pendingLight = Color(0xFFF3F4F6);
  static const verified = success;

  // ── Category accents (muted, brand-consistent) ──────────────────────────
  static const categoryBeauty = Color(0xFFB87B8A);
  static const categoryClothing = Color(0xFF8B7355);
  static const categoryElectronics = Color(0xFF5C6B8A);
  static const categoryFood = Color(0xFFB86B52);
  static const categoryServices = Color(0xFF5F8A6B);
  static const categoryDefault = primary;

  // ── Buttons ───────────────────────────────────────────────────────────────
  static const buttonPrimary = primary;
  static const buttonPrimaryPressed = primaryDark;
  static const buttonPrimaryDisabled = Color(0x668B1E2D); // primary @ 40%
  static const buttonSecondary = backgroundSecondary;
  static const buttonSecondaryPressed = neutral200;
  static const buttonOutlinedBorder = primary;
  static const buttonGhost = Color(0x00000000);
  static const buttonLoading = textInverse;

  // ── Chat ─────────────────────────────────────────────────────────────────
  static const chatIncoming = neutral100;
  static const chatOutgoing = primary;

  // ── Utility / overlays ──────────────────────────────────────────────────
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);
  static const scrim = Color(0x8C000000); // black @ 55%
  static const scrimLight = Color(0x0D000000); // black @ 5%
  static const scrimMedium = Color(0x1F000000); // black @ 12%
  static const overlayLight = Color(0xEBFFFFFF); // white @ 92%
  static const overlayFaint = Color(0x59FFFFFF); // white @ 35%
  static const overlaySoft = Color(0x4DFFFFFF); // white @ 30%
  static const overlaySubtle = Color(0x33FFFFFF); // white @ 20%
  static const onPrimaryMuted = Color(0xB3FFFFFF); // white @ 70%
  static const shadowColor = Color(0x1A1A1918); // neutral900 @ 10%

  // ── Ratings & premium highlights ──────────────────────────────────────────
  static const star = gold;
  static const goldenCrown = gold;

  // ── Brand assets ──────────────────────────────────────────────────────────
  static const charcoal = neutral900;
  static const splashBackground = backgroundPrimary;
  static const logoPlaceholder = primaryTint;
  static const logoInner = primary;
  static const logoDarkFill = Color(0xFF1A1A1A);

  // ── Illustration / onboarding accents ─────────────────────────────────────
  static const illustrationBurgundy = primary;
  static const illustrationOrange = Color(0xFFC47A5A);
  static const illustrationGreen = categoryServices;
  static const illustrationBlue = categoryElectronics;
  static const onboardingSlideLight = Color(0xFFE8F1FA);
  static const onboardingSlideDark = Color(0xFF0B0B0B);
  static const buyerAccent = categoryElectronics;

  // ── Legacy aliases (backward-compatible) ──────────────────────────────────
  static const surfaceLight = backgroundCard;
  static const surfaceMuted = backgroundSecondary;
  static const surfaceInput = backgroundSearch;

  /// Returns a category accent color for the given slug.
  static Color categoryFor(String slug) {
    return switch (slug) {
      'beauty' || 'spa' => categoryBeauty,
      'clothing' || 'fashion' => categoryClothing,
      'electronics' => categoryElectronics,
      'food' || 'restaurant' => categoryFood,
      'services' => categoryServices,
      _ => categoryDefault,
    };
  }
}
