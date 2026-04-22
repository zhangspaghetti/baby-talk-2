import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';

void main() {
  group('AppTheme.build() — light theme', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.build();
    });

    test('包含 BabyTalkColors extension', () {
      final colors = theme.extension<BabyTalkColors>();
      expect(colors, isNotNull, reason: 'light ThemeData 必须携带 BabyTalkColors');
    });

    test('亮度为 Brightness.light', () {
      expect(theme.brightness, Brightness.light);
    });

    test('card radius 为 16', () {
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      final borderRadius = cardShape.borderRadius as BorderRadius;
      expect(
        borderRadius.topLeft.x,
        16.0,
        reason: 'DESIGN.md 要求 card radius 16',
      );
    });

    test('Title 1 (headlineMedium) 字号 28 / Fraunces', () {
      final style = theme.textTheme.headlineMedium;
      expect(style?.fontSize, 28);
      expect(style?.fontFamily, 'Fraunces');
    });

    test('Title 2 (headlineSmall) 字号 24 / Fraunces', () {
      final style = theme.textTheme.headlineSmall;
      expect(style?.fontSize, 24);
      expect(style?.fontFamily, 'Fraunces');
    });

    test('额外 TextStyles: title1Style / title2Style / monoStyle 存在', () {
      expect(AppTheme.title1Style.fontSize, 28);
      expect(AppTheme.title2Style.fontSize, 24);
      expect(AppTheme.monoStyle.fontFamily, 'JetBrains Mono');
    });

    test('warmShadowSm 匹配 DESIGN.md: offset(0,1) blur 3', () {
      final shadow = AppTheme.warmShadowSm.first;
      expect(shadow.offset, const Offset(0, 1));
      expect(shadow.blurRadius, 3);
    });

    test('warmShadowMd 匹配 DESIGN.md: offset(0,2) blur 12', () {
      final shadow = AppTheme.warmShadowMd.first;
      expect(shadow.offset, const Offset(0, 2));
      expect(shadow.blurRadius, 12);
    });

    test('warmShadowLg 匹配 DESIGN.md: offset(0,8) blur 24', () {
      final shadow = AppTheme.warmShadowLg.first;
      expect(shadow.offset, const Offset(0, 8));
      expect(shadow.blurRadius, 24);
    });
  });

  group('AppTheme.buildDark() — dark theme', () {
    late ThemeData darkTheme;
    late BabyTalkColors darkColors;

    setUp(() {
      darkTheme = AppTheme.buildDark();
      darkColors = darkTheme.extension<BabyTalkColors>()!;
    });

    test('亮度为 Brightness.dark', () {
      expect(darkTheme.brightness, Brightness.dark);
    });

    test('包含 BabyTalkColors extension', () {
      expect(
        darkTheme.extension<BabyTalkColors>(),
        isNotNull,
        reason: 'dark ThemeData 必须携带 BabyTalkColors',
      );
    });

    test('bgBase = #1C1816', () {
      expect(darkColors.bgBase, const Color(0xFF1C1816));
    });

    test('bgSurface = #2A2420', () {
      expect(darkColors.bgSurface, const Color(0xFF2A2420));
    });

    test('accent = #FF9E5C (brightened for dark)', () {
      expect(darkColors.accent, const Color(0xFFFF9E5C));
    });

    test('english = #5AAFA0 (brightened for dark)', () {
      expect(darkColors.english, const Color(0xFF5AAFA0));
    });

    test('textPrimary = #F5F0EB (light text on dark bg)', () {
      expect(darkColors.textPrimary, const Color(0xFFF5F0EB));
    });

    test('outlineSoft = #3D3630', () {
      expect(darkColors.outlineSoft, const Color(0xFF3D3630));
    });

    test('dark card radius 为 16', () {
      final cardShape = darkTheme.cardTheme.shape as RoundedRectangleBorder;
      final borderRadius = cardShape.borderRadius as BorderRadius;
      expect(
        borderRadius.topLeft.x,
        16.0,
        reason: 'DESIGN.md 要求 card radius 16，dark mode 同',
      );
    });

    test('dark warmShadowSm 使用纯黑透明度', () {
      final shadow = darkColors.warmShadowSm.first;
      expect(shadow.offset, const Offset(0, 1));
      expect(shadow.blurRadius, 3);
      // dark 模式阴影颜色应为纯黑透明度而非暖色调
      expect((shadow.color.a * 255).round(), lessThan(40));
    });
  });

  group('BabyTalkColors factory', () {
    test('light() 所有字段非空', () {
      final colors = BabyTalkColors.light();
      expect(colors.bgBase, isNotNull);
      expect(colors.accent, isNotNull);
      expect(colors.warmShadowSm, isNotEmpty);
      expect(colors.warmShadowMd, isNotEmpty);
      expect(colors.warmShadowLg, isNotEmpty);
    });

    test('dark() 所有字段非空', () {
      final colors = BabyTalkColors.dark();
      expect(colors.bgBase, isNotNull);
      expect(colors.accent, isNotNull);
      expect(colors.warmShadowSm, isNotEmpty);
      expect(colors.warmShadowMd, isNotEmpty);
      expect(colors.warmShadowLg, isNotEmpty);
    });

    test('copyWith 可以覆盖单一属性', () {
      final original = BabyTalkColors.light();
      final modified = original.copyWith(accent: Colors.red);
      expect(modified.accent, Colors.red);
      expect(modified.bgBase, original.bgBase);
    });

    test('lerp 在 t=0 和 t=1 之间正确插值', () {
      final light = BabyTalkColors.light();
      final dark = BabyTalkColors.dark();
      final half = light.lerp(dark, 0.5);
      // lerp(0.5) 产生的颜色应不等于两端
      expect(half.bgBase, isNot(equals(light.bgBase)));
      expect(half.bgBase, isNot(equals(dark.bgBase)));
    });
  });
}
