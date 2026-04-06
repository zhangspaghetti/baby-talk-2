import 'package:flutter/material.dart';

class AppPalette {
  static const bgBase = Color(0xFFFFF8F0);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgSunken = Color(0xFFF5F0EB);
  static const accent = Color(0xFFFF8C42);
  static const accentDark = Color(0xFFE67A30);
  static const accentLight = Color(0xFFFFF0E5);
  static const english = Color(0xFF3B8577);
  static const englishSoft = Color(0xFFD4E8E3);
  static const success = Color(0xFF6B8F5E);
  static const successSoft = Color(0xFFE8F0E5);
  static const warning = Color(0xFFE6A817);
  static const warningSoft = Color(0xFFFFF5D9);
  static const error = Color(0xFFD94B3C);
  static const errorSoft = Color(0xFFFDE8E6);
  static const textPrimary = Color(0xFF2D2926);
  static const textSecondary = Color(0xFF6B5E57);
  static const textMuted = Color(0xFF8A7D76);
  static const border = Color(0xFFE3D6CB);

  static const darkBgBase = Color(0xFF1C1816);
  static const darkBgSurface = Color(0xFF2A2420);
  static const darkBgSunken = Color(0xFF241F1B);
  static const darkAccent = Color(0xFFFF9E5C);
  static const darkEnglish = Color(0xFF5AAFA0);
  static const darkTextPrimary = Color(0xFFF7EDE3);
  static const darkTextSecondary = Color(0xFFCCBBAE);
  static const darkTextMuted = Color(0xFFA89284);
  static const darkBorder = Color(0xFF483F39);
}

class AppTheme {
  static ThemeData light() {
    return _buildTheme(
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppPalette.accent,
        onPrimary: Colors.white,
        secondary: AppPalette.english,
        onSecondary: Colors.white,
        error: AppPalette.error,
        onError: Colors.white,
        surface: AppPalette.bgSurface,
        onSurface: AppPalette.textPrimary,
      ),
      scaffoldBackground: AppPalette.bgBase,
      surfaceColor: AppPalette.bgSurface,
      sunkenColor: AppPalette.bgSunken,
      textPrimary: AppPalette.textPrimary,
      textSecondary: AppPalette.textSecondary,
      textMuted: AppPalette.textMuted,
      borderColor: AppPalette.border,
      englishTone: AppPalette.english,
    );
  }

  static ThemeData dark() {
    return _buildTheme(
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppPalette.darkAccent,
        onPrimary: Colors.black,
        secondary: AppPalette.darkEnglish,
        onSecondary: Colors.black,
        error: AppPalette.error,
        onError: Colors.white,
        surface: AppPalette.darkBgSurface,
        onSurface: AppPalette.darkTextPrimary,
      ),
      scaffoldBackground: AppPalette.darkBgBase,
      surfaceColor: AppPalette.darkBgSurface,
      sunkenColor: AppPalette.darkBgSunken,
      textPrimary: AppPalette.darkTextPrimary,
      textSecondary: AppPalette.darkTextSecondary,
      textMuted: AppPalette.darkTextMuted,
      borderColor: AppPalette.darkBorder,
      englishTone: AppPalette.darkEnglish,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color surfaceColor,
    required Color sunkenColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color borderColor,
    required Color englishTone,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: TextStyle(
        fontFamily: 'Fraunces',
        fontFamilyFallback: _serifFallbacks,
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Fraunces',
        fontFamilyFallback: _serifFallbacks,
        fontSize: 28,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Fraunces',
        fontFamilyFallback: _serifFallbacks,
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamilyFallback: _bodyFallbacks,
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamilyFallback: _bodyFallbacks,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamilyFallback: _bodyFallbacks,
        fontSize: 15,
        height: 1.6,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamilyFallback: _bodyFallbacks,
        fontSize: 14,
        height: 1.6,
        color: textSecondary,
      ),
      bodySmall: TextStyle(
        fontFamilyFallback: _bodyFallbacks,
        fontSize: 13,
        height: 1.5,
        color: textSecondary,
      ),
      labelMedium: TextStyle(
        fontFamilyFallback: _bodyFallbacks,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      labelSmall: TextStyle(
        fontFamilyFallback: _bodyFallbacks,
        fontSize: 11,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: textMuted,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerColor: borderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceColor,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sunkenColor,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.titleMedium,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: sunkenColor,
        selectedColor: colorScheme.primary.withValues(alpha: 0.12),
        secondarySelectedColor: colorScheme.primary.withValues(alpha: 0.12),
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        labelStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        extendedTextStyle: textTheme.titleMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(color: textSecondary),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: textSecondary)),
        height: 74,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: sunkenColor,
        circularTrackColor: sunkenColor,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeTone(
          paperSurface: surfaceColor,
          paperSunken: sunkenColor,
          englishTone: englishTone,
          borderTone: borderColor,
        ),
      ],
    );
  }

  static const List<String> _serifFallbacks = ['Georgia', 'Times New Roman'];
  static const List<String> _bodyFallbacks = [
    'PingFang SC',
    'Noto Sans SC',
    'Microsoft YaHei',
    'sans-serif',
  ];
}

class AppThemeTone extends ThemeExtension<AppThemeTone> {
  const AppThemeTone({
    required this.paperSurface,
    required this.paperSunken,
    required this.englishTone,
    required this.borderTone,
  });

  final Color paperSurface;
  final Color paperSunken;
  final Color englishTone;
  final Color borderTone;

  @override
  AppThemeTone copyWith({
    Color? paperSurface,
    Color? paperSunken,
    Color? englishTone,
    Color? borderTone,
  }) {
    return AppThemeTone(
      paperSurface: paperSurface ?? this.paperSurface,
      paperSunken: paperSunken ?? this.paperSunken,
      englishTone: englishTone ?? this.englishTone,
      borderTone: borderTone ?? this.borderTone,
    );
  }

  @override
  AppThemeTone lerp(ThemeExtension<AppThemeTone>? other, double t) {
    if (other is! AppThemeTone) {
      return this;
    }

    return AppThemeTone(
      paperSurface:
          Color.lerp(paperSurface, other.paperSurface, t) ?? paperSurface,
      paperSunken: Color.lerp(paperSunken, other.paperSunken, t) ?? paperSunken,
      englishTone: Color.lerp(englishTone, other.englishTone, t) ?? englishTone,
      borderTone: Color.lerp(borderTone, other.borderTone, t) ?? borderTone,
    );
  }
}
