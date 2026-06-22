import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/theme/baby_talk_theme.dart';
import 'package:mobile_v2/app/theme/ritual_room_theme.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_atmosphere_tone.dart';

void main() {
  group('RitualRoomTheme', () {
    test('defines the exact light core tokens', () {
      expect(RitualRoomTheme.light.canvas, const Color(0xFFFBF6EF));
      expect(RitualRoomTheme.light.lightField, const Color(0xFFFFFDF9));
      expect(RitualRoomTheme.light.textPrimary, const Color(0xFF302A26));
      expect(RitualRoomTheme.light.textSecondary, const Color(0xFF6D625B));
      expect(RitualRoomTheme.light.textMuted, const Color(0xFF756A63));
      expect(RitualRoomTheme.light.assistive, const Color(0xFF3F746B));
      expect(RitualRoomTheme.light.assistiveSurface, const Color(0xFFE4F0EC));
      expect(RitualRoomTheme.light.warmAccent, const Color(0xFFB9653B));
      expect(RitualRoomTheme.light.divider, const Color(0xFFE2D9D1));
    });

    test('selects the exact palette for every atmosphere tone', () {
      expect(
        RitualRoomTheme.light.paletteFor(RitualAtmosphereTone.everydayCalm),
        const RitualAtmospherePalette(
          canvas: Color(0xFFFBF6EF),
          lightField: Color(0xFFFFFDF9),
        ),
      );
      expect(
        RitualRoomTheme.light.paletteFor(RitualAtmosphereTone.gentlyLively),
        const RitualAtmospherePalette(
          canvas: Color(0xFFFCF5E8),
          lightField: Color(0xFFFFFDF8),
        ),
      );
      expect(
        RitualRoomTheme.light.paletteFor(RitualAtmosphereTone.groundedSoothing),
        const RitualAtmospherePalette(
          canvas: Color(0xFFF7F2EC),
          lightField: Color(0xFFFCFAF6),
        ),
      );
      expect(
        RitualRoomTheme.light.paletteFor(RitualAtmosphereTone.bedtimeQuiet),
        const RitualAtmospherePalette(
          canvas: Color(0xFFF6EFE8),
          lightField: Color(0xFFFCF8F3),
        ),
      );
    });

    test('copyWith replaces every field', () {
      const replacement = RitualRoomTheme(
        canvas: Color(0xFF000001),
        lightField: Color(0xFF000002),
        textPrimary: Color(0xFF000003),
        textSecondary: Color(0xFF000004),
        textMuted: Color(0xFF000005),
        assistive: Color(0xFF000006),
        assistiveSurface: Color(0xFF000007),
        warmAccent: Color(0xFF000008),
        divider: Color(0xFF000009),
      );

      final copied = RitualRoomTheme.light.copyWith(
        canvas: replacement.canvas,
        lightField: replacement.lightField,
        textPrimary: replacement.textPrimary,
        textSecondary: replacement.textSecondary,
        textMuted: replacement.textMuted,
        assistive: replacement.assistive,
        assistiveSurface: replacement.assistiveSurface,
        warmAccent: replacement.warmAccent,
        divider: replacement.divider,
      );

      _expectThemeFields(copied, replacement);
      _expectThemeFields(
        RitualRoomTheme.light.copyWith(),
        RitualRoomTheme.light,
      );
    });

    test('lerp interpolates every field', () {
      const target = RitualRoomTheme(
        canvas: Color(0xFFFFFFFF),
        lightField: Color(0xFFEEEEEE),
        textPrimary: Color(0xFFDDDDDD),
        textSecondary: Color(0xFFCCCCCC),
        textMuted: Color(0xFFBBBBBB),
        assistive: Color(0xFFAAAAAA),
        assistiveSurface: Color(0xFF999999),
        warmAccent: Color(0xFF888888),
        divider: Color(0xFF777777),
      );

      final midpoint = RitualRoomTheme.light.lerp(target, 0.5);

      expect(
        midpoint.canvas,
        Color.lerp(RitualRoomTheme.light.canvas, target.canvas, 0.5),
      );
      expect(
        midpoint.lightField,
        Color.lerp(RitualRoomTheme.light.lightField, target.lightField, 0.5),
      );
      expect(
        midpoint.textPrimary,
        Color.lerp(RitualRoomTheme.light.textPrimary, target.textPrimary, 0.5),
      );
      expect(
        midpoint.textSecondary,
        Color.lerp(
          RitualRoomTheme.light.textSecondary,
          target.textSecondary,
          0.5,
        ),
      );
      expect(
        midpoint.textMuted,
        Color.lerp(RitualRoomTheme.light.textMuted, target.textMuted, 0.5),
      );
      expect(
        midpoint.assistive,
        Color.lerp(RitualRoomTheme.light.assistive, target.assistive, 0.5),
      );
      expect(
        midpoint.assistiveSurface,
        Color.lerp(
          RitualRoomTheme.light.assistiveSurface,
          target.assistiveSurface,
          0.5,
        ),
      );
      expect(
        midpoint.warmAccent,
        Color.lerp(RitualRoomTheme.light.warmAccent, target.warmAccent, 0.5),
      );
      expect(
        midpoint.divider,
        Color.lerp(RitualRoomTheme.light.divider, target.divider, 0.5),
      );
    });

    test('is registered on the light app theme', () {
      expect(
        BabyTalkTheme.light.extension<RitualRoomTheme>(),
        same(RitualRoomTheme.light),
      );
    });

    test('configures the required system-font typography roles', () {
      final textTheme = BabyTalkTheme.light.textTheme;

      _expectTextStyle(
        textTheme.displaySmall,
        color: RitualRoomTheme.light.textPrimary,
        fontSize: 36,
        height: 1.25,
        fontWeight: FontWeight.w600,
      );
      _expectTextStyle(
        textTheme.bodyLarge,
        color: RitualRoomTheme.light.textSecondary,
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w400,
      );
      _expectTextStyle(
        textTheme.labelLarge,
        color: RitualRoomTheme.light.textMuted,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
      );
      final themeSource = File(
        'lib/app/theme/baby_talk_theme.dart',
      ).readAsStringSync();
      expect(themeSource, isNot(contains('GoogleFonts')));
      expect(themeSource, isNot(contains('fontFamily:')));
    });
  });
}

void _expectThemeFields(RitualRoomTheme actual, RitualRoomTheme expected) {
  expect(actual.canvas, expected.canvas);
  expect(actual.lightField, expected.lightField);
  expect(actual.textPrimary, expected.textPrimary);
  expect(actual.textSecondary, expected.textSecondary);
  expect(actual.textMuted, expected.textMuted);
  expect(actual.assistive, expected.assistive);
  expect(actual.assistiveSurface, expected.assistiveSurface);
  expect(actual.warmAccent, expected.warmAccent);
  expect(actual.divider, expected.divider);
}

void _expectTextStyle(
  TextStyle? actual, {
  required Color color,
  required double fontSize,
  required double height,
  required FontWeight fontWeight,
}) {
  expect(actual?.color, color);
  expect(actual?.fontSize, fontSize);
  expect(actual?.height, height);
  expect(actual?.fontWeight, fontWeight);
}
