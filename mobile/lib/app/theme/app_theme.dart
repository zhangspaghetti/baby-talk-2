import 'package:flutter/material.dart';

class AppTheme {
  static const Color bgBase = Color(0xFFFFF8F0);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSunken = Color(0xFFF5F0EB);
  static const Color bgAccentSoft = Color(0xFFFFF0E5);
  static const Color accent = Color(0xFFFF8C42);
  static const Color accentDark = Color(0xFFE67A30);
  static const Color english = Color(0xFF3B8577);
  static const Color textPrimary = Color(0xFF2D2926);
  static const Color textSecondary = Color(0xFF6B5E57);
  static const Color textMuted = Color(0xFF8A7D76);

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      secondary: english,
      surface: bgSurface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgBase,
      fontFamily: 'DM Sans',
      textTheme: const TextTheme(
        displayMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 32,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: textMuted,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: accentDark,
        ),
      ),
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x14000000)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: textPrimary,
          side: const BorderSide(color: Color(0xFFD8CFC8)),
          backgroundColor: bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: bgAccentSoft,
        selectedColor: bgAccentSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accentDark,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
    );
  }
}
