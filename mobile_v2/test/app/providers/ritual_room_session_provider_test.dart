import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/input/event_id_generator.dart';
import 'package:mobile_v2/app/providers/interaction_engine_providers.dart';
import 'package:mobile_v2/app/providers/ritual_room_data_providers.dart';
import 'package:mobile_v2/app/providers/ritual_room_session_provider.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_room_content.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/interaction_repository.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/interaction_outcome_unknown_exception.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/ritual_room_repository.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_session_initializer.dart';
import 'package:mobile_v2/features/ritual_room/presentation/state/ritual_room_ui_state.dart';

import '../../fixtures/interaction_test_fixtures.dart';
import '../../helpers/interaction_test_doubles.dart';

void main() {
  test(
    'openRoom loads content then initializes once for the ready room',
    () async {
      final calls = <String>[];
      final roomRepository = _FakeRitualRoomRepository(
        onLoad: (ritualRoomId) async {
          calls.add('load:$ritualRoomId');
          return _room();
        },
      );
      final initializer = _FakeInitializer(
        onInitialize: (ritualRoomId) async {
          calls.add('initialize:$ritualRoomId');
          return interactionSnapshot();
        },
      );
      final container = _container(
        roomRepository: roomRepository,
        initializer: initializer,
      );

      await container
          .read(ritualRoomSessionProvider.notifier)
          .openRoom(ritualRoomId);
      await container
          .read(ritualRoomSessionProvider.notifier)
          .openRoom(ritualRoomId);

      final state = container.read(ritualRoomSessionProvider);
      expect(state, isA<RitualRoomReady>());
      expect(state.snapshot, same(initializer.snapshots.single));
      expect(calls, ['load:$ritualRoomId', 'initialize:$ritualRoomId']);
      expect(roomRepository.calls, 1);
      expect(initializer.calls, 1);
    },
  );

  test('openRoom exposes a load failure without creating a session', () async {
    final initializer = _FakeInitializer(
      onInitialize: (_) async => interactionSnapshot(),
    );
    final container = _container(
      roomRepository: _FakeRitualRoomRepository(
        onLoad: (_) async => throw StateError('room unavailable'),
      ),
      initializer: initializer,
    );

    await container
        .read(ritualRoomSessionProvider.notifier)
        .openRoom(ritualRoomId);

    expect(
      container.read(ritualRoomSessionProvider),
      isA<RitualRoomLoadFailure>(),
    );
    expect(initializer.calls, 0);
  });

  test('a newer room open prevents stale content from initializing', () async {
    final firstLoad = Completer<RitualRoomContent>();
    final secondLoad = Completer<RitualRoomContent>();
    final initializer = _FakeInitializer(
      onInitialize: (roomId) async => _snapshotFor(roomId, revision: 0),
    );
    final container = _container(
      roomRepository: _FakeRitualRoomRepository(
        onLoad: (roomId) =>
            roomId == 'room-a' ? firstLoad.future : secondLoad.future,
      ),
      initializer: initializer,
    );
    final notifier = container.read(ritualRoomSessionProvider.notifier);

    final firstOpen = notifier.openRoom('room-a');
    final secondOpen = notifier.openRoom('room-b');
    secondLoad.complete(_room(ritualRoomId: 'room-b'));
    await secondOpen;
    firstLoad.complete(_room(ritualRoomId: 'room-a'));
    await firstOpen;

    final state = container.read(ritualRoomSessionProvider) as RitualRoomReady;
    expect(state.room.ritualRoomId, 'room-b');
    expect(state.snapshot.ritualRoomId, 'room-b');
    expect(initializer.roomIds, ['room-b']);
  });

  test('disposed open ignores completion and does not initialize', () async {
    final load = Completer<RitualRoomContent>();
    final initializer = _FakeInitializer(
      onInitialize: (_) async => interactionSnapshot(),
    );
    final container = _container(
      roomRepository: _FakeRitualRoomRepository(onLoad: (_) => load.future),
      initializer: initializer,
    );
    final open = container
        .read(ritualRoomSessionProvider.notifier)
        .openRoom(ritualRoomId);

    container.dispose();
    load.complete(_room());

    await open;
    expect(initializer.calls, 0);
  });

  test('submit preserves the current snapshot while pending', () async {
    final advance = Completer<AdvanceResult>();
    final repository = _FakeInteractionRepository(
      onAdvance:
          ({
            required interactionId,
            required expectedRevision,
            required input,
          }) => advance.future,
    );
    final container = await _openedContainer(
      interactionRepository: repository,
      snapshot: interactionSnapshot(revision: 2),
    );
    final notifier = container.read(ritualRoomSessionProvider.notifier);

    final pending = notifier.submit(interactionInputs.first);
    final submitting =
        container.read(ritualRoomSessionProvider) as RitualRoomSubmitting;

    expect(submitting.snapshot.revision, 2);
    expect(repository.lastExpectedRevision, 2);
    advance.complete(AdvanceApplied(interactionSnapshot(revision: 3)));
    await pending;

    expect(container.read(ritualRoomSessionProvider), isA<RitualRoomReady>());
    expect(container.read(ritualRoomSessionProvider).snapshot?.revision, 3);
  });

  test(
    'two rapid reaction taps allocate and submit exactly one command',
    () async {
      final advance = Completer<AdvanceResult>();
      final ids = _CountingEventIdGenerator();
      final repository = _FakeInteractionRepository(
        onAdvance:
            ({
              required interactionId,
              required expectedRevision,
              required input,
            }) => advance.future,
      );
      final container = await _openedContainer(
        interactionRepository: repository,
        snapshot: interactionSnapshot(),
        eventIdGenerator: ids,
      );
      final notifier = container.read(ritualRoomSessionProvider.notifier);

      final first = notifier.submitReaction('not_ready');
      final second = notifier.submitReaction('self');
      await second;

      final submitting =
          container.read(ritualRoomSessionProvider) as RitualRoomSubmitting;
      expect(submitting.selectedReaction, 'not_ready');
      expect(ids.calls, 1);
      expect(repository.inputs, hasLength(1));
      expect(
        (repository.inputs.single.payload as ReactionSelectionPayload).selected,
        'not_ready',
      );

      advance.complete(AdvanceApplied(interactionSnapshot(revision: 1)));
      await first;

      final ready =
          container.read(ritualRoomSessionProvider) as RitualRoomReady;
      expect(ready.snapshot.revision, 1);
      expect(ids.calls, 1);
      expect(repository.inputs, hasLength(1));
    },
  );

  test(
    'commit then lost response retries the exact command and reconciles duplicate',
    () async {
      final harness = InteractionEngineHarness();
      final initial = await harness.engine.initialize(ritualRoomId);
      final ids = _CountingEventIdGenerator();
      final repository = _CommitThenLoseResponseRepository(harness);
      final container = await _openedContainer(
        interactionRepository: repository,
        snapshot: initial,
        eventIdGenerator: ids,
      );
      final notifier = container.read(ritualRoomSessionProvider.notifier);

      await notifier.submitReaction('not_ready');

      final unknown =
          container.read(ritualRoomSessionProvider) as RitualRoomUnknownOutcome;
      expect(unknown.selectedReaction, 'not_ready');
      expect(unknown.isRetrying, isFalse);
      expect(repository.firstCommittedResult, isA<AdvanceApplied>());
      expect(repository.calls, hasLength(1));
      expect(ids.calls, 1);

      await notifier.retryPendingEvent();

      expect(repository.calls, hasLength(2));
      expect(repository.calls[1].input, same(repository.calls[0].input));
      expect(
        repository.calls[1].input.eventId,
        repository.calls[0].input.eventId,
      );
      expect(
        repository.calls[1].interactionId,
        repository.calls[0].interactionId,
      );
      expect(
        repository.calls[1].expectedRevision,
        repository.calls[0].expectedRevision,
      );
      expect(repository.calls.first.expectedRevision, 0);
      expect(repository.retryResult, isA<AdvanceDuplicateIgnored>());
      expect(ids.calls, 1);
      final ready =
          container.read(ritualRoomSessionProvider) as RitualRoomReady;
      expect(ready.snapshot.revision, 1);
    },
  );

  test(
    'unknown outcome retains one command and repeated retry taps remain single flight',
    () async {
      final retry = Completer<AdvanceResult>();
      final ids = _CountingEventIdGenerator();
      var call = 0;
      final repository = _FakeInteractionRepository(
        onAdvance:
            ({
              required interactionId,
              required expectedRevision,
              required input,
            }) {
              call += 1;
              if (call == 1) {
                throw const InteractionOutcomeUnknownException(
                  reason:
                      InteractionOutcomeUnknownReason.responseLostAfterDispatch,
                );
              }
              return retry.future;
            },
      );
      final container = await _openedContainer(
        interactionRepository: repository,
        snapshot: interactionSnapshot(),
        eventIdGenerator: ids,
      );
      final notifier = container.read(ritualRoomSessionProvider.notifier);
      await notifier.submitReaction('not_ready');

      final firstRetry = notifier.retryPendingEvent();
      final ignoredRetry = notifier.retryPendingEvent();
      await ignoredRetry;
      await notifier.submitReaction('self');

      expect(repository.inputs, hasLength(2));
      expect(repository.inputs[1], same(repository.inputs[0]));
      expect(ids.calls, 1);
      expect(
        (container.read(ritualRoomSessionProvider) as RitualRoomUnknownOutcome)
            .isRetrying,
        isTrue,
      );

      retry.completeError(
        const InteractionOutcomeUnknownException(
          reason: InteractionOutcomeUnknownReason.connectionClosedAfterDispatch,
        ),
      );
      await firstRetry;

      final unknown =
          container.read(ritualRoomSessionProvider) as RitualRoomUnknownOutcome;
      expect(unknown.isRetrying, isFalse);
      expect(repository.inputs, hasLength(2));
      expect(ids.calls, 1);
    },
  );

  test(
    'authoritative rejection and non-unknown exception clear retry command',
    () async {
      final cases = <Future<AdvanceResult> Function(int call)>[
        (call) async => call == 1
            ? const AdvanceRejected(code: AdvanceErrorCode.pipelineFailed)
            : AdvanceApplied(interactionSnapshot(revision: 1)),
        (call) async {
          if (call == 1) {
            throw StateError('known failure');
          }
          return AdvanceApplied(interactionSnapshot(revision: 1));
        },
        (call) async => call == 1
            ? AdvanceRejected(
                code: AdvanceErrorCode.revisionConflict,
                latestSnapshot: interactionSnapshot(revision: 7),
              )
            : AdvanceApplied(interactionSnapshot(revision: 8)),
      ];

      for (final resultForCall in cases) {
        final ids = _CountingEventIdGenerator();
        var call = 0;
        final repository = _FakeInteractionRepository(
          onAdvance:
              ({
                required interactionId,
                required expectedRevision,
                required input,
              }) => resultForCall(++call),
        );
        final container = await _openedContainer(
          interactionRepository: repository,
          snapshot: interactionSnapshot(),
          eventIdGenerator: ids,
        );
        final notifier = container.read(ritualRoomSessionProvider.notifier);

        await notifier.submitReaction('not_ready');
        await notifier.retryPendingEvent();
        expect(repository.inputs, hasLength(1));

        await notifier.submitReaction('self');
        expect(repository.inputs, hasLength(2));
        expect(repository.inputs[1], isNot(same(repository.inputs[0])));
        expect(
          repository.inputs[1].eventId,
          isNot(repository.inputs[0].eventId),
        );
        expect(ids.calls, 2);
      }
    },
  );

  test(
    'room switch reload and disposal abandon retry without replacement submission',
    () async {
      for (final lifecycle in ['switch', 'reload', 'dispose']) {
        final ids = _CountingEventIdGenerator();
        final repository = _FakeInteractionRepository(
          onAdvance:
              ({
                required interactionId,
                required expectedRevision,
                required input,
              }) async => throw const InteractionOutcomeUnknownException(
                reason: InteractionOutcomeUnknownReason.timeoutAfterDispatch,
              ),
        );
        final container = _container(
          roomRepository: _FakeRitualRoomRepository(
            onLoad: (roomId) async => _room(ritualRoomId: roomId),
          ),
          initializer: _FakeInitializer(
            onInitialize: (roomId) async => _snapshotFor(roomId, revision: 0),
          ),
          interactionRepository: repository,
          eventIdGenerator: ids,
        );
        final notifier = container.read(ritualRoomSessionProvider.notifier);
        await notifier.openRoom('room-a');
        await notifier.submitReaction('not_ready');

        switch (lifecycle) {
          case 'switch':
            await notifier.openRoom('room-b');
            await notifier.retryPendingEvent();
          case 'reload':
            await notifier.reloadRoom('room-a');
            await notifier.retryPendingEvent();
          case 'dispose':
            container.dispose();
        }

        expect(repository.inputs, hasLength(1));
        expect(ids.calls, 1);
      }
    },
  );

  test('applied and duplicate results replace the whole snapshot', () async {
    for (final result in <AdvanceResult>[
      AdvanceApplied(interactionSnapshot(revision: 3)),
      AdvanceDuplicateIgnored(interactionSnapshot(revision: 4)),
    ]) {
      final repository = _FakeInteractionRepository(
        onAdvance:
            ({
              required interactionId,
              required expectedRevision,
              required input,
            }) async => result,
      );
      final container = await _openedContainer(
        interactionRepository: repository,
        snapshot: interactionSnapshot(revision: 2),
      );

      await container
          .read(ritualRoomSessionProvider.notifier)
          .submit(interactionInputs.first);

      final state =
          container.read(ritualRoomSessionProvider) as RitualRoomReady;
      expect(state.snapshot, same(result.snapshot));
      expect(repository.lastInteractionId, interactionId);
      expect(repository.lastExpectedRevision, 2);
    }
  });

  test(
    'revision and event-ID conflicts use the engine latest snapshot',
    () async {
      for (final code in [
        AdvanceErrorCode.revisionConflict,
        AdvanceErrorCode.eventIdConflict,
      ]) {
        final latest = interactionSnapshot(revision: 7);
        final container = await _openedContainer(
          interactionRepository: _FakeInteractionRepository(
            onAdvance:
                ({
                  required interactionId,
                  required expectedRevision,
                  required input,
                }) async => AdvanceRejected(code: code, latestSnapshot: latest),
          ),
          snapshot: interactionSnapshot(revision: 2),
        );

        await container
            .read(ritualRoomSessionProvider.notifier)
            .submit(interactionInputs.first);

        final state =
            container.read(ritualRoomSessionProvider)
                as RitualRoomRecoverableFailure;
        expect(state.snapshot, same(latest));
        expect(state.problem.code, code);
      }
    },
  );

  test('pipeline failure retains the last usable snapshot', () async {
    final original = interactionSnapshot(revision: 2);
    final cause = StateError('pipeline failed');
    final container = await _openedContainer(
      interactionRepository: _FakeInteractionRepository(
        onAdvance:
            ({
              required interactionId,
              required expectedRevision,
              required input,
            }) async =>
                const AdvanceRejected(code: AdvanceErrorCode.pipelineFailed),
      ),
      snapshot: original,
    );

    await container
        .read(ritualRoomSessionProvider.notifier)
        .submit(interactionInputs.first);

    final state =
        container.read(ritualRoomSessionProvider)
            as RitualRoomRecoverableFailure;
    expect(state.snapshot, same(original));
    expect(state.problem.code, AdvanceErrorCode.pipelineFailed);
    expect(state.problem.cause, isNull);

    final throwingContainer = await _openedContainer(
      interactionRepository: _FakeInteractionRepository(
        onAdvance:
            ({
              required interactionId,
              required expectedRevision,
              required input,
            }) async => throw cause,
      ),
      snapshot: original,
    );
    await throwingContainer
        .read(ritualRoomSessionProvider.notifier)
        .submit(interactionInputs.first);
    final thrownState =
        throwingContainer.read(ritualRoomSessionProvider)
            as RitualRoomRecoverableFailure;
    expect(thrownState.snapshot, same(original));
    expect(thrownState.problem.code, isNull);
    expect(thrownState.problem.cause, same(cause));
  });

  test('all five input variants use the same submit command', () async {
    final repository = _FakeInteractionRepository(
      onAdvance:
          ({
            required interactionId,
            required expectedRevision,
            required input,
          }) async => AdvanceApplied(
            interactionSnapshot(revision: expectedRevision + 1),
          ),
    );
    final container = await _openedContainer(
      interactionRepository: repository,
      snapshot: interactionSnapshot(),
    );
    final notifier = container.read(ritualRoomSessionProvider.notifier);

    for (final input in interactionInputs) {
      await notifier.submit(input);
    }

    expect(repository.inputs, interactionInputs);
    expect(repository.expectedRevisions, [0, 1, 2, 3, 4]);
    expect(repository.inputs.map((input) => input.type), InputEventType.values);
    expect(container.read(ritualRoomSessionProvider).snapshot?.revision, 5);
  });

  test('a newer open invalidates a stale submit completion', () async {
    final advance = Completer<AdvanceResult>();
    final repository = _FakeInteractionRepository(
      onAdvance:
          ({
            required interactionId,
            required expectedRevision,
            required input,
          }) => advance.future,
    );
    final roomRepository = _FakeRitualRoomRepository(
      onLoad: (roomId) async => _room(ritualRoomId: roomId),
    );
    final initializer = _FakeInitializer(
      onInitialize: (roomId) async => _snapshotFor(roomId, revision: 0),
    );
    final container = _container(
      roomRepository: roomRepository,
      initializer: initializer,
      interactionRepository: repository,
    );
    final notifier = container.read(ritualRoomSessionProvider.notifier);
    await notifier.openRoom('room-a');
    final pending = notifier.submit(interactionInputs.first);

    await notifier.openRoom('room-b');
    advance.complete(AdvanceApplied(_snapshotFor('room-a', revision: 1)));
    await pending;

    final state = container.read(ritualRoomSessionProvider) as RitualRoomReady;
    expect(state.room.ritualRoomId, 'room-b');
    expect(state.snapshot.ritualRoomId, 'room-b');
  });

  test('provider source contains exactly one mutable NotifierProvider', () {
    final providerSources = Directory('lib/app/providers')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(
      RegExp(r'\bNotifierProvider<').allMatches(providerSources).length,
      1,
    );
    expect(providerSources, isNot(contains('StateNotifierProvider')));
  });
}

ProviderContainer _container({
  required RitualRoomRepository roomRepository,
  required InteractionSessionInitializer initializer,
  InteractionRepository? interactionRepository,
  EventIdGenerator? eventIdGenerator,
}) => ProviderContainer.test(
  overrides: [
    ritualRoomRepositoryProvider.overrideWithValue(roomRepository),
    interactionSessionInitializerProvider.overrideWithValue(initializer),
    if (interactionRepository != null)
      interactionRepositoryProvider.overrideWithValue(interactionRepository),
    if (eventIdGenerator != null)
      interactionEventIdGeneratorProvider.overrideWithValue(eventIdGenerator),
  ],
);

Future<ProviderContainer> _openedContainer({
  required InteractionRepository interactionRepository,
  required ProductSnapshot snapshot,
  EventIdGenerator? eventIdGenerator,
}) async {
  final container = _container(
    roomRepository: _FakeRitualRoomRepository(onLoad: (_) async => _room()),
    initializer: _FakeInitializer(onInitialize: (_) async => snapshot),
    interactionRepository: interactionRepository,
    eventIdGenerator: eventIdGenerator,
  );
  await container
      .read(ritualRoomSessionProvider.notifier)
      .openRoom(ritualRoomId);
  return container;
}

final class _FakeRitualRoomRepository implements RitualRoomRepository {
  _FakeRitualRoomRepository({required this.onLoad});

  final Future<RitualRoomContent> Function(String ritualRoomId) onLoad;
  var calls = 0;

  @override
  Future<RitualRoomContent> loadRoom(String ritualRoomId) {
    calls += 1;
    return onLoad(ritualRoomId);
  }
}

final class _FakeInitializer implements InteractionSessionInitializer {
  _FakeInitializer({required this.onInitialize});

  final Future<ProductSnapshot> Function(String ritualRoomId) onInitialize;
  final roomIds = <String>[];
  final snapshots = <ProductSnapshot>[];
  int get calls => roomIds.length;

  @override
  Future<ProductSnapshot> initialize(String ritualRoomId) async {
    roomIds.add(ritualRoomId);
    final snapshot = await onInitialize(ritualRoomId);
    snapshots.add(snapshot);
    return snapshot;
  }
}

typedef _Advance =
    Future<AdvanceResult> Function({
      required String interactionId,
      required int expectedRevision,
      required InputEvent input,
    });

final class _FakeInteractionRepository implements InteractionRepository {
  _FakeInteractionRepository({required this.onAdvance});

  final _Advance onAdvance;
  final inputs = <InputEvent>[];
  final expectedRevisions = <int>[];
  String? lastInteractionId;
  int? lastExpectedRevision;

  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) {
    lastInteractionId = interactionId;
    lastExpectedRevision = expectedRevision;
    expectedRevisions.add(expectedRevision);
    inputs.add(input);
    return onAdvance(
      interactionId: interactionId,
      expectedRevision: expectedRevision,
      input: input,
    );
  }

  @override
  Future<ProductSnapshot> getSnapshot(String interactionId) async =>
      throw UnsupportedError('not used by session orchestration');
}

final class _CountingEventIdGenerator implements EventIdGenerator {
  var calls = 0;

  @override
  String nextEventId() => 'reaction-event-${++calls}';
}

final class _RecordedAdvanceCall {
  const _RecordedAdvanceCall({
    required this.input,
    required this.interactionId,
    required this.expectedRevision,
  });

  final InputEvent input;
  final String interactionId;
  final int expectedRevision;
}

final class _CommitThenLoseResponseRepository implements InteractionRepository {
  _CommitThenLoseResponseRepository(this.harness);

  final InteractionEngineHarness harness;
  final calls = <_RecordedAdvanceCall>[];
  AdvanceResult? firstCommittedResult;
  AdvanceResult? retryResult;

  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) async {
    calls.add(
      _RecordedAdvanceCall(
        input: input,
        interactionId: interactionId,
        expectedRevision: expectedRevision,
      ),
    );
    final result = await harness.engine.advance(
      interactionId: interactionId,
      expectedRevision: expectedRevision,
      input: input,
    );
    if (calls.length == 1) {
      firstCommittedResult = result;
      throw const InteractionOutcomeUnknownException(
        reason: InteractionOutcomeUnknownReason.responseLostAfterDispatch,
      );
    }
    retryResult = result;
    return result;
  }

  @override
  Future<ProductSnapshot> getSnapshot(String interactionId) async =>
      (await harness.engine.getSnapshot(interactionId))!;
}

RitualRoomContent _room({String ritualRoomId = 'shoes_on_room_v1'}) =>
    RitualRoomContent(
      ritualRoomId: ritualRoomId,
      roomName: 'Shoes On',
      routineAnchor: 'getting ready to go outside',
      anchorPhrase: 'Shoes on.',
      chineseHelper: '穿鞋啦。',
      illustration: const RitualIllustration(
        assetPath: 'assets/illustrations/rituals/shoes_on/shoes_on.png',
        status: 'approved',
      ),
      bootstrapUtterance: const RitualBootstrapUtterance(
        primary: "Let's put your shoes on.",
        zhHelper: '我们来穿鞋吧。',
      ),
      actionCue: 'Hold one shoe nearby.',
      audio: const RitualAudioContent(
        available: false,
        label: 'Play',
        assetReference: null,
      ),
      reactionPrompt: 'What is happening now?',
      reactionChoices: const [
        RitualReactionChoice(id: 'joining_action', label: 'Joining'),
      ],
      pendingCopy: 'Finding the next words...',
      reassurance: 'You can keep it simple.',
      quietExit: 'Pause for now',
      governanceEvidence: const RitualGovernanceEvidence(
        contextSeedId: 'shoes-on-seed',
        joinabilityHypothesis: 'shared_action_available',
        governorDecision: 'explore',
        productionGardenStatus: 'unchanged',
      ),
    );

ProductSnapshot _snapshotFor(String roomId, {required int revision}) {
  final base = interactionSnapshot(revision: revision);
  return ProductSnapshot(
    schemaVersion: base.schemaVersion,
    revision: base.revision,
    interactionId: 'interaction-$roomId',
    ritualRoomId: roomId,
    anchor: base.anchor,
    normalizedContext: base.normalizedContext,
    memory: base.memory,
    strategy: base.strategy,
    utterance: base.utterance,
    metadata: base.metadata,
  );
}
