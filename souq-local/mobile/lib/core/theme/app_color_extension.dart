import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme-aware semantic colors beyond Material [ColorScheme].
@immutable
class AppColorExtension extends ThemeExtension<AppColorExtension> {
  const AppColorExtension({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.backgroundCard,
    required this.backgroundModal,
    required this.backgroundBottomSheet,
    required this.backgroundSearch,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textDisabled,
    required this.textInverse,
    required this.border,
    required this.divider,
    required this.cardSelected,
    required this.cardUnselected,
    required this.heroBackground,
    required this.chatIncoming,
    required this.chatOutgoing,
    required this.gold,
    required this.star,
    required this.success,
    required this.successLight,
    required this.warning,
    required this.warningLight,
    required this.error,
    required this.errorLight,
    required this.info,
    required this.infoLight,
    required this.pending,
    required this.pendingLight,
    required this.scrim,
    required this.scrimLight,
    required this.scrimMedium,
    required this.overlayLight,
    required this.onPrimaryMuted,
    required this.favoriteOverlay,
    required this.navBackground,
    required this.iconDefault,
    required this.iconMuted,
  });

  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color backgroundCard;
  final Color backgroundModal;
  final Color backgroundBottomSheet;
  final Color backgroundSearch;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color textDisabled;
  final Color textInverse;
  final Color border;
  final Color divider;
  final Color cardSelected;
  final Color cardUnselected;
  final Color heroBackground;
  final Color chatIncoming;
  final Color chatOutgoing;
  final Color gold;
  final Color star;
  final Color success;
  final Color successLight;
  final Color warning;
  final Color warningLight;
  final Color error;
  final Color errorLight;
  final Color info;
  final Color infoLight;
  final Color pending;
  final Color pendingLight;
  final Color scrim;
  final Color scrimLight;
  final Color scrimMedium;
  final Color overlayLight;
  final Color onPrimaryMuted;
  final Color favoriteOverlay;
  final Color navBackground;
  final Color iconDefault;
  final Color iconMuted;

  static const light = AppColorExtension(
    backgroundPrimary: AppColors.backgroundPrimary,
    backgroundSecondary: AppColors.backgroundSecondary,
    backgroundCard: AppColors.backgroundCard,
    backgroundModal: AppColors.backgroundModal,
    backgroundBottomSheet: AppColors.backgroundBottomSheet,
    backgroundSearch: AppColors.backgroundSearch,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textHint: AppColors.textHint,
    textDisabled: AppColors.textDisabled,
    textInverse: AppColors.textInverse,
    border: AppColors.border,
    divider: AppColors.divider,
    cardSelected: AppColors.cardSelected,
    cardUnselected: AppColors.cardUnselected,
    heroBackground: AppColors.heroBackground,
    chatIncoming: AppColors.chatIncoming,
    chatOutgoing: AppColors.chatOutgoing,
    gold: AppColors.gold,
    star: AppColors.star,
    success: AppColors.success,
    successLight: AppColors.successLight,
    warning: AppColors.warning,
    warningLight: AppColors.warningLight,
    error: AppColors.error,
    errorLight: AppColors.errorLight,
    info: AppColors.info,
    infoLight: AppColors.infoLight,
    pending: AppColors.pending,
    pendingLight: AppColors.pendingLight,
    scrim: AppColors.scrim,
    scrimLight: AppColors.scrimLight,
    scrimMedium: AppColors.scrimMedium,
    overlayLight: AppColors.overlayLight,
    onPrimaryMuted: AppColors.onPrimaryMuted,
    favoriteOverlay: AppColors.overlayLight,
    navBackground: AppColors.backgroundCard,
    iconDefault: AppColors.textPrimary,
    iconMuted: AppColors.textHint,
  );

  static const dark = AppColorExtension(
    backgroundPrimary: AppColors.darkBackground,
    backgroundSecondary: AppColors.darkSurface,
    backgroundCard: AppColors.darkCard,
    backgroundModal: AppColors.darkModalBackground,
    backgroundBottomSheet: AppColors.darkBottomSheetBackground,
    backgroundSearch: AppColors.darkSearchBackground,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textHint: AppColors.darkTextHint,
    textDisabled: AppColors.neutral600,
    textInverse: AppColors.textInverse,
    border: AppColors.darkBorder,
    divider: AppColors.darkBorder,
    cardSelected: AppColors.darkCardSelected,
    cardUnselected: AppColors.darkCard,
    heroBackground: AppColors.darkHeroBackground,
    chatIncoming: AppColors.darkCard,
    chatOutgoing: AppColors.primary,
    gold: AppColors.gold,
    star: AppColors.gold,
    success: AppColors.darkSuccess,
    successLight: AppColors.darkSuccessLight,
    warning: AppColors.darkWarning,
    warningLight: AppColors.darkWarningLight,
    error: AppColors.darkError,
    errorLight: AppColors.darkErrorLight,
    info: AppColors.darkInfo,
    infoLight: AppColors.darkInfoLight,
    pending: AppColors.neutral500,
    pendingLight: AppColors.darkCard,
    scrim: AppColors.scrim,
    scrimLight: AppColors.darkScrimLight,
    scrimMedium: AppColors.darkScrimMedium,
    overlayLight: AppColors.darkOverlayLight,
    onPrimaryMuted: AppColors.onPrimaryMuted,
    favoriteOverlay: AppColors.darkFavoriteOverlay,
    navBackground: AppColors.darkSurface,
    iconDefault: AppColors.darkTextPrimary,
    iconMuted: AppColors.darkTextHint,
  );

  @override
  AppColorExtension copyWith({
    Color? backgroundPrimary,
    Color? backgroundSecondary,
    Color? backgroundCard,
    Color? backgroundModal,
    Color? backgroundBottomSheet,
    Color? backgroundSearch,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? textDisabled,
    Color? textInverse,
    Color? border,
    Color? divider,
    Color? cardSelected,
    Color? cardUnselected,
    Color? heroBackground,
    Color? chatIncoming,
    Color? chatOutgoing,
    Color? gold,
    Color? star,
    Color? success,
    Color? successLight,
    Color? warning,
    Color? warningLight,
    Color? error,
    Color? errorLight,
    Color? info,
    Color? infoLight,
    Color? pending,
    Color? pendingLight,
    Color? scrim,
    Color? scrimLight,
    Color? scrimMedium,
    Color? overlayLight,
    Color? onPrimaryMuted,
    Color? favoriteOverlay,
    Color? navBackground,
    Color? iconDefault,
    Color? iconMuted,
  }) {
    return AppColorExtension(
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      backgroundCard: backgroundCard ?? this.backgroundCard,
      backgroundModal: backgroundModal ?? this.backgroundModal,
      backgroundBottomSheet:
          backgroundBottomSheet ?? this.backgroundBottomSheet,
      backgroundSearch: backgroundSearch ?? this.backgroundSearch,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      cardSelected: cardSelected ?? this.cardSelected,
      cardUnselected: cardUnselected ?? this.cardUnselected,
      heroBackground: heroBackground ?? this.heroBackground,
      chatIncoming: chatIncoming ?? this.chatIncoming,
      chatOutgoing: chatOutgoing ?? this.chatOutgoing,
      gold: gold ?? this.gold,
      star: star ?? this.star,
      success: success ?? this.success,
      successLight: successLight ?? this.successLight,
      warning: warning ?? this.warning,
      warningLight: warningLight ?? this.warningLight,
      error: error ?? this.error,
      errorLight: errorLight ?? this.errorLight,
      info: info ?? this.info,
      infoLight: infoLight ?? this.infoLight,
      pending: pending ?? this.pending,
      pendingLight: pendingLight ?? this.pendingLight,
      scrim: scrim ?? this.scrim,
      scrimLight: scrimLight ?? this.scrimLight,
      scrimMedium: scrimMedium ?? this.scrimMedium,
      overlayLight: overlayLight ?? this.overlayLight,
      onPrimaryMuted: onPrimaryMuted ?? this.onPrimaryMuted,
      favoriteOverlay: favoriteOverlay ?? this.favoriteOverlay,
      navBackground: navBackground ?? this.navBackground,
      iconDefault: iconDefault ?? this.iconDefault,
      iconMuted: iconMuted ?? this.iconMuted,
    );
  }

  @override
  AppColorExtension lerp(ThemeExtension<AppColorExtension>? other, double t) {
    if (other is! AppColorExtension) return this;
    Color lerpColor(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColorExtension(
      backgroundPrimary: lerpColor(backgroundPrimary, other.backgroundPrimary),
      backgroundSecondary:
          lerpColor(backgroundSecondary, other.backgroundSecondary),
      backgroundCard: lerpColor(backgroundCard, other.backgroundCard),
      backgroundModal: lerpColor(backgroundModal, other.backgroundModal),
      backgroundBottomSheet:
          lerpColor(backgroundBottomSheet, other.backgroundBottomSheet),
      backgroundSearch: lerpColor(backgroundSearch, other.backgroundSearch),
      textPrimary: lerpColor(textPrimary, other.textPrimary),
      textSecondary: lerpColor(textSecondary, other.textSecondary),
      textHint: lerpColor(textHint, other.textHint),
      textDisabled: lerpColor(textDisabled, other.textDisabled),
      textInverse: lerpColor(textInverse, other.textInverse),
      border: lerpColor(border, other.border),
      divider: lerpColor(divider, other.divider),
      cardSelected: lerpColor(cardSelected, other.cardSelected),
      cardUnselected: lerpColor(cardUnselected, other.cardUnselected),
      heroBackground: lerpColor(heroBackground, other.heroBackground),
      chatIncoming: lerpColor(chatIncoming, other.chatIncoming),
      chatOutgoing: lerpColor(chatOutgoing, other.chatOutgoing),
      gold: lerpColor(gold, other.gold),
      star: lerpColor(star, other.star),
      success: lerpColor(success, other.success),
      successLight: lerpColor(successLight, other.successLight),
      warning: lerpColor(warning, other.warning),
      warningLight: lerpColor(warningLight, other.warningLight),
      error: lerpColor(error, other.error),
      errorLight: lerpColor(errorLight, other.errorLight),
      info: lerpColor(info, other.info),
      infoLight: lerpColor(infoLight, other.infoLight),
      pending: lerpColor(pending, other.pending),
      pendingLight: lerpColor(pendingLight, other.pendingLight),
      scrim: lerpColor(scrim, other.scrim),
      scrimLight: lerpColor(scrimLight, other.scrimLight),
      scrimMedium: lerpColor(scrimMedium, other.scrimMedium),
      overlayLight: lerpColor(overlayLight, other.overlayLight),
      onPrimaryMuted: lerpColor(onPrimaryMuted, other.onPrimaryMuted),
      favoriteOverlay: lerpColor(favoriteOverlay, other.favoriteOverlay),
      navBackground: lerpColor(navBackground, other.navBackground),
      iconDefault: lerpColor(iconDefault, other.iconDefault),
      iconMuted: lerpColor(iconMuted, other.iconMuted),
    );
  }
}

/// Convenient access to MarGem semantic colors from any [BuildContext].
extension AppColorContext on BuildContext {
  AppColorExtension get appColors =>
      Theme.of(this).extension<AppColorExtension>() ?? AppColorExtension.light;
}
