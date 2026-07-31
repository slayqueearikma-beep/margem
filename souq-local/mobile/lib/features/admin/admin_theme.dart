import 'package:flutter/material.dart';

/// Enterprise admin console palette — isolated from customer theme.
abstract final class AdminTheme {
  static const sidebarBg = Color(0xFF0F1419);
  static const sidebarHover = Color(0xFF1A2332);
  static const sidebarActive = Color(0xFF243044);
  static const accent = Color(0xFFD4AF37);
  static const accentMuted = Color(0xFF8B1E2D);
  static const surface = Color(0xFFF4F6F9);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF1A1D21);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  static ThemeData theme() {
    const scheme = ColorScheme.light(
      primary: accentMuted,
      secondary: accent,
      surface: surface,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF9FAFB)),
        dataRowMinHeight: 48,
        headingRowHeight: 44,
      ),
    );
  }
}
