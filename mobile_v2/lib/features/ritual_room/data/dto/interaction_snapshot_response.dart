import 'dart:collection';

import '../../domain/models/product_snapshot.dart';

final class UnsupportedInteractionSchemaException implements Exception {
  const UnsupportedInteractionSchemaException(this.schemaVersion);

  final int schemaVersion;

  @override
  String toString() => 'Unsupported interaction schema version: $schemaVersion';
}

/// Schema-versioned transport projection of current product truth.
final class InteractionSnapshotResponse {
  const InteractionSnapshotResponse({
    required this.schemaVersion,
    required this.revision,
    required this.interactionId,
    required this.ritualRoomId,
    required this.anchor,
    required this.normalizedContext,
    required this.memory,
    required this.strategy,
    required this.utterance,
    required this.metadata,
  });

  factory InteractionSnapshotResponse.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredNonNegativeInt(json, 'schemaVersion');
    if (schemaVersion != ProductSnapshot.currentSchemaVersion) {
      throw UnsupportedInteractionSchemaException(schemaVersion);
    }
    return InteractionSnapshotResponse(
      schemaVersion: schemaVersion,
      revision: _requiredNonNegativeInt(json, 'revision'),
      interactionId: _requiredString(json, 'interactionId'),
      ritualRoomId: _requiredString(json, 'ritualRoomId'),
      anchor: _requiredString(json, 'anchor'),
      normalizedContext: InteractionNormalizedContextResponse.fromJson(
        _requiredMap(json, 'normalizedContext'),
      ),
      memory: InteractionMemoryResponse.fromJson(_requiredMap(json, 'memory')),
      strategy: InteractionStrategyResponse.fromJson(
        _requiredMap(json, 'strategy'),
      ),
      utterance: InteractionUtteranceResponse.fromJson(
        _requiredMap(json, 'utterance'),
      ),
      metadata: InteractionSnapshotMetadataResponse.fromJson(
        _requiredMap(json, 'metadata'),
      ),
    );
  }

  final int schemaVersion;
  final int revision;
  final String interactionId;
  final String ritualRoomId;
  final String anchor;
  final InteractionNormalizedContextResponse normalizedContext;
  final InteractionMemoryResponse memory;
  final InteractionStrategyResponse strategy;
  final InteractionUtteranceResponse utterance;
  final InteractionSnapshotMetadataResponse metadata;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'revision': revision,
    'interactionId': interactionId,
    'ritualRoomId': ritualRoomId,
    'anchor': anchor,
    'normalizedContext': normalizedContext.toJson(),
    'memory': memory.toJson(),
    'strategy': strategy.toJson(),
    'utterance': utterance.toJson(),
    'metadata': metadata.toJson(),
  };
}

final class InteractionNormalizedContextResponse {
  InteractionNormalizedContextResponse({
    required List<String> semanticSignals,
    required this.intentEstimate,
    required this.momentHypothesis,
    required Map<String, String> contextFrame,
    required this.confidence,
    required this.eventSummary,
  }) : semanticSignals = List.unmodifiable(semanticSignals),
       contextFrame = UnmodifiableMapView(Map.of(contextFrame));

  factory InteractionNormalizedContextResponse.fromJson(
    Map<String, Object?> json,
  ) => InteractionNormalizedContextResponse(
    semanticSignals: _requiredStringList(json, 'semanticSignals'),
    intentEstimate: _requiredString(json, 'intentEstimate'),
    momentHypothesis: _requiredString(json, 'momentHypothesis'),
    contextFrame: _requiredStringMap(json, 'contextFrame'),
    confidence: _requiredDouble(json, 'confidence'),
    eventSummary: _requiredString(json, 'eventSummary'),
  );

  final List<String> semanticSignals;
  final String intentEstimate;
  final String momentHypothesis;
  final Map<String, String> contextFrame;
  final double confidence;
  final String eventSummary;

  Map<String, Object?> toJson() => {
    'semanticSignals': semanticSignals,
    'intentEstimate': intentEstimate,
    'momentHypothesis': momentHypothesis,
    'contextFrame': contextFrame,
    'confidence': confidence,
    'eventSummary': eventSummary,
  };
}

final class InteractionMemoryResponse {
  InteractionMemoryResponse({
    required this.summary,
    required List<String> eventLog,
    required Map<String, double> signalWeights,
    required this.interactionTrend,
    required this.contextStability,
    required this.narrative,
  }) : eventLog = List.unmodifiable(eventLog),
       signalWeights = UnmodifiableMapView(Map.of(signalWeights));

  factory InteractionMemoryResponse.fromJson(Map<String, Object?> json) =>
      InteractionMemoryResponse(
        summary: _requiredString(json, 'summary'),
        eventLog: _requiredStringList(json, 'eventLog'),
        signalWeights: _requiredDoubleMap(json, 'signalWeights'),
        interactionTrend: _requiredString(json, 'interactionTrend'),
        contextStability: _requiredDouble(json, 'contextStability'),
        narrative: _requiredString(json, 'narrative'),
      );

  final String summary;
  final List<String> eventLog;
  final Map<String, double> signalWeights;
  final String interactionTrend;
  final double contextStability;
  final String narrative;

  Map<String, Object?> toJson() => {
    'summary': summary,
    'eventLog': eventLog,
    'signalWeights': signalWeights,
    'interactionTrend': interactionTrend,
    'contextStability': contextStability,
    'narrative': narrative,
  };
}

final class InteractionStrategyResponse {
  InteractionStrategyResponse({
    required this.primary,
    required List<String> modifiers,
    required this.confidence,
    required this.rationale,
    required this.pressureLevel,
    required this.recommendedTone,
    required this.interactionHint,
  }) : modifiers = List.unmodifiable(modifiers);

  factory InteractionStrategyResponse.fromJson(Map<String, Object?> json) =>
      InteractionStrategyResponse(
        primary: _requiredString(json, 'primary'),
        modifiers: _requiredStringList(json, 'modifiers'),
        confidence: _requiredDouble(json, 'confidence'),
        rationale: _requiredString(json, 'rationale'),
        pressureLevel: _requiredNonNegativeInt(json, 'pressureLevel'),
        recommendedTone: _requiredString(json, 'recommendedTone'),
        interactionHint: _requiredString(json, 'interactionHint'),
      );

  final String primary;
  final List<String> modifiers;
  final double confidence;
  final String rationale;
  final int pressureLevel;
  final String recommendedTone;
  final String interactionHint;

  Map<String, Object?> toJson() => {
    'primary': primary,
    'modifiers': modifiers,
    'confidence': confidence,
    'rationale': rationale,
    'pressureLevel': pressureLevel,
    'recommendedTone': recommendedTone,
    'interactionHint': interactionHint,
  };
}

final class InteractionUtteranceResponse {
  InteractionUtteranceResponse({
    required this.primary,
    required this.zhHelper,
    required this.actionCue,
    required this.tone,
    required this.clarityLevel,
    required this.contextFit,
    required List<String> alternatives,
  }) : alternatives = List.unmodifiable(alternatives);

  factory InteractionUtteranceResponse.fromJson(Map<String, Object?> json) =>
      InteractionUtteranceResponse(
        primary: _requiredString(json, 'primary'),
        zhHelper: _requiredString(json, 'zhHelper'),
        actionCue: _requiredString(json, 'actionCue'),
        tone: _requiredString(json, 'tone'),
        clarityLevel: _requiredString(json, 'clarityLevel'),
        contextFit: _requiredString(json, 'contextFit'),
        alternatives: _requiredStringList(json, 'alternatives'),
      );

  final String primary;
  final String zhHelper;
  final String actionCue;
  final String tone;
  final String clarityLevel;
  final String contextFit;
  final List<String> alternatives;

  Map<String, Object?> toJson() => {
    'primary': primary,
    'zhHelper': zhHelper,
    'actionCue': actionCue,
    'tone': tone,
    'clarityLevel': clarityLevel,
    'contextFit': contextFit,
    'alternatives': alternatives,
  };
}

final class InteractionSnapshotMetadataResponse {
  const InteractionSnapshotMetadataResponse({
    required this.lastEventId,
    required this.updatedAt,
  });

  factory InteractionSnapshotMetadataResponse.fromJson(
    Map<String, Object?> json,
  ) => InteractionSnapshotMetadataResponse(
    lastEventId: _optionalString(json, 'lastEventId'),
    updatedAt: _requiredTimestamp(json, 'updatedAt'),
  );

  final String? lastEventId;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'lastEventId': lastEventId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be null or a non-empty string');
  }
  return value;
}

int _requiredNonNegativeInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('$key must be a non-negative integer');
  }
  return value;
}

double _requiredDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('$key must be a finite number');
  }
  return value.toDouble();
}

DateTime _requiredTimestamp(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key must be an ISO-8601 timestamp');
  }
  return parsed.toUtc();
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('$key must be an object');
  }
  return value.map((mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue));
}

List<String> _requiredStringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('$key must be a list');
  }
  return value
      .map((item) {
        if (item is! String || item.trim().isEmpty) {
          throw FormatException('$key must contain non-empty strings');
        }
        return item;
      })
      .toList(growable: false);
}

Map<String, String> _requiredStringMap(Map<String, Object?> json, String key) {
  final value = _requiredMap(json, key);
  return value.map((mapKey, mapValue) {
    if (mapValue is! String || mapValue.trim().isEmpty) {
      throw FormatException('$key values must be non-empty strings');
    }
    return MapEntry(mapKey, mapValue);
  });
}

Map<String, double> _requiredDoubleMap(Map<String, Object?> json, String key) {
  final value = _requiredMap(json, key);
  return value.map((mapKey, mapValue) {
    if (mapValue is! num || !mapValue.isFinite) {
      throw FormatException('$key values must be finite numbers');
    }
    return MapEntry(mapKey, mapValue.toDouble());
  });
}
