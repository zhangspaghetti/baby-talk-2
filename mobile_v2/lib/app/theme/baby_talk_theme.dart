import 'package:flutter/material.dart';

abstract final class BabyTalkTheme {
  static const _warmPaper = Color(0xFFFFF8F0);
  static const _warmSurface = Color(0xFFFFFCF7);
  static const _teal = Color(0xFF3B8577);
  static const _orange = Color(0xFFFF8C42);
  static const _textPrimary = Color(0xFF2D2926);
  static const _textSecondary = Color(0xFF6B5E57);
  static const _outline = Color(0xFFD8CFC8);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: Brightness.light,
      primary: _teal,
      secondary: _orange,
      surface: _warmSurface,
      outline: _outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _warmPaper,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: _textPrimary,
          fontSize: 15,
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: _textSecondary,
          fontSize: 15,
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: _textPrimary,
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: _textPrimary,
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        displaySmall: TextStyle(
          color: _teal,
          fontSize: 30,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          side: const BorderSide(color: _outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _textSecondary),
      ),
    );
  }
}
