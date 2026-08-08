import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_semantic_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final semantic =
        isDark ? AppSemanticColors.dark : AppSemanticColors.light;
    final textTheme = AppTypography.textTheme(brightness, semantic);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: semantic.primary,
      onPrimary: semantic.onPrimary,
      secondary: semantic.secondary,
      onSecondary: semantic.onPrimary,
      tertiary: semantic.info,
      error: semantic.error,
      onError: semantic.onPrimary,
      surface: semantic.surface,
      onSurface: semantic.textPrimary,
      onSurfaceVariant: semantic.textSecondary,
      outline: semantic.border,
      surfaceContainerHighest: semantic.surfaceVariant,
      surfaceContainerLow: semantic.background,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [semantic],
      scaffoldBackgroundColor: semantic.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: semantic.textPrimary,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: semantic.surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: semantic.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: semantic.divider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantic.surfaceVariant,
        labelStyle: TextStyle(color: semantic.textSecondary),
        hintStyle: TextStyle(color: semantic.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: semantic.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: semantic.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: semantic.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: semantic.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: semantic.primary,
          foregroundColor: semantic.onPrimary,
          disabledBackgroundColor: semantic.primary.withValues(alpha: 0.35),
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget + 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: semantic.textPrimary,
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget + 4),
          side: BorderSide(color: semantic.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: semantic.primary,
          textStyle: textTheme.labelLarge?.copyWith(color: semantic.primary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantic.surfaceVariant,
        selectedColor: semantic.primaryMuted,
        labelStyle: textTheme.bodySmall!,
        side: BorderSide(color: semantic.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: semantic.surface,
        indicatorColor: semantic.primaryMuted,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: semantic.primary,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: semantic.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: semantic.primary, size: 24);
          }
          return IconThemeData(color: semantic.textSecondary, size: 24);
        }),
      ),
      bottomAppBarTheme: BottomAppBarTheme(
        color: semantic.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: semantic.primary,
        foregroundColor: semantic.onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: semantic.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
          side: BorderSide(color: semantic.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: semantic.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: semantic.onPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: semantic.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: semantic.border,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: semantic.primary,
        unselectedLabelColor: semantic.textSecondary,
        indicatorColor: semantic.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        iconColor: semantic.textSecondary,
        textColor: semantic.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: semantic.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return semantic.primary;
          return semantic.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return semantic.primary.withValues(alpha: 0.4);
          }
          return semantic.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return semantic.primary;
          return Colors.transparent;
        }),
        side: BorderSide(color: semantic.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return semantic.primary;
          return semantic.border;
        }),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(semantic.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: semantic.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          side: BorderSide(color: semantic.border),
        ),
      ),
    );
  }
}
