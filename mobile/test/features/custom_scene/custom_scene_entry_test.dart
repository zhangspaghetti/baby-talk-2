import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_feature_flag.dart';
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
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiscoverScreen(
              catalogLoader: () async => _catalog(),
              customSceneEntryOpener: (_, source) async => opened.add(source),
            ),
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
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pump();
    expect(opened, <CustomSceneEntrySource>[CustomSceneEntrySource.scene]);
  });

  testWidgets('Scene entry is one actionable semantics leaf and opens once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final opened = <CustomSceneEntrySource>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomSceneEntryLink(
            source: CustomSceneEntrySource.scene,
            onOpen: (_, source) async => opened.add(source),
          ),
        ),
      ),
    );

    final entry = find.byKey(const Key('custom-scene-entry-scene'));
    final node = tester.getSemantics(entry);
    expect(
      node,
      matchesSemantics(
        label: '没找到正在发生的场景？描述一下此刻',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        children: <Matcher>[],
      ),
    );
    final semanticsEntry = find.semantics.byLabel('没找到正在发生的场景？描述一下此刻');
    expect(semanticsEntry, findsOne);

    tester.semantics.tap(semanticsEntry);
    await tester.pump();
    expect(opened, <CustomSceneEntrySource>[CustomSceneEntrySource.scene]);
    semantics.dispose();
  });

  testWidgets('Today entry is one actionable semantics leaf and opens once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final opened = <CustomSceneEntrySource>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomSceneEntryLink(
            source: CustomSceneEntrySource.today,
            onOpen: (_, source) async => opened.add(source),
          ),
        ),
      ),
    );

    final entry = find.byKey(const Key('custom-scene-entry-today'));
    final node = tester.getSemantics(entry);
    expect(
      node,
      matchesSemantics(
        label: '不是正在发生的事？描述一下此刻',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        children: <Matcher>[],
      ),
    );
    final semanticsEntry = find.semantics.byLabel('不是正在发生的事？描述一下此刻');
    expect(semanticsEntry, findsOne);

    tester.semantics.tap(semanticsEntry);
    await tester.pump();
    expect(opened, <CustomSceneEntrySource>[CustomSceneEntrySource.today]);
    semantics.dispose();
  });

  testWidgets(
    'Discover traversal keeps final card, custom entry, then bottom navigation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.build(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiscoverScreen(
                catalogLoader: () async => _catalog(),
                customSceneEntryOpener: (_, _) async {},
              ),
              bottomNavigationBar: Semantics(
                key: const Key('test-bottom-navigation'),
                container: true,
                button: true,
                label: '底部导航',
                child: const SizedBox(height: 56),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entryFinder = find.byKey(const Key('custom-scene-entry-scene'));
      await tester.ensureVisible(entryFinder);
      await tester.pumpAndSettle();
      final finalCardAction = tester.getSemantics(
        find.descendant(
          of: find.byKey(const Key('discover-phrase-card-bath_time')),
          matching: find.byType(InkWell),
        ),
      );
      final entry = tester.getSemantics(entryFinder);
      final bottomNavigation = tester.getSemantics(
        find.byKey(const Key('test-bottom-navigation')),
      );
      final traversal = tester.semantics
          .simulatedAccessibilityTraversal()
          .toList(growable: false);
      final forward = <int>[
        traversal.indexWhere((node) => node.id == finalCardAction.id),
        traversal.indexWhere((node) => node.id == entry.id),
        traversal.indexWhere((node) => node.id == bottomNavigation.id),
      ];

      expect(forward.every((index) => index >= 0), isTrue);
      expect(forward, orderedEquals(forward.toList()..sort()));
      final reversedTraversal = traversal.reversed.toList(growable: false);
      final reverse = <int>[
        reversedTraversal.indexWhere((node) => node.id == bottomNavigation.id),
        reversedTraversal.indexWhere((node) => node.id == entry.id),
        reversedTraversal.indexWhere((node) => node.id == finalCardAction.id),
      ];
      expect(reverse, orderedEquals(reverse.toList()..sort()));
      expect(traversal.where((node) => node.id == entry.id), hasLength(1));
      semantics.dispose();
    },
  );

  testWidgets('preset catalog stays usable when custom scene is disabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [customSceneFeatureEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(
          theme: AppTheme.build(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiscoverScreen(catalogLoader: () async => _catalog()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('discover-phrase-card-bath_time')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('custom-scene-entry-scene')), findsNothing);
    expect(find.semantics.byLabel('没找到正在发生的场景？描述一下此刻'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'secondary caregiver catalog keeps shared-profile custom scene visible',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.build(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiscoverScreen(catalogLoader: () async => _catalog()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('discover-phrase-card-bath_time')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('custom-scene-entry-scene')), findsOneWidget);
    },
  );
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
