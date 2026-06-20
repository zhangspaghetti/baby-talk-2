import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/providers/interaction_engine_providers.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/interaction_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/interaction_engine_port.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/normalize_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/state_accumulator.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/strategy_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/utterance_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_clock.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_id_generator.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_store.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_seed_source.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_session_initializer.dart';

import '../../fixtures/interaction_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider graph builds one engine over one runtime store', () {
    final container = ProviderContainer.test();

    final engine = container.read(interactionEngineProvider);
    final port = container.read(interactionEnginePortProvider);
    final initializer = container.read(interactionSessionInitializerProvider);
    final store =
        container.read(interactionRuntimeStoreProvider)
            as InMemoryInteractionRuntimeStore;

    expect(engine, isA<InteractionEngine>());
    expect(port, isA<InteractionEnginePort>());
    expect(initializer, isA<InteractionSessionInitializer>());
    expect(
      identical(engine, container.read(interactionEngineProvider)),
      isTrue,
    );
    expect(identical(engine, port), isTrue);
    expect(identical(engine, initializer), isTrue);
    expect(
      identical(store, container.read(interactionRuntimeStoreProvider)),
      isTrue,
    );
  });

  test('public providers replace every engine dependency', () async {
    final clock = _FixedClock();
    final ids = _FixedInteractionIds();
    final seed = _FixedSeedSource();
    final normalize = RuleBasedNormalizeEngine();
    final accumulator = DecayStateAccumulator(decay: 0.5);
    final strategy = RuleBasedStrategyEngine();
    final utterance = RuleBasedUtteranceEngine();
    final store = InMemoryInteractionRuntimeStore();
    final container = ProviderContainer.test(
      overrides: [
        interactionClockProvider.overrideWithValue(clock),
        interactionIdGeneratorProvider.overrideWithValue(ids),
        interactionSeedSourceProvider.overrideWithValue(seed),
        normalizeEngineProvider.overrideWithValue(normalize),
        stateAccumulatorProvider.overrideWithValue(accumulator),
        strategyEngineProvider.overrideWithValue(strategy),
        utteranceEngineProvider.overrideWithValue(utterance),
        interactionRuntimeStoreProvider.overrideWithValue(store),
      ],
    );

    expect(container.read(interactionClockProvider), same(clock));
    expect(container.read(interactionIdGeneratorProvider), same(ids));
    expect(container.read(interactionSeedSourceProvider), same(seed));
    expect(container.read(normalizeEngineProvider), same(normalize));
    expect(container.read(stateAccumulatorProvider), same(accumulator));
    expect(container.read(strategyEngineProvider), same(strategy));
    expect(container.read(utteranceEngineProvider), same(utterance));
    expect(container.read(interactionRuntimeStoreProvider), same(store));

    final snapshot = await container
        .read(interactionSessionInitializerProvider)
        .initialize(ritualRoomId);
    expect(snapshot.interactionId, 'override-interaction');
    expect(snapshot.metadata.updatedAt, DateTime.utc(2026, 6, 20, 12));
    expect(store.read(snapshot.interactionId)?.snapshot, same(snapshot));
  });

  test('default seed adapter initializes from stable room content', () async {
    final container = ProviderContainer.test();

    final snapshot = await container
        .read(interactionSessionInitializerProvider)
        .initialize(ritualRoomId);
    final store =
        container.read(interactionRuntimeStoreProvider)
            as InMemoryInteractionRuntimeStore;

    expect(snapshot.ritualRoomId, ritualRoomId);
    expect(snapshot.anchor, 'Shoes on.');
    expect(snapshot.revision, 0);
    expect(store.read(snapshot.interactionId)?.snapshot, same(snapshot));
  });
}

final class _FixedClock implements InteractionClock {
  @override
  DateTime now() => DateTime.utc(2026, 6, 20, 12);
}

final class _FixedInteractionIds implements InteractionIdGenerator {
  @override
  String generate() => 'override-interaction';
}

final class _FixedSeedSource implements InteractionSeedSource {
  @override
  Future<InteractionSeed> load(String ritualRoomId) async => InteractionSeed(
    anchor: 'test anchor',
    normalizedContext: interactionNormalizedInput('shared_action'),
    memory: interactionMemory('shared_action'),
    strategy: interactionStrategy(),
    utterance: interactionUtterance(),
  );
}
