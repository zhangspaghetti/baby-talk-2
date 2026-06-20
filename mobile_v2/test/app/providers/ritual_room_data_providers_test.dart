import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/input/event_id_generator.dart';
import 'package:mobile_v2/app/providers/interaction_engine_providers.dart';
import 'package:mobile_v2/app/providers/ritual_room_data_providers.dart';
import 'package:mobile_v2/features/ritual_room/data/datasources/interaction_api.dart';
import 'package:mobile_v2/features/ritual_room/data/datasources/ritual_content_api.dart';
import 'package:mobile_v2/features/ritual_room/data/mappers/interaction_mapper.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/interaction_repository.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_clock.dart';

import '../../fixtures/interaction_test_fixtures.dart';
import '../../helpers/interaction_test_doubles.dart';

void main() {
  test('data graph resolves replaceable APIs and repositories', () {
    final container = ProviderContainer.test();

    expect(container.read(interactionApiProvider), isA<InteractionApi>());
    expect(container.read(ritualContentApiProvider), isA<RitualContentApi>());
    expect(
      identical(
        container.read(interactionRepositoryProvider),
        container.read(interactionRepositoryProvider),
      ),
      isTrue,
    );
    expect(
      identical(
        container.read(ritualRoomRepositoryProvider),
        container.read(ritualRoomRepositoryProvider),
      ),
      isTrue,
    );
  });

  test('API and repository providers accept public overrides', () {
    final api = FakeInteractionApi(
      advanceResponse: const InteractionMapper().resultFromDomain(
        AdvanceApplied(interactionSnapshot(revision: 1)),
      ),
      snapshotResponse: const InteractionMapper().snapshotFromDomain(
        interactionSnapshot(),
      ),
    );
    final repository = _FakeInteractionRepository();
    final container = ProviderContainer.test(
      overrides: [
        interactionApiProvider.overrideWithValue(api),
        interactionRepositoryProvider.overrideWithValue(repository),
      ],
    );

    expect(container.read(interactionApiProvider), same(api));
    expect(container.read(interactionRepositoryProvider), same(repository));
  });

  test('input factory creates all five typed events from override seams', () {
    final clock = _FixedClock();
    final ids = _SequenceEventIds();
    final container = ProviderContainer.test(
      overrides: [
        interactionClockProvider.overrideWithValue(clock),
        interactionEventIdGeneratorProvider.overrideWithValue(ids),
      ],
    );
    final factory = container.read(interactionInputFactoryProvider);

    final events = [
      factory.reaction('joining_action'),
      factory.voice('shared action'),
      factory.freeText('still nearby'),
      factory.futureSignal(signal: 'shared_action', value: 'available'),
      factory.strategyPreference('reduce_options'),
    ];

    expect(events.map((event) => event.type), InputEventType.values);
    expect(events.map((event) => event.eventId), [
      'event-1',
      'event-2',
      'event-3',
      'event-4',
      'event-5',
    ]);
    expect(events.map((event) => event.occurredAt).toSet(), {
      DateTime.utc(2026, 6, 20, 13),
    });
    expect(
      (events[0].payload as ReactionSelectionPayload).selected,
      'joining_action',
    );
    expect(
      (events[1].payload as VoiceObservationPayload).transcript,
      'shared action',
    );
    expect((events[2].payload as FreeTextPayload).text, 'still nearby');
    expect((events[3].payload as FutureSignalPayload).signal, 'shared_action');
    expect(
      (events[4].payload as StrategyPreferencePayload).preference,
      'reduce_options',
    );
  });

  test('secure event IDs are opaque 128-bit lowercase hex', () {
    final generator = SecureEventIdGenerator(random: _ZeroRandom());

    expect(generator.nextEventId(), matches(RegExp(r'^[0-9a-f]{32}$')));
  });
}

final class _FixedClock implements InteractionClock {
  @override
  DateTime now() => DateTime.utc(2026, 6, 20, 13);
}

final class _SequenceEventIds implements EventIdGenerator {
  var _next = 1;

  @override
  String nextEventId() => 'event-${_next++}';
}

final class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

final class _FakeInteractionRepository implements InteractionRepository {
  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) async => AdvanceApplied(interactionSnapshot(revision: 1));

  @override
  Future<ProductSnapshot> getSnapshot(String interactionId) async =>
      interactionSnapshot();
}
