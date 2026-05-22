import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/shell/presentation/screens/garden_growth_combined_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'garden tab preserves loading, error, empty, and refresh states',
    (tester) async {
      await _pumpScreen(
        tester,
        status: GardenGrowthLoadStatus.loading,
        snapshot: GardenGrowthSnapshot.empty(),
      );

      expect(
        find.byKey(const Key('growth-combined-segmented-control')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('growth-combined-loading-shimmer')),
        findsOneWidget,
      );

      await _pumpScreen(
        tester,
        status: GardenGrowthLoadStatus.error,
        snapshot: GardenGrowthSnapshot.empty(),
        message: '花园暂时不可用。',
      );

      expect(
        find.byKey(const Key('growth-combined-garden-warning-banner')),
        findsOneWidget,
      );
      expect(find.text('花园暂时不可用。'), findsOneWidget);
      expect(
        find.byKey(const Key('growth-combined-empty-state')),
        findsOneWidget,
      );
    },
  );

  testWidgets('garden tab renders ready patch and missing shared provider', (
    tester,
  ) async {
    _setTallViewport(tester);

    final notifier = await _pumpScreen(
      tester,
      status: GardenGrowthLoadStatus.ready,
      snapshot: _gardenSnapshot(spaces: [_gardenPatch()]),
    );

    final refreshState = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refreshState.show();
    await tester.pumpAndSettle();
    await refreshFuture;
    expect(notifier.refreshCount, 1);

    expect(find.byKey(const Key('garden-hero-card')), findsOneWidget);
    expect(find.byKey(const Key('garden-continue-card')), findsOneWidget);
    expect(find.byKey(const Key('garden-patch-home')), findsOneWidget);
    expect(find.byKey(const Key('garden-flower-song_time')), findsOneWidget);
    expect(
      find.byKey(const Key('growth-combined-household-provider-missing')),
      findsOneWidget,
    );
  });

  testWidgets('growth tab keeps diary and milestone preview limits', (
    tester,
  ) async {
    _setTallViewport(tester);

    await _pumpScreen(
      tester,
      status: GardenGrowthLoadStatus.ready,
      snapshot: _gardenSnapshot(
        spaces: [_gardenPatch()],
        diaryEntries: _diaryEntries(4),
        milestones: _milestones(7),
        projectionWarning: '有 1 条记录暂时无法归类。',
      ),
    );

    await _openGrowthTab(tester);

    expect(
      find.byKey(const Key('growth-combined-latest-impact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('growth-combined-projection-warning')),
      findsOneWidget,
    );
    expect(find.text('有一小段练习记录暂时没整理好，花圃先保留可用结果。'), findsOneWidget);
    expect(find.textContaining('有 1 条记录'), findsNothing);
    expect(find.text('花圃醒来了'), findsOneWidget);
    expect(find.text('宝宝模仿了 hello。'), findsOneWidget);
    expect(
      find.byKey(const Key('growth-combined-diary-view-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('growth-combined-milestones-view-all')),
      findsOneWidget,
    );

    for (var index = 0; index < 3; index += 1) {
      expect(
        find.byKey(Key('growth-combined-diary-diary_$index')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('growth-combined-diary-diary_3')),
      findsNothing,
    );

    for (var index = 0; index < 6; index += 1) {
      expect(
        find.byKey(Key('growth-combined-milestone-milestone_$index')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('growth-combined-milestone-milestone_6')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('growth-combined-diary-view-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('growth-combined-diary-sheet')),
      findsOneWidget,
    );
    expect(find.text('全部成长日记'), findsOneWidget);
    expect(find.text('共 4 条记录'), findsOneWidget);
    expect(find.text('练习记录'), findsWidgets);
    expect(
      find.byKey(const Key('growth-combined-diary-sheet-diary_3')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('growth-preview-sheet-close')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('growth-combined-milestones-view-all')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('growth-combined-milestones-sheet')),
      findsOneWidget,
    );
    expect(find.text('全部里程碑'), findsOneWidget);
    expect(find.text('已点亮'), findsWidgets);
    expect(find.text('待点亮'), findsWidgets);
    expect(
      find.byKey(const Key('growth-combined-milestone-sheet-milestone_6')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('growth-combined-latest-impact')),
      findsOneWidget,
    );
  });

  testWidgets(
    'growth tab localizes hero label and keeps preview actions tappable',
    (tester) async {
      _setTallViewport(tester);

      await _pumpScreen(
        tester,
        status: GardenGrowthLoadStatus.ready,
        snapshot: _gardenSnapshot(
          spaces: [_gardenPatch()],
          diaryEntries: _diaryEntries(4),
          milestones: _milestones(7),
        ),
      );

      await _openGrowthTab(tester);

      final hero = find.byKey(const Key('growth-combined-latest-impact'));
      expect(
        find.descendant(of: hero, matching: find.text('Growth diary')),
        findsNothing,
      );
      expect(
        find.descendant(of: hero, matching: find.text('成长日记')),
        findsOneWidget,
      );

      for (final actionKey in [
        const Key('growth-combined-diary-view-all'),
        const Key('growth-combined-milestones-view-all'),
      ]) {
        final size = tester.getSize(find.byKey(actionKey));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    },
  );

  testWidgets('growth tab renders empty diary and milestone sections', (
    tester,
  ) async {
    _setTallViewport(tester);

    await _pumpScreen(
      tester,
      status: GardenGrowthLoadStatus.ready,
      snapshot: _gardenSnapshot(spaces: [_gardenPatch()], includeImpact: false),
    );

    await _openGrowthTab(tester);

    expect(
      find.byKey(const Key('growth-combined-diary-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('growth-combined-milestones-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('growth-combined-diary-view-all')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('growth-combined-milestones-view-all')),
      findsNothing,
    );
  });

  testWidgets('growth preview sheets stay scrollable on compact phones', (
    tester,
  ) async {
    _setPhoneViewport(tester);

    await _pumpScreen(
      tester,
      status: GardenGrowthLoadStatus.ready,
      snapshot: _gardenSnapshot(
        spaces: [_gardenPatch()],
        diaryEntries: _diaryEntries(12),
        milestones: _milestones(12),
      ),
    );

    await _openGrowthTab(tester);

    await tester.tap(find.byKey(const Key('growth-combined-diary-view-all')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('growth-combined-diary-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('growth-preview-sheet-close')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('growth-combined-diary-sheet-diary_9')),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('growth-combined-diary-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.byKey(const Key('growth-combined-diary-sheet-diary_9')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('growth-preview-sheet-close')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('growth-combined-milestones-view-all')),
    );
    await tester.tap(
      find.byKey(const Key('growth-combined-milestones-view-all')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('growth-combined-milestones-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('growth-preview-sheet-close')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('growth-combined-milestone-sheet-milestone_11')),
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('growth-combined-milestones-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.byKey(const Key('growth-combined-milestone-sheet-milestone_11')),
      findsOneWidget,
    );
  });
}

Future<_GardenGrowthNotifierHarness> _pumpScreen(
  WidgetTester tester, {
  required GardenGrowthLoadStatus status,
  required GardenGrowthSnapshot snapshot,
  String? message,
}) async {
  final notifier = _GardenGrowthNotifierHarness(
    snapshot: snapshot,
    status: status,
    message: message,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [gardenGrowthNotifierProvider.overrideWith((ref) => notifier)],
      key: UniqueKey(),
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.build(),
        home: const Scaffold(body: GardenGrowthCombinedScreen()),
      ),
    ),
  );
  await tester.pump();
  return notifier;
}

Future<void> _openGrowthTab(WidgetTester tester) async {
  final context = tester.element(
    find.byKey(const Key('growth-combined-segmented-control')),
  );
  final l = AppLocalizations.of(context)!;
  await tester.tap(find.text(l.shellGrowth));
  await tester.pumpAndSettle();
}

void _setTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(900, 4200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

GardenGrowthSnapshot _gardenSnapshot({
  required List<GardenPatchSnapshot> spaces,
  List<GrowthDiaryEntry> diaryEntries = const [],
  List<GrowthMilestoneSnapshot> milestones = const [],
  LatestPracticeImpact? latestImpact,
  bool includeImpact = true,
  String? projectionWarning,
}) {
  return GardenGrowthSnapshot(
    installationId: 'install_growth_combined_test',
    spaces: spaces,
    diaryEntries: diaryEntries,
    milestones: milestones,
    latestImpact: includeImpact ? latestImpact ?? _latestImpact() : null,
    totalStoredEvents: 2,
    validEvents: 2,
    knownEvents: 2,
    skippedMalformedEvents: projectionWarning == null ? 0 : 1,
    skippedUnknownContentEvents: 0,
    projectionWarning: projectionWarning,
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
    activities: [_gardenFlower()],
    careNote: '花圃刚被照料',
    lastPracticedAt: DateTime.utc(2026, 5, 19, 8),
  );
}

GardenFlowerSnapshot _gardenFlower() {
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

List<GrowthDiaryEntry> _diaryEntries(int count) {
  return List.generate(count, (index) {
    return GrowthDiaryEntry(
      entryId: 'diary_$index',
      kind: GrowthDiaryEntryKind.practice,
      occurredAt: DateTime.utc(
        2026,
        5,
        19,
        8,
      ).subtract(Duration(minutes: index)),
      title: '日记 $index',
      body: '宝宝完成了第 $index 次练习。',
      spaceId: 'home',
      activityId: 'song_time',
    );
  });
}

List<GrowthMilestoneSnapshot> _milestones(int count) {
  return List.generate(count, (index) {
    return GrowthMilestoneSnapshot(
      id: 'milestone_$index',
      title: '里程碑 $index',
      body: '第 $index 个成长节点。',
      sortOrder: index,
      achievedAt: index.isEven ? DateTime.utc(2026, 5, 19, 8) : null,
    );
  });
}

LatestPracticeImpact _latestImpact() {
  return LatestPracticeImpact(
    eventKey: 'install_growth_combined_test:evt_1',
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
  );
}

class _GardenGrowthNotifierHarness extends GardenGrowthNotifier {
  _GardenGrowthNotifierHarness({
    required GardenGrowthSnapshot snapshot,
    required GardenGrowthLoadStatus status,
    String? message,
  }) : _snapshot = snapshot,
       _status = status,
       _message = message,
       super(repository: _GardenGrowthRepositoryFake(snapshot));

  final GardenGrowthSnapshot _snapshot;
  final GardenGrowthLoadStatus _status;
  final String? _message;
  int refreshCount = 0;

  @override
  GardenGrowthSnapshot get snapshot => _snapshot;

  @override
  GardenGrowthLoadStatus get status => _status;

  @override
  String? get message => _message;

  @override
  bool get hasError => _status == GardenGrowthLoadStatus.error;

  @override
  Future<void> refresh() async {
    refreshCount += 1;
  }
}

class _GardenGrowthRepositoryFake implements GardenGrowthRepository {
  const _GardenGrowthRepositoryFake(this.snapshot);

  final GardenGrowthSnapshot snapshot;

  @override
  Future<GardenGrowthSnapshot> buildSnapshot() async => snapshot;
}
