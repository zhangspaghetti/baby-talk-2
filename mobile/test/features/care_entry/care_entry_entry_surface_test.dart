import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/presentation/care_entry_selection_controller.dart';
import 'package:mobile/features/care_entry/presentation/widgets/care_entry_entry_surface.dart';

void main() {
  testWidgets(
    'renders four entries, tile only selects, and primary CTA reveals exact first utterance',
    (tester) async {
      final controller = CareEntrySelectionController(
        registry: _MemoryRegistry(_resolution()),
      );
      final audioPlayer = _RecordingAudioPlayer();
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      await tester.pumpWidget(
        MaterialApp(
          home: CareEntryEntrySurface(
            controller: controller,
            audioControllerFactory: () => audioPlayer,
          ),
        ),
      );

      expect(find.byKey(const Key('care-entry-grid')), findsOneWidget);
      expect(find.byType(CareEntryTile), findsNWidgets(4));
      expect(find.text("I'm right here."), findsNothing);
      expect(
        find.byKey(const Key('care-entry-primary-action')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('care-entry-tile-care.post_cry_soothing')),
      );
      await tester.pump();

      expect(controller.state.phase, CareEntrySelectionPhase.selection);
      expect(controller.state.selectedEntryId?.value, 'care.post_cry_soothing');
      expect(find.text("I'm right here."), findsNothing);

      await tester.tap(find.byKey(const Key('care-entry-primary-action')));
      await tester.pump();

      expect(controller.state.phase, CareEntrySelectionPhase.firstUtterance);
      expect(find.text("I'm right here."), findsOneWidget);
      expect(find.text('我就在这里。'), findsOneWidget);
      expect(find.text('aɪm raɪt hɪr'), findsOneWidget);
      expect(
        find.byKey(const Key('care-entry-first-utterance-audio')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('care-entry-first-utterance-audio')),
      );
      await tester.pump();

      expect(audioPlayer.playedAssets, <String>['audio/phrases/test_3.mp3']);
    },
  );
}

final class _RecordingAudioPlayer implements CareEntryAudioPlayer {
  final List<String> playedAssets = <String>[];

  @override
  Future<void> playAsset(String assetPath) async {
    playedAssets.add(assetPath);
  }

  @override
  Future<void> dispose() async {}
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
  final entries = <ResolvedCareEntry>[
    _entry(
      id: 'care.bedtime_soothing',
      title: '哄睡中',
      english: 'Time to sleep.',
      chinese: '该睡觉啦。',
      pronunciation: 'taɪm tə sliːp',
      visualToken: 'route.moon',
      order: 1,
      recommended: true,
    ),
    _entry(
      id: 'care.feeding_now',
      title: '正在喂奶',
      english: 'Open wide.',
      chinese: '张大嘴巴。',
      pronunciation: 'ˈoʊ.pən waɪd',
      visualToken: 'route.bottle',
      order: 2,
      recommended: false,
    ),
    _entry(
      id: 'care.post_cry_soothing',
      title: '宝宝刚哭过',
      english: "I'm right here.",
      chinese: '我就在这里。',
      pronunciation: 'aɪm raɪt hɪr',
      visualToken: 'route.soothing',
      order: 3,
      recommended: false,
    ),
    _entry(
      id: 'care.diaper_change',
      title: '换尿布',
      english: 'Clean bottom.',
      chinese: '擦干净屁屁。',
      pronunciation: 'kliːn ˈbɑː.t̬əm',
      visualToken: 'route.diaper',
      order: 4,
      recommended: false,
    ),
  ];
  return CareEntryResolution(
    schemaVersion: 1,
    revision: 'test.1',
    placement: const CareEntryPlacementId('onboarding.primary'),
    entries: entries,
    recommendedEntryId: entries.first.id,
  );
}

ResolvedCareEntry _entry({
  required String id,
  required String title,
  required String english,
  required String chinese,
  required String pronunciation,
  required String visualToken,
  required int order,
  required bool recommended,
}) {
  return ResolvedCareEntry(
    id: CareEntryId(id),
    title: title,
    subtitle: '现在就能说',
    visualToken: visualToken,
    order: order,
    isRecommended: recommended,
    seed: CareMomentSeed(
      generationRef: GenerationSceneRef(
        id: GenerationSceneId('generation.$order'),
        schemaVersion: 1,
        sceneType: 'scene_$order',
        parentTonePreference: 'short_gentle',
      ),
      fallback: CatalogFallbackRef(
        id: CatalogFallbackId('fallback.$order'),
        spaceId: 'space',
        activityId: 'activity',
        phraseId: 'phrase_$order',
      ),
      firstUtterance: CareFirstUtterance(
        english: english,
        chinese: chinese,
        pronunciation: pronunciation,
        audioAsset: 'assets/audio/phrases/test_$order.mp3',
        audioReview: AudioReview.reviewed,
      ),
    ),
  );
}
