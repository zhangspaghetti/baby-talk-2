import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/shell/presentation/screens/me_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  group('MeScreen', () {
    testWidgets('renders user info section with child name', (tester) async {
      await _pumpMeScreen(tester, onboardingSnapshot: _onboardingSnapshot());

      expect(find.byKey(const Key('me-user-info')), findsOneWidget);
      expect(find.text('米米'), findsOneWidget);
      // Avatar shows first character
      expect(find.text('米'), findsWidgets);
    });

    testWidgets('shows default baby name when onboarding snapshot is null', (
      tester,
    ) async {
      await _pumpMeScreen(tester, onboardingSnapshot: null);

      expect(find.byKey(const Key('me-user-info')), findsOneWidget);
      // Default name from l10n: "这位宝宝"
      expect(find.text('这位宝宝'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('shows age bucket label when available', (tester) async {
      final snapshot = _onboardingSnapshot();
      await _pumpMeScreen(tester, onboardingSnapshot: snapshot);

      final ageLabel = snapshot.ageBucket.label;
      expect(find.text(ageLabel), findsOneWidget);
    });

    testWidgets('renders garden status block', (tester) async {
      await _pumpMeScreen(tester);

      expect(find.byKey(const Key('me-garden-status')), findsOneWidget);
      // With 0 spaces, shows empty state
      expect(find.text('还没有种下花圃'), findsOneWidget);
    });

    testWidgets('shows garden summary when spaces exist', (tester) async {
      final gardenSnapshot = _gardenSnapshot(spaceCount: 2);
      await _pumpMeScreen(tester, gardenSnapshot: gardenSnapshot);

      expect(find.byKey(const Key('me-garden-status')), findsOneWidget);
      expect(find.text('2 个花圃正在成长'), findsOneWidget);
    });

    testWidgets('renders growth data block with correct stats', (
      tester,
    ) async {
      final gardenSnapshot = _gardenSnapshot(
        spaceCount: 1,
        knownEvents: 5,
        diaryCount: 2,
        milestoneCount: 3,
        achievedMilestones: 1,
      );
      await _pumpMeScreen(tester, gardenSnapshot: gardenSnapshot);

      expect(find.byKey(const Key('me-growth-data')), findsOneWidget);
      expect(find.text('成长数据'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // events
      expect(find.text('2'), findsOneWidget); // diary
      expect(find.text('1/3'), findsOneWidget); // milestones
    });

    testWidgets('renders growth data block with zero stats', (tester) async {
      await _pumpMeScreen(tester);

      expect(find.byKey(const Key('me-growth-data')), findsOneWidget);
      expect(find.text('成长数据'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // all zero
    });

    testWidgets('renders function grid with all four tiles', (tester) async {
      await _pumpMeScreen(tester);

      expect(find.text('提醒设置'), findsOneWidget);
      expect(find.text('宝宝档案'), findsOneWidget);
      expect(find.text('播放偏好'), findsOneWidget);
      expect(find.text('帮助与反馈'), findsOneWidget);
    });

    testWidgets('function grid is a 2-column grid', (tester) async {
      await _pumpMeScreen(tester);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('renders stat labels in growth data block', (tester) async {
      await _pumpMeScreen(tester);

      expect(find.text('练习次数'), findsOneWidget);
      expect(find.text('成长日记'), findsOneWidget);
      expect(find.text('里程碑'), findsOneWidget);
    });

    testWidgets('garden status block opens the garden tab on tap', (
      tester,
    ) async {
      var gardenTaps = 0;
      await _pumpMeScreen(
        tester,
        onOpenGarden: () => gardenTaps++,
      );

      await tester.tap(find.byKey(const Key('me-garden-status')));
      await tester.pumpAndSettle();

      expect(gardenTaps, 1);
    });

    testWidgets('growth data block opens the growth detail on tap', (
      tester,
    ) async {
      var growthTaps = 0;
      await _pumpMeScreen(
        tester,
        onOpenGrowth: () => growthTaps++,
      );

      await tester.tap(find.byKey(const Key('me-growth-data')));
      await tester.pumpAndSettle();

      expect(growthTaps, 1);
    });
  });
}

Future<void> _pumpMeScreen(
  WidgetTester tester, {
  OnboardingSnapshot? onboardingSnapshot,
  GardenGrowthSnapshot? gardenSnapshot,
  VoidCallback? onOpenGarden,
  VoidCallback? onOpenGrowth,
}) async {
  final snapshot = gardenSnapshot ?? GardenGrowthSnapshot.empty();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gardenGrowthNotifierProvider.overrideWith((ref) {
          return _StubGardenGrowthNotifier(snapshot: snapshot);
        }),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.build(),
        home: Scaffold(
          body: MeScreen(
            onboardingSnapshot: onboardingSnapshot,
            onOpenGarden: onOpenGarden,
            onOpenGrowth: onOpenGrowth,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

OnboardingSnapshot _onboardingSnapshot() {
  final stageMatch = StageMatchCatalog.forAgeBucket(
    OnboardingAgeBucket.sixToTwelve,
  );
  return OnboardingSnapshot(
    childDisplayName: '米米',
    ageBucket: OnboardingAgeBucket.sixToTwelve,
    approxMonths: stageMatch.approxMonths,
    currentStage: stageMatch.stageId,
    starterSpaceId: 'daily_care',
    starterActivityId: 'bath_time',
    starterPhraseId: 'bath_time_warm_water',
    consentState: OnboardingConsentState.localOnly,
    completedAt: DateTime.utc(2026, 4, 8, 8),
  );
}

GardenGrowthSnapshot _gardenSnapshot({
  int spaceCount = 0,
  int knownEvents = 0,
  int diaryCount = 0,
  int milestoneCount = 0,
  int achievedMilestones = 0,
}) {
  final spaces = List.generate(
    spaceCount,
    (index) => GardenPatchSnapshot(
      spaceId: 'space_$index',
      title: '花圃 $index',
      description: '描述 $index',
      stage: GardenPatchStage.tended,
      totalKnownEvents: knownEvents,
      startedActivityCount: 1,
      completedActivityCount: 0,
      totalActivityCount: 1,
      activities: const [],
      careNote: '继续照料',
      lastPracticedAt: DateTime.utc(2026, 5, 19, 8),
    ),
  );

  final milestones = List.generate(
    milestoneCount,
    (index) => GrowthMilestoneSnapshot(
      id: 'milestone_$index',
      title: '里程碑 $index',
      body: '描述 $index',
      sortOrder: index,
      achievedAt: index < achievedMilestones
          ? DateTime.utc(2026, 5, 20, index)
          : null,
    ),
  );

  final diaryEntries = List.generate(
    diaryCount,
    (index) => GrowthDiaryEntry(
      entryId: 'diary_$index',
      kind: GrowthDiaryEntryKind.milestone,
      occurredAt: DateTime.utc(2026, 5, 20, index),
      title: '日记 $index',
      body: '内容 $index',
      spaceId: 'space_0',
      activityId: 'activity_0',
    ),
  );

  return GardenGrowthSnapshot(
    installationId: 'install_me_screen_test',
    spaces: spaces,
    diaryEntries: diaryEntries,
    milestones: milestones,
    latestImpact: null,
    totalStoredEvents: knownEvents,
    validEvents: knownEvents,
    knownEvents: knownEvents,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
}

/// A stub [GardenGrowthNotifier] for testing MeScreen without a real
/// repository. Returns a configurable snapshot.
class _StubGardenGrowthNotifier extends ChangeNotifier
    implements GardenGrowthNotifier {
  _StubGardenGrowthNotifier({required GardenGrowthSnapshot snapshot})
      : _snapshot = snapshot;

  GardenGrowthSnapshot _snapshot;

  @override
  GardenGrowthSnapshot get snapshot => _snapshot;

  @override
  GardenGrowthLoadStatus get status => GardenGrowthLoadStatus.ready;

  @override
  bool get isReady => true;

  @override
  bool get isRefreshing => false;

  @override
  String? get message => null;

  @override
  bool get isEmpty => _snapshot.isEmpty;

  @override
  bool get hasError => false;

  @override
  Duration get refreshTimeout => const Duration(seconds: 4);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh() async {}

  @override
  void resetToSafeEmpty() {
    _snapshot = GardenGrowthSnapshot.empty();
    notifyListeners();
  }
}
