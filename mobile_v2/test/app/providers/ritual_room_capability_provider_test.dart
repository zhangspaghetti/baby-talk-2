import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/providers/interaction_engine_providers.dart';
import 'package:mobile_v2/app/providers/ritual_room_capability_provider.dart';
import 'package:mobile_v2/app/providers/ritual_room_data_providers.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/utterance_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/active_utterance_source.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_seed_source.dart';
import 'package:mobile_v2/features/ritual_room/presentation/capability/interaction_capability_mask.dart';

import '../../fixtures/interaction_test_fixtures.dart';

void main() {
  test(
    'engine v1 supports all channels while Phase 41 exposes reaction only',
    () {
      expect(EngineCapabilities.v1.supported, {
        InteractionCapability.reactionSelection,
        InteractionCapability.voiceObservation,
        InteractionCapability.freeText,
        InteractionCapability.futureSignal,
        InteractionCapability.strategyPreference,
      });
      expect(InteractionCapabilityMask.phase41.visible, {
        InteractionCapability.reactionSelection,
      });
      expect(
        InteractionCapabilityMask.phase41.exposes(
          InteractionCapability.voiceObservation,
        ),
        isFalse,
      );
    },
  );

  test('capability mask override changes visibility only', () async {
    final container = ProviderContainer.test(
      overrides: [
        interactionSeedSourceProvider.overrideWithValue(_FixedSeedSource()),
        utteranceEngineProvider.overrideWithValue(
          RuleBasedUtteranceEngine(source: _ActiveSource()),
        ),
        interactionCapabilityMaskProvider.overrideWithValue(
          const InteractionCapabilityMask({}),
        ),
      ],
    );

    expect(container.read(interactionCapabilityMaskProvider).visible, isEmpty);
    final initializer = container.read(interactionSessionInitializerProvider);
    final engine = container.read(interactionEnginePortProvider);
    final repository = container.read(interactionRepositoryProvider);
    final initial = await initializer.initialize(ritualRoomId);

    for (final input in interactionInputs) {
      final current = await engine.getSnapshot(initial.interactionId);
      final result = await repository.advance(
        interactionId: initial.interactionId,
        expectedRevision: current!.revision,
        input: input,
      );
      expect(
        result,
        isA<AdvanceApplied>(),
        reason: result is AdvanceRejected ? result.code.wireName : null,
      );
    }

    expect(
      (await engine.getSnapshot(initial.interactionId))!.revision,
      interactionInputs.length,
    );
  });
}

final class _ActiveSource implements ActiveUtteranceSource {
  @override
  Future<ActiveUtterance> resolveActiveUtterance({
    required String ritualRoomId,
    required ActiveUtteranceSlot slot,
  }) async => interactionActiveUtterance(
    displayId: slot == ActiveUtteranceSlot.ready
        ? 'shoes_on_ready_v1'
        : 'shoes_on_revised_wait_v1',
  );
}

final class _FixedSeedSource implements InteractionSeedSource {
  @override
  Future<InteractionSeed> load(String ritualRoomId) async => InteractionSeed(
    anchor: 'test anchor',
    normalizedContext: interactionNormalizedInput('shared_action'),
    memory: interactionMemory('shared_action'),
    strategy: interactionStrategy(),
    activeUtterance: interactionActiveUtterance(),
  );
}
