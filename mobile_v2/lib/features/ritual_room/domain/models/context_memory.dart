import 'dart:collection';

/// Compressed interaction-local memory. It never stores verbatim observations.
final class ContextMemory {
  ContextMemory({
    required this.summary,
    required List<String> eventLog,
    required Map<String, double> signalWeights,
    required this.interactionTrend,
    required this.contextStability,
    required this.narrative,
  }) : eventLog = List.unmodifiable(eventLog),
       signalWeights = UnmodifiableMapView(Map.of(signalWeights));

  final String summary;
  final List<String> eventLog;
  final Map<String, double> signalWeights;
  final String interactionTrend;
  final double contextStability;
  final String narrative;
}
