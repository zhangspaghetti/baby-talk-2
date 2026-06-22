import '../../domain/models/advance_result.dart';
import '../../domain/models/active_utterance.dart';
import '../../domain/models/context_memory.dart';
import '../../domain/models/input_event.dart';
import '../../domain/models/normalized_input.dart';
import '../../domain/models/product_snapshot.dart';
import '../../domain/models/strategy_decision.dart';
import '../dto/interaction_input_dto.dart';
import '../dto/interaction_result_response.dart';
import '../dto/interaction_snapshot_response.dart';

final class UnsupportedInteractionSchemaException implements Exception {
  const UnsupportedInteractionSchemaException(this.schemaVersion);

  final int schemaVersion;

  @override
  String toString() => 'Unsupported interaction schema version: $schemaVersion';
}

/// Strict conversion boundary between stable transport names and domain values.
final class InteractionMapper {
  const InteractionMapper();

  InteractionInputDto inputFromDomain(InputEvent input) {
    final payload = switch (input.payload) {
      ReactionSelectionPayload(:final selected) => <String, Object?>{
        'selected': selected,
      },
      VoiceObservationPayload(:final transcript) => <String, Object?>{
        'transcript': transcript,
      },
      FreeTextPayload(:final text) => <String, Object?>{'text': text},
      FutureSignalPayload(:final signal, :final value) => <String, Object?>{
        'signal': signal,
        'value': value,
      },
      StrategyPreferencePayload(:final preference) => <String, Object?>{
        'preference': preference,
      },
    };
    return InteractionInputDto(
      eventId: input.eventId,
      type: input.type.wireName,
      timestamp: input.occurredAt,
      payload: payload,
    );
  }

  InputEvent inputToDomain(InteractionInputDto input) {
    return switch (input.type) {
      'reaction_selection' => InputEvent.reactionSelection(
        eventId: input.eventId,
        occurredAt: input.timestamp,
        selected: _payloadString(input, 'selected'),
      ),
      'voice_observation' => InputEvent.voiceObservation(
        eventId: input.eventId,
        occurredAt: input.timestamp,
        transcript: _payloadString(input, 'transcript'),
      ),
      'free_text' => InputEvent.freeText(
        eventId: input.eventId,
        occurredAt: input.timestamp,
        text: _payloadString(input, 'text'),
      ),
      'future_signal' => InputEvent.futureSignal(
        eventId: input.eventId,
        occurredAt: input.timestamp,
        signal: _payloadString(input, 'signal'),
        value: _payloadString(input, 'value'),
      ),
      'strategy_preference' => InputEvent.strategyPreference(
        eventId: input.eventId,
        occurredAt: input.timestamp,
        preference: _payloadString(input, 'preference'),
      ),
      _ => throw FormatException('unsupported input type: ${input.type}'),
    };
  }

  InteractionSnapshotResponse snapshotFromDomain(ProductSnapshot snapshot) {
    return InteractionSnapshotResponse(
      schemaVersion: snapshot.schemaVersion,
      revision: snapshot.revision,
      interactionId: snapshot.interactionId,
      ritualRoomId: snapshot.ritualRoomId,
      anchor: snapshot.anchor,
      normalizedContext: InteractionNormalizedContextResponse(
        semanticSignals: snapshot.normalizedContext.semanticSignals,
        intentEstimate: snapshot.normalizedContext.intentEstimate,
        momentHypothesis: snapshot.normalizedContext.momentHypothesis,
        contextFrame: snapshot.normalizedContext.contextFrame,
        confidence: snapshot.normalizedContext.confidence,
        eventSummary: snapshot.normalizedContext.eventSummary,
      ),
      memory: InteractionMemoryResponse(
        summary: snapshot.memory.summary,
        eventLog: snapshot.memory.eventLog,
        signalWeights: snapshot.memory.signalWeights,
        interactionTrend: snapshot.memory.interactionTrend,
        contextStability: snapshot.memory.contextStability,
        narrative: snapshot.memory.narrative,
      ),
      strategy: InteractionStrategyResponse(
        primary: snapshot.strategy.primary.wireName,
        modifiers: snapshot.strategy.modifiers
            .map((modifier) => modifier.wireName)
            .toList(growable: false),
        confidence: snapshot.strategy.confidence,
        rationale: snapshot.strategy.rationale,
        pressureLevel: snapshot.strategy.pressureLevel,
        recommendedTone: snapshot.strategy.recommendedTone,
        interactionHint: snapshot.strategy.interactionHint,
      ),
      utterance: InteractionUtteranceResponse(
        primary: snapshot.activeUtterance.primary,
        zhHelper: snapshot.activeUtterance.zhSupport,
        tone: snapshot.strategy.recommendedTone,
        clarityLevel: snapshot.activeUtterance.displayId,
        contextFit: snapshot.activeUtterance.contextLabel ?? snapshot.anchor,
        alternatives: [
          snapshot.activeUtterance.audioAssetId,
          if (snapshot.activeUtterance.gentleSupport != null)
            snapshot.activeUtterance.gentleSupport!,
        ],
      ),
      metadata: InteractionSnapshotMetadataResponse(
        lastEventId: snapshot.metadata.lastEventId,
        updatedAt: snapshot.metadata.updatedAt,
      ),
    );
  }

  ProductSnapshot snapshotToDomain(InteractionSnapshotResponse response) {
    if (response.schemaVersion != ProductSnapshot.currentSchemaVersion) {
      throw UnsupportedInteractionSchemaException(response.schemaVersion);
    }
    return ProductSnapshot(
      schemaVersion: response.schemaVersion,
      revision: response.revision,
      interactionId: response.interactionId,
      ritualRoomId: response.ritualRoomId,
      anchor: response.anchor,
      normalizedContext: NormalizedInput(
        semanticSignals: response.normalizedContext.semanticSignals,
        intentEstimate: response.normalizedContext.intentEstimate,
        momentHypothesis: response.normalizedContext.momentHypothesis,
        contextFrame: response.normalizedContext.contextFrame,
        confidence: response.normalizedContext.confidence,
        eventSummary: response.normalizedContext.eventSummary,
      ),
      memory: ContextMemory(
        summary: response.memory.summary,
        eventLog: response.memory.eventLog,
        signalWeights: response.memory.signalWeights,
        interactionTrend: response.memory.interactionTrend,
        contextStability: response.memory.contextStability,
        narrative: response.memory.narrative,
      ),
      strategy: StrategyDecision(
        primary: _pressurePolicy(response.strategy.primary),
        modifiers: response.strategy.modifiers
            .map(_strategyModifier)
            .toList(growable: false),
        confidence: response.strategy.confidence,
        rationale: response.strategy.rationale,
        pressureLevel: response.strategy.pressureLevel,
        recommendedTone: response.strategy.recommendedTone,
        interactionHint: response.strategy.interactionHint,
      ),
      activeUtterance: ActiveUtterance(
        displayId: response.utterance.clarityLevel,
        primary: response.utterance.primary,
        zhSupport: response.utterance.zhHelper,
        audioAssetId: response.utterance.alternatives.isEmpty
            ? 'transport_audio_unavailable'
            : response.utterance.alternatives.first,
        contextLabel: response.utterance.contextFit,
        gentleSupport: response.utterance.alternatives.length < 2
            ? null
            : response.utterance.alternatives[1],
      ),
      metadata: ProductSnapshotMetadata(
        lastEventId: response.metadata.lastEventId,
        updatedAt: response.metadata.updatedAt,
      ),
    );
  }

  InteractionResultResponse resultFromDomain(AdvanceResult result) {
    if (result case AdvanceRejected(:final code, latestSnapshot: null)
        when code == AdvanceErrorCode.revisionConflict ||
            code == AdvanceErrorCode.eventIdConflict) {
      throw FormatException('${code.wireName} requires latestSnapshot');
    }
    return switch (result) {
      AdvanceApplied(:final snapshot) => InteractionResultResponse(
        status: AdvanceStatus.applied.wireName,
        snapshot: snapshotFromDomain(snapshot),
      ),
      AdvanceDuplicateIgnored(:final snapshot) => InteractionResultResponse(
        status: AdvanceStatus.duplicateIgnored.wireName,
        snapshot: snapshotFromDomain(snapshot),
      ),
      AdvanceRejected(:final code, :final latestSnapshot) =>
        InteractionResultResponse(
          status: AdvanceStatus.rejected.wireName,
          error: code.wireName,
          latestSnapshot: latestSnapshot == null
              ? null
              : snapshotFromDomain(latestSnapshot),
        ),
    };
  }

  AdvanceResult resultToDomain(InteractionResultResponse response) {
    return switch (response.status) {
      'applied' => AdvanceApplied(
        snapshotToDomain(_requiredSnapshot(response.snapshot, 'snapshot')),
      ),
      'duplicate_ignored' => AdvanceDuplicateIgnored(
        snapshotToDomain(_requiredSnapshot(response.snapshot, 'snapshot')),
      ),
      'rejected' => _rejectedToDomain(response),
      _ => throw FormatException(
        'unsupported result status: ${response.status}',
      ),
    };
  }

  AdvanceRejected _rejectedToDomain(InteractionResultResponse response) {
    final code = _advanceErrorCode(response.error);
    if (code == AdvanceErrorCode.unsupportedSchemaVersion) {
      return AdvanceRejected(code: code);
    }
    final latestSnapshot = response.latestSnapshot == null
        ? null
        : snapshotToDomain(response.latestSnapshot!);
    if ((code == AdvanceErrorCode.revisionConflict ||
            code == AdvanceErrorCode.eventIdConflict) &&
        latestSnapshot == null) {
      throw FormatException('${code.wireName} requires latestSnapshot');
    }
    return AdvanceRejected(code: code, latestSnapshot: latestSnapshot);
  }
}

String _payloadString(InteractionInputDto input, String key) {
  final value = input.payload[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('${input.type} payload.$key is required');
  }
  return value;
}

InteractionSnapshotResponse _requiredSnapshot(
  InteractionSnapshotResponse? response,
  String key,
) {
  if (response == null) {
    throw FormatException('$key is required');
  }
  return response;
}

PressurePolicy _pressurePolicy(String wireName) => switch (wireName) {
  'low_pressure' => PressurePolicy.lowPressure,
  'neutral' => PressurePolicy.neutral,
  'structured_guidance' => PressurePolicy.structuredGuidance,
  _ => throw FormatException('unsupported pressure policy: $wireName'),
};

StrategyModifier _strategyModifier(String wireName) => switch (wireName) {
  'continue' => StrategyModifier.continueInteraction,
  'simplify' => StrategyModifier.simplify,
  'redirect' => StrategyModifier.redirect,
  'pause' => StrategyModifier.pause,
  'reduce_options' => StrategyModifier.reduceOptions,
  'maintain' => StrategyModifier.maintain,
  'increase_clarity' => StrategyModifier.increaseClarity,
  _ => throw FormatException('unsupported strategy modifier: $wireName'),
};

AdvanceErrorCode _advanceErrorCode(String? wireName) => switch (wireName) {
  'interaction_not_found' => AdvanceErrorCode.interactionNotFound,
  'revision_conflict' => AdvanceErrorCode.revisionConflict,
  'event_id_conflict' => AdvanceErrorCode.eventIdConflict,
  'unsupported_schema_version' => AdvanceErrorCode.unsupportedSchemaVersion,
  'invalid_input' => AdvanceErrorCode.invalidInput,
  'pipeline_failed' => AdvanceErrorCode.pipelineFailed,
  null => throw const FormatException('rejected result requires error'),
  _ => throw FormatException('unsupported result error: $wireName'),
};
