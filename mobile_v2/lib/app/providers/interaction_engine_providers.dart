import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ritual_room/domain/engine/interaction_engine.dart';
import '../../features/ritual_room/domain/engine/interaction_engine_port.dart';
import '../../features/ritual_room/domain/engine/normalize_engine.dart';
import '../../features/ritual_room/domain/engine/state_accumulator.dart';
import '../../features/ritual_room/domain/engine/strategy_engine.dart';
import '../../features/ritual_room/domain/engine/utterance_engine.dart';
import '../../features/ritual_room/domain/runtime/interaction_clock.dart';
import '../../features/ritual_room/domain/runtime/interaction_id_generator.dart';
import '../../features/ritual_room/domain/runtime/interaction_runtime_store.dart';
import '../../features/ritual_room/domain/runtime/interaction_seed_source.dart';
import '../../features/ritual_room/domain/runtime/interaction_session_initializer.dart';
import '../../features/ritual_room/domain/runtime/ritual_room_interaction_seed_source.dart';
import '../input/event_id_generator.dart';
import '../input/interaction_input_factory.dart';
import 'ritual_room_data_providers.dart';

final interactionClockProvider = Provider<InteractionClock>(
  (ref) => const SystemInteractionClock(),
);

final interactionEventIdGeneratorProvider = Provider<EventIdGenerator>(
  (ref) => SecureEventIdGenerator(),
);

final interactionIdGeneratorProvider = Provider<InteractionIdGenerator>(
  (ref) => SecureInteractionIdGenerator(),
);

final interactionInputFactoryProvider = Provider<InteractionInputFactory>(
  (ref) => InteractionInputFactory(
    clock: ref.watch(interactionClockProvider),
    idGenerator: ref.watch(interactionEventIdGeneratorProvider),
  ),
);

final interactionSeedSourceProvider = Provider<InteractionSeedSource>(
  (ref) => RitualRoomInteractionSeedSource(
    repository: ref.watch(ritualRoomRepositoryProvider),
  ),
);

final normalizeEngineProvider = Provider<NormalizeEngine>(
  (ref) => RuleBasedNormalizeEngine(),
);

final stateAccumulatorProvider = Provider<StateAccumulator>(
  (ref) => DecayStateAccumulator(),
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

final interactionEngineProvider = Provider<InteractionEngine>(
  (ref) => InteractionEngine(
    clock: ref.watch(interactionClockProvider),
    idGenerator: ref.watch(interactionIdGeneratorProvider),
    seedSource: ref.watch(interactionSeedSourceProvider),
    store: ref.watch(interactionRuntimeStoreProvider),
    normalizeEngine: ref.watch(normalizeEngineProvider),
    stateAccumulator: ref.watch(stateAccumulatorProvider),
    strategyEngine: ref.watch(strategyEngineProvider),
    utteranceEngine: ref.watch(utteranceEngineProvider),
  ),
);

final interactionEnginePortProvider = Provider<InteractionEnginePort>(
  (ref) => ref.watch(interactionEngineProvider),
);

final interactionSessionInitializerProvider =
    Provider<InteractionSessionInitializer>(
      (ref) => ref.watch(interactionEngineProvider),
    );
