import 'package:flutter/material.dart';

/// 暖纸亲和 设计系统自定义颜色 ThemeExtension。
/// 包含 light / dark 两套完整色板，通过 context.appColors 获取。
@immutable
class BabyTalkColors extends ThemeExtension<BabyTalkColors> {
  const BabyTalkColors({
    required this.bgBase,
    required this.bgSurface,
    required this.bgSunken,
    required this.bgAccentSoft,
    required this.accent,
    required this.accentDark,
    required this.english,
    required this.englishSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.info,
    required this.infoSoft,
    required this.outlineSoft,
    required this.warmShadowSm,
    required this.warmShadowMd,
    required this.warmShadowLg,
  });

  final Color bgBase;
  final Color bgSurface;
  final Color bgSunken;
  final Color bgAccentSoft;
  final Color accent;
  final Color accentDark;
  final Color english;
  final Color englishSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color error;
  final Color errorSoft;
  final Color info;
  final Color infoSoft;
  final Color outlineSoft;
  final List<BoxShadow> warmShadowSm;
  final List<BoxShadow> warmShadowMd;
  final List<BoxShadow> warmShadowLg;

  /// Light 色板 — 引用 AppTheme 静态常量
  factory BabyTalkColors.light() => const BabyTalkColors(
    bgBase: AppTheme.bgBase,
    bgSurface: AppTheme.bgSurface,
    bgSunken: AppTheme.bgSunken,
    bgAccentSoft: AppTheme.bgAccentSoft,
    accent: AppTheme.accent,
    accentDark: AppTheme.accentDark,
    english: AppTheme.english,
    englishSoft: AppTheme.englishSoft,
    textPrimary: AppTheme.textPrimary,
    textSecondary: AppTheme.textSecondary,
    textMuted: AppTheme.textMuted,
    success: AppTheme.success,
    successSoft: AppTheme.successSoft,
    warning: AppTheme.warning,
    warningSoft: AppTheme.warningSoft,
    error: AppTheme.error,
    errorSoft: AppTheme.errorSoft,
    info: AppTheme.info,
    infoSoft: AppTheme.infoSoft,
    outlineSoft: AppTheme.outlineSoft,
    warmShadowSm: AppTheme.warmShadowSm,
    warmShadowMd: AppTheme.warmShadowMd,
    warmShadowLg: AppTheme.warmShadowLg,
  );

  /// Dark 色板 — DESIGN.md Dark Mode Strategy
  factory BabyTalkColors.dark() => const BabyTalkColors(
    bgBase: Color(0xFF1C1816),
    bgSurface: Color(0xFF2A2420),
    bgSunken: Color(0xFF242018),
    bgAccentSoft: Color(0xFF3D2E20),
    accent: Color(0xFFFF9E5C),
    accentDark: Color(0xFFFFB47A),
    english: Color(0xFF5AAFA0),
    englishSoft: Color(0xFF1E3530),
    textPrimary: Color(0xFFF5F0EB),
    textSecondary: Color(0xFFB0A69D),
    textMuted: Color(0xFF807670),
    success: Color(0xFF8AB87A),
    successSoft: Color(0xFF1E2E1A),
    warning: Color(0xFFEFBE3A),
    warningSoft: Color(0xFF3A3018),
    error: Color(0xFFEF6F62),
    errorSoft: Color(0xFF3A1E1A),
    info: Color(0xFF5AAFA0),
    infoSoft: Color(0xFF1E3530),
    outlineSoft: Color(0xFF3D3630),
    // Dark 模式阴影用纯黑透明度（DESIGN.md：阴影改用纯黑透明度）
    warmShadowSm: [
      BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    warmShadowMd: [
      BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
    ],
    warmShadowLg: [
      BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  @override
  BabyTalkColors copyWith({
    Color? bgBase,
    Color? bgSurface,
    Color? bgSunken,
    Color? bgAccentSoft,
    Color? accent,
    Color? accentDark,
    Color? english,
    Color? englishSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? error,
    Color? errorSoft,
    Color? info,
    Color? infoSoft,
    Color? outlineSoft,
    List<BoxShadow>? warmShadowSm,
    List<BoxShadow>? warmShadowMd,
    List<BoxShadow>? warmShadowLg,
  }) => BabyTalkColors(
    bgBase: bgBase ?? this.bgBase,
    bgSurface: bgSurface ?? this.bgSurface,
    bgSunken: bgSunken ?? this.bgSunken,
    bgAccentSoft: bgAccentSoft ?? this.bgAccentSoft,
    accent: accent ?? this.accent,
    accentDark: accentDark ?? this.accentDark,
    english: english ?? this.english,
    englishSoft: englishSoft ?? this.englishSoft,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    success: success ?? this.success,
    successSoft: successSoft ?? this.successSoft,
    warning: warning ?? this.warning,
    warningSoft: warningSoft ?? this.warningSoft,
    error: error ?? this.error,
    errorSoft: errorSoft ?? this.errorSoft,
    info: info ?? this.info,
    infoSoft: infoSoft ?? this.infoSoft,
    outlineSoft: outlineSoft ?? this.outlineSoft,
    warmShadowSm: warmShadowSm ?? this.warmShadowSm,
    warmShadowMd: warmShadowMd ?? this.warmShadowMd,
    warmShadowLg: warmShadowLg ?? this.warmShadowLg,
  );

  @override
  BabyTalkColors lerp(covariant BabyTalkColors? other, double t) {
    if (other is! BabyTalkColors) return this;
    return BabyTalkColors(
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgSunken: Color.lerp(bgSunken, other.bgSunken, t)!,
      bgAccentSoft: Color.lerp(bgAccentSoft, other.bgAccentSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      english: Color.lerp(english, other.english, t)!,
      englishSoft: Color.lerp(englishSoft, other.englishSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      // BoxShadow 不做 lerp，直接选择目标
      warmShadowSm: t < 0.5 ? warmShadowSm : other.warmShadowSm,
      warmShadowMd: t < 0.5 ? warmShadowMd : other.warmShadowMd,
      warmShadowLg: t < 0.5 ? warmShadowLg : other.warmShadowLg,
    );
  }
}

/// BuildContext 便捷扩展：context.appColors
extension BabyTalkColorsExtension on BuildContext {
  BabyTalkColors get appColors {
    final theme = Theme.of(this);
    return theme.extension<BabyTalkColors>() ??
        (theme.brightness == Brightness.dark
            ? BabyTalkColors.dark()
            : BabyTalkColors.light());
  }
}

class AppTheme {
  // ─── Light 色板静态常量（保持向后兼容，T03 迁移前消费者仍引用） ───
  static const Color bgBase = Color(0xFFFFF8F0);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSunken = Color(0xFFF5F0EB);
  static const Color bgAccentSoft = Color(0xFFFFF0E5);
  static const Color accent = Color(0xFFFF8C42);
  static const Color accentDark = Color(0xFFE67A30);
  static const Color english = Color(0xFF3B8577);
  static const Color englishSoft = Color(0xFFD4E8E3);
  static const Color textPrimary = Color(0xFF2D2926);
  static const Color textSecondary = Color(0xFF6B5E57);
  static const Color textMuted = Color(0xFF8A7D76);
  static const Color success = Color(0xFF6B8F5E);
  static const Color successSoft = Color(0xFFE8F0E5);
  static const Color warning = Color(0xFFE6A817);
  static const Color warningSoft = Color(0xFFFFF5D9);
  static const Color error = Color(0xFFD94B3C);
  static const Color errorSoft = Color(0xFFFDE8E6);
  static const Color info = Color(0xFF3B8577);
  static const Color infoSoft = Color(0xFFD4E8E3);
  static const Color outlineSoft = Color(0xFFD8CFC8);

  // ─── 阴影（DESIGN.md 对齐） ───

  /// --shadow-sm: 0 1px 3px rgba(45,41,38,0.06)
  static const List<BoxShadow> warmShadowSm = [
    BoxShadow(
      color: Color(0x0F2D2926), // rgba(45,41,38, ~0.06)
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  /// --shadow-md: 0 2px 12px rgba(45,41,38,0.08)
  static const List<BoxShadow> warmShadowMd = [
    BoxShadow(
      color: Color(0x142D2926), // rgba(45,41,38, ~0.08)
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  /// --shadow-lg: 0 8px 24px rgba(45,41,38,0.12)
  static const List<BoxShadow> warmShadowLg = [
    BoxShadow(
      color: Color(0x1F2D2926), // rgba(45,41,38, ~0.12)
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  // ─── 额外 Typography styles（DESIGN.md 定义但 TextTheme 不直接映射） ───

  /// Title 1: Fraunces 28/500/1.3 — 英文短语标准显示
  static const TextStyle title1Style = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: textPrimary,
  );

  /// Title 2: Fraunces 24/500/1.3 — 英文短语最小号
  static const TextStyle title2Style = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: textPrimary,
  );

  /// Mono: JetBrains Mono 14/400/1.5 — IPA 音标
  static const TextStyle monoStyle = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: textSecondary,
  );

  // ─── Light theme ───

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      secondary: english,
      surface: bgSurface,
      error: error,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgBase,
      fontFamily: 'DM Sans',
      dividerColor: outlineSoft,
      textTheme: const TextTheme(
        displayMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 32,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: textPrimary,
        ),
        // Title 1 映射 → headlineMedium (Fraunces 28/500/1.3)
        headlineMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 28,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: textPrimary,
        ),
        // Title 2 映射 → headlineSmall (Fraunces 24/500/1.3)
        headlineSmall: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.3,
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
      extensions: <ThemeExtension<dynamic>>[BabyTalkColors.light()],
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // DESIGN.md --radius-md
          side: const BorderSide(color: outlineSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        hintStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: outlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: outlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error, width: 1.4),
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
          side: const BorderSide(color: outlineSoft),
          backgroundColor: bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: bgSurface,
        indicatorColor: bgAccentSoft,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: bgSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
    );
  }

  // ─── Dark theme ───

  static ThemeData buildDark() {
    const dk = _DarkPalette();

    final colorScheme = ColorScheme.fromSeed(
      seedColor: dk.accent,
      brightness: Brightness.dark,
      primary: dk.accent,
      secondary: dk.english,
      surface: dk.bgSurface,
      error: dk.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: dk.bgBase,
      fontFamily: 'DM Sans',
      dividerColor: dk.outlineSoft,
      textTheme: TextTheme(
        displayMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 32,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: dk.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 28,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: dk.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: dk.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: dk.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.4,
          color: dk.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: dk.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: dk.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: dk.textMuted,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: dk.accentDark,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[BabyTalkColors.dark()],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: dk.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: dk.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dk.outlineSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dk.bgSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: dk.textSecondary,
        ),
        hintStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: dk.textMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dk.outlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dk.outlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dk.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dk.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dk.error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dk.accent,
          foregroundColor: const Color(0xFF1C1816), // 深色按钮文字
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
          foregroundColor: dk.textPrimary,
          side: BorderSide(color: dk.outlineSoft),
          backgroundColor: dk.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dk.bgSurface,
        indicatorColor: dk.bgAccentSoft,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: dk.textPrimary,
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: dk.bgSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: dk.bgAccentSoft,
        selectedColor: dk.bgAccentSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: dk.accentDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dk.bgSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: dk.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: dk.accent,
        foregroundColor: const Color(0xFF1C1816),
        shape: const CircleBorder(),
      ),
    );
  }
}

/// 内部 dark palette 常量集合，避免在 buildDark 中重复 Color 构造
class _DarkPalette {
  const _DarkPalette();
  Color get bgBase => const Color(0xFF1C1816);
  Color get bgSurface => const Color(0xFF2A2420);
  Color get bgSunken => const Color(0xFF242018);
  Color get bgAccentSoft => const Color(0xFF3D2E20);
  Color get accent => const Color(0xFFFF9E5C);
  Color get accentDark => const Color(0xFFFFB47A);
  Color get english => const Color(0xFF5AAFA0);
  Color get englishSoft => const Color(0xFF1E3530);
  Color get textPrimary => const Color(0xFFF5F0EB);
  Color get textSecondary => const Color(0xFFB0A69D);
  Color get textMuted => const Color(0xFF807670);
  Color get outlineSoft => const Color(0xFF3D3630);
  Color get error => const Color(0xFFEF6F62);
}
