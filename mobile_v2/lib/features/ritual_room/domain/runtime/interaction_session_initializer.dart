import '../models/product_snapshot.dart';
import 'interaction_clock.dart';
import 'interaction_id_generator.dart';
import 'interaction_runtime_state.dart';
import 'interaction_runtime_store.dart';
import 'interaction_seed_source.dart';

abstract interface class InteractionSessionInitializer {
  Future<ProductSnapshot> initialize(String ritualRoomId);
}

final class SeededInteractionSessionInitializer
    implements InteractionSessionInitializer {
  const SeededInteractionSessionInitializer({
    required InteractionClock clock,
    required InteractionIdGenerator idGenerator,
    required InteractionSeedSource seedSource,
    required InteractionRuntimeStore store,
  }) : _clock = clock,
       _idGenerator = idGenerator,
       _seedSource = seedSource,
       _store = store;

  final InteractionClock _clock;
  final InteractionIdGenerator _idGenerator;
  final InteractionSeedSource _seedSource;
  final InteractionRuntimeStore _store;

  @override
  Future<ProductSnapshot> initialize(String ritualRoomId) async {
    final seed = await _seedSource.load(ritualRoomId);
    final snapshot = ProductSnapshot.initial(
      interactionId: _idGenerator.generate(),
      ritualRoomId: ritualRoomId,
      anchor: seed.anchor,
      normalizedContext: seed.normalizedContext,
      memory: seed.memory,
      strategy: seed.strategy,
      activeUtterance: seed.activeUtterance,
      updatedAt: _clock.now(),
    );
    await _store.create(InteractionRuntimeState.initial(snapshot));
    return snapshot;
  }
}
