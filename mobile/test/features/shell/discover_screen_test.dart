import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/shell/presentation/screens/discover_screen.dart';

void main() {
  testWidgets('Discover 按 activity 渲染至少 4 个真实 activity 与稳定 keys', (
    tester,
  ) async {
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
    expect(find.byKey(const Key('discover-view-activity')), findsOneWidget);
    expect(
      find.byKey(const Key('discover-activity-card-bath_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-activity-card-diaper_change')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-activity-card-feeding_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-activity-card-bedtime')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discover-route-target-family_rhythm-bedtime')),
      findsOneWidget,
    );
  });

  testWidgets('Discover activity / space 视图切换不重读目录，并把 route args 传给 opener', (
    tester,
  ) async {
    _setTallViewport(tester);
    var loadCount = 0;
    PracticeRouteArgs? openedArgs;

    await tester.pumpWidget(
      _buildApp(
        catalogLoader: () async {
          loadCount += 1;
          return _buildCatalog();
        },
        practiceOpener: (_, args) async {
          openedArgs = args;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 1);

    await tester.tap(find.byKey(const Key('discover-tab-space')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover-view-space')), findsOneWidget);
    expect(loadCount, 1);

    await tester.tap(
      find.byKey(const Key('discover-route-target-family_rhythm-bedtime')),
    );
    await tester.pumpAndSettle();

    expect(openedArgs?.scopeLabel, 'family_rhythm/bedtime');

    await tester.tap(find.byKey(const Key('discover-tab-activity')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover-view-activity')), findsOneWidget);
    expect(loadCount, 1);
  });

  testWidgets('Discover 初次加载失败后显示明确 error state，并允许 retry 成功恢复', (
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
    expect(find.textContaining('disk denied'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discover-retry-button')));
    await tester.pump();
    expect(find.byKey(const Key('discover-loading-state')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.byKey(const Key('discover-view-activity')), findsOneWidget);
  });

  testWidgets('Discover 空目录显示明确 empty state，而不是旧 placeholder 文案', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        catalogLoader: () async =>
            PracticeActivityCatalog.empty(installationId: 'install_test'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover-empty-state')), findsOneWidget);
    expect(find.textContaining('旧 placeholder'), findsNothing);
  });

  testWidgets('Discover 遇到缺失 route args 的坏卡片时禁止导航并暴露 UI 级错误', (tester) async {
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

    await tester.dragUntilVisible(
      find.byKey(const Key('discover-route-target--mystery_time')),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.tap(
      find.byKey(const Key('discover-route-target--mystery_time')),
    );
    await tester.pumpAndSettle();

    expect(openCount, 0);
    expect(find.byKey(const Key('discover-navigation-error')), findsOneWidget);
    expect(find.textContaining('缺少有效的 spaceId/activityId'), findsOneWidget);
  });
}

void _setTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 4000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _buildApp({
  required DiscoverCatalogLoader catalogLoader,
  DiscoverPracticeOpener? practiceOpener,
}) {
  return MaterialApp(
    theme: AppTheme.build(),
    home: Scaffold(
      body: DiscoverScreen(
        catalogLoader: catalogLoader,
        practiceOpener: practiceOpener,
      ),
    ),
  );
}

PracticeActivityCatalog _buildCatalog({bool includeMalformedCard = false}) {
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
      recentResult: PracticeCatalogRecentResultSummary(
        phraseId: 'bath_time_warm_water',
        phraseEnglish: 'Warm water.',
        reactionType: BabyReactionType.engaged,
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
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
    lastEventTime: recentResult?.eventTime,
    recentResult: recentResult,
  );
}
