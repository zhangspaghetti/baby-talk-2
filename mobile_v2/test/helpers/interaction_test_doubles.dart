import 'package:mobile_v2/features/ritual_room/data/datasources/interaction_api.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/interaction_advance_request.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/interaction_result_response.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/interaction_snapshot_response.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/interaction_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/interaction_engine_port.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/normalize_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/state_accumulator.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/strategy_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/utterance_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_clock.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_id_generator.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_store.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_seed_source.dart';

import '../fixtures/interaction_test_fixtures.dart';

final class FakeInteractionEnginePort implements InteractionEnginePort {
  FakeInteractionEnginePort({required this.advanceResult, this.snapshot});

  AdvanceResult advanceResult;
  ProductSnapshot? snapshot;
  var advanceCalls = 0;
  var snapshotCalls = 0;
  String? lastInteractionId;
  int? lastExpectedRevision;
  InputEvent? lastInput;

  @override
  Future<ProductSnapshot?> getSnapshot(String interactionId) async {
    snapshotCalls += 1;
    lastInteractionId = interactionId;
    return snapshot;
  }

  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) async {
    advanceCalls += 1;
    lastInteractionId = interactionId;
    lastExpectedRevision = expectedRevision;
    lastInput = input;
    return advanceResult;
  }
}

final class FakeInteractionApi implements InteractionApi {
  FakeInteractionApi({
    required this.advanceResponse,
    required this.snapshotResponse,
  });

  InteractionResultResponse advanceResponse;
  InteractionSnapshotResponse snapshotResponse;
  var advanceCalls = 0;
  var snapshotCalls = 0;
  String? lastInteractionId;
  InteractionAdvanceRequest? lastRequest;

  @override
  Future<InteractionSnapshotResponse> getSnapshot(String interactionId) async {
    snapshotCalls += 1;
    lastInteractionId = interactionId;
    return snapshotResponse;
  }

  @override
  Future<InteractionResultResponse> advance({
    required String interactionId,
    required InteractionAdvanceRequest request,
  }) async {
    advanceCalls += 1;
    lastInteractionId = interactionId;
    lastRequest = request;
    return advanceResponse;
  }
}

final class InteractionEngineHarness {
  InteractionEngineHarness()
    : store = InMemoryInteractionRuntimeStore(),
      clock = _FixedClock(),
      ids = _FixedIdGenerator(),
      seed = _FixedSeedSource() {
    engine = InteractionEngine(
      clock: clock,
      idGenerator: ids,
      seedSource: seed,
      store: store,
      normalizeEngine: RuleBasedNormalizeEngine(),
      stateAccumulator: DecayStateAccumulator(),
      strategyEngine: RuleBasedStrategyEngine(),
      utteranceEngine: RuleBasedUtteranceEngine(),
    );
  }

  final InMemoryInteractionRuntimeStore store;
  final _FixedClock clock;
  final _FixedIdGenerator ids;
  final _FixedSeedSource seed;
  late final InteractionEngine engine;
}

final class _FixedClock implements InteractionClock {
  var calls = 0;

  @override
  DateTime now() => DateTime.utc(2026, 6, 20, 10, calls++);
}

final class _FixedIdGenerator implements InteractionIdGenerator {
  @override
  String generate() => interactionId;
}

final class _FixedSeedSource implements InteractionSeedSource {
  @override
  Future<InteractionSeed> load(String ritualRoomId) async => InteractionSeed(
    anchor: 'Shoes on.',
    normalizedContext: interactionNormalizedInput('shared_action'),
    memory: interactionMemory('shared_action'),
    strategy: interactionStrategy(),
    utterance: interactionUtterance(),
  );
}
