import 'package:flutter/material.dart';

import '../../features/ritual_room/domain/models/ritual_atmosphere_tone.dart';

@immutable
final class RitualAtmospherePalette {
  const RitualAtmospherePalette({
    required this.canvas,
    required this.lightField,
  });

  final Color canvas;
  final Color lightField;
}

@immutable
final class RitualRoomTheme extends ThemeExtension<RitualRoomTheme> {
  const RitualRoomTheme({
    required this.canvas,
    required this.lightField,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.assistive,
    required this.assistiveSurface,
    required this.warmAccent,
    required this.divider,
  });

  static const light = RitualRoomTheme(
    canvas: Color(0xFFFBF6EF),
    lightField: Color(0xFFFFFDF9),
    textPrimary: Color(0xFF302A26),
    textSecondary: Color(0xFF6D625B),
    textMuted: Color(0xFF756A63),
    assistive: Color(0xFF3F746B),
    assistiveSurface: Color(0xFFE4F0EC),
    warmAccent: Color(0xFFB9653B),
    divider: Color(0xFFE2D9D1),
  );

  final Color canvas;
  final Color lightField;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color assistive;
  final Color assistiveSurface;
  final Color warmAccent;
  final Color divider;

  RitualAtmospherePalette paletteFor(RitualAtmosphereTone tone) =>
      switch (tone) {
        RitualAtmosphereTone.everydayCalm => const RitualAtmospherePalette(
          canvas: Color(0xFFFBF6EF),
          lightField: Color(0xFFFFFDF9),
        ),
        RitualAtmosphereTone.gentlyLively => const RitualAtmospherePalette(
          canvas: Color(0xFFFCF5E8),
          lightField: Color(0xFFFFFDF8),
        ),
        RitualAtmosphereTone.groundedSoothing => const RitualAtmospherePalette(
          canvas: Color(0xFFF7F2EC),
          lightField: Color(0xFFFCFAF6),
        ),
        RitualAtmosphereTone.bedtimeQuiet => const RitualAtmospherePalette(
          canvas: Color(0xFFF6EFE8),
          lightField: Color(0xFFFCF8F3),
        ),
      };

  @override
  RitualRoomTheme copyWith({
    Color? canvas,
    Color? lightField,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? assistive,
    Color? assistiveSurface,
    Color? warmAccent,
    Color? divider,
  }) => RitualRoomTheme(
    canvas: canvas ?? this.canvas,
    lightField: lightField ?? this.lightField,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    assistive: assistive ?? this.assistive,
    assistiveSurface: assistiveSurface ?? this.assistiveSurface,
    warmAccent: warmAccent ?? this.warmAccent,
    divider: divider ?? this.divider,
  );

  @override
  RitualRoomTheme lerp(covariant RitualRoomTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return RitualRoomTheme(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      lightField: Color.lerp(lightField, other.lightField, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      assistive: Color.lerp(assistive, other.assistive, t)!,
      assistiveSurface: Color.lerp(
        assistiveSurface,
        other.assistiveSurface,
        t,
      )!,
      warmAccent: Color.lerp(warmAccent, other.warmAccent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
