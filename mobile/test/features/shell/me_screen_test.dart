import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
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

    testWidgets('renders growth data block with correct stats', (tester) async {
      final gardenSnapshot = _gardenSnapshot(
        spaceCount: 6,
        knownEvents: 47,
        streakDays: 18,
      );
      await _pumpMeScreen(tester, gardenSnapshot: gardenSnapshot);

      expect(find.byKey(const Key('me-growth-data')), findsOneWidget);
      expect(find.text('成长数据'), findsOneWidget);
      expect(find.text('47 句 · 6 场景'), findsOneWidget); // 练习总量
      expect(find.text('18 天'), findsOneWidget); // 坚持天数
    });

    testWidgets('renders growth data block with zero stats', (tester) async {
      await _pumpMeScreen(tester);

      expect(find.byKey(const Key('me-growth-data')), findsOneWidget);
      expect(find.text('成长数据'), findsOneWidget);
      expect(find.text('0 句 · 0 场景'), findsOneWidget);
      expect(find.text('0 天'), findsOneWidget);
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

    testWidgets('提醒设置 tile opens the named reminder page', (tester) async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.localOnly,
        ),
      );
      await accountNotifier.initialize();
      addTearDown(accountNotifier.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MeScreen()),
          GoRoute(
            path: '/me/settings/reminder',
            builder: (_, _) => const Scaffold(body: Text('提醒页')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gardenGrowthNotifierProvider.overrideWith(
              (ref) => _StubGardenGrowthNotifier(
                snapshot: GardenGrowthSnapshot.empty(),
              ),
            ),
            accountNotifierProvider.overrideWith((ref) => accountNotifier),
            householdNotifierProvider.overrideWith(
              (ref) => HouseholdNotifier(
                repository: _StaticHouseholdRepository(
                  snapshot: HouseholdLocalSnapshot.empty,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.build(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('me-function-reminder')));
      await tester.pumpAndSettle();

      expect(find.text('提醒页'), findsOneWidget);
    });

    testWidgets('renders stat labels in growth data block', (tester) async {
      await _pumpMeScreen(tester);

      expect(find.text('练习总量'), findsOneWidget);
      expect(find.text('坚持天数'), findsOneWidget);
    });

    testWidgets('garden status block opens the garden tab on tap', (
      tester,
    ) async {
      var gardenTaps = 0;
      await _pumpMeScreen(tester, onOpenGarden: () => gardenTaps++);

      await tester.tap(find.byKey(const Key('me-garden-status')));
      await tester.pumpAndSettle();

      expect(gardenTaps, 1);
    });

    testWidgets('growth data block opens the growth detail on tap', (
      tester,
    ) async {
      var growthTaps = 0;
      await _pumpMeScreen(tester, onOpenGrowth: () => growthTaps++);

      await tester.tap(find.byKey(const Key('me-growth-data')));
      await tester.pumpAndSettle();

      expect(growthTaps, 1);
    });

    testWidgets('shows sign-in hint when not signed in', (tester) async {
      await _pumpMeScreen(tester);

      expect(find.byKey(const Key('me-account-state')), findsOneWidget);
      expect(find.text('登录后同步数据'), findsOneWidget);
      expect(find.byKey(const Key('me-account-syncing')), findsNothing);
    });

    testWidgets('shows masked phone and no syncing indicator when signed in', (
      tester,
    ) async {
      await _pumpMeScreen(tester, accountSnapshot: _signedInAccountSnapshot());

      expect(find.text('138****8000'), findsOneWidget);
      expect(find.text('登录后同步数据'), findsNothing);
      expect(find.byKey(const Key('me-account-syncing')), findsNothing);
    });

    testWidgets('shows syncing indicator when sync is pending', (tester) async {
      await _pumpMeScreen(
        tester,
        accountSnapshot: _signedInAccountSnapshot(pendingSyncCount: 2),
      );

      expect(find.text('138****8000'), findsOneWidget);
      expect(find.byKey(const Key('me-account-syncing')), findsOneWidget);
    });

    testWidgets('shows primary caregiver household identity', (tester) async {
      await _pumpMeScreen(
        tester,
        householdSnapshot: const HouseholdLocalSnapshot(
          householdId: 'household_primary',
          role: HouseholdRole.primaryCaregiver,
        ),
      );

      expect(find.text('主照护者'), findsOneWidget);
      expect(find.text('使用家庭共享宝宝档案'), findsNothing);
    });

    testWidgets(
      'shows caregiver household identity and shared profile detail',
      (tester) async {
        await _pumpMeScreen(
          tester,
          householdSnapshot: const HouseholdLocalSnapshot(
            householdId: 'household_caregiver',
            role: HouseholdRole.caregiver,
          ),
        );

        expect(find.text('次照护者'), findsOneWidget);
        expect(find.text('使用家庭共享宝宝档案'), findsOneWidget);
      },
    );

    testWidgets('shows household identity sync before membership loads', (
      tester,
    ) async {
      final loadingNotifier = HouseholdNotifier(
        repository: _StaticHouseholdRepository(
          snapshot: HouseholdLocalSnapshot.empty,
        ),
      );
      await _pumpMeScreen(tester, householdNotifier: loadingNotifier);
      expect(find.text('家庭身份同步中'), findsOneWidget);
      expect(find.text('尚未加入共享家庭'), findsNothing);
    });

    testWidgets('shows no membership after household state loads', (
      tester,
    ) async {
      final noMembershipNotifier = HouseholdNotifier(
        repository: _StaticHouseholdRepository(
          snapshot: HouseholdLocalSnapshot.empty,
        ),
      );
      await noMembershipNotifier.initialize();
      await _pumpMeScreen(tester, householdNotifier: noMembershipNotifier);
      expect(find.text('尚未加入共享家庭'), findsOneWidget);
      expect(find.text('家庭身份同步中'), findsNothing);
    });

    testWidgets('does not claim no membership for a local-load error', (
      tester,
    ) async {
      await _pumpMeScreen(
        tester,
        householdSnapshot: const HouseholdLocalSnapshot(
          lastPhase: 'local_store_unavailable',
          lastVisibleError: '本地家庭状态暂时不可用。',
        ),
      );

      expect(find.text('尚未加入共享家庭'), findsNothing);
      expect(find.text('家庭身份暂时不可用'), findsOneWidget);
      expect(find.text('家庭状态读取失败，请稍后重试。'), findsOneWidget);
    });

    testWidgets('hides stale role while household refresh is in flight', (
      tester,
    ) async {
      final notifier = _HouseholdNotifierIdentityStub(
        isLoading: true,
        hasLoaded: true,
        value: const HouseholdLocalSnapshot(
          householdId: 'household_stale',
          role: HouseholdRole.caregiver,
        ),
      );

      await _pumpMeScreen(tester, householdNotifier: notifier);
      expect(find.text('次照护者'), findsNothing);
      expect(find.text('家庭身份同步中'), findsOneWidget);
      expect(find.text('家庭状态正在更新，暂不显示上一份身份。'), findsOneWidget);
    });

    testWidgets('hides stale role after a household refresh error', (
      tester,
    ) async {
      await _pumpMeScreen(
        tester,
        householdSnapshot: const HouseholdLocalSnapshot(
          householdId: 'household_stale',
          role: HouseholdRole.caregiver,
          lastPhase: 'shared_context_offline',
          lastVisibleError: '当前离线，已保留最近一次稳定状态。',
        ),
      );

      expect(find.text('次照护者'), findsNothing);
      expect(find.text('尚未加入共享家庭'), findsNothing);
      expect(find.text('家庭身份暂时不可用'), findsOneWidget);
      expect(find.text('家庭状态正在更新，暂不显示上一份身份。'), findsOneWidget);
    });
  });
}

Future<void> _pumpMeScreen(
  WidgetTester tester, {
  OnboardingSnapshot? onboardingSnapshot,
  GardenGrowthSnapshot? gardenSnapshot,
  VoidCallback? onOpenGarden,
  VoidCallback? onOpenGrowth,
  AccountLocalSnapshot? accountSnapshot,
  HouseholdLocalSnapshot? householdSnapshot,
  HouseholdNotifier? householdNotifier,
}) async {
  final snapshot = gardenSnapshot ?? GardenGrowthSnapshot.empty();
  final accountNotifier = AccountNotifier(
    repository: _StaticAccountRepository(
      seedSnapshot: accountSnapshot ?? AccountLocalSnapshot.localOnly,
    ),
  );
  await accountNotifier.initialize();
  final resolvedHouseholdNotifier =
      householdNotifier ??
      HouseholdNotifier(
        repository: _StaticHouseholdRepository(
          snapshot: householdSnapshot ?? HouseholdLocalSnapshot.empty,
        ),
      );
  if (householdNotifier == null || householdSnapshot != null) {
    await resolvedHouseholdNotifier.initialize();
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gardenGrowthNotifierProvider.overrideWith((ref) {
          return _StubGardenGrowthNotifier(snapshot: snapshot);
        }),
        accountNotifierProvider.overrideWith((ref) => accountNotifier),
        householdNotifierProvider.overrideWith(
          (ref) => resolvedHouseholdNotifier,
        ),
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
  // Avoid pumpAndSettle: the syncing indicator animates indefinitely.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

AccountLocalSnapshot _signedInAccountSnapshot({int pendingSyncCount = 0}) {
  return AccountLocalSnapshot(
    consentState: AccountConsentState.acceptedPendingSync,
    session: AccountSession(
      accountId: 'acct-me-screen',
      sessionId: 'sess-me-screen',
      maskedPhoneNumber: '138****8000',
      createdAt: DateTime.utc(2026, 4, 9, 1),
    ),
    pendingSyncCount: pendingSyncCount,
    syncedCount: 4,
    failedCount: 0,
    lastSyncPhase: pendingSyncCount > 0 ? 'pending' : 'synced',
    lastSyncAt: DateTime.utc(2026, 4, 9, 1, 5),
  );
}

OnboardingSnapshot _onboardingSnapshot() {
  final stageMatch = StageMatchCatalog.forAgeBucket(
    OnboardingAgeBucket.sevenToTwelve,
  );
  return OnboardingSnapshot(
    childDisplayName: '米米',
    ageBucket: OnboardingAgeBucket.sevenToTwelve,
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
  int streakDays = 0,
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
    currentStreakDays: streakDays,
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
  Future<void> refreshForAccountProjection() async {}

  @override
  void bindAccountContext(String? accountContext, {bool notify = true}) {}

  @override
  void resetToSafeEmpty() {
    _snapshot = GardenGrowthSnapshot.empty();
    notifyListeners();
  }
}

/// A static [AccountRepository] returning a fixed snapshot, for MeScreen tests.
class _StaticAccountRepository implements AccountRepository {
  _StaticAccountRepository({required this.seedSnapshot});

  final AccountLocalSnapshot seedSnapshot;

  @override
  final String consentVersion = 'pipl-v1';

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => seedSnapshot ?? this.seedSnapshot;

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async => seedSnapshot;

  @override
  Future<AccountSession> persistRefreshedSession(
    AccountSession refreshedSession,
  ) async => refreshedSession;

  @override
  Future<void> deleteLocalSnapshotForLifecycle() async {}

  @override
  Future<void> close() async {}
}

class _StaticHouseholdRepository extends Fake implements HouseholdRepository {
  _StaticHouseholdRepository({required this.snapshot});

  final HouseholdLocalSnapshot snapshot;

  @override
  Future<HouseholdLocalSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<void> close() async {}
}

class _HouseholdNotifierIdentityStub extends HouseholdNotifier {
  _HouseholdNotifierIdentityStub({
    required this.isLoading,
    required this.hasLoaded,
    required this.value,
  }) : super(repository: _StaticHouseholdRepository(snapshot: value));

  @override
  final bool isLoading;

  @override
  final bool hasLoaded;

  final HouseholdLocalSnapshot value;

  @override
  HouseholdLocalSnapshot get snapshot => value;
}
