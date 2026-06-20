enum PressurePolicy {
  lowPressure('low_pressure'),
  neutral('neutral'),
  structuredGuidance('structured_guidance');

  const PressurePolicy(this.wireName);

  final String wireName;
}

enum StrategyModifier {
  continueInteraction('continue'),
  simplify('simplify'),
  redirect('redirect'),
  pause('pause'),
  reduceOptions('reduce_options'),
  maintain('maintain'),
  increaseClarity('increase_clarity');

  const StrategyModifier(this.wireName);

  final String wireName;
}

/// Language policy for the current interaction, never a description of a child.
final class StrategyDecision {
  StrategyDecision({
    required this.primary,
    required List<StrategyModifier> modifiers,
    required this.confidence,
    required this.rationale,
    required this.pressureLevel,
    required this.recommendedTone,
    required this.interactionHint,
  }) : modifiers = List.unmodifiable(modifiers);

  final PressurePolicy primary;
  final List<StrategyModifier> modifiers;
  final double confidence;
  final String rationale;
  final int pressureLevel;
  final String recommendedTone;
  final String interactionHint;
}
