import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/product_snapshot.dart';

abstract interface class StateAccumulator {
  Future<ContextMemory> accumulate({
    required NormalizedInput normalized,
    required ContextMemory previous,
    required ProductSnapshot current,
  });
}

final class DecayStateAccumulator implements StateAccumulator {
  DecayStateAccumulator({this.decay = 0.65})
    : assert(decay >= 0),
      assert(decay <= 1);

  static const int _eventLogLimit = 8;

  final double decay;

  @override
  Future<ContextMemory> accumulate({
    required NormalizedInput normalized,
    required ContextMemory previous,
    required ProductSnapshot current,
  }) async {
    final weights = <String, double>{
      for (final entry in previous.signalWeights.entries)
        entry.key: _clamp(entry.value * decay),
    };
    for (final signal in normalized.semanticSignals) {
      weights[signal] = _clamp((weights[signal] ?? 0) + 1);
    }

    final eventLog = [...previous.eventLog, normalized.eventSummary];
    final boundedLog = eventLog.length <= _eventLogLimit
        ? eventLog
        : eventLog.sublist(eventLog.length - _eventLogLimit);
    final trend = _deriveTrend(weights);
    final leadingSignal = _leadingSignal(weights);

    return ContextMemory(
      summary: normalized.eventSummary,
      eventLog: boundedLog,
      signalWeights: weights,
      interactionTrend: trend,
      contextStability: _deriveStability(weights),
      narrative: _narrative(
        trend: trend,
        anchor: current.anchor,
        leadingSignal: leadingSignal,
      ),
    );
  }

  String _deriveTrend(Map<String, double> weights) {
    final shared = weights['shared_action'] ?? 0;
    final difficult = weights['low_joinability'] ?? 0;
    if (difficult > shared + 0.1) {
      return 'decreasing_joinability';
    }
    if (shared > difficult + 0.1) {
      return 'increasing_joinability';
    }
    return 'uncertain';
  }

  double _deriveStability(Map<String, double> weights) {
    if (weights.isEmpty) {
      return 0;
    }
    final sorted = weights.values.toList()..sort((a, b) => b.compareTo(a));
    final difference = sorted.length == 1
        ? sorted.first
        : sorted.first - sorted[1];
    return _clamp(0.5 + difference / 2);
  }

  String _leadingSignal(Map<String, double> weights) {
    if (weights.isEmpty) {
      return 'uncertain evidence';
    }
    return weights.entries
        .reduce((left, right) {
          return left.value >= right.value ? left : right;
        })
        .key
        .replaceAll('_', ' ');
  }

  String _narrative({
    required String trend,
    required String anchor,
    required String leadingSignal,
  }) {
    return switch (trend) {
      'decreasing_joinability' =>
        'The $anchor routine became harder to enter as $leadingSignal strengthened.',
      'increasing_joinability' =>
        'The $anchor routine became easier to enter as $leadingSignal strengthened.',
      _ => 'The $anchor routine contains mixed current-interaction evidence.',
    };
  }

  double _clamp(double value) => value.clamp(0, 1).toDouble();
}
