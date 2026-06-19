# Interaction Engine v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-Dart, snapshot-driven Interaction Engine v1 authority shell, deterministic pipeline, consistency/replay runtime, transport adapters, repository, and Phase 41 capability projection without implementing Phase 42 LLM or voice acquisition.

**Architecture:** `InteractionEngine` is the only lifecycle and state authority. It serializes each interaction, runs four replaceable modules, and atomically commits `ProductSnapshot + ConsistencyState + ReplayJournal`; API/repository/controller layers only adapt this result. The engine is Flutter-free, the Phase 41 UI mask exposes reaction selection only, and the pending visual prototype gate blocks presentation construction but does not block engine/domain implementation.

**Tech Stack:** Dart 3.11, Flutter test runner, `package:crypto` for canonical SHA-256 fingerprints, immutable hand-written Dart models, existing repository-owned semantic and Activation Governor verifiers.

---

## Scope and execution order

This plan is the implementation authority for the Interaction Engine portion of
Phase 41. Where older `41-02` through `41-05` mechanics describe a stateless
mock response table, a pre-normalized voice input, or a single flattened
`RitualInteractionSnapshot`, this plan and
`41-INTERACTION-ENGINE-CONTRACT.md` control.

The work is split into independently testable slices:

1. contract/model foundation
2. deterministic pipeline modules
3. authority shell, consistency, atomicity, and replay
4. transport adapters and repository
5. controller and capability projection
6. final engine verification and Phase 42 design-only handoff

The visual prototype and static illustration gate applies before adding or
changing Phase 41 presentation widgets. Tasks 1-5 are system work and may
proceed without visual approval. This plan does not implement visual UI.

## File map

```text
mobile_v2/lib/features/ritual_room/
├── domain/
│   ├── engine/
│   │   ├── interaction_engine.dart
│   │   ├── normalize_engine.dart
│   │   ├── state_accumulator.dart
│   │   ├── strategy_engine.dart
│   │   └── utterance_engine.dart
│   ├── models/
│   │   ├── input_event.dart
│   │   ├── normalized_input.dart
│   │   ├── context_memory.dart
│   │   ├── strategy_decision.dart
│   │   ├── utterance.dart
│   │   ├── product_snapshot.dart
│   │   └── advance_result.dart
│   ├── repositories/
│   │   └── interaction_repository.dart
│   └── runtime/
│       ├── interaction_clock.dart
│       ├── interaction_id_generator.dart
│       ├── interaction_session_initializer.dart
│       ├── interaction_seed_source.dart
│       ├── input_fingerprint.dart
│       ├── consistency_state.dart
│       ├── replay_journal.dart
│       ├── interaction_runtime_state.dart
│       └── interaction_runtime_store.dart
├── data/
│   ├── datasources/
│   │   ├── interaction_api.dart
│   │   └── mock_interaction_api.dart
│   ├── dto/
│   │   ├── interaction_advance_request.dart
│   │   ├── interaction_input_dto.dart
│   │   ├── interaction_snapshot_response.dart
│   │   └── interaction_result_response.dart
│   ├── mappers/
│   │   └── interaction_mapper.dart
│   └── repositories/
│       └── interaction_repository_impl.dart
└── presentation/
    ├── capability/
    │   └── interaction_capability_mask.dart
    └── controllers/
        └── ritual_room_controller.dart
```

Tests mirror production ownership under
`mobile_v2/test/features/ritual_room/`.

### Task 1: Align execution authority and add immutable domain contracts

**Files:**

- Modify: `mobile_v2/pubspec.yaml`
- Modify: `mobile_v2/CODING_STANDARDS.md`
- Modify: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-02-PLAN.md`
- Modify: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-VALIDATION.md`
- Create: `mobile_v2/lib/features/ritual_room/domain/models/input_event.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/models/normalized_input.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/models/context_memory.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/models/strategy_decision.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/models/utterance.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/models/product_snapshot.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/models/advance_result.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/models/interaction_contract_test.dart`

- [ ] **Step 1: Update planning and coding authority before runtime code**

Replace the old flattened artifact list with the file map above. State
explicitly:

```text
raw InputEvent -> NormalizeEngine -> StateAccumulator
  -> StrategyEngine -> UtteranceEngine -> atomic runtime commit

ProductSnapshot + ConsistencyState = current runtime truth
ReplayJournal = historical evidence only
```

Change validation language from “normalized voice input enters the API” to
“raw voice/text input is ephemeral and normalized inside the engine.” Preserve
the existing visual gate for presentation tasks only.

- [ ] **Step 2: Add the fingerprint dependency**

Run:

```powershell
cd mobile_v2
flutter pub add crypto:^3.0.7
```

Expected: `mobile_v2/pubspec.yaml` has a direct `crypto` dependency and
dependency resolution succeeds. Do not add Riverpod, Bloc, Freezed, JSON
generation, networking, or persistence packages.

- [ ] **Step 3: Write the failing immutable-contract tests**

Create tests that instantiate all five input variants and a complete revision-0
snapshot:

```dart
test('input event variants retain typed ephemeral payloads', () {
  final events = <InputEvent>[
    InputEvent.reaction(
      eventId: 'reaction-1',
      occurredAt: DateTime.utc(2026, 6, 19),
      selected: 'running_away',
    ),
    InputEvent.voice(
      eventId: 'voice-1',
      occurredAt: DateTime.utc(2026, 6, 19),
      transcript: 'attention moved away from the shoe routine',
    ),
    InputEvent.freeText(
      eventId: 'text-1',
      occurredAt: DateTime.utc(2026, 6, 19),
      text: 'the shared action is hard to enter',
    ),
    InputEvent.futureSignal(
      eventId: 'signal-1',
      occurredAt: DateTime.utc(2026, 6, 19),
      signalType: 'attention_shift',
      value: 'away_from_ritual',
    ),
    InputEvent.strategyPreference(
      eventId: 'strategy-1',
      occurredAt: DateTime.utc(2026, 6, 19),
      primary: 'low_pressure',
      modifiers: const ['simplify'],
    ),
  ];

  expect(events.map((event) => event.type).toSet(), hasLength(5));
});

test('schema version and interaction revision are independent', () {
  final snapshot = ProductSnapshot.initial(
    interactionId: 'interaction-1',
    ritualRoomId: 'shoes_on_room_v1',
    anchor: 'Shoes on.',
    context: InteractionContext.initial(
      actionContext: 'putting shoes on',
    ),
    memory: ContextMemory.empty(),
    strategy: StrategyDecision.initial(),
    utterance: const Utterance(
      primary: "Let's put your shoes on.",
      zhHelper: '穿鞋啦。',
      tone: 'soft',
      clarityLevel: 'high',
      contextFit: 'when the shoe routine begins',
      alternatives: [],
    ),
    updatedAt: DateTime.utc(2026, 6, 19),
  );

  expect(snapshot.schemaVersion, 1);
  expect(snapshot.revision, 0);
});
```

- [ ] **Step 4: Run the model tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/domain/models/interaction_contract_test.dart
```

Expected: FAIL because the domain model files and symbols do not exist.

- [ ] **Step 5: Implement focused immutable models**

Use a typed payload hierarchy while keeping the outer envelope stable:

```dart
enum InputEventType {
  reactionSelection,
  voiceObservation,
  freeText,
  futureSignal,
  strategyPreference,
}

sealed class InputPayload {
  const InputPayload();
  Map<String, Object?> toCanonicalJson();
}

final class InputEvent {
  const InputEvent({
    required this.eventId,
    required this.occurredAt,
    required this.type,
    required this.payload,
  });

  final String eventId;
  final DateTime occurredAt;
  final InputEventType type;
  final InputPayload payload;

  factory InputEvent.reaction({
    required String eventId,
    required DateTime occurredAt,
    required String selected,
  }) = ReactionInputEvent;

  factory InputEvent.voice({
    required String eventId,
    required DateTime occurredAt,
    required String transcript,
  }) = VoiceInputEvent;

  factory InputEvent.freeText({
    required String eventId,
    required DateTime occurredAt,
    required String text,
  }) = FreeTextInputEvent;

  factory InputEvent.futureSignal({
    required String eventId,
    required DateTime occurredAt,
    required String signalType,
    required String value,
  }) = FutureSignalInputEvent;

  factory InputEvent.strategyPreference({
    required String eventId,
    required DateTime occurredAt,
    required String primary,
    required List<String> modifiers,
  }) = StrategyPreferenceInputEvent;

  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'eventId': eventId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'type': type.name,
    'payload': payload.toCanonicalJson(),
  };
}
```

`ProductSnapshot` must be composed from immutable focused values:

```dart
final class ProductSnapshot {
  const ProductSnapshot({
    required this.interactionId,
    required this.ritualRoomId,
    required this.schemaVersion,
    required this.revision,
    required this.anchor,
    required this.context,
    required this.memory,
    required this.strategy,
    required this.utterance,
    required this.meta,
  });

  static const currentSchemaVersion = 1;

  final String interactionId;
  final String ritualRoomId;
  final int schemaVersion;
  final int revision;
  final String anchor;
  final InteractionContext context;
  final ContextMemory memory;
  final StrategyDecision strategy;
  final Utterance utterance;
  final SnapshotMeta meta;
}
```

Implement these named constructors used by tests:

```dart
factory ProductSnapshot.initial({
  required String interactionId,
  required String ritualRoomId,
  required String anchor,
  required InteractionContext context,
  required ContextMemory memory,
  required StrategyDecision strategy,
  required Utterance utterance,
  required DateTime updatedAt,
}) => ProductSnapshot(
  interactionId: interactionId,
  ritualRoomId: ritualRoomId,
  schemaVersion: ProductSnapshot.currentSchemaVersion,
  revision: 0,
  anchor: anchor,
  context: context,
  memory: memory,
  strategy: strategy,
  utterance: utterance,
  meta: SnapshotMeta(lastEventId: null, updatedAt: updatedAt),
);

factory InteractionContext.initial({required String actionContext}) =>
    InteractionContext(
      actionContext: actionContext,
      momentHypothesis: 'the shared action is ready to begin',
      normalizedSignals: const [],
    );

factory ContextMemory.empty() => const ContextMemory(
  eventSummary: '',
  eventLogCompressed: [],
  signalAggregation: {},
  interactionTrend: 'unclear',
  contextStability: 0,
  interactionNarrative: '',
);

factory StrategyDecision.initial() => const StrategyDecision(
  primary: 'neutral',
  modifiers: ['maintain'],
  confidence: 1,
  rationale: 'initial ritual state',
  pressureLevel: 0,
  recommendedTone: 'neutral',
  interactionHint: 'begin with the stable ritual anchor',
);
```

Use `List.unmodifiable` and `Map.unmodifiable` at constructor boundaries. Models
must import only `dart:` libraries or sibling domain files.

- [ ] **Step 6: Add advance result types**

Implement an exhaustive sealed result:

```dart
sealed class AdvanceResult {
  const AdvanceResult();
}

final class Applied extends AdvanceResult {
  const Applied(this.snapshot);
  final ProductSnapshot snapshot;
}

final class DuplicateIgnored extends AdvanceResult {
  const DuplicateIgnored(this.snapshot);
  final ProductSnapshot snapshot;
}

enum AdvanceErrorCode {
  interactionNotFound,
  revisionConflict,
  eventIdConflict,
  unsupportedSchemaVersion,
  invalidInput,
  pipelineFailed,
}

final class AdvanceRejected extends AdvanceResult {
  const AdvanceRejected({
    required this.code,
    this.latestSnapshot,
  });

  final AdvanceErrorCode code;
  final ProductSnapshot? latestSnapshot;
}
```

- [ ] **Step 7: Run focused tests and static import audit**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/domain/models/interaction_contract_test.dart
dart analyze lib/features/ritual_room/domain
```

Expected: PASS with no Flutter import under `domain/`.

- [ ] **Step 8: Commit**

```powershell
git add mobile_v2/pubspec.yaml mobile_v2/pubspec.lock mobile_v2/CODING_STANDARDS.md .planning/phases/41-mobile-v2-runnable-vertical-slice/41-02-PLAN.md .planning/phases/41-mobile-v2-runnable-vertical-slice/41-VALIDATION.md mobile_v2/lib/features/ritual_room/domain mobile_v2/test/features/ritual_room/domain/models
git commit -m "feat(41): add interaction engine domain contracts"
```

### Task 2: Implement deterministic pipeline modules

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/domain/engine/normalize_engine.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/engine/state_accumulator.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/engine/strategy_engine.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/engine/utterance_engine.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/engine/normalize_engine_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/engine/state_accumulator_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/engine/strategy_engine_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/engine/utterance_engine_test.dart`

- [ ] **Step 1: Write RED tests for cross-modal normalization**

Use semantically equivalent reaction, voice, and free-text events:

```dart
test('equivalent modalities produce the same canonical signals', () async {
  final engine = RuleBasedNormalizeEngine();
  final reaction = await engine.normalize(reactionRunningAway);
  final voice = await engine.normalize(voiceRunningAway);
  final text = await engine.normalize(textRunningAway);

  expect(reaction.semanticSignals, containsAll(['avoidance', 'low_joinability']));
  expect(voice.semanticSignals, reaction.semanticSignals);
  expect(text.semanticSignals, reaction.semanticSignals);
  expect(voice.eventSummary, isNot(rawVoiceText));
});
```

Include a strategy-preference test proving it normalizes to an explicit
preference signal without bypassing StrategyEngine.

- [ ] **Step 2: Write RED tests for non-monotonic decay accumulation**

```dart
test('new shared-action evidence can reverse an earlier trend', () {
  final accumulator = DecayStateAccumulator(decay: 0.65);
  final resistant = accumulator.accumulate(
    previous: ContextMemory.empty(),
    input: avoidanceInput,
  );
  final engaged = accumulator.accumulate(
    previous: resistant,
    input: sharedActionInput,
  );

  expect(resistant.interactionTrend, 'decreasing_joinability');
  expect(engaged.interactionTrend, isNot('decreasing_joinability'));
  expect(engaged.signalAggregation['shared_action'], greaterThan(0));
});
```

- [ ] **Step 3: Write RED tests for strategy and utterance separation**

```dart
test('strategy selects policy without producing language', () async {
  final decision = await RuleBasedStrategyEngine().decide(
    normalized: avoidanceInput,
    memory: lowJoinabilityMemory,
    current: initialSnapshot,
  );

  expect(decision.primary, 'low_pressure');
  expect(decision.modifiers, containsAll(['simplify', 'reduce_options']));
});

test('utterance realizes the supplied strategy without changing it', () async {
  const decision = StrategyDecision(
    primary: 'low_pressure',
    modifiers: ['simplify', 'reduce_options'],
    confidence: 0.8,
    rationale: 'current signals indicate low joinability',
    pressureLevel: 25,
    recommendedTone: 'soft',
    interactionHint: 'offer one small shared action',
  );

  final utterance = await RuleBasedUtteranceEngine().realize(
    anchor: 'Shoes on.',
    strategy: decision,
    normalized: avoidanceInput,
    memory: lowJoinabilityMemory,
  );

  expect(utterance.primary, isNotEmpty);
  expect(utterance.alternatives, hasLength(lessThanOrEqualTo(2)));
  expect(decision.primary, 'low_pressure');
});
```

- [ ] **Step 4: Run pipeline tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/domain/engine
```

Expected: FAIL because engine contracts and deterministic implementations do
not exist.

- [ ] **Step 5: Implement async replaceable module contracts**

```dart
abstract interface class NormalizeEngine {
  Future<NormalizedInput> normalize(InputEvent event);
}

abstract interface class StateAccumulator {
  Future<ContextMemory> accumulate({
    required NormalizedInput normalized,
    required ContextMemory previous,
    required ProductSnapshot current,
  });
}

abstract interface class StrategyEngine {
  Future<StrategyDecision> decide({
    required NormalizedInput normalized,
    required ContextMemory memory,
    required ProductSnapshot current,
  });
}

abstract interface class UtteranceEngine {
  Future<Utterance> realize({
    required String anchor,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  });
}
```

Async return types preserve the Phase 42 provider seam. Implementations must not
retain request data or expose mutable collections.

- [ ] **Step 6: Implement deterministic rules**

Use explicit tables for Phase 41:

```dart
const reactionSignals = <String, List<String>>{
  'running_away': ['avoidance', 'low_joinability'],
  'not_ready': ['resistance', 'low_joinability'],
  'trying_independently': ['independent_attempt', 'shared_action'],
  'joining_action': ['shared_action'],
};
```

The accumulator applies `newWeight = oldWeight * decay + evidence`, clamps to
`0..1`, retains at most eight compressed event summaries, and derives only
interaction-local trends. Strategy rules must inspect normalized context and
memory; utterance rules must inspect the supplied decision and stable anchor.
Do not use compliance, cooperation, correctness, ability, diagnosis, or
developmental vocabulary.

- [ ] **Step 7: Run pipeline tests and semantic vocabulary scan**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/domain/engine
rg -n "cooperation|compliance|comply|childStateHypothesis|behavioralTrend|rawSummary" lib/features/ritual_room/domain
```

Expected: tests PASS and `rg` returns no runtime matches.

- [ ] **Step 8: Commit**

```powershell
git add mobile_v2/lib/features/ritual_room/domain/engine mobile_v2/test/features/ritual_room/domain/engine
git commit -m "feat(41): add deterministic interaction pipeline"
```

### Task 3: Build the authority shell, consistency state, and replay journal

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_clock.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_id_generator.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_session_initializer.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_seed_source.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/input_fingerprint.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/consistency_state.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/replay_journal.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_runtime_state.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_runtime_store.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/runtime/input_fingerprint_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/runtime/replay_journal_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_test.dart`

- [ ] **Step 1: Write RED tests for initialization and successful advance**

```dart
test('initialize creates schema 1 revision 0 runtime state', () async {
  final snapshot = await engine.initialize('shoes_on_room_v1');

  expect(snapshot.schemaVersion, 1);
  expect(snapshot.revision, 0);
  expect(snapshot.interactionId, 'interaction-1');
  expect(store.debugState(snapshot.interactionId)!.consistency.receipts, isEmpty);
  expect(store.debugState(snapshot.interactionId)!.journal.records, isEmpty);
});

test('accepted event commits all runtime structures once', () async {
  final initial = await engine.initialize('shoes_on_room_v1');
  final result = await engine.advance(
    interactionId: initial.interactionId,
    expectedRevision: 0,
    input: reactionRunningAway,
  );

  expect(result, isA<Applied>());
  final state = store.debugState(initial.interactionId)!;
  expect(state.snapshot.revision, 1);
  expect(state.consistency.receipts.single.appliedRevision, 1);
  expect(state.journal.records.single.toRevision, 1);
});
```

- [ ] **Step 2: Write RED tests for consistency ordering**

Cover:

```dart
test('duplicate retry after later revisions returns latest snapshot', () async {
  final initial = await engine.initialize('shoes_on_room_v1');
  await engine.advance(
    interactionId: initial.interactionId,
    expectedRevision: 0,
    input: reactionRunningAway,
  );
  await engine.advance(
    interactionId: initial.interactionId,
    expectedRevision: 1,
    input: reactionJoining,
  );

  final duplicate = await engine.advance(
    interactionId: initial.interactionId,
    expectedRevision: 0,
    input: reactionRunningAway,
  );

  expect(duplicate, isA<DuplicateIgnored>());
  expect((duplicate as DuplicateIgnored).snapshot.revision, 2);
});
```

Also test:

- same `eventId`, different fingerprint -> `eventIdConflict`
- unseen event, stale expected revision -> `revisionConflict`
- missing interaction -> `interactionNotFound`
- duplicate and rejected requests do not call pipeline modules
- pipeline exception leaves all three runtime structures unchanged
- duplicate and rejected requests do not advance the injected clock

Add a real concurrency test:

```dart
test('two requests cannot commit from the same revision', () async {
  final initial = await engine.initialize('shoes_on_room_v1');
  final results = await Future.wait([
    engine.advance(
      interactionId: initial.interactionId,
      expectedRevision: 0,
      input: reactionRunningAway,
    ),
    engine.advance(
      interactionId: initial.interactionId,
      expectedRevision: 0,
      input: reactionJoining,
    ),
  ]);

  expect(results.whereType<Applied>(), hasLength(1));
  expect(
    results.whereType<AdvanceRejected>().single.code,
    AdvanceErrorCode.revisionConflict,
  );
  expect(store.debugState(initial.interactionId)!.snapshot.revision, 1);
});
```

- [ ] **Step 3: Write RED tests for deterministic replay**

```dart
test('replay applies records without invoking pipeline modules', () async {
  final initial = await engine.initialize('shoes_on_room_v1');
  await engine.advance(
    interactionId: initial.interactionId,
    expectedRevision: 0,
    input: reactionRunningAway,
  );
  final state = store.debugState(initial.interactionId)!;

  final replayed = state.journal.replayFrom(
    initial: state.initialSnapshot,
  );

  expect(replayed.revision, state.snapshot.revision);
  expect(
    replayed.context.normalizedSignals,
    state.snapshot.context.normalizedSignals,
  );
  expect(
    replayed.memory.signalAggregation,
    state.snapshot.memory.signalAggregation,
  );
  expect(replayed.strategy.primary, state.snapshot.strategy.primary);
  expect(replayed.utterance.primary, state.snapshot.utterance.primary);
  expect(normalizeSpy.callCount, 1);
  expect(strategySpy.callCount, 1);
  expect(utteranceSpy.callCount, 1);
});
```

- [ ] **Step 4: Run authority tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/domain/runtime test/features/ritual_room/domain/engine/interaction_engine_test.dart
```

Expected: FAIL because runtime state, store, and authority shell are absent.

- [ ] **Step 5: Implement deterministic fingerprinting**

Canonicalize maps recursively by sorted key before hashing:

```dart
String fingerprintInput(InputEvent event) {
  final canonical = jsonEncode(_canonicalize(event.toCanonicalJson()));
  return 'sha256:${sha256.convert(utf8.encode(canonical))}';
}
```

`_canonicalize` must preserve list order, sort map keys, encode timestamps as
UTC ISO-8601, and reject unsupported payload values.

- [ ] **Step 6: Implement internal runtime structures**

```dart
final class InteractionRuntimeState {
  const InteractionRuntimeState({
    required this.initialSnapshot,
    required this.snapshot,
    required this.consistency,
    required this.journal,
  });

  final ProductSnapshot initialSnapshot;
  final ProductSnapshot snapshot;
  final ConsistencyState consistency;
  final ReplayJournal journal;
}
```

`ConsistencyState` stores only `eventId`, fingerprint, and applied revision.
`TransitionRecord` stores only normalized input, updated memory, strategy,
utterance, revisions, event ID, and recorded time.

- [ ] **Step 7: Implement per-interaction serialization**

Expose a commit callback only inside an exclusive operation:

```dart
abstract interface class InteractionRuntimeStore {
  Future<void> create(InteractionRuntimeState state);

  Future<T> runExclusive<T>(
    String interactionId,
    Future<T> Function(
      InteractionRuntimeState? current,
      void Function(InteractionRuntimeState next) commit,
    ) operation,
  );
}
```

`InMemoryInteractionRuntimeStore` chains futures by interaction ID and commits
the new immutable aggregate in one assignment. Holding the per-interaction
exclusive operation across pipeline awaits is acceptable in Phase 41.

- [ ] **Step 8: Implement InteractionEngine**

`InteractionEngine` implements the domain-only initializer seam:

```dart
abstract interface class InteractionSessionInitializer {
  Future<ProductSnapshot> initialize(String ritualRoomId);
}
```

The advance ordering must be literal:

```dart
final receipt = current.consistency.find(input.eventId);
if (receipt != null && receipt.inputFingerprint == fingerprint) {
  return DuplicateIgnored(current.snapshot);
}
if (receipt != null) {
  return AdvanceRejected(
    code: AdvanceErrorCode.eventIdConflict,
    latestSnapshot: current.snapshot,
  );
}
if (expectedRevision != current.snapshot.revision) {
  return AdvanceRejected(
    code: AdvanceErrorCode.revisionConflict,
    latestSnapshot: current.snapshot,
  );
}
```

Only after those checks may the engine run Normalize -> Accumulate -> Strategy
-> Utterance. Build all next values first, then call `commit(nextState)` once.
Catch module failures and return `pipelineFailed` without committing.

- [ ] **Step 9: Run authority, replay, and non-retention tests**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/domain/runtime test/features/ritual_room/domain/engine/interaction_engine_test.dart
```

Expected: PASS. Tests serialize the current runtime state and prove the raw
voice/free-text test strings are absent from ProductSnapshot,
ConsistencyState, and ReplayJournal.

- [ ] **Step 10: Commit**

```powershell
git add mobile_v2/lib/features/ritual_room/domain/runtime mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine.dart mobile_v2/test/features/ritual_room/domain/runtime mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_test.dart
git commit -m "feat(41): add interaction authority and replay runtime"
```

### Task 4: Standardize Mock API and repository adapters

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/data/datasources/interaction_api.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/datasources/mock_interaction_api.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/dto/interaction_advance_request.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/dto/interaction_input_dto.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/dto/interaction_result_response.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/mappers/interaction_mapper.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/repositories/interaction_repository.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/repositories/interaction_repository_impl.dart`
- Test: `mobile_v2/test/features/ritual_room/data/datasources/mock_interaction_api_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/mappers/interaction_mapper_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/repositories/interaction_repository_test.dart`

- [ ] **Step 1: Write RED adapter delegation tests**

```dart
test('mock API delegates advance exactly once to the engine', () async {
  final spy = InteractionEngineSpy(result: Applied(snapshotRevision1));
  final api = MockInteractionApi(engine: spy, mapper: mapper);

  final response = await api.advance(requestRevision0);

  expect(spy.advanceCalls, 1);
  expect(response.status, 'applied');
  expect(response.snapshot!.revision, 1);
});
```

Add tests proving:

- API snapshot read has no initialize side effect
- all five input DTO variants map losslessly to domain InputEvent
- repository exposes domain models, never DTOs
- revision conflict returns latest domain snapshot
- event ID conflict returns latest domain snapshot
- schema version 1 ignores unknown optional transport fields
- a schema version other than 1 maps to `unsupportedSchemaVersion`
- mock API and direct engine execution produce equal ProductSnapshot values

- [ ] **Step 2: Run adapter tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/data
```

Expected: FAIL because adapter files do not exist.

- [ ] **Step 3: Implement API-shaped transport contracts**

```dart
abstract interface class InteractionApi {
  Future<InteractionSnapshotResponse> getSnapshot(String interactionId);
  Future<InteractionResultResponse> advance(
    InteractionAdvanceRequest request,
  );
}
```

The request contains `interactionId`, `expectedRevision`, and typed
`InteractionInputDto`. The response uses status/error codes matching the
contract and carries only ProductSnapshot transport data. It must not expose
ConsistencyState or ReplayJournal.

- [ ] **Step 4: Implement thin MockInteractionApi**

```dart
final class MockInteractionApi implements InteractionApi {
  MockInteractionApi({
    required InteractionEngine engine,
    required InteractionMapper mapper,
  }) : _engine = engine,
       _mapper = mapper;

  final InteractionEngine _engine;
  final InteractionMapper _mapper;

  @override
  Future<InteractionResultResponse> advance(
    InteractionAdvanceRequest request,
  ) async {
    final result = await _engine.advance(
      interactionId: request.interactionId,
      expectedRevision: request.expectedRevision,
      input: _mapper.inputToDomain(request.input),
    );
    return _mapper.resultToResponse(result);
  }
}
```

No switch in this class may select strategy, utterance, signals, or revisions.

- [ ] **Step 5: Implement repository mapping**

```dart
abstract interface class InteractionRepository {
  Future<ProductSnapshot> getSnapshot(String interactionId);

  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  });
}
```

`InteractionRepositoryImpl` maps domain -> request DTO -> API -> response DTO ->
domain. It contains no fallback sentences, normalization tables, memory
aggregation, or strategy rules.

- [ ] **Step 6: Run adapter tests and source-boundary scan**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/data
rg -n "low_pressure|low_joinability|eventLogCompressed|signalAggregation" lib/features/ritual_room/data/datasources lib/features/ritual_room/data/repositories
```

Expected: tests PASS. The source scan has no business-rule literals in API or
repository implementations; DTO field names are allowed only in DTO/mapper
files.

- [ ] **Step 7: Commit**

```powershell
git add mobile_v2/lib/features/ritual_room/data mobile_v2/lib/features/ritual_room/domain/repositories/interaction_repository.dart mobile_v2/test/features/ritual_room/data
git commit -m "feat(41): add interaction transport adapters"
```

### Task 5: Add composition-root initialization, controller overwrite semantics, and CapabilityMask

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/presentation/capability/interaction_capability_mask.dart`
- Create or Modify: `mobile_v2/lib/features/ritual_room/presentation/controllers/ritual_room_controller.dart`
- Create: `mobile_v2/lib/app/interaction_composition.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/capability/interaction_capability_mask_test.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/controllers/ritual_room_controller_test.dart`

- [ ] **Step 1: Write RED CapabilityMask tests**

```dart
test('Phase 41 exposes reaction only without reducing engine capability', () {
  expect(EngineCapabilities.v1.supports(InteractionCapability.voiceObservation), isTrue);
  expect(InteractionCapabilityMask.phase41.exposes(
    InteractionCapability.reactionSelection,
  ), isTrue);
  expect(InteractionCapabilityMask.phase41.exposes(
    InteractionCapability.voiceObservation,
  ), isFalse);
  expect(InteractionCapabilityMask.phase41.exposes(
    InteractionCapability.freeText,
  ), isFalse);
  expect(InteractionCapabilityMask.phase41.exposes(
    InteractionCapability.strategyControl,
  ), isFalse);
});
```

The engine capability set and UI exposure mask must be separate immutable
objects. The engine must never accept a mask.

- [ ] **Step 2: Write RED controller tests**

Cover:

```dart
test('room load initializes interaction exactly once', () async {
  await controller.loadRoom('shoes_on_room_v1');
  await controller.loadRoom('shoes_on_room_v1');

  expect(initializer.calls, 1);
  expect(controller.state.snapshot!.revision, 0);
});

test('revision conflict overwrites local product snapshot', () async {
  repository.nextResult = AdvanceRejected(
    code: AdvanceErrorCode.revisionConflict,
    latestSnapshot: snapshotRevision3,
  );

  await controller.submit(reactionRunningAway);

  expect(controller.state.snapshot, snapshotRevision3);
  expect(controller.state.errorCode, AdvanceErrorCode.revisionConflict);
});
```

Also test:

- applied response replaces the whole ProductSnapshot
- duplicate response uses the returned latest ProductSnapshot
- controller does not derive strategy/context/utterance
- pending raw InputEvent exists only during request/retry handling and is
  cleared after a terminal response
- programmatic voice/text/future/strategy events can pass through the same
  controller/repository method even though the Phase 41 UI mask hides controls

- [ ] **Step 3: Run presentation-state tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/presentation/capability test/features/ritual_room/presentation/controllers/ritual_room_controller_test.dart
```

Expected: FAIL because mask/controller behavior is absent.

- [ ] **Step 4: Implement capability separation**

```dart
enum InteractionCapability {
  reactionSelection,
  voiceObservation,
  freeText,
  futureSignal,
  strategyPreference,
  strategyControl,
}

final class EngineCapabilities {
  const EngineCapabilities(this.supported);
  final Set<InteractionCapability> supported;

  static const v1 = EngineCapabilities({
    InteractionCapability.reactionSelection,
    InteractionCapability.voiceObservation,
    InteractionCapability.freeText,
    InteractionCapability.futureSignal,
    InteractionCapability.strategyPreference,
  });
}

final class InteractionCapabilityMask {
  const InteractionCapabilityMask(this.visible);
  final Set<InteractionCapability> visible;

  static const phase41 = InteractionCapabilityMask({
    InteractionCapability.reactionSelection,
  });
}
```

Use unmodifiable sets in the concrete implementation if const sets cannot
satisfy mutation safety.

- [ ] **Step 5: Implement composition-root-only initialization**

`interaction_composition.dart` constructs:

```text
seed source
-> deterministic modules
-> in-memory runtime store
-> InteractionEngine
-> MockInteractionApi
-> InteractionRepository
-> RitualRoomController
```

The room-load path calls `InteractionEngine.initialize(ritualRoomId)` through an
internal `InteractionSessionInitializer` abstraction. There is no public API
initialize method and `getSnapshot` never initializes.

The later visually approved `main.dart` calls this composition function. Task 5
must not create an app entrypoint or presentation widget.

- [ ] **Step 6: Implement snapshot-driven controller state**

The controller may own transient presentation state:

```dart
enum RitualRoomStatus { idle, loading, ready, submitting, error }

final class RitualRoomState {
  const RitualRoomState({
    required this.status,
    this.snapshot,
    this.errorCode,
  });

  final RitualRoomStatus status;
  final ProductSnapshot? snapshot;
  final AdvanceErrorCode? errorCode;
}
```

It must not mirror snapshot context, memory, strategy, utterance, schema
version, or revision as separate fields. Submission always uses
`state.snapshot!.revision` as expectedRevision and replaces the complete
snapshot from engine results.

- [ ] **Step 7: Run controller/mask tests**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/presentation/capability test/features/ritual_room/presentation/controllers/ritual_room_controller_test.dart
```

Expected: PASS. No presentation widget is added or changed in this task.

- [ ] **Step 8: Commit**

```powershell
git add mobile_v2/lib/app/interaction_composition.dart mobile_v2/lib/features/ritual_room/presentation/capability mobile_v2/lib/features/ritual_room/presentation/controllers mobile_v2/test/features/ritual_room/presentation/capability mobile_v2/test/features/ritual_room/presentation/controllers
git commit -m "feat(41): add snapshot driven interaction projection"
```

### Task 6: Verify engine completeness and record the Phase 42 handoff

**Files:**

- Create: `mobile_v2/test/features/ritual_room/interaction_engine_contract_test.dart`
- Modify: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-VALIDATION.md`
- Create: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-ENGINE-PROOF.md`
- Create: `.planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-ENGINE-HANDOFF.md`

- [ ] **Step 1: Add one end-to-end engine contract test**

The test must:

1. initialize revision 0
2. submit reaction at expected revision 0
3. submit raw voice at expected revision 1
4. submit free text at expected revision 2
5. submit future signal at expected revision 3
6. submit strategy preference at expected revision 4
7. assert final revision 5
8. retry event 1 and receive `DuplicateIgnored` at revision 5
9. replay the journal from revision 0 and reproduce revision 5
10. prove no raw voice/free-text strings exist in runtime truth or journal

```dart
expect(finalSnapshot.schemaVersion, 1);
expect(finalSnapshot.revision, 5);
expect(replayed.revision, finalSnapshot.revision);
expect(replayed.memory.signalAggregation, finalSnapshot.memory.signalAggregation);
expect(replayed.strategy.primary, finalSnapshot.strategy.primary);
expect(replayed.utterance.primary, finalSnapshot.utterance.primary);
expect(runtimeDump, isNot(contains(rawVoiceText)));
expect(runtimeDump, isNot(contains(rawFreeText)));
```

- [ ] **Step 2: Run the focused full engine suite**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/domain test/features/ritual_room/data test/features/ritual_room/presentation/controllers test/features/ritual_room/interaction_engine_contract_test.dart
```

Expected: all tests PASS.

- [ ] **Step 3: Run package and repository gates**

Run:

```powershell
cd mobile_v2
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart run ../tool/verify_mobile_v2_semantic_firewall.dart
dart run ../tool/verify_activation_governor_contract.dart
```

Expected:

```text
mobile_v2_semantic_firewall_status=pass
activation_governor_contract_status=pass
```

- [ ] **Step 4: Run source-boundary audits**

Run:

```powershell
rg -n "package:flutter" mobile_v2/lib/features/ritual_room/domain
rg -n "V2|cooperation|compliance|comply|childStateHypothesis|behavioralTrend|rawSummary" mobile_v2/lib/features/ritual_room
rg -n "NormalizeEngine|StateAccumulator|StrategyEngine|UtteranceEngine" mobile_v2/lib/features/ritual_room/data
```

Expected:

- no Flutter imports under domain
- no forbidden runtime vocabulary or V2 runtime names
- data matches only mapper/API type references, never rule implementations or
  direct business decisions

- [ ] **Step 5: Write `41-ENGINE-PROOF.md`**

Record:

- exact commit hashes for Tasks 1-5
- command outputs and test counts
- all five input channels
- initialization and revision evidence
- duplicate, event conflict, revision conflict, and not-found evidence
- atomic pipeline failure evidence
- raw-input non-retention evidence
- deterministic replay evidence
- adapter parity evidence
- capability catalog versus Phase 41 mask evidence
- explicit statement that no Spring endpoint, persistence, LLM call, microphone,
  free-text UI, strategy UI, or future-signal producer exists

- [ ] **Step 6: Write Phase 42 design-only handoff**

`42-ENGINE-HANDOFF.md` must state:

```text
Allowed replacements:
- NormalizeEngine implementation
- StrategyEngine implementation
- UtteranceEngine implementation

Allowed acquisition additions:
- voice_observation adapter
- free-text UI adapter
- strategy-control UI adapter

Invariant:
- InteractionEngine remains authority
- an LLM must not replace InteractionEngine
- schemaVersion remains 1 unless a breaking change is approved
- no LLM controls lifecycle, revision, idempotency, commit, or replay
- replay uses recorded TransitionRecord outputs
- Phase 41 deterministic implementations remain fallback-capable
```

Do not implement provider clients, prompts, STT, memory persistence, or hybrid
selection in Phase 41.

- [ ] **Step 7: Commit**

```powershell
git add mobile_v2/test/features/ritual_room/interaction_engine_contract_test.dart .planning/phases/41-mobile-v2-runnable-vertical-slice/41-VALIDATION.md .planning/phases/41-mobile-v2-runnable-vertical-slice/41-ENGINE-PROOF.md .planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-ENGINE-HANDOFF.md
git commit -m "test(41): prove interaction engine v1 contract"
```

## Completion gate

The engine-first Phase 41 slice is complete only when:

- all Task 6 commands pass
- ProductSnapshot remains the sole product-semantic source
- ConsistencyState is not exposed through API/repository/UI
- ReplayJournal is not consulted for current decisions
- every successful event advances revision once
- duplicates and conflicts never execute the pipeline
- raw voice/free text is absent from persisted in-memory structures after the
  advance invocation finishes
- adapters contain no domain policy
- Phase 41 UI capability mask hides non-reaction controls without reducing
  engine support
- visual UI work remains blocked until its separate prototype/asset gate is
  approved
