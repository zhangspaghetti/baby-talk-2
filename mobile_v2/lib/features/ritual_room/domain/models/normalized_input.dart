import 'dart:collection';

/// Irreversible, non-verbatim semantic form of one raw input event.
final class NormalizedInput {
  NormalizedInput({
    required List<String> semanticSignals,
    required this.intentEstimate,
    required this.momentHypothesis,
    required Map<String, String> contextFrame,
    required this.confidence,
    required this.eventSummary,
  }) : semanticSignals = List.unmodifiable(semanticSignals),
       contextFrame = UnmodifiableMapView(Map.of(contextFrame));

  final List<String> semanticSignals;
  final String intentEstimate;
  final String momentHypothesis;
  final Map<String, String> contextFrame;
  final double confidence;
  final String eventSummary;
}
