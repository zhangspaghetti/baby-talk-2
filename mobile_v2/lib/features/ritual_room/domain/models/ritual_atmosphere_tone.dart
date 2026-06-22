enum RitualAtmosphereTone {
  everydayCalm('everyday_calm'),
  gentlyLively('gently_lively'),
  groundedSoothing('grounded_soothing'),
  bedtimeQuiet('bedtime_quiet');

  const RitualAtmosphereTone(this.wireName);

  final String wireName;

  static RitualAtmosphereTone fromWireName(String value) =>
      RitualAtmosphereTone.values.firstWhere(
        (tone) => tone.wireName == value,
        orElse: () =>
            throw FormatException('Unsupported ritual atmosphere tone: $value'),
      );
}
