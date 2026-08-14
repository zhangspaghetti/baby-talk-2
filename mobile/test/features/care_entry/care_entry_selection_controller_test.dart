import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/presentation/care_entry_selection_controller.dart';

void main() {
  test(
    'tile intent only selects and primary intent starts exact local utterance',
    () async {
      final registry = _MemoryRegistry(_resolution());
      final controller = CareEntrySelectionController(
        registry: registry,
        visibleSlots: 2,
      );

      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      expect(controller.state.phase, CareEntrySelectionPhase.selection);
      expect(controller.state.selectedEntryId?.value, 'care.bedtime_soothing');
      expect(controller.state.activeUtterance, isNull);

      controller.select(const CareEntryId('care.post_cry_soothing'));

      expect(controller.state.phase, CareEntrySelectionPhase.selection);
      expect(controller.state.selectedEntryId?.value, 'care.post_cry_soothing');
      expect(controller.state.activeUtterance, isNull);

      controller.startSelected();

      expect(controller.state.phase, CareEntrySelectionPhase.firstUtterance);
      expect(controller.state.activeEntry?.id.value, 'care.post_cry_soothing');
      expect(controller.state.activeUtterance?.english, "I'm right here.");
      expect(controller.state.activeUtterance?.chinese, '我就在这里。');
      expect(controller.state.activeUtterance?.pronunciation, 'aɪm raɪt hɪr');
      expect(
        controller.state.activeUtterance,
        same(controller.state.activeEntry?.seed.firstUtterance),
      );
    },
  );
}

final class _MemoryRegistry implements CareEntryRegistry {
  const _MemoryRegistry(this.resolution);

  final CareEntryResolution resolution;

  @override
  Future<CareEntryResolution> resolve({
    required CareEntryPlacementId placement,
    required int visibleSlots,
    required DateTime localTime,
  }) async => resolution;
}

CareEntryResolution _resolution() {
  final bedtime = _entry(
    id: 'care.bedtime_soothing',
    english: 'Time to sleep.',
    chinese: '该睡觉啦。',
    pronunciation: 'taɪm tə sliːp',
    order: 1,
    recommended: true,
  );
  final postCry = _entry(
    id: 'care.post_cry_soothing',
    english: "I'm right here.",
    chinese: '我就在这里。',
    pronunciation: 'aɪm raɪt hɪr',
    order: 2,
    recommended: false,
  );
  return CareEntryResolution(
    schemaVersion: 1,
    revision: 'test.1',
    placement: const CareEntryPlacementId('onboarding.primary'),
    entries: <ResolvedCareEntry>[bedtime, postCry],
    recommendedEntryId: bedtime.id,
  );
}

ResolvedCareEntry _entry({
  required String id,
  required String english,
  required String chinese,
  required String pronunciation,
  required int order,
  required bool recommended,
}) {
  return ResolvedCareEntry(
    id: CareEntryId(id),
    title: id,
    subtitle: 'subtitle',
    visualToken: 'route.moon',
    order: order,
    isRecommended: recommended,
    seed: CareMomentSeed(
      generationRef: GenerationSceneRef(
        id: GenerationSceneId('generation.$id'),
        schemaVersion: 1,
        sceneType: 'test',
        parentTonePreference: 'short_gentle',
      ),
      fallback: CatalogFallbackRef(
        id: CatalogFallbackId('fallback.$id'),
        spaceId: 'space',
        activityId: 'activity',
        phraseId: 'phrase',
      ),
      firstUtterance: CareFirstUtterance(
        english: english,
        chinese: chinese,
        pronunciation: pronunciation,
        audioAsset: 'assets/audio/phrases/test.mp3',
        audioReview: AudioReview.reviewed,
      ),
    ),
  );
}
