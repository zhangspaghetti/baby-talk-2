# Interaction Engine Flutter Riverpod Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Map Interaction Engine v1 into `mobile_v2` with a strict Flutter/Riverpod composition layer, transport DTOs, repositories, a thin Mock API adapter, and one snapshot-driven session Notifier.

**Architecture:** Pure-Dart engine contracts remain under `domain/`; DTOs, mappers, repositories, and mock transport remain under `data/`; Riverpod exists only under `app/providers/`. Providers construct the real deterministic InteractionEngine and in-memory runtime, while one Notifier projects the latest ProductSnapshot plus transient UI status without becoming a second domain authority.

**Tech Stack:** Flutter, Dart 3.11, `flutter_riverpod` 3.3.x without code generation, existing pure-Dart Interaction Engine contracts, manual JSON DTO mapping, `flutter_test`, `ProviderContainer.test`, repository fakes, existing semantic and Activation Governor verifiers.

---

## Prerequisites and precedence

Before this plan:

1. Execute Tasks 1-3 from
   `docs/superpowers/plans/2026-06-19-interaction-engine-v1.md`.
2. Confirm the following pure-Dart contracts exist and pass tests:
   `InteractionEngine`, `InputEvent`, `ProductSnapshot`, `AdvanceResult`,
   `InteractionSessionInitializer`, all four pipeline modules,
   `InteractionRuntimeStore`, `ConsistencyState`, and `ReplayJournal`.
3. Do not execute the superseded Tasks 4-5 from that plan.
4. After this plan passes, return to Task 6 of that plan for final engine proof.

This plan controls Flutter/Riverpod composition. It does not weaken:

- InteractionEngine authority
- schemaVersion/revision separation
- eventId/expectedRevision behavior
- raw-input non-retention
- ConsistencyState privacy
- ReplayJournal privacy
- Phase 41 reaction-only UI exposure

## Locked dependency direction

```text
Flutter widget
  -> app Riverpod session provider
  -> domain repository interface
  -> data repository implementation
  -> transport API
  -> MockInteractionApi
  -> pure-Dart InteractionEngine

InteractionEngine
  -> NormalizeEngine
  -> StateAccumulator
  -> StrategyEngine
  -> UtteranceEngine
  -> ProductSnapshot commit
```

Forbidden:

```text
domain -> Riverpod
data -> Riverpod
MockInteractionApi -> strategy/normalization rules
Repository -> snapshot mutation
Notifier -> context/strategy/utterance derivation
CapabilityMask -> engine support
```

## Final directory map

```text
mobile_v2/
├── lib/
│   ├── app/
│   │   ├── input/
│   │   │   ├── event_id_generator.dart
│   │   │   └── interaction_input_factory.dart
│   │   └── providers/
│   │       ├── interaction_engine_providers.dart
│   │       ├── ritual_room_data_providers.dart
│   │       ├── ritual_room_session_provider.dart
│   │       └── ritual_room_capability_provider.dart
│   └── features/
│       └── ritual_room/
│           ├── domain/
│           │   ├── engine/
│           │   ├── models/
│           │   │   ├── ritual_room_content.dart
│           │   │   ├── input_event.dart
│           │   │   ├── product_snapshot.dart
│           │   │   └── advance_result.dart
│           │   ├── repositories/
│           │   │   ├── ritual_room_repository.dart
│           │   │   └── interaction_repository.dart
│           │   └── runtime/
│           ├── data/
│           │   ├── datasources/
│           │   │   ├── ritual_content_api.dart
│           │   │   ├── mock_ritual_content_api.dart
│           │   │   ├── interaction_api.dart
│           │   │   └── mock_interaction_api.dart
│           │   ├── dto/
│           │   │   ├── ritual_room_response.dart
│           │   │   ├── interaction_input_dto.dart
│           │   │   ├── interaction_advance_request.dart
│           │   │   ├── interaction_snapshot_response.dart
│           │   │   └── interaction_result_response.dart
│           │   ├── mappers/
│           │   │   ├── ritual_room_mapper.dart
│           │   │   └── interaction_mapper.dart
│           │   └── repositories/
│           │       ├── ritual_room_repository_impl.dart
│           │       └── interaction_repository_impl.dart
│           └── presentation/
│               ├── capability/
│               │   └── interaction_capability_mask.dart
│               └── state/
│                   └── ritual_room_ui_state.dart
├── assets/
│   └── fixtures/
│       └── ritual_rooms/
│           └── shoes_on.json
└── test/
    ├── app/providers/
    └── features/ritual_room/
        ├── data/
        └── presentation/state/
```

Provider definitions live in `app/providers/` because this is the only layer
allowed to import domain contracts, concrete data implementations, and
Riverpod at the same time. Feature widgets remain unaware of DTOs and concrete
repositories.

### Task 1: Approve and install Riverpod without code generation

**Files:**

- Modify: `mobile_v2/pubspec.yaml`
- Create or Modify: `mobile_v2/pubspec.lock`
- Modify: `mobile_v2/CODING_STANDARDS.md`
- Test: `mobile_v2/test/app/providers/riverpod_smoke_test.dart`

- [ ] **Step 1: Record the dependency decision**

Add this decision under `Dependencies And Code Generation`:

```text
flutter_riverpod 3.3.x is approved for mobile_v2 because the Interaction Engine
composition is shared, lifecycle-aware, dependency-rich, and requires provider
overrides in tests. Riverpod is limited to app composition and presentation
orchestration. No riverpod_generator, build_runner, hooks_riverpod, Freezed, or
StateNotifier compatibility layer is approved for Phase 41.
```

Record:

- publisher/project: Riverpod (`rrousselGit/riverpod`)
- license: MIT
- platforms: Flutter-supported platforms
- privacy: local state container; no data collection or transport
- performance: one root ProviderScope and one Ritual Room session Notifier
- test strategy: `ProviderContainer.test` and `ProviderScope` overrides

- [ ] **Step 2: Add the package**

Run:

```powershell
cd mobile_v2
flutter pub add flutter_riverpod:^3.3.0
```

Expected:

- `flutter_riverpod` appears under dependencies
- a package-local `pubspec.lock` is created or updated
- no code-generation dependency is added

- [ ] **Step 3: Write the failing ProviderScope smoke test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProviderScope exposes a read-only provider', (tester) async {
    final valueProvider = Provider<String>((ref) => 'engine-ready');

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, child) {
            return Text(ref.watch(valueProvider));
          },
        ),
      ),
    );

    expect(find.text('engine-ready'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run the smoke test**

Run:

```powershell
cd mobile_v2
flutter test test/app/providers/riverpod_smoke_test.dart
```

Expected: PASS, proving Riverpod is resolved without generated code.

- [ ] **Step 5: Commit**

```powershell
git add mobile_v2/pubspec.yaml mobile_v2/pubspec.lock mobile_v2/CODING_STANDARDS.md mobile_v2/test/app/providers/riverpod_smoke_test.dart
git commit -m "build(41): add riverpod composition dependency"
```

### Task 2: Implement transport DTOs and strict boundary mappers

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/dto/interaction_input_dto.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/dto/interaction_advance_request.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/dto/interaction_result_response.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/mappers/interaction_mapper.dart`
- Test: `mobile_v2/test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/mappers/interaction_mapper_test.dart`

- [ ] **Step 1: Write RED tests for all input wire variants**

```dart
test('maps every input event to its stable wire type', () {
  final mapper = InteractionMapper();
  final cases = <InputEvent, String>{
    reactionEvent: 'reaction_selection',
    voiceEvent: 'voice_observation',
    freeTextEvent: 'free_text',
    futureSignalEvent: 'future_signal',
    strategyPreferenceEvent: 'strategy_preference',
  };

  for (final entry in cases.entries) {
    final dto = mapper.inputToDto(entry.key);
    expect(dto.type, entry.value);
    expect(dto.eventId, entry.key.eventId);
  }
});
```

Add tests asserting:

- `eventId` and timestamp survive mapping
- raw voice/text exists only inside `InteractionInputDto.payload`
- `expectedRevision` is request-level, not payload-level
- strategy preference remains an input and does not become a StrategyDecision

- [ ] **Step 2: Write RED tests for schema compatibility**

```dart
test('accepts schema 1 and ignores unknown optional fields', () {
  final json = snapshotJson(schemaVersion: 1)
    ..['futureOptionalField'] = <String, Object?>{'ignored': true};

  final snapshot = InteractionMapper().snapshotToDomain(
    InteractionSnapshotResponse.fromJson(json),
  );

  expect(snapshot.schemaVersion, 1);
});

test('rejects unsupported snapshot schema', () {
  final response = InteractionSnapshotResponse.fromJson(
    snapshotJson(schemaVersion: 2),
  );

  expect(
    () => InteractionMapper().snapshotToDomain(response),
    throwsA(isA<UnsupportedSnapshotSchema>()),
  );
});
```

- [ ] **Step 3: Write RED tests for ProductSnapshot-only transport**

Serialize `InteractionResultResponse` and assert it contains:

```text
status
error.code when rejected
snapshot or latestSnapshot
```

Assert it does not contain:

```text
processedEvents
ConsistencyState
ReplayJournal
TransitionRecord
inputFingerprint
```

- [ ] **Step 4: Run mapper tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/data/mappers
```

Expected: FAIL because DTOs and mappers do not exist.

- [ ] **Step 5: Implement manual immutable DTOs**

Use explicit transport names:

```dart
final class InteractionInputDto {
  const InteractionInputDto({
    required this.eventId,
    required this.type,
    required this.timestamp,
    required this.payload,
  });

  final String eventId;
  final String type;
  final int timestamp;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
    'eventId': eventId,
    'type': type,
    'timestamp': timestamp,
    'payload': payload,
  };
}

final class InteractionAdvanceRequest {
  const InteractionAdvanceRequest({
    required this.interactionId,
    required this.expectedRevision,
    required this.input,
  });

  final String interactionId;
  final int expectedRevision;
  final InteractionInputDto input;
}
```

`InteractionSnapshotResponse.fromJson` validates required fields and stores
unknown optional fields nowhere. It must not create defaults that alter
ProductSnapshot meaning.

- [ ] **Step 6: Implement strict mappers**

```dart
final class InteractionMapper {
  InteractionInputDto inputToDto(InputEvent event);

  InputEvent inputToDomain(InteractionInputDto dto);

  ProductSnapshot snapshotToDomain(
    InteractionSnapshotResponse response,
  ) {
    if (response.schemaVersion != ProductSnapshot.currentSchemaVersion) {
      throw UnsupportedSnapshotSchema(response.schemaVersion);
    }
    // Map required product-semantic fields only.
  }

  AdvanceResult resultToDomain(InteractionResultResponse response);
}
```

Use exhaustive switches for input and result types. A missing payload field
throws a typed mapper exception; it must not silently select a fallback
strategy or utterance.

- [ ] **Step 7: Run mapper tests**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/data/mappers
dart analyze lib/features/ritual_room/data/dto lib/features/ritual_room/data/mappers
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add mobile_v2/lib/features/ritual_room/data/dto mobile_v2/lib/features/ritual_room/data/mappers mobile_v2/test/features/ritual_room/data/mappers
git commit -m "feat(41): add interaction transport DTO mapping"
```

### Task 3: Implement content and interaction repositories over thin Mock APIs

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/repositories/ritual_room_repository.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/repositories/interaction_repository.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/datasources/ritual_content_api.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/datasources/mock_ritual_content_api.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/datasources/interaction_api.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/datasources/mock_interaction_api.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/repositories/ritual_room_repository_impl.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/repositories/interaction_repository_impl.dart`
- Create: `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json`
- Modify: `mobile_v2/pubspec.yaml`
- Create: `mobile_v2/test/fixtures/interaction_test_fixtures.dart`
- Create: `mobile_v2/test/helpers/interaction_test_doubles.dart`
- Test: `mobile_v2/test/features/ritual_room/data/datasources/mock_ritual_content_api_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/datasources/mock_interaction_api_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/repositories/ritual_room_repository_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/repositories/interaction_repository_test.dart`

- [ ] **Step 1: Write RED delegation tests for MockInteractionApi**

Create shared immutable fixtures (`reactionEvent`, `voiceEvent`,
`snapshotRevision0`, `snapshotRevision1`) in
`test/fixtures/interaction_test_fixtures.dart`.

Create this port fake in `test/helpers/interaction_test_doubles.dart`:

```dart
final class FakeInteractionEnginePort implements InteractionEnginePort {
  FakeInteractionEnginePort({
    required this.advanceResult,
    this.snapshot,
  });

  AdvanceResult advanceResult;
  ProductSnapshot? snapshot;
  var advanceCalls = 0;
  var snapshotCalls = 0;

  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) async {
    advanceCalls += 1;
    return advanceResult;
  }

  @override
  Future<ProductSnapshot?> getSnapshot(String interactionId) async {
    snapshotCalls += 1;
    return snapshot;
  }
}
```

```dart
test('advance delegates exactly once and does not decide policy', () async {
  final engine = FakeInteractionEnginePort(
    advanceResult: Applied(snapshotRevision1),
  );
  final api = MockInteractionApi(
    engine: engine,
    mapper: InteractionMapper(),
  );

  final response = await api.advance(requestRevision0);

  expect(engine.advanceCalls, 1);
  expect(response.status, 'applied');
  expect(response.snapshot!.revision, 1);
});
```

Test `getSnapshot` separately and assert it never invokes initialize.

- [ ] **Step 2: Write RED repository tests**

```dart
test('interaction repository returns domain result only', () async {
  final repository = InteractionRepositoryImpl(
    api: FakeInteractionApi.applied(snapshotResponseRevision1),
    mapper: InteractionMapper(),
  );

  final result = await repository.advance(
    interactionId: 'interaction-1',
    expectedRevision: 0,
    input: reactionEvent,
  );

  expect(result, isA<Applied>());
  expect((result as Applied).snapshot, isA<ProductSnapshot>());
});
```

Cover `duplicate_ignored`, `revision_conflict`, `event_id_conflict`,
`interaction_not_found`, and unsupported schema responses.

- [ ] **Step 3: Write RED content bootstrap tests**

Load `shoes_on.json` through `MockRitualContentApi` and assert:

- one `shoes_on_room_v1` room
- stable `Shoes on.` anchor
- reaction choices are content-owned
- no interaction snapshot or runtime receipt is embedded in the content DTO

- [ ] **Step 4: Run API/repository tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/data/datasources test/features/ritual_room/data/repositories
```

Expected: FAIL because APIs and repositories do not exist.

- [ ] **Step 5: Implement API interfaces**

```dart
abstract interface class InteractionApi {
  Future<InteractionSnapshotResponse> getSnapshot(String interactionId);

  Future<InteractionResultResponse> advance(
    InteractionAdvanceRequest request,
  );
}

abstract interface class RitualContentApi {
  Future<RitualRoomResponse> loadRoom(String ritualRoomId);
}
```

- [ ] **Step 6: Implement thin MockInteractionApi**

```dart
final class MockInteractionApi implements InteractionApi {
  MockInteractionApi({
    required InteractionEnginePort engine,
    required InteractionMapper mapper,
  }) : _engine = engine,
       _mapper = mapper;

  final InteractionEnginePort _engine;
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

Do not create a separate `MockInteractionEngine`. Phase 41 mock mode uses the
real `InteractionEngine` authority with deterministic module implementations
and an in-memory runtime store.

- [ ] **Step 7: Implement repositories**

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

Repositories perform request/response conversion only. They do not normalize
input, aggregate memory, choose strategy, generate utterances, increment
revision, retry with a new event ID, or keep a mutable snapshot cache.

- [ ] **Step 8: Run tests and scan for duplicated engine logic**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/data
rg -n "signalAggregation|pressureLevel|reduce_options|low_joinability" lib/features/ritual_room/data/datasources lib/features/ritual_room/data/repositories
```

Expected:

- tests PASS
- the scan finds no strategy, normalization, or accumulation rule literals in
  APIs/repositories

- [ ] **Step 9: Commit**

```powershell
git add mobile_v2/pubspec.yaml mobile_v2/assets/fixtures/ritual_rooms mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart mobile_v2/lib/features/ritual_room/domain/repositories mobile_v2/lib/features/ritual_room/data/datasources mobile_v2/lib/features/ritual_room/data/repositories mobile_v2/test/fixtures/interaction_test_fixtures.dart mobile_v2/test/helpers/interaction_test_doubles.dart mobile_v2/test/features/ritual_room/data
git commit -m "feat(41): add ritual room mock repositories"
```

### Task 4: Build the Riverpod dependency graph

**Files:**

- Create: `mobile_v2/lib/app/providers/interaction_engine_providers.dart`
- Create: `mobile_v2/lib/app/providers/ritual_room_data_providers.dart`
- Create: `mobile_v2/lib/app/providers/ritual_room_capability_provider.dart`
- Create: `mobile_v2/lib/app/input/event_id_generator.dart`
- Create: `mobile_v2/lib/app/input/interaction_input_factory.dart`
- Create: `mobile_v2/lib/features/ritual_room/presentation/capability/interaction_capability_mask.dart`
- Test: `mobile_v2/test/app/providers/interaction_engine_providers_test.dart`
- Test: `mobile_v2/test/app/providers/ritual_room_data_providers_test.dart`
- Test: `mobile_v2/test/app/providers/ritual_room_capability_provider_test.dart`

- [ ] **Step 1: Write RED provider graph tests**

```dart
test('provider graph builds one engine over one runtime store', () {
  final container = ProviderContainer.test();

  final firstEngine = container.read(interactionEngineProvider);
  final secondEngine = container.read(interactionEngineProvider);
  final firstStore = container.read(interactionRuntimeStoreProvider);
  final secondStore = container.read(interactionRuntimeStoreProvider);

  expect(identical(firstEngine, secondEngine), isTrue);
  expect(identical(firstStore, secondStore), isTrue);
});
```

Test that `interactionSessionInitializerProvider` and
`interactionEngineProvider` resolve to the same authority object.

- [ ] **Step 2: Write RED provider override tests**

```dart
test('repository provider can be overridden without replacing engine rules', () {
  final fake = FakeInteractionRepository(
    result: Applied(snapshotRevision1),
  );
  final container = ProviderContainer.test(
    overrides: [
      interactionRepositoryProvider.overrideWithValue(fake),
    ],
  );

  expect(container.read(interactionRepositoryProvider), same(fake));
});
```

- [ ] **Step 3: Write RED mask isolation test**

Create two containers with different
`interactionCapabilityMaskProvider` overrides. Initialize and advance both
engines with the same inputs. Assert equal ProductSnapshot semantics, proving
the mask does not feed the engine graph.

- [ ] **Step 4: Run provider tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/app/providers/interaction_engine_providers_test.dart test/app/providers/ritual_room_data_providers_test.dart test/app/providers/ritual_room_capability_provider_test.dart
```

Expected: FAIL because providers do not exist.

- [ ] **Step 5: Implement pure engine providers**

```dart
final interactionClockProvider = Provider<InteractionClock>(
  (ref) => SystemInteractionClock(),
);

final interactionIdGeneratorProvider = Provider<InteractionIdGenerator>(
  (ref) => SystemInteractionIdGenerator(),
);

final normalizeEngineProvider = Provider<NormalizeEngine>(
  (ref) => RuleBasedNormalizeEngine(),
);

final stateAccumulatorProvider = Provider<StateAccumulator>(
  (ref) => DecayStateAccumulator(decay: 0.65),
);

final strategyEngineProvider = Provider<StrategyEngine>(
  (ref) => RuleBasedStrategyEngine(),
);

final utteranceEngineProvider = Provider<UtteranceEngine>(
  (ref) => RuleBasedUtteranceEngine(),
);

final interactionRuntimeStoreProvider = Provider<InteractionRuntimeStore>(
  (ref) => InMemoryInteractionRuntimeStore(),
);
```

- [ ] **Step 6: Compose the authority provider**

```dart
final interactionEngineProvider = Provider<InteractionEngine>(
  (ref) => InteractionEngine(
    clock: ref.watch(interactionClockProvider),
    idGenerator: ref.watch(interactionIdGeneratorProvider),
    seedSource: ref.watch(interactionSeedSourceProvider),
    normalizeEngine: ref.watch(normalizeEngineProvider),
    stateAccumulator: ref.watch(stateAccumulatorProvider),
    strategyEngine: ref.watch(strategyEngineProvider),
    utteranceEngine: ref.watch(utteranceEngineProvider),
    store: ref.watch(interactionRuntimeStoreProvider),
  ),
);

final interactionEnginePortProvider = Provider<InteractionEnginePort>(
  (ref) => ref.watch(interactionEngineProvider),
);

final interactionSessionInitializerProvider =
    Provider<InteractionSessionInitializer>(
      (ref) => ref.watch(interactionEngineProvider),
    );
```

Do not pass `Ref`, ProviderContainer, or CapabilityMask into InteractionEngine.

- [ ] **Step 7: Compose API and repository providers**

```dart
final interactionMapperProvider = Provider<InteractionMapper>(
  (ref) => InteractionMapper(),
);

final interactionApiProvider = Provider<InteractionApi>(
  (ref) => MockInteractionApi(
    engine: ref.watch(interactionEnginePortProvider),
    mapper: ref.watch(interactionMapperProvider),
  ),
);

final interactionRepositoryProvider = Provider<InteractionRepository>(
  (ref) => InteractionRepositoryImpl(
    api: ref.watch(interactionApiProvider),
    mapper: ref.watch(interactionMapperProvider),
  ),
);
```

Create equivalent content API/mapper/repository providers.

- [ ] **Step 8: Implement the Phase 41 mask provider**

```dart
final interactionCapabilityMaskProvider =
    Provider<InteractionCapabilityMask>(
      (ref) => InteractionCapabilityMask.phase41,
    );
```

The mask exposes `reactionSelection` only. The provider graph for engine/API/
repository must not watch this provider.

- [ ] **Step 9: Add the app-level InputEvent factory**

Define an event-ID seam that tests can override:

```dart
abstract interface class EventIdGenerator {
  String nextEventId();
}
```

Implement:

```dart
import 'dart:math';

final class SecureEventIdGenerator implements EventIdGenerator {
  SecureEventIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextEventId() => List<int>.generate(
    16,
    (_) => _random.nextInt(256),
    growable: false,
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
```

The 128-bit output is opaque; no UI or engine code may parse meaning from it.

```dart
final interactionEventIdGeneratorProvider = Provider<EventIdGenerator>(
  (ref) => SecureEventIdGenerator(),
);

final interactionInputFactoryProvider = Provider<InteractionInputFactory>(
  (ref) => InteractionInputFactory(
    clock: ref.watch(interactionClockProvider),
    idGenerator: ref.watch(interactionEventIdGeneratorProvider),
  ),
);
```

`InteractionInputFactory` creates typed raw events:

```dart
final class InteractionInputFactory {
  InteractionInputFactory({
    required InteractionClock clock,
    required EventIdGenerator idGenerator,
  }) : _clock = clock,
       _idGenerator = idGenerator;

  final InteractionClock _clock;
  final EventIdGenerator _idGenerator;

  InputEvent reaction(String selected) => InputEvent.reaction(
    eventId: _idGenerator.nextEventId(),
    occurredAt: _clock.now(),
    selected: selected,
  );
}
```

Add equivalent `voice`, `freeText`, `futureSignal`, and `strategyPreference`
methods. This factory does not normalize or retain input. Widget callbacks read
this provider instead of reading clock, ID, or engine providers directly.

- [ ] **Step 10: Run provider tests**

Run:

```powershell
cd mobile_v2
flutter test test/app/providers
```

Expected: PASS.

- [ ] **Step 11: Commit**

```powershell
git add mobile_v2/lib/app/input mobile_v2/lib/app/providers/interaction_engine_providers.dart mobile_v2/lib/app/providers/ritual_room_data_providers.dart mobile_v2/lib/app/providers/ritual_room_capability_provider.dart mobile_v2/lib/features/ritual_room/presentation/capability mobile_v2/test/app/providers
git commit -m "feat(41): compose interaction engine with riverpod"
```

### Task 5: Implement the snapshot-driven Ritual Room session Notifier

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/presentation/state/ritual_room_ui_state.dart`
- Create: `mobile_v2/lib/app/providers/ritual_room_session_provider.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/state/ritual_room_ui_state_test.dart`
- Test: `mobile_v2/test/app/providers/ritual_room_session_provider_test.dart`

- [ ] **Step 1: Write RED UI state shape tests**

```dart
test('ready state references room content and the complete snapshot', () {
  final state = RitualRoomReady(
    room: roomContent,
    snapshot: snapshotRevision2,
  );

  expect(state.room, same(roomContent));
  expect(state.snapshot, same(snapshotRevision2));
});
```

The state file must not declare duplicate fields named:

```text
context
memory
strategy
utterance
revision
schemaVersion
```

Those values are read through `state.snapshot`.

- [ ] **Step 2: Write RED room initialization tests**

Extend `interaction_test_doubles.dart`:

```dart
final class FakeRitualRoomRepository implements RitualRoomRepository {
  FakeRitualRoomRepository(this.room);
  final RitualRoomContent room;
  var calls = 0;

  @override
  Future<RitualRoomContent> loadRoom(String ritualRoomId) async {
    calls += 1;
    return room;
  }
}

final class FakeInteractionSessionInitializer
    implements InteractionSessionInitializer {
  FakeInteractionSessionInitializer(this.snapshot);
  final ProductSnapshot snapshot;
  var calls = 0;

  @override
  Future<ProductSnapshot> initialize(String ritualRoomId) async {
    calls += 1;
    return snapshot;
  }
}

final class FakeInteractionRepository implements InteractionRepository {
  FakeInteractionRepository({required this.result});
  AdvanceResult result;
  int? lastExpectedRevision;

  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) async {
    lastExpectedRevision = expectedRevision;
    return result;
  }

  @override
  Future<ProductSnapshot> getSnapshot(String interactionId) async {
    final current = result;
    return switch (current) {
      Applied(:final snapshot) ||
      DuplicateIgnored(:final snapshot) =>
        snapshot,
      AdvanceRejected(:final latestSnapshot) when latestSnapshot != null =>
        latestSnapshot,
      _ => throw StateError('Fake has no snapshot'),
    };
  }
}
```

```dart
test('openRoom loads content then initializes interaction once', () async {
  final roomRepository = FakeRitualRoomRepository(roomContent);
  final initializer = FakeInteractionSessionInitializer(snapshotRevision0);
  final container = ProviderContainer.test(
    overrides: [
      ritualRoomRepositoryProvider.overrideWithValue(roomRepository),
      interactionSessionInitializerProvider.overrideWithValue(initializer),
    ],
  );

  await container
      .read(ritualRoomSessionProvider.notifier)
      .openRoom('shoes_on_room_v1');

  final state = container.read(ritualRoomSessionProvider);
  expect(state, isA<RitualRoomReady>());
  expect(initializer.calls, 1);
});
```

Calling `openRoom` again for the same ready room must not create a second
interaction unless an explicit future reset command is introduced.

- [ ] **Step 3: Write RED submission tests**

Cover:

- request uses current snapshot revision as `expectedRevision`
- `Applied` replaces the complete ProductSnapshot
- `DuplicateIgnored` replaces with the returned latest ProductSnapshot
- `revisionConflict` overwrites with `latestSnapshot`
- `eventIdConflict` overwrites with `latestSnapshot`
- `pipelineFailed` retains the current ProductSnapshot and exposes a transient
  recoverable problem
- no raw InputEvent is stored in RitualRoomUiState
- programmatic voice/free-text/future-signal/strategy inputs use the same
  `submit(InputEvent)` command despite hidden Phase 41 controls

```dart
test('revision conflict uses engine snapshot as last write', () async {
  repository.result = AdvanceRejected(
    code: AdvanceErrorCode.revisionConflict,
    latestSnapshot: snapshotRevision3,
  );

  await container
      .read(ritualRoomSessionProvider.notifier)
      .submit(reactionEvent);

  final state = container.read(ritualRoomSessionProvider);
  expect(state, isA<RitualRoomRecoverableFailure>());
  final failure = state as RitualRoomRecoverableFailure;
  expect(failure.snapshot, same(snapshotRevision3));
  expect(failure.problem.code, AdvanceErrorCode.revisionConflict);
});
```

- [ ] **Step 4: Run session tests and verify RED**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/presentation/state test/app/providers/ritual_room_session_provider_test.dart
```

Expected: FAIL because the UI state union and Notifier do not exist.

- [ ] **Step 5: Implement an immutable UI state union**

```dart
sealed class RitualRoomUiState {
  const RitualRoomUiState();

  ProductSnapshot? get snapshot;
}

sealed class RitualRoomSnapshotState extends RitualRoomUiState {
  const RitualRoomSnapshotState({
    required this.room,
    required this.snapshot,
  });

  final RitualRoomContent room;
  @override
  final ProductSnapshot snapshot;
}

final class RitualRoomIdle extends RitualRoomUiState {
  const RitualRoomIdle();
  @override
  ProductSnapshot? get snapshot => null;
}

final class RitualRoomLoading extends RitualRoomUiState {
  const RitualRoomLoading();
  @override
  ProductSnapshot? get snapshot => null;
}

final class RitualRoomReady extends RitualRoomSnapshotState {
  const RitualRoomReady({
    required super.room,
    required super.snapshot,
  });
}
```

Add:

```dart
final class RitualRoomSubmitting extends RitualRoomSnapshotState {
  const RitualRoomSubmitting({
    required super.room,
    required super.snapshot,
  });
}

final class RitualRoomProblem {
  const RitualRoomProblem(this.code, {this.cause});
  final AdvanceErrorCode? code;
  final Object? cause;
}

final class RitualRoomRecoverableFailure extends RitualRoomSnapshotState {
  const RitualRoomRecoverableFailure({
    required super.room,
    required super.snapshot,
    required this.problem,
  });

  final RitualRoomProblem problem;
}

final class RitualRoomLoadFailure extends RitualRoomUiState {
  const RitualRoomLoadFailure(this.cause);
  final Object cause;

  @override
  ProductSnapshot? get snapshot => null;
}
```

Do not copy snapshot subfields.

- [ ] **Step 6: Implement one NotifierProvider**

```dart
final ritualRoomSessionProvider =
    NotifierProvider<RitualRoomSessionNotifier, RitualRoomUiState>(
      RitualRoomSessionNotifier.new,
    );

final class RitualRoomSessionNotifier extends Notifier<RitualRoomUiState> {
  var _operationEpoch = 0;

  @override
  RitualRoomUiState build() {
    ref.onDispose(() => _operationEpoch += 1);
    return const RitualRoomIdle();
  }
}
```

This is the only mutable Riverpod state provider for the feature. All other
providers are read-only dependency providers.

- [ ] **Step 7: Implement openRoom**

```dart
Future<void> openRoom(String ritualRoomId) async {
  final current = state;
  if (current is RitualRoomReady &&
      current.room.ritualRoomId == ritualRoomId) {
    return;
  }

  final epoch = ++_operationEpoch;
  state = const RitualRoomLoading();
  try {
    final room = await ref
        .read(ritualRoomRepositoryProvider)
        .loadRoom(ritualRoomId);
    final snapshot = await ref
        .read(interactionSessionInitializerProvider)
        .initialize(ritualRoomId);
    if (epoch != _operationEpoch) return;
    state = RitualRoomReady(room: room, snapshot: snapshot);
  } catch (error) {
    if (epoch != _operationEpoch) return;
    state = RitualRoomLoadFailure(error);
  }
}
```

Initialization is composition-internal. It does not call InteractionApi.

- [ ] **Step 8: Implement submit**

```dart
Future<void> submit(InputEvent input) async {
  final current = state;
  if (current is! RitualRoomSnapshotState) return;

  final room = current.room;
  final snapshot = current.snapshot;
  final epoch = ++_operationEpoch;
  state = RitualRoomSubmitting(room: room, snapshot: snapshot);

  final result = await ref.read(interactionRepositoryProvider).advance(
    interactionId: snapshot.interactionId,
    expectedRevision: snapshot.revision,
    input: input,
  );
  if (epoch != _operationEpoch) return;

  state = switch (result) {
    Applied(:final snapshot) ||
    DuplicateIgnored(:final snapshot) =>
      RitualRoomReady(room: room, snapshot: snapshot),
    AdvanceRejected(:final code, :final latestSnapshot)
        when latestSnapshot != null =>
      RitualRoomRecoverableFailure(
        room: room,
        snapshot: latestSnapshot,
        problem: RitualRoomProblem(code),
      ),
    AdvanceRejected(:final code) =>
      RitualRoomRecoverableFailure(
        room: room,
        snapshot: snapshot,
        problem: RitualRoomProblem(code),
      ),
  };
}
```

Do not retain `input` after this invocation. Transport retry, if later added,
must reuse the same request inside the repository call; Riverpod state must not
store raw voice/text for a user-visible retry.

- [ ] **Step 9: Run session tests**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/presentation/state test/app/providers/ritual_room_session_provider_test.dart
```

Expected: PASS.

- [ ] **Step 10: Commit**

```powershell
git add mobile_v2/lib/features/ritual_room/presentation/state mobile_v2/lib/app/providers/ritual_room_session_provider.dart mobile_v2/test/features/ritual_room/presentation/state mobile_v2/test/app/providers/ritual_room_session_provider_test.dart
git commit -m "feat(41): add riverpod ritual room session"
```

### Task 6: Prove provider boundaries and prepare widget integration

**Files:**

- Create: `mobile_v2/test/app/providers/interaction_provider_contract_test.dart`
- Create: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-RIVERPOD-MAPPING.md`
- Modify: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-VALIDATION.md`
- Modify: `mobile_v2/AGENTS.md`

- [ ] **Step 1: Add a full ProviderContainer contract test**

The test must:

1. create `ProviderContainer.test`
2. read the real deterministic engine graph
3. open `shoes_on_room_v1`
4. submit reaction
5. submit raw voice programmatically
6. assert revision 2
7. override the capability mask to hide all controls
8. prove engine execution remains unchanged
9. override the repository with a fake and prove provider isolation

```dart
expect(
  container.read(ritualRoomSessionProvider).snapshot!.revision,
  2,
);
expect(
  container.read(interactionCapabilityMaskProvider).visible,
  {InteractionCapability.reactionSelection},
);
```

- [ ] **Step 2: Add source-boundary assertions**

The test reads source files and fails if:

- `domain/` imports `flutter` or `flutter_riverpod`
- `data/` imports `flutter_riverpod`
- `app/providers/` contains raw ritual utterance literals
- more than one `NotifierProvider` exists for Ritual Room product state
- DTOs are imported by presentation files
- CapabilityMask is read by an engine/data provider

- [ ] **Step 3: Run all integration tests**

Run:

```powershell
cd mobile_v2
flutter test test/features/ritual_room/data test/features/ritual_room/presentation/state test/app/providers
```

Expected: PASS.

- [ ] **Step 4: Run full quality gates**

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

- [ ] **Step 5: Write `41-RIVERPOD-MAPPING.md`**

Record this provider graph:

```text
ProviderScope
├─ InteractionClock Provider
├─ InteractionIdGenerator Provider
├─ EventIdGenerator Provider
├─ InteractionInputFactory Provider
├─ InteractionSeedSource Provider
├─ NormalizeEngine Provider
├─ StateAccumulator Provider
├─ StrategyEngine Provider
├─ UtteranceEngine Provider
├─ InteractionRuntimeStore Provider
├─ InteractionEngine Provider
├─ InteractionEnginePort Provider
├─ InteractionSessionInitializer Provider
├─ InteractionApi Provider
├─ InteractionRepository Provider
├─ RitualContentApi Provider
├─ RitualRoomRepository Provider
├─ InteractionCapabilityMask Provider
└─ RitualRoomSession NotifierProvider  ← only mutable Riverpod node
```

Also record:

- `main.dart` will wrap the future approved UI with `ProviderScope`
- a future app entry watches `ritualRoomSessionProvider`
- widgets render `state.snapshot` and receive callbacks
- widgets never read DTO or concrete repository providers
- ProviderScope/widget integration remains behind the existing visual approval
  gate

- [ ] **Step 6: Update execution instructions**

Add:

```text
Riverpod is an app composition and transient UI orchestration mechanism.
ProductSnapshot remains the product truth; ConsistencyState and ReplayJournal
remain internal to InteractionEngine. Do not add a second Notifier/ViewModel
that mirrors RitualRoomSession state.
```

- [ ] **Step 7: Commit**

```powershell
git add mobile_v2/test/app/providers/interaction_provider_contract_test.dart .planning/phases/41-mobile-v2-runnable-vertical-slice/41-RIVERPOD-MAPPING.md .planning/phases/41-mobile-v2-runnable-vertical-slice/41-VALIDATION.md mobile_v2/AGENTS.md
git commit -m "test(41): verify riverpod interaction boundaries"
```

## Widget integration handoff

After the visual prototype gate is approved:

```dart
void main() {
  runApp(
    const ProviderScope(
      child: BabyTalkApp(),
    ),
  );
}
```

The app-level entry watches only:

```dart
final state = ref.watch(ritualRoomSessionProvider);
final mask = ref.watch(interactionCapabilityMaskProvider);
```

It dispatches commands with:

```dart
final input = ref
    .read(interactionInputFactoryProvider)
    .reaction('running_away');
ref.read(ritualRoomSessionProvider.notifier).submit(input);
```

Inside widget `build`, use `ref.watch`. Inside callbacks, use `ref.read`.
Provider overrides supply fakes in widget tests. The visual UI must not import
engine module providers, API providers, DTOs, mapper implementations, or
concrete repositories.

## Completion gate

This Flutter mapping is complete only when:

- Riverpod exists only in `app/providers/`, app bootstrap, and provider tests
- no code generation is introduced
- InteractionEngine remains the only lifecycle/consistency authority
- the Mock API delegates to the real deterministic engine
- repositories contain conversion logic only
- ProductSnapshot is carried whole through Notifier states
- only one mutable NotifierProvider owns Ritual Room UI orchestration
- CapabilityMask changes UI exposure only
- provider override tests pass
- all semantic and Activation Governor gates pass

## Official references

- Riverpod containers and ProviderScope:
  `https://riverpod.dev/docs/concepts2/containers`
- Riverpod provider overrides:
  `https://riverpod.dev/docs/concepts2/overrides`
- `flutter_riverpod` 3.3.0 API:
  `https://pub.dev/documentation/flutter_riverpod/3.3.0/flutter_riverpod/`
- Flutter app architecture guide:
  `https://docs.flutter.dev/app-architecture/guide`
- Flutter architecture testing:
  `https://docs.flutter.dev/app-architecture/case-study/testing`
