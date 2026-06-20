/// One immediately speakable caregiver line realized from the current strategy.
final class Utterance {
  Utterance({
    required this.primary,
    required this.zhHelper,
    required this.tone,
    required this.clarityLevel,
    required this.contextFit,
    required List<String> alternatives,
  }) : assert(primary != ''),
       alternatives = List.unmodifiable(alternatives);

  final String primary;
  final String zhHelper;
  final String tone;
  final String clarityLevel;
  final String contextFit;
  final List<String> alternatives;
}
