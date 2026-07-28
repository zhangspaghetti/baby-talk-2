import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_entry.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/shell/presentation/screens/discover_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  test('Today entry remains lower priority than an open matching moment', () {
    expect(
      shouldOfferCustomSceneFromToday(
        const CustomSceneTodayEntryContext(
          currentRecommendationMatches: true,
          userSkippedRecommendation: false,
          hasOpenableMoment: true,
        ),
      ),
      isFalse,
    );
    expect(
      shouldOfferCustomSceneFromToday(
        const CustomSceneTodayEntryContext(
          currentRecommendationMatches: false,
          userSkippedRecommendation: false,
          hasOpenableMoment: true,
        ),
      ),
      isTrue,
    );
    expect(
      shouldOfferCustomSceneFromToday(
        const CustomSceneTodayEntryContext(
          currentRecommendationMatches: true,
          userSkippedRecommendation: true,
          hasOpenableMoment: true,
        ),
      ),
      isTrue,
    );
    expect(
      shouldOfferCustomSceneFromToday(
        const CustomSceneTodayEntryContext(
          currentRecommendationMatches: false,
          userSkippedRecommendation: false,
          hasOpenableMoment: false,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('Scene entry stays after stable catalog cards and opens once', (
    tester,
  ) async {
    final opened = <CustomSceneEntrySource>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiscoverScreen(
            customSceneEnabled: true,
            catalogLoader: () async => _catalog(),
            customSceneEntryOpener: (_, source) async => opened.add(source),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('discover-phrase-card-bath_time'));
    final entry = find.byKey(const Key('custom-scene-entry-scene'));
    expect(card, findsOneWidget);
    expect(entry, findsOneWidget);
    expect(
      tester.getTopLeft(entry).dy,
      greaterThan(tester.getTopLeft(card).dy),
    );
    await tester.tap(entry);
    await tester.pump();
    expect(opened, <CustomSceneEntrySource>[CustomSceneEntrySource.scene]);
  });
}

PracticeActivityCatalog _catalog() {
  final activity = PracticeCatalogActivitySummary(
    spaceId: 'daily_care',
    spaceTitle: '日常照护',
    activityId: 'bath_time',
    title: '洗澡时间',
    summary: '洗澡时的一句照护表达。',
    sceneTag: 'Bath time',
    coachTip: '慢慢来',
    totalPhraseCount: 1,
    completedPhraseCount: 0,
    completedPhraseIds: const <String>[],
    nextPhraseId: 'bath_1',
    nextPhraseEnglish: 'Warm water',
    totalEvents: 0,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );
  return PracticeActivityCatalog(
    installationId: 'install_1',
    spaces: <PracticeCatalogSpaceSummary>[
      PracticeCatalogSpaceSummary(
        spaceId: 'daily_care',
        title: '日常照护',
        description: '日常场景',
        activities: <PracticeCatalogActivitySummary>[activity],
        totalEvents: 0,
        startedActivityCount: 0,
        completedActivityCount: 0,
      ),
    ],
    activities: <PracticeCatalogActivitySummary>[activity],
    totalStoredEvents: 0,
    validEvents: 0,
    knownEvents: 0,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
}
