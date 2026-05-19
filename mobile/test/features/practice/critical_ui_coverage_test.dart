import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_celebration_overlay.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/practice/presentation/widgets/activation_frame.dart';
import 'package:mobile/features/practice/presentation/widgets/home_garden_mini_entry.dart';
import 'package:mobile/features/practice/presentation/widgets/home_growth_summary_card.dart';
import 'package:mobile/features/practice/presentation/widgets/home_recent_result_card.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';
import 'package:mobile/features/share/presentation/share_notifier.dart';
import 'package:mobile/features/share/presentation/widgets/share_callout_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_patch_card.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('Practice fallback and activation affordances stay visible', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      PracticeSessionScreen(routeEntry: PracticeRouteEntry.fromObject(null)),
      scaffold: false,
    );

    expect(find.byKey(const Key('practice-safe-fallback')), findsOneWidget);
    expect(find.textContaining('practice route 参数'), findsOneWidget);

    await _pumpApp(
      tester,
      ActivationFrame(
        stepLabel: 'STEP 2',
        title: '跟着宝宝节奏来',
        child: const Text('Hello wave'),
      ),
    );

    expect(find.byKey(const Key('activation-frame')), findsOneWidget);
    expect(find.text('C3 激活框'), findsOneWidget);
    expect(find.text('STEP 2'), findsOneWidget);
    expect(find.text('Hello wave'), findsOneWidget);

    await _pumpApp(
      tester,
      const AppCelebrationOverlay(
        duration: Duration(milliseconds: 20),
        child: Text('练习已保存'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('练习已保存'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets('Garden cards render ready and warning states', (tester) async {
    final patch = _gardenPatch();
    final snapshot = _gardenSnapshot(
      spaces: [patch],
      projectionWarning: '有 1 条记录暂时无法归类。',
    );
    final notifier = _GardenGrowthNotifierStub(
      snapshot: snapshot,
      status: GardenGrowthLoadStatus.ready,
    );

    await _pumpApp(tester, GardenPatchCard(patch: patch));

    expect(find.byKey(const Key('garden-patch-home')), findsOneWidget);
    expect(find.byKey(const Key('garden-patch-stage-home')), findsOneWidget);
    expect(find.byKey(const Key('garden-flower-song_time')), findsOneWidget);
    expect(find.text('已开始 1/1'), findsOneWidget);
    expect(find.text('已连起 1/3 句 · 2 次记录'), findsOneWidget);

    await _pumpApp(tester, HomeGardenMiniEntry(notifier: notifier));

    expect(find.byKey(const Key('home-garden-mini-entry')), findsOneWidget);
    expect(
      find.byKey(const Key('home-garden-mini-entry-warning')),
      findsOneWidget,
    );
    expect(find.textContaining('有 1 条记录'), findsOneWidget);

    await _pumpApp(tester, HomeGrowthSummaryCard(notifier: notifier));

    expect(find.byKey(const Key('home-growth-summary')), findsOneWidget);
    expect(find.text('花圃醒来了'), findsOneWidget);
    expect(find.text('宝宝模仿了 hello。'), findsOneWidget);
    expect(
      find.byKey(const Key('home-growth-summary-warning')),
      findsOneWidget,
    );
  });

  testWidgets('Home critical cards expose empty, recent, and retry states', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      const HomeRecentResultCard(continuitySnapshot: null),
    );

    expect(
      find.byKey(const Key('recent-result-empty')),
      findsAtLeastNWidgets(1),
    );

    await _pumpApp(
      tester,
      HomeRecentResultCard(continuitySnapshot: _continuitySnapshot()),
    );

    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('Hello wave'), findsOneWidget);

    final errorNotifier = _GardenGrowthNotifierStub(
      snapshot: GardenGrowthSnapshot.empty(),
      status: GardenGrowthLoadStatus.error,
      message: '花园暂时不可用。',
    );
    await _pumpApp(tester, HomeGrowthSummaryCard(notifier: errorNotifier));

    expect(find.byKey(const Key('home-growth-summary-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-growth-summary-retry')));
    await tester.pump();

    expect(errorNotifier.refreshCount, 1);
    expect(find.text('花园暂时不可用。'), findsOneWidget);
  });

  testWidgets(
    'Share callout covers disabled, ready, loading, and error states',
    (tester) async {
      var shareCount = 0;
      await _pumpApp(
        tester,
        ShareCalloutCard(
          surfaceKeyPrefix: 'home',
          notifier: _ShareNotifierStub(currentDraft: null),
          sectionLabel: '分享给家人',
          emptyMessage: '暂无可分享内容。',
          onShare: () async {
            shareCount += 1;
          },
        ),
      );

      expect(
        find.byKey(const Key('home-share-state-disabled')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-share-button')), findsOneWidget);

      final draft = _shareDraft();
      await _pumpApp(
        tester,
        ShareCalloutCard(
          surfaceKeyPrefix: 'home',
          notifier: _ShareNotifierStub(currentDraft: draft),
          sectionLabel: '分享给家人',
          emptyMessage: '暂无可分享内容。',
          onShare: () async {
            shareCount += 1;
          },
        ),
      );

      expect(find.byKey(const Key('home-share-state-ready')), findsOneWidget);
      expect(find.byKey(const Key('home-share-phrase-pill')), findsOneWidget);
      expect(
        find.byKey(const Key('home-share-recommendation')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('home-share-button')));
      await tester.pump();
      expect(shareCount, 1);

      await _pumpApp(
        tester,
        ShareCalloutCard(
          surfaceKeyPrefix: 'home',
          notifier: _ShareNotifierStub(currentDraft: draft, isSharing: true),
          sectionLabel: '分享给家人',
          emptyMessage: '暂无可分享内容。',
          onShare: () async {
            shareCount += 1;
          },
        ),
      );

      expect(find.byKey(const Key('home-share-state-loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _pumpApp(
        tester,
        ShareCalloutCard(
          surfaceKeyPrefix: 'home',
          notifier: _ShareNotifierStub(
            currentDraft: draft,
            lastShareStatus: ShareViewStatus.error,
            message: '分享服务暂时不可用。',
          ),
          sectionLabel: '分享给家人',
          emptyMessage: '暂无可分享内容。',
        ),
      );

      expect(find.byKey(const Key('home-share-state-error')), findsOneWidget);
      expect(find.text('分享服务暂时不可用。'), findsOneWidget);
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  Widget child, {
  bool scaffold = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.build(),
        home: scaffold
            ? Scaffold(
                body: SafeArea(child: SingleChildScrollView(child: child)),
              )
            : child,
      ),
    ),
  );
  await tester.pump();
}

GardenFlowerSnapshot _flower() {
  return GardenFlowerSnapshot(
    spaceId: 'home',
    activityId: 'song_time',
    title: '唱一小段',
    sceneTag: 'music',
    summary: '短歌互动',
    stage: GardenFlowerStage.sprout,
    totalEvents: 2,
    completedPhraseCount: 1,
    totalPhraseCount: 3,
    completedPhraseIds: const ['hello_wave'],
    careNote: '继续轻声重复',
    lastPracticedAt: DateTime.utc(2026, 5, 19, 8),
  );
}

GardenPatchSnapshot _gardenPatch() {
  return GardenPatchSnapshot(
    spaceId: 'home',
    title: '居家花圃',
    description: '日常互动',
    stage: GardenPatchStage.tended,
    totalKnownEvents: 2,
    startedActivityCount: 1,
    completedActivityCount: 0,
    totalActivityCount: 1,
    activities: [_flower()],
    careNote: '花圃刚被照料',
    lastPracticedAt: DateTime.utc(2026, 5, 19, 8),
  );
}

GardenGrowthSnapshot _gardenSnapshot({
  required List<GardenPatchSnapshot> spaces,
  String? projectionWarning,
}) {
  return GardenGrowthSnapshot(
    installationId: 'install_critical_ui',
    spaces: spaces,
    diaryEntries: const [],
    milestones: const [],
    latestImpact: LatestPracticeImpact(
      eventKey: 'install_critical_ui:evt_1',
      occurredAt: DateTime.utc(2026, 5, 19, 8),
      spaceId: 'home',
      spaceTitle: '居家花圃',
      activityId: 'song_time',
      activityTitle: '唱一小段',
      phraseId: 'hello_wave',
      phraseTitle: 'hello',
      reactionType: BabyReactionType.imitated,
      previousPatchStage: GardenPatchStage.quiet,
      currentPatchStage: GardenPatchStage.tended,
      previousFlowerStage: GardenFlowerStage.seed,
      currentFlowerStage: GardenFlowerStage.sprout,
      headline: '花圃醒来了',
      detail: '宝宝模仿了 hello。',
    ),
    totalStoredEvents: 2,
    validEvents: 2,
    knownEvents: 2,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
    projectionWarning: projectionWarning,
  );
}

PracticeContinuitySnapshot _continuitySnapshot() {
  final activity = PracticeCatalogActivitySummary(
    spaceId: 'home',
    spaceTitle: '家里',
    activityId: 'song_time',
    title: '唱一小段',
    summary: '短歌互动',
    sceneTag: 'music',
    coachTip: '放慢一点。',
    totalPhraseCount: 3,
    completedPhraseCount: 1,
    completedPhraseIds: const ['hello_wave'],
    nextPhraseId: 'clap_hands',
    nextPhraseEnglish: 'Clap hands',
    totalEvents: 2,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
    recentResult: PracticeCatalogRecentResultSummary(
      phraseId: 'hello_wave',
      phraseEnglish: 'Hello wave',
      reactionType: BabyReactionType.imitated,
      eventTime: DateTime.utc(2026, 5, 19, 8),
      totalEvents: 2,
    ),
  );
  final catalog = PracticeActivityCatalog(
    installationId: 'install_critical_ui',
    spaces: const [],
    activities: [activity],
    totalStoredEvents: 2,
    validEvents: 2,
    knownEvents: 2,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
  return PracticeContinuitySnapshot(
    catalog: catalog,
    recommendedActivity: activity,
    recentActivity: activity,
    nextIncompleteActivity: activity,
    starterActivity: activity,
    recommendation: PracticeContinuityRecommendation(
      spaceId: activity.spaceId,
      activityId: activity.activityId,
      activityTitle: activity.title,
      reason: PracticeContinuityReason.recentActivity,
      reasonLabel: PracticeContinuityReason.recentActivity.label,
    ),
    cadence: const PracticeContinuityCadenceSummary(
      totalKnownEvents: 2,
      startedActivityCount: 1,
      lastEventTime: null,
      headline: '今天已经开始',
      detail: '继续刚才的节奏。',
    ),
  );
}

ShareLinkDraft _shareDraft() {
  return const ShareLinkDraft(
    source: ShareLinkSource.pairedProgress,
    headline: '今天有一个新尝试',
    storyText: '宝宝跟着节奏模仿了一次。',
    phraseText: 'hello',
    recommendationTitle: '接下来继续唱一小段',
    recommendationReason: '继续刚才的节奏。',
    spaceId: 'home',
    activityId: 'song_time',
  );
}

class _GardenGrowthNotifierStub {
  _GardenGrowthNotifierStub({
    required this.snapshot,
    required this.status,
    this.message,
  });

  final GardenGrowthSnapshot snapshot;
  final GardenGrowthLoadStatus status;
  final String? message;
  int refreshCount = 0;

  bool get hasError => status == GardenGrowthLoadStatus.error;
  bool get isEmpty => snapshot.isEmpty;

  void refresh() {
    refreshCount += 1;
  }
}

class _ShareNotifierStub {
  _ShareNotifierStub({
    required this.currentDraft,
    this.isSharing = false,
    this.lastShareStatus = ShareViewStatus.idle,
    this.message,
  });

  final ShareLinkDraft? currentDraft;
  final bool isSharing;
  final ShareViewStatus lastShareStatus;
  final String? message;
}
