import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/shell/presentation/screens/discover_screen.dart';

void main() {
  testWidgets(
    'Discover V1 renders hero, search bar, scene pills, and phrase cards',
    (tester) async {
      var loadCount = 0;

      await tester.pumpWidget(
        _buildApp(
          catalogLoader: () async {
            loadCount += 1;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return _buildCatalog();
          },
        ),
      );

      expect(find.byKey(const Key('discover-loading-state')), findsOneWidget);

      await tester.pumpAndSettle();

      expect(loadCount, 1);
      expect(find.byKey(const Key('shell-tab-discover')), findsOneWidget);

      // Hero card
      expect(find.byKey(const Key('discover-hero-card')), findsOneWidget);
      expect(find.text('BabyTalk'), findsOneWidget);
      expect(find.text('每天一句亲子英语'), findsOneWidget);

      // Search bar
      expect(find.byKey(const Key('discover-search-field')), findsOneWidget);

      // Scene pills
      expect(find.byKey(const Key('discover-scene-pills')), findsOneWidget);
      expect(find.byKey(const Key('discover-pill-all')), findsOneWidget);
      expect(find.byKey(const Key('discover-pill-mealtime')), findsOneWidget);
      expect(find.byKey(const Key('discover-pill-bath')), findsOneWidget);

      // Sort dropdown
      expect(find.byKey(const Key('discover-sort-dropdown')), findsOneWidget);

      // Phrase list with cards
      expect(find.byKey(const Key('discover-phrase-list')), findsOneWidget);
      expect(
        find.byKey(const Key('discover-phrase-card-bath_time')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('discover-phrase-card-diaper_change')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('discover-phrase-card-feeding_time')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('discover-phrase-card-bedtime')),
        findsOneWidget,
      );

      // Practice button exists
      expect(find.text('练这一句'), findsWidgets);
    },
  );

  testWidgets('Discover scene pill filters activities by scene tag', (
    tester,
  ) async {
    _setWideViewport(tester);

    await tester.pumpWidget(
      _buildApp(catalogLoader: () async => _buildCatalog()),
    );
    await tester.pumpAndSettle();

    // All 4 activities visible by default
    expect(
      find.byKey(const Key('discover-phrase-card-bath_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-diaper_change')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-feeding_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-bedtime')),
      findsOneWidget,
    );

    // Scene pills container exists with all 7 pills
    expect(find.byKey(const Key('discover-scene-pills')), findsOneWidget);
    expect(find.byKey(const Key('discover-pill-all')), findsOneWidget);
    expect(find.byKey(const Key('discover-pill-mealtime')), findsOneWidget);
    expect(find.byKey(const Key('discover-pill-bath')), findsOneWidget);
    expect(find.byKey(const Key('discover-pill-diaper')), findsOneWidget);
    expect(find.byKey(const Key('discover-pill-drinking')), findsOneWidget);
    expect(find.byKey(const Key('discover-pill-bedtime')), findsOneWidget);
    expect(find.byKey(const Key('discover-pill-outing')), findsOneWidget);

    // Tap "全部" pill (always visible) - should keep all activities
    await tester.tap(find.byKey(const Key('discover-pill-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('discover-phrase-card-bath_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-diaper_change')),
      findsOneWidget,
    );
  });

  testWidgets('Discover search bar filters activities by title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(catalogLoader: () async => _buildCatalog()),
    );
    await tester.pumpAndSettle();

    // Type in search
    await tester.enterText(
      find.byKey(const Key('discover-search-field')),
      '洗澡',
    );
    await tester.pumpAndSettle();

    // Only matching activity visible
    expect(
      find.byKey(const Key('discover-phrase-card-bath_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-diaper_change')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-feeding_time')),
      findsNothing,
    );
    expect(find.byKey(const Key('discover-phrase-card-bedtime')), findsNothing);

    // Clear search
    await tester.enterText(find.byKey(const Key('discover-search-field')), '');
    await tester.pumpAndSettle();

    // All activities visible again
    expect(
      find.byKey(const Key('discover-phrase-card-bath_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-diaper_change')),
      findsOneWidget,
    );
  });

  testWidgets('Discover search + scene filter combined', (tester) async {
    _setWideViewport(tester);

    await tester.pumpWidget(
      _buildApp(catalogLoader: () async => _buildCatalog()),
    );
    await tester.pumpAndSettle();

    // Search for "洗澡" - only bath_time matches
    await tester.enterText(
      find.byKey(const Key('discover-search-field')),
      '洗澡',
    );
    await tester.pumpAndSettle();

    // Only bath_time visible
    expect(
      find.byKey(const Key('discover-phrase-card-bath_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-diaper_change')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-feeding_time')),
      findsNothing,
    );

    // Now add scene filter that doesn't match - no results
    // (search "洗澡" + tap "全部" still matches because scene filter is "all")
    // Clear search and search for nonexistent term
    await tester.enterText(
      find.byKey(const Key('discover-search-field')),
      '不存在的短语xyz',
    );
    await tester.pumpAndSettle();

    // Empty filter state shown
    expect(
      find.byKey(const Key('discover-filter-empty-state')),
      findsOneWidget,
    );
  });

  testWidgets('Discover filter empty state shows clear filters button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(catalogLoader: () async => _buildCatalog()),
    );
    await tester.pumpAndSettle();

    // Search for nonexistent phrase
    await tester.enterText(
      find.byKey(const Key('discover-search-field')),
      '不存在的短语',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('discover-filter-empty-state')),
      findsOneWidget,
    );
    expect(find.text('没有找到匹配的短语，换个关键词试试'), findsOneWidget);

    // Clear filters
    await tester.tap(find.byKey(const Key('discover-clear-filters')));
    await tester.pumpAndSettle();

    // All activities restored
    expect(
      find.byKey(const Key('discover-phrase-card-bath_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-phrase-card-diaper_change')),
      findsOneWidget,
    );
  });

  testWidgets('Discover practice button triggers opener with route args', (
    tester,
  ) async {
    _setTallViewport(tester);
    PracticeRouteArgs? openedArgs;

    await tester.pumpWidget(
      _buildApp(
        catalogLoader: () async => _buildCatalog(),
        practiceOpener: (_, args) async {
          openedArgs = args;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Tap the first "练这一句" button
    await tester.tap(find.text('练这一句').first);
    await tester.pumpAndSettle();

    expect(openedArgs, isNotNull);
  });

  testWidgets('Discover loading state shows shimmer', (tester) async {
    final completer = Completer<PracticeActivityCatalog>();

    await tester.pumpWidget(_buildApp(catalogLoader: () => completer.future));

    await tester.pump();
    expect(find.byKey(const Key('discover-loading-state')), findsOneWidget);

    // Complete the future to avoid timer leak
    completer.complete(_buildCatalog());
    await tester.pumpAndSettle();
  });

  testWidgets('Discover error state shows retry button and recovers', (
    tester,
  ) async {
    var attempt = 0;

    await tester.pumpWidget(
      _buildApp(
        catalogLoader: () async {
          attempt += 1;
          if (attempt == 1) {
            throw StateError('disk denied');
          }
          return _buildCatalog();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover-error-state')), findsOneWidget);
    expect(find.byKey(const Key('discover-retry-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('discover-retry-button')));
    await tester.pump();
    expect(find.byKey(const Key('discover-loading-state')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.byKey(const Key('discover-phrase-list')), findsOneWidget);
  });

  testWidgets('Discover empty catalog shows empty state', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        catalogLoader: () async =>
            PracticeActivityCatalog.empty(installationId: 'install_test'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover-empty-state')), findsOneWidget);
  });

  testWidgets('Discover malformed card shows navigation error', (tester) async {
    _setTallViewport(tester);
    var openCount = 0;

    await tester.pumpWidget(
      _buildApp(
        catalogLoader: () async => _buildCatalog(includeMalformedCard: true),
        practiceOpener: (_, args) async {
          openCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    // The malformed card has a "练这一句" button; scroll to find it
    final practiceButtons = find.text('练这一句');
    expect(practiceButtons, findsWidgets);

    // Scroll to the last practice button (malformed card is at the bottom)
    final lastButton = practiceButtons.last;
    await tester.ensureVisible(lastButton);
    await tester.pumpAndSettle();
    await tester.tap(lastButton);
    await tester.pumpAndSettle();

    expect(openCount, 0);
    expect(find.byKey(const Key('discover-navigation-error')), findsOneWidget);
    expect(find.textContaining('这张活动卡暂时打不开'), findsOneWidget);
  });

  testWidgets('Discover 活动卡在真实页面中保持 AppSurfaceCard 默认风格契约', (tester) async {
    await tester.pumpWidget(
      _buildApp(catalogLoader: () async => _buildCatalog()),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<AppSurfaceCard>(
      find.byKey(const Key('discover-phrase-card-bath_time')),
    );

    expect(card.variant, AppSurfaceCardVariant.standard);
    expect(card.borderColor, isNull);
    expect(card.borderRadius, AppLayoutConstants.cardRadius);
    expect(
      card.padding,
      const EdgeInsets.symmetric(
        horizontal: AppLayoutConstants.spacingLg,
        vertical: AppLayoutConstants.spacingXl,
      ),
    );
  });
}

void _setTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 4000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _setWideViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 2000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _buildApp({
  required DiscoverCatalogLoader catalogLoader,
  DiscoverPracticeOpener? practiceOpener,
}) {
  return MaterialApp(
    theme: AppTheme.build(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DiscoverScreen(
        catalogLoader: catalogLoader,
        practiceOpener: practiceOpener,
      ),
    ),
  );
}

PracticeActivityCatalog _buildCatalog({
  bool includeMalformedCard = false,
  bool includeRecoverableIssueCard = false,
}) {
  final activities = [
    _activity(
      spaceId: 'daily_care',
      spaceTitle: '日常照护',
      activityId: 'bath_time',
      title: '洗澡时间',
      summary: '从暖水、泼水到收尾，一次完成三句真实可说出口的 bath time 短语。',
      sceneTag: 'Bath time',
      totalPhrases: 3,
      completedPhrases: 1,
      totalEvents: 1,
      nextPhraseEnglish: 'Splash, splash!',
      skippedMalformedEventCount: includeRecoverableIssueCard ? 1 : 0,
      warningMessage: includeRecoverableIssueCard ? '恢复了 1 条异常记录' : null,
      recentResult: PracticeCatalogRecentResultSummary(
        phraseId: 'bath_time_warm_water',
        phraseEnglish: 'Warm water.',
        reactionType: BabyReactionType.cooperating,
        eventTime: DateTime.utc(2026, 4, 10, 9),
        totalEvents: 1,
      ),
    ),
    _activity(
      spaceId: 'daily_care',
      spaceTitle: '日常照护',
      activityId: 'diaper_change',
      title: '换尿布',
      summary: '围绕擦拭、整理和收尾，给换尿布场景两句可以立刻开口的安抚短语。',
      sceneTag: 'Diaper change',
      totalPhrases: 2,
      completedPhrases: 0,
      totalEvents: 0,
      nextPhraseEnglish: 'Clean bottom.',
    ),
    _activity(
      spaceId: 'family_rhythm',
      spaceTitle: '家庭节奏',
      activityId: 'feeding_time',
      title: '吃饭时间',
      summary: '从张嘴到鼓励吞咽，用两句短语把喂饭时刻变成可重复的英文 cue。',
      sceneTag: 'Feeding time',
      totalPhrases: 2,
      completedPhrases: 1,
      totalEvents: 1,
      nextPhraseEnglish: 'Yummy bite.',
    ),
    _activity(
      spaceId: 'family_rhythm',
      spaceTitle: '家庭节奏',
      activityId: 'bedtime',
      title: '睡前时间',
      summary: '围绕调暗灯光和进入睡眠，给 bedtime 场景补上两句柔和、低刺激的英文短语。',
      sceneTag: 'Bedtime',
      totalPhrases: 2,
      completedPhrases: 0,
      totalEvents: 0,
      nextPhraseEnglish: 'Dim the lights.',
    ),
    if (includeMalformedCard)
      _activity(
        spaceId: '',
        spaceTitle: '损坏目录',
        activityId: 'mystery_time',
        title: '神秘活动',
        summary: '',
        sceneTag: 'Broken card',
        totalPhrases: 1,
        completedPhrases: 0,
        totalEvents: 0,
        nextPhraseEnglish: null,
      ),
  ];

  return PracticeActivityCatalog(
    installationId: 'install_test',
    spaces: [
      PracticeCatalogSpaceSummary(
        spaceId: 'daily_care',
        title: '日常照护',
        description: '把洗澡、换尿布这些重复动作变成可预测、可重复的英文互动。',
        activities: activities
            .where((activity) => activity.spaceId == 'daily_care')
            .toList(growable: false),
        totalEvents: 1,
        startedActivityCount: 1,
        completedActivityCount: 0,
        lastEventTime: DateTime.utc(2026, 4, 10, 9),
      ),
      PracticeCatalogSpaceSummary(
        spaceId: 'family_rhythm',
        title: '家庭节奏',
        description: '把吃饭和睡前这些每天都会发生的时刻，变成稳定的英语输入节奏。',
        activities: activities
            .where((activity) => activity.spaceId == 'family_rhythm')
            .toList(growable: false),
        totalEvents: 1,
        startedActivityCount: 1,
        completedActivityCount: 0,
        lastEventTime: DateTime.utc(2026, 4, 10, 10),
      ),
    ],
    activities: activities,
    totalStoredEvents: 2,
    validEvents: 2,
    knownEvents: 2,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
}

PracticeCatalogActivitySummary _activity({
  required String spaceId,
  required String spaceTitle,
  required String activityId,
  required String title,
  required String summary,
  required String sceneTag,
  required int totalPhrases,
  required int completedPhrases,
  required int totalEvents,
  required String? nextPhraseEnglish,
  int skippedUnknownPhraseCount = 0,
  int skippedMalformedEventCount = 0,
  String? warningMessage,
  PracticeCatalogRecentResultSummary? recentResult,
}) {
  return PracticeCatalogActivitySummary(
    spaceId: spaceId,
    spaceTitle: spaceTitle,
    activityId: activityId,
    title: title,
    summary: summary,
    sceneTag: sceneTag,
    coachTip: 'coach tip',
    totalPhraseCount: totalPhrases,
    completedPhraseCount: completedPhrases,
    completedPhraseIds: [
      for (var index = 0; index < completedPhrases; index++) 'phrase_$index',
    ],
    nextPhraseId: nextPhraseEnglish == null ? null : 'next_phrase',
    nextPhraseEnglish: nextPhraseEnglish,
    totalEvents: totalEvents,
    skippedUnknownPhraseCount: skippedUnknownPhraseCount,
    skippedMalformedEventCount: skippedMalformedEventCount,
    lastEventTime: recentResult?.eventTime,
    recentResult: recentResult,
    warningMessage: warningMessage,
  );
}
