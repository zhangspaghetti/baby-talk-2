import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Provider;
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/router/custom_scene_care_turn_handoff.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_input_screen.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_flower_stage.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';
import 'package:mobile/features/garden/presentation/garden_fertilizer_notifier.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/care_entry/presentation/screens/care_entry_onboarding_screen.dart';
import 'package:mobile/features/care_entry/data/file_onboarding_conversation_repository.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import '../support/isar_test_library.dart';
import '../support/onboarding_test_fixtures.dart';
import '../support/generated_care_moment_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );

    // app_links 插件在 shell 路由中订阅 EventChannel，单元测试环境需要 mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (MethodCall methodCall) async => null,
        );

    // audioplayers 插件可能被惰性创建的 AudioPlayer 在测试完成后初始化，
    // 若不 mock 会抛出 MissingPluginException 连累所在测试失败。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (MethodCall methodCall) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (MethodCall methodCall) async => null,
        );
  });

  test('seed content parser rejects malformed payload', () {
    expect(
      () => SeedContentBundle.fromJsonString('{"schemaVersion":1,"spaces":[]}'),
      throwsFormatException,
    );
  });

  test('seed content validator rejects wrong audio asset key', () async {
    final bundle = SeedContentBundle(
      spaces: [
        SeedSpace(
          id: 'daily_care',
          title: '日常照护',
          description: 'desc',
          activities: [
            SeedActivity(
              id: 'bath_time',
              title: '洗澡时间',
              summary: 'summary',
              sceneTag: 'Bath time',
              coachTip: 'tip',
              phrases: [
                SeedPhrase(
                  id: 'bad',
                  step: 1,
                  english: 'Bad',
                  chinese: '坏',
                  pronunciation: 'bad',
                  difficulty: 'starter',
                  audioAsset: 'audio/bad.mp3',
                ),
              ],
            ),
          ],
        ),
      ],
    );

    expect(bundle.validateAssets(rootBundle), throwsFormatException);
  });

  testWidgets('fresh install 先进入 onboarding gate，而不是默认 guest home', (
    WidgetTester tester,
  ) async {
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      return _createHarness();
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            harness.bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => harness.tempDir),
          mentorRepositoryProvider.overrideWith(
            (ref) async => harness.mentorRepository,
          ),
          practiceRepositoryProvider.overrideWith((ref) => harness.repository),
          accountRepositoryProvider.overrideWith(
            (ref) => AccountRepository(
              localStore: AccountLocalStore(),
              practiceRepository: harness.repository,
            ),
          ),
          householdRepositoryProvider.overrideWith((ref) {
            final accountRepo = ref
                .read(accountRepositoryProvider)
                .requireValue;
            return HouseholdRepository(
              localStore: HouseholdLocalStore(
                directoryResolver: () async => harness.tempDir,
              ),
              apiService: HouseholdApiService(),
              accountSnapshotLoader: accountRepo.loadSnapshot,
              persistRefreshedSession: accountRepo.persistRefreshedSession,
            );
          }),
        ],
        child: BabyTalkApp(
          bootState: harness.bootState,
          audioControllerFactory: _SilentPracticeAudioController.new,
          completedSnapshotLoader: () async => null,
          practiceContinuityRefreshTimeout: Duration.zero,
          gardenGrowthRefreshTimeout: Duration.zero,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('boot-route-onboarding')),
    );

    expect(find.byKey(const Key('boot-route-gate-ready')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsOneWidget);
    await _pumpUntilFound(tester, find.text('今天先从现在这一刻开始。'));
    expect(find.byType(CareEntryOnboardingScreen), findsOneWidget);
    expect(find.text('今天先从现在这一刻开始。'), findsOneWidget);
    expect(find.byKey(const Key('home-start-practice')), findsNothing);

    final content = harness.bootState.content!;
    final allActivities = [
      for (final space in content.spaces) ...space.activities,
    ];
    final allPhrases = [
      for (final activity in allActivities) ...activity.phrases,
    ];

    expect(content.spaces.map((space) => space.id), [
      'daily_care',
      'family_rhythm',
    ]);
    expect(allActivities.map((activity) => activity.id), [
      'bath_time',
      'diaper_change',
      'post_cry_soothing',
      'feeding_time',
      'bedtime',
    ]);
    expect(allPhrases, hasLength(10));

    for (final phrase in allPhrases) {
      final audioBytes = await rootBundle.load(phrase.audioAsset);
      expect(audioBytes.lengthInBytes, greaterThan(0));
    }
  });

  testWidgets('deferred V4 cold start stays in Today shell', (
    WidgetTester tester,
  ) async {
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      await FileOnboardingConversationRepository(
        directoryResolver: () async => created.tempDir,
      ).save(
        OnboardingConversationSnapshot(
          status: OnboardingConversationStatus.deferred,
          deferredAt: DateTime.utc(2026, 8, 14, 12),
          registryRevision: 'test.deferred.1',
          phase: OnboardingCheckpointPhase.selection,
          selectedEntryId: const CareEntryId('care.bedtime_soothing'),
        ),
      );
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async => _disposeWidgetTree(tester));

    await tester.pumpWidget(
      _bootApp(harness, completedSnapshotLoader: () async => null),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));

    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
  });

  testWidgets('in-progress M1 boot quarantines metadata and opens fresh V4', (
    WidgetTester tester,
  ) async {
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      await File(
        '${created.tempDir.path}${Platform.pathSeparator}onboarding_flow_snapshot.json',
      ).writeAsString(
        '{"schemaVersion":1,"step":"care_turn","starterPhraseId":"legacy-private","updatedAt":"2026-08-01T08:00:00.000Z"}',
      );
      await OnboardingSnapshotStore(
        directoryResolver: () async => created.tempDir,
      ).write(
        const OnboardingSnapshot(
          schemaVersion: 1,
          childDisplayName: 'legacy-private-name',
          ageBucket: OnboardingAgeBucket.oneToTwo,
          approxMonths: 15,
          currentStage: 'gesture_plus_words',
          starterSpaceId: 'daily_care',
          starterActivityId: 'bedtime',
          starterPhraseId: 'legacy-private-phrase',
          consentState: OnboardingConsentState.localOnly,
        ),
      );
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async => _disposeWidgetTree(tester));

    await tester.pumpWidget(
      _bootApp(harness, completedSnapshotLoader: () async => null),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('boot-route-onboarding')),
    );

    final metadata = (await tester.runAsync<List<String>>(() async {
      final legacy = File(
        '${harness.tempDir.path}${Platform.pathSeparator}onboarding_flow_snapshot.json',
      );
      expect(await legacy.exists(), isFalse);
      final legacySnapshot = File(
        '${harness.tempDir.path}${Platform.pathSeparator}onboarding_snapshot.json',
      );
      expect(await legacySnapshot.exists(), isFalse);
      return Future.wait(<Future<String>>[
        File(
          '${harness.tempDir.path}${Platform.pathSeparator}onboarding_flow_snapshot.m1_quarantine.json',
        ).readAsString(),
        File(
          '${harness.tempDir.path}${Platform.pathSeparator}onboarding_snapshot.m1_quarantine.json',
        ).readAsString(),
      ]);
    }))!;
    expect(metadata, everyElement(contains('legacy_m1_in_progress')));
    expect(metadata.join(), isNot(contains('legacy-private')));
    expect(find.byKey(const Key('boot-route-shell')), findsNothing);
  });

  testWidgets('account route renders the AccountNotifier-backed entry screen', (
    WidgetTester tester,
  ) async {
    final harness = (await tester.runAsync<_AppBootHarness>(_createHarness))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    await tester.pumpWidget(
      _bootApp(harness, completedSnapshotLoader: () async => null),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('boot-route-onboarding')),
    );

    GoRouter.of(
      tester.element(find.byKey(const Key('boot-route-onboarding'))),
    ).go(AppRouteNames.account);
    await _pumpUntilFound(tester, find.byKey(const Key('auth-contact-field')));

    expect(find.byKey(const Key('auth-contact-field')), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
    expect(find.byKey(const Key('account-entry-surface')), findsNothing);
  });

  testWidgets('runtime router opens the custom scene input screen', (
    WidgetTester tester,
  ) async {
    final harness = (await tester.runAsync<_AppBootHarness>(_createHarness))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    await tester.pumpWidget(
      _bootApp(harness, completedSnapshotLoader: () async => null),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('boot-route-onboarding')),
    );

    GoRouter.of(
      tester.element(find.byKey(const Key('boot-route-onboarding'))),
    ).go(AppRouteNames.customScene);
    await _pumpUntilFound(tester, find.byType(CustomSceneInputScreen));

    expect(find.byType(CustomSceneInputScreen), findsOneWidget);
  });

  testWidgets('存在 completed snapshot 时冷启动直接进入 shell home', (
    WidgetTester tester,
  ) async {
    late OnboardingSnapshot completedSnapshot;
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      final onboardingRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => created.tempDir,
        ),
      );
      completedSnapshot = await saveCompletedOnboardingSnapshot(
        onboardingRepository,
        childDisplayName: '米米',
        ageBucket: OnboardingAgeBucket.zeroToSix,
        selectedSceneIds: const ['bedtime'],
        supportGoal: OnboardingSupportGoal.firstWords,
        starterSpaceId: 'family_rhythm',
        starterActivityId: 'bedtime',
        starterPhraseId: 'bedtime_dim_the_lights',
        firstTraceEventKey: 'install_smoke_test:evt_onboarding_first',
        completedAt: DateTime.utc(2026, 4, 8, 8),
      );
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            harness.bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => harness.tempDir),
          mentorRepositoryProvider.overrideWith(
            (ref) async => harness.mentorRepository,
          ),
          practiceRepositoryProvider.overrideWith((ref) => harness.repository),
          accountRepositoryProvider.overrideWith(
            (ref) => AccountRepository(
              localStore: AccountLocalStore(),
              practiceRepository: harness.repository,
            ),
          ),
          householdRepositoryProvider.overrideWith((ref) {
            final accountRepo = ref
                .read(accountRepositoryProvider)
                .requireValue;
            return HouseholdRepository(
              localStore: HouseholdLocalStore(
                directoryResolver: () async => harness.tempDir,
              ),
              apiService: HouseholdApiService(),
              accountSnapshotLoader: accountRepo.loadSnapshot,
              persistRefreshedSession: accountRepo.persistRefreshedSession,
            );
          }),
          onboardingRepositoryProvider.overrideWith((ref) {
            return OnboardingRepository(
              snapshotStore: OnboardingSnapshotStore(
                directoryResolver: () async => harness.tempDir,
              ),
            );
          }),
        ],
        child: BabyTalkApp(
          bootState: harness.bootState,
          audioControllerFactory: _SilentPracticeAudioController.new,
          completedSnapshotLoader: () async => completedSnapshot,
          practiceContinuityRefreshTimeout: Duration.zero,
          gardenGrowthRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));

    expect(find.byKey(const Key('boot-route-gate-ready')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shell-ready'))),
    );
    final defaultArgs = container.read(defaultPracticeRouteArgsProvider);
    expect(defaultArgs.spaceId, 'family_rhythm');
    expect(defaultArgs.activityId, 'bedtime');
  });

  testWidgets('legacy completed snapshot remains shell compatible', (
    WidgetTester tester,
  ) async {
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      final match = StageMatchCatalog.forAgeBucket(
        OnboardingAgeBucket.zeroToSix,
      );
      await _onboardingRepositoryFor(created).saveSnapshot(
        OnboardingSnapshot(
          schemaVersion: 1,
          childDisplayName: '米米',
          ageBucket: match.ageBucket,
          approxMonths: match.approxMonths,
          currentStage: match.stageId,
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          consentState: OnboardingConsentState.localOnly,
          completedAt: DateTime.utc(2026, 7, 24, 12),
        ),
      );
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    await tester.pumpWidget(_bootApp(harness));
    await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));

    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shell-ready'))),
    );
    expect(
      container.read(defaultPracticeRouteArgsProvider).activityId,
      'bath_time',
    );
  });

  testWidgets(
    'production router opens the same generated Care Turn for automatic and retry handoff',
    (WidgetTester tester) async {
      late OnboardingSnapshot completedSnapshot;
      final harness = (await tester.runAsync<_AppBootHarness>(() async {
        final created = await _createHarness();
        completedSnapshot = await saveCompletedOnboardingSnapshot(
          _onboardingRepositoryFor(created),
          childDisplayName: '米米',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          selectedSceneIds: const ['bedtime'],
          supportGoal: OnboardingSupportGoal.firstWords,
          starterSpaceId: 'family_rhythm',
          starterActivityId: 'bedtime',
          starterPhraseId: 'bedtime_dim_the_lights',
          firstTraceEventKey: 'install_handoff_test:evt_onboarding_first',
          completedAt: DateTime.utc(2026, 8, 2, 8),
        );
        return created;
      }))!;
      addTearDown(harness.close);
      addTearDown(() async {
        await _disposeWidgetTree(tester);
      });

      await tester.pumpWidget(
        _bootApp(
          harness,
          completedSnapshotLoader: () async => completedSnapshot,
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

      const sink = AppCustomSceneCareTurnHandoffSink();
      final handoff = CustomSceneCareTurnHandoff(
        generatedContentId: 'generated_reconciled',
      );

      Future<void> expectGeneratedHandoff() async {
        var routeAttemptCompleted = false;
        final routeAttempt = await sink.handoff(handoff);
        unawaited(
          routeAttempt.routeCompletion.then((_) {
            routeAttemptCompleted = true;
          }),
        );
        await _pumpUntilFound(tester, find.byType(PracticeSessionScreen));
        final screen = tester.widget<PracticeSessionScreen>(
          find.byType(PracticeSessionScreen),
        );
        expect(
          screen.routeEntry.generatedArgs?.generatedContentId,
          'generated_reconciled',
        );
        await tester.pump();
        expect(routeAttemptCompleted, isFalse);

        Navigator.of(tester.element(find.byType(PracticeSessionScreen))).pop();
        await routeAttempt.routeCompletion;
        expect(routeAttemptCompleted, isTrue);
        await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
      }

      await expectGeneratedHandoff();
      await expectGeneratedHandoff();
    },
  );

  testWidgets(
    '存在 completed snapshot 与 recent activity 时冷启动会 seed continuity recommendation',
    (WidgetTester tester) async {
      late OnboardingSnapshot completedSnapshot;
      final harness = (await tester.runAsync<_AppBootHarness>(() async {
        final created = await _createHarness();
        await created.repository.recordReaction(
          spaceId: 'family_rhythm',
          activityId: 'feeding_time',
          phraseId: 'feeding_time_open_wide',
          reactionType: BabyReactionType.cooperating,
          clientTimestamp: DateTime.utc(2026, 4, 8, 9, 0),
          localEventId: 'evt_boot_feed_1',
        );
        await created.repository.recordReaction(
          spaceId: 'family_rhythm',
          activityId: 'feeding_time',
          phraseId: 'feeding_time_yummy_bite',
          reactionType: BabyReactionType.cooperating,
          clientTimestamp: DateTime.utc(2026, 4, 8, 9, 1),
          localEventId: 'evt_boot_feed_2',
        );
        final onboardingRepository = OnboardingRepository(
          snapshotStore: OnboardingSnapshotStore(
            directoryResolver: () async => created.tempDir,
          ),
        );
        completedSnapshot = await saveCompletedOnboardingSnapshot(
          onboardingRepository,
          childDisplayName: '米米',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          selectedSceneIds: const ['bath_time'],
          supportGoal: OnboardingSupportGoal.firstWords,
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          firstTraceEventKey: 'install_smoke_test:evt_onboarding_first',
          completedAt: DateTime.utc(2026, 4, 8, 8),
        );
        return created;
      }))!;
      addTearDown(harness.close);
      addTearDown(() async {
        await _disposeWidgetTree(tester);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetPhraseServiceProvider.overrideWithValue(
              harness.bootState.assetPhraseService!,
            ),
            appDirectoryProvider.overrideWith((ref) => harness.tempDir),
            mentorRepositoryProvider.overrideWith(
              (ref) async => harness.mentorRepository,
            ),
            practiceRepositoryProvider.overrideWith(
              (ref) => harness.repository,
            ),
            accountRepositoryProvider.overrideWith(
              (ref) => AccountRepository(
                localStore: AccountLocalStore(),
                practiceRepository: harness.repository,
              ),
            ),
            householdRepositoryProvider.overrideWith((ref) {
              final accountRepo = ref
                  .read(accountRepositoryProvider)
                  .requireValue;
              return HouseholdRepository(
                localStore: HouseholdLocalStore(
                  directoryResolver: () async => harness.tempDir,
                ),
                apiService: HouseholdApiService(),
                accountSnapshotLoader: accountRepo.loadSnapshot,
                persistRefreshedSession: accountRepo.persistRefreshedSession,
              );
            }),
            onboardingRepositoryProvider.overrideWith((ref) {
              return OnboardingRepository(
                snapshotStore: OnboardingSnapshotStore(
                  directoryResolver: () async => harness.tempDir,
                ),
              );
            }),
          ],
          child: BabyTalkApp(
            bootState: harness.bootState,
            audioControllerFactory: _SilentPracticeAudioController.new,
            completedSnapshotLoader: () async => completedSnapshot,
            practiceContinuityRefreshTimeout: Duration.zero,
            gardenGrowthRefreshTimeout: Duration.zero,
          ),
        ),
      );
      // Drive boot resolution with real wall-clock time WITHOUT advancing the
      // fake clock. The boot continuity seed performs real-async Isar reads
      // bounded by a fake-timer .timeout(4s) inside FeatureGates.resolve. If we
      // advance fake time (e.g. pump(50ms)) while waiting, that fake timeout
      // fires before the real Isar read finishes and the seed is dropped
      // (continuitySeed=null), so the recommendation only later resolves via
      // the home_bootstrap refresh. By only pumping microtasks (Duration.zero)
      // between real runAsync windows, the seed read wins the race and the
      // notifier boots already seeded with reason 'boot_seed_recent_activity'.
      final bootShellFinder = find.byKey(const Key('boot-route-shell'));
      for (var i = 0; i < 60 && bootShellFinder.evaluate().isEmpty; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }
      expect(
        bootShellFinder,
        findsOneWidget,
        reason: 'boot shell should mount after boot resolution',
      );
      await tester.pump();

      final continuityNotifier = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('shell-ready'))),
      ).read(practiceContinuityNotifierProvider);

      expect(continuityNotifier.hasResolvedRecommendation, isTrue);
      expect(continuityNotifier.recommendedArgs?.activityId, 'feeding_time');
      expect(
        continuityNotifier.snapshot?.recommendation.reason,
        PracticeContinuityReason.recentActivity,
      );
      expect(continuityNotifier.lastRefreshReason, 'boot_seed_recent_activity');

      await tester.tap(find.byKey(const Key('shell-nav-garden')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('shell-tab-growth-combined')),
      );
      // Bounded settle: pumpAndSettle can hang if a notifier keeps a pending
      // refresh/animation alive, so advance a fixed number of frames instead.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('garden-continue-practice')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      expect(
        find.byKey(const Key('garden-continue-target-feeding_time')),
        findsOneWidget,
      );
      expect(find.textContaining('接着刚才练过的场景'), findsWidgets);
    },
  );

  testWidgets('account projection 首次不可用后会自动刷新 generated Today 与 Garden', (
    WidgetTester tester,
  ) async {
    late OnboardingSnapshot completedSnapshot;
    late PracticeRepository generatedRepository;
    late _ReadTrackingSecureStorage accountStorage;
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final generatedHarness = await _createGeneratedProjectionHarness();
      final created = generatedHarness.harness;
      generatedRepository = created.repository;
      accountStorage = generatedHarness.accountStorage;
      completedSnapshot = await saveCompletedOnboardingSnapshot(
        _onboardingRepositoryFor(created),
        childDisplayName: '米米',
        ageBucket: OnboardingAgeBucket.zeroToSix,
        selectedSceneIds: const ['bath_time'],
        supportGoal: OnboardingSupportGoal.firstWords,
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
        starterPhraseId: 'bath_time_warm_water',
        firstTraceEventKey: 'install_projection_boot:evt_onboarding_first',
        completedAt: DateTime.utc(2026, 8, 9, 8),
      );

      return created;
    }))!;
    addTearDown(() async {
      await harness.mentorRepository.close(deleteFromDisk: true);
      await harness.repository.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (await harness.tempDir.exists()) {
        await _deleteDirectoryWithRetry(harness.tempDir);
      }
    });
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });
    addTearDown(accountStorage.releaseRead);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            harness.bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => harness.tempDir),
          mentorRepositoryProvider.overrideWith(
            (ref) async => harness.mentorRepository,
          ),
          practiceRepositoryProvider.overrideWith((ref) => generatedRepository),
          accountRepositoryProvider.overrideWith(
            (ref) => AccountRepository(
              localStore: AccountLocalStore(secureStorage: accountStorage),
              practiceRepository: generatedRepository,
              connectivityChecker: () async => false,
            ),
          ),
          householdRepositoryProvider.overrideWith((ref) {
            final accountRepository = ref
                .read(accountRepositoryProvider)
                .requireValue;
            return HouseholdRepository(
              localStore: HouseholdLocalStore(
                directoryResolver: () async => harness.tempDir,
              ),
              apiService: HouseholdApiService(),
              accountSnapshotLoader: accountRepository.loadSnapshot,
              persistRefreshedSession:
                  accountRepository.persistRefreshedSession,
            );
          }),
          onboardingRepositoryProvider.overrideWith(
            (ref) => _onboardingRepositoryFor(harness),
          ),
          gardenFertilizerNotifierProvider.overrideWith(
            (ref) => _FertilizerNotifierStub(
              ref.watch(gardenGrowthNotifierProvider),
            ),
          ),
        ],
        child: BabyTalkApp(
          bootState: harness.bootState,
          audioControllerFactory: _SilentPracticeAudioController.new,
          completedSnapshotLoader: () async => completedSnapshot,
          practiceContinuityRefreshTimeout: Duration.zero,
          gardenGrowthRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    final projectionContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shell-ready'))),
    );
    final observedContinuity = projectionContainer.read(
      practiceContinuityNotifierProvider,
    );
    final observedGarden = projectionContainer.read(
      gardenGrowthNotifierProvider,
    );
    final observedCarePath = projectionContainer.read(carePathNotifierProvider);
    for (var index = 0; index < 120; index++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      if (accountStorage.wasRead &&
          !observedContinuity.isRefreshing &&
          !observedGarden.isRefreshing) {
        break;
      }
    }
    var continuityRefreshStarts = 0;
    var gardenRefreshStarts = 0;
    var continuityWasRefreshing = observedContinuity.isRefreshing;
    var gardenWasRefreshing = observedGarden.isRefreshing;
    void countContinuityRefresh() {
      if (!continuityWasRefreshing &&
          observedContinuity.isRefreshing &&
          observedContinuity.lastRefreshReason == 'account_projection_ready') {
        continuityRefreshStarts += 1;
      }
      continuityWasRefreshing = observedContinuity.isRefreshing;
    }

    void countGardenRefresh() {
      if (!gardenWasRefreshing && observedGarden.isRefreshing) {
        gardenRefreshStarts += 1;
      }
      gardenWasRefreshing = observedGarden.isRefreshing;
    }

    observedContinuity.addListener(countContinuityRefresh);
    observedGarden.addListener(countGardenRefresh);
    addTearDown(() {
      observedContinuity.removeListener(countContinuityRefresh);
      observedGarden.removeListener(countGardenRefresh);
    });
    accountStorage.releaseRead();
    for (var index = 0; index < 120; index++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      final continuity = projectionContainer.read(
        practiceContinuityNotifierProvider,
      );
      final garden = projectionContainer.read(gardenGrowthNotifierProvider);
      if (continuity.lastRefreshReason == 'account_projection_ready' &&
          continuity.status == PracticeContinuityLoadStatus.ready &&
          !continuity.isRefreshing &&
          !garden.isRefreshing &&
          !observedCarePath.isBusy) {
        break;
      }
    }

    final container = projectionContainer;
    final continuity = container.read(practiceContinuityNotifierProvider);
    final garden = container.read(gardenGrowthNotifierProvider);
    final account = container.read(accountNotifierProvider);
    expect(accountStorage.wasRead, isTrue);
    expect(
      continuity.lastRefreshReason,
      'account_projection_ready',
      reason:
          'status=${continuity.status.name}; accountLoaded=${account.hasLoaded}; '
          'accountBusy=${account.isBusy}; accountSignedIn=${account.isSignedIn}; '
          'gardenStatus=${garden.status.name}',
    );
    expect(
      continuity.generatedRecommendedArgs?.generatedContentId,
      'fixture_generated_cold_boot',
    );
    expect(continuityRefreshStarts, 1);
    expect(gardenRefreshStarts, 1);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('home-today-care-moment-title')))
          .data,
      '测试照护时刻',
    );
    expect(
      garden.snapshot.spaces.any(
        (space) => space.activities.any(
          (activity) => activity.activityId == 'fixture_generated_activity',
        ),
      ),
      isTrue,
    );
  });

  testWidgets('production signed-out account keeps bundled scenes available', (
    WidgetTester tester,
  ) async {
    late OnboardingSnapshot completedSnapshot;
    late PracticeRepository signedOutRepository;
    const signedOutStorage = _SignedOutSecureStorage();
    final signedOutAccountStore = AccountLocalStore(
      secureStorage: signedOutStorage,
    );
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      completedSnapshot = await saveCompletedOnboardingSnapshot(
        _onboardingRepositoryFor(created),
        childDisplayName: '米米',
        ageBucket: OnboardingAgeBucket.zeroToSix,
        selectedSceneIds: const ['bath_time'],
        supportGoal: OnboardingSupportGoal.firstWords,
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
        starterPhraseId: 'bath_time_warm_water',
        firstTraceEventKey: 'install_signed_out:evt_onboarding_first',
        completedAt: DateTime.utc(2026, 8, 11, 8),
      );
      signedOutRepository = PracticeRepository(
        assetPhraseService: created.bootState.assetPhraseService!,
        localDataSource: created.localDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => created.tempDir,
          idGenerator: () => 'install_signed_out',
        ),
        contentResolver: GeneratedPracticeContentRegistry(
          store: GeneratedCareMomentLocalStore(
            directoryResolver: () async => created.tempDir,
          ),
          resumeStore: GeneratedCareTurnResumeMarkerStore(
            directoryResolver: () async => created.tempDir,
          ),
          accountContextLoader: () async {
            return (await signedOutAccountStore.read()).session?.accountId;
          },
        ),
      );
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            harness.bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => harness.tempDir),
          mentorRepositoryProvider.overrideWith(
            (ref) async => harness.mentorRepository,
          ),
          practiceRepositoryProvider.overrideWith((ref) => signedOutRepository),
          accountRepositoryProvider.overrideWith(
            (ref) => AccountRepository(
              localStore: signedOutAccountStore,
              practiceRepository: signedOutRepository,
            ),
          ),
          householdRepositoryProvider.overrideWith((ref) {
            final accountRepository = ref
                .read(accountRepositoryProvider)
                .requireValue;
            return HouseholdRepository(
              localStore: HouseholdLocalStore(
                directoryResolver: () async => harness.tempDir,
              ),
              apiService: HouseholdApiService(),
              accountSnapshotLoader: accountRepository.loadSnapshot,
              persistRefreshedSession:
                  accountRepository.persistRefreshedSession,
            );
          }),
          onboardingRepositoryProvider.overrideWith(
            (ref) => _onboardingRepositoryFor(harness),
          ),
        ],
        child: BabyTalkApp(
          bootState: harness.bootState,
          audioControllerFactory: _SilentPracticeAudioController.new,
          completedSnapshotLoader: () async => completedSnapshot,
          practiceContinuityRefreshTimeout: Duration.zero,
          gardenGrowthRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

    await tester.tap(find.byKey(const Key('shell-nav-discover')));
    await _pumpUntilFound(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget.key == const Key('discover-phrase-list') ||
            widget.key == const Key('discover-error-state'),
      ),
    );

    expect(find.byKey(const Key('discover-error-state')), findsNothing);
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
  });

  testWidgets('malformed account snapshot 只会退回未登录，不会破坏 shell route gate', (
    WidgetTester tester,
  ) async {
    late OnboardingSnapshot completedSnapshot;
    late AccountLocalSnapshot loadedAccountSnapshot;
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      final onboardingRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => created.tempDir,
        ),
      );
      completedSnapshot = await saveCompletedOnboardingSnapshot(
        onboardingRepository,
        childDisplayName: '米米',
        ageBucket: OnboardingAgeBucket.zeroToSix,
        selectedSceneIds: const ['bath_time'],
        supportGoal: OnboardingSupportGoal.firstWords,
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
        starterPhraseId: 'bath_time_warm_water',
        firstTraceEventKey: 'install_smoke_test:evt_onboarding_first',
        completedAt: DateTime.utc(2026, 4, 8, 8),
      );
      final accountRepository = AccountRepository(
        localStore: AccountLocalStore(
          secureStorage: const _MalformedSecureStorage(),
        ),
        practiceRepository: created.repository,
      );
      loadedAccountSnapshot = await accountRepository.loadSnapshot();
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    expect(loadedAccountSnapshot.consentState, AccountConsentState.signedOut);
    expect(loadedAccountSnapshot.session, isNull);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            harness.bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => harness.tempDir),
          mentorRepositoryProvider.overrideWith(
            (ref) async => harness.mentorRepository,
          ),
          practiceRepositoryProvider.overrideWith((ref) => harness.repository),
          accountRepositoryProvider.overrideWith(
            (ref) => AccountRepository(
              localStore: AccountLocalStore(),
              practiceRepository: harness.repository,
            ),
          ),
          householdRepositoryProvider.overrideWith((ref) {
            final accountRepo = ref
                .read(accountRepositoryProvider)
                .requireValue;
            return HouseholdRepository(
              localStore: HouseholdLocalStore(
                directoryResolver: () async => harness.tempDir,
              ),
              apiService: HouseholdApiService(),
              accountSnapshotLoader: accountRepo.loadSnapshot,
              persistRefreshedSession: accountRepo.persistRefreshedSession,
            );
          }),
          onboardingRepositoryProvider.overrideWith((ref) {
            return OnboardingRepository(
              snapshotStore: OnboardingSnapshotStore(
                directoryResolver: () async => harness.tempDir,
              ),
            );
          }),
        ],
        child: BabyTalkApp(
          bootState: harness.bootState,
          audioControllerFactory: _SilentPracticeAudioController.new,
          completedSnapshotLoader: () async => completedSnapshot,
          practiceContinuityRefreshTimeout: Duration.zero,
          gardenGrowthRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));

    expect(find.byKey(const Key('boot-route-gate-ready')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
  });

  testWidgets('snapshot 目录读取失败时暴露明确的 route gate 失败态', (
    WidgetTester tester,
  ) async {
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });
    final bootState = (await tester.runAsync<AppBootState>(() async {
      return AppBootState.load(rootBundle);
    }))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) {
            throw StateError('disk denied');
          }),
        ],
        child: BabyTalkApp(
          bootState: bootState,
          audioControllerFactory: _SilentPracticeAudioController.new,
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('boot-route-gate-failed')),
    );

    expect(find.byKey(const Key('boot-route-gate-failed')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-gate-retry')), findsOneWidget);
    expect(find.textContaining('本地档案读取失败，请重试'), findsOneWidget);
    expect(find.textContaining('onboarding 本地档案'), findsNothing);
  });

  testWidgets('boot 失败态不依赖 asset override 且可渲染失败屏', (
    WidgetTester tester,
  ) async {
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });
    final bootState = (await tester.runAsync<AppBootState>(() async {
      return AppBootState.load(_AlwaysFailingAssetBundle());
    }))!;

    expect(bootState.isReady, isFalse);
    expect(bootState.assetPhraseService, isNull);

    await tester.pumpWidget(
      ProviderScope(
        child: BabyTalkApp(
          bootState: bootState,
          audioControllerFactory: _SilentPracticeAudioController.new,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('boot-status-failed')), findsOneWidget);
    expect(find.textContaining('应用启动失败'), findsOneWidget);
  });
}

class _AlwaysFailingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('asset load failed: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    throw FlutterError('asset loadString failed: $key');
  }
}

class _AppBootHarness {
  const _AppBootHarness({
    required this.bootState,
    required this.tempDir,
    required this.localDataSource,
    required this.repository,
    required this.mentorRepository,
  });

  final AppBootState bootState;
  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository repository;
  final MentorRepository mentorRepository;

  Future<void> close() async {
    await mentorRepository.close(deleteFromDisk: true);
    await repository.close(deleteFromDisk: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (await tempDir.exists()) {
      await _deleteDirectoryWithRetry(tempDir);
    }
  }
}

class _SilentPracticeAudioController implements PracticeAudioController {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _controller.stream;

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FertilizerNotifierStub extends GardenFertilizerNotifier {
  _FertilizerNotifierStub(GardenGrowthNotifier growth)
    : super(
        repositoryFuture: Completer<GardenFertilizerRepository>().future,
        growthNotifier: growth,
      );

  @override
  GardenFertilizerViewState get view => GardenFertilizerViewState(
    isLoading: false,
    pendingPacks: const [],
    claimedPacks: const [],
    backpackCount: 0,
    stageInfo: resolveFertilizerStage(0),
  );

  @override
  Future<void> initialize() async {}
}

OnboardingRepository _onboardingRepositoryFor(_AppBootHarness harness) {
  return OnboardingRepository(
    snapshotStore: OnboardingSnapshotStore(
      directoryResolver: () async => harness.tempDir,
    ),
  );
}

Widget _bootApp(
  _AppBootHarness harness, {
  Future<OnboardingSnapshot?> Function()? completedSnapshotLoader,
}) {
  return ProviderScope(
    overrides: [
      assetPhraseServiceProvider.overrideWithValue(
        harness.bootState.assetPhraseService!,
      ),
      appDirectoryProvider.overrideWith((ref) => harness.tempDir),
      mentorRepositoryProvider.overrideWith(
        (ref) async => harness.mentorRepository,
      ),
      practiceRepositoryProvider.overrideWith((ref) => harness.repository),
      accountRepositoryProvider.overrideWith(
        (ref) => AccountRepository(
          localStore: AccountLocalStore(),
          practiceRepository: harness.repository,
        ),
      ),
      householdRepositoryProvider.overrideWith((ref) {
        final accountRepository = ref
            .read(accountRepositoryProvider)
            .requireValue;
        return HouseholdRepository(
          localStore: HouseholdLocalStore(
            directoryResolver: () async => harness.tempDir,
          ),
          apiService: HouseholdApiService(),
          accountSnapshotLoader: accountRepository.loadSnapshot,
          persistRefreshedSession: accountRepository.persistRefreshedSession,
        );
      }),
      onboardingRepositoryProvider.overrideWith(
        (ref) => _onboardingRepositoryFor(harness),
      ),
    ],
    child: BabyTalkApp(
      bootState: harness.bootState,
      audioControllerFactory: _SilentPracticeAudioController.new,
      completedSnapshotLoader: completedSnapshotLoader,
      practiceContinuityRefreshTimeout: Duration.zero,
      gardenGrowthRefreshTimeout: Duration.zero,
    ),
  );
}

Future<_AppBootHarness> _createHarness() async {
  final bootState = await AppBootState.load(rootBundle);
  final tempDir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}app_boot_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'app_boot_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final repository = PracticeRepository(
    assetPhraseService: bootState.assetPhraseService!,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => 'install_app_boot_test',
    ),
  );
  final mentorLocalDataSource = await MentorLocalDataSource.open(
    directory: tempDir.path,
    name: 'mentor_app_boot_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final mentorRepository = MentorRepository(
    localDataSource: mentorLocalDataSource,
    practiceRepository: repository,
    onboardingSnapshotStore: OnboardingSnapshotStore(
      directoryResolver: () async => tempDir,
    ),
  );
  return _AppBootHarness(
    bootState: bootState,
    tempDir: tempDir,
    localDataSource: localDataSource,
    repository: repository,
    mentorRepository: mentorRepository,
  );
}

Future<({_AppBootHarness harness, _ReadTrackingSecureStorage accountStorage})>
_createGeneratedProjectionHarness() async {
  const accountContext = 'fixture_projection_account';
  final bootState = await AppBootState.load(rootBundle);
  final tempDir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}generated_app_boot_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);
  final projectionGate = _GeneratedProjectionAccountGate(accountContext);
  final accountStorage = _ReadTrackingSecureStorage(
    onRead: projectionGate.release,
  );
  await AccountLocalStore(secureStorage: accountStorage).write(
    AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: AccountSession.validated(
        accountId: accountContext,
        sessionId: 'fixture_projection_session',
        maskedPhoneNumber: '***',
        createdAt: DateTime.utc(2026, 8, 9, 8),
      ),
    ),
  );
  final generatedStore = GeneratedCareMomentLocalStore(
    directoryResolver: () async => tempDir,
  );
  final generatedMoment = _generatedColdBootMoment();
  await generatedStore.upsert(
    StoredGeneratedCareMoment(
      accountContext: accountContext,
      moment: generatedMoment,
    ),
  );
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'generated_app_boot_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final repository = PracticeRepository(
    assetPhraseService: bootState.assetPhraseService!,
    localDataSource: localDataSource,
    contentResolver: GeneratedPracticeContentRegistry(
      store: generatedStore,
      resumeStore: GeneratedCareTurnResumeMarkerStore(
        directoryResolver: () async => tempDir,
      ),
      accountContextLoader: projectionGate.load,
    ),
    installationIdService: InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => 'install_projection_boot_test',
    ),
  );
  await repository.recordReaction(
    spaceId: generatedMoment.spaceId,
    activityId: generatedMoment.activityId,
    phraseId: generatedMoment.starter.phraseId,
    reactionType: BabyReactionType.cooperating,
    generatedContentId: generatedMoment.generatedContentId,
    utteranceId: generatedMoment.starter.utteranceId,
    clientTimestamp: DateTime.utc(2026, 8, 9, 8, 5),
  );
  projectionGate.armColdBoot();
  final mentorLocalDataSource = await MentorLocalDataSource.open(
    directory: tempDir.path,
    name:
        'mentor_generated_app_boot_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final mentorRepository = MentorRepository(
    localDataSource: mentorLocalDataSource,
    practiceRepository: repository,
    onboardingSnapshotStore: OnboardingSnapshotStore(
      directoryResolver: () async => tempDir,
    ),
  );
  return (
    harness: _AppBootHarness(
      bootState: bootState,
      tempDir: tempDir,
      localDataSource: localDataSource,
      repository: repository,
      mentorRepository: mentorRepository,
    ),
    accountStorage: accountStorage,
  );
}

Future<void> _deleteDirectoryWithRetry(
  Directory directory, {
  int attempts = 20,
  Duration delay = const Duration(milliseconds: 50),
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      if (!await directory.exists()) {
        return;
      }
      await directory.delete(recursive: true);
      return;
    } on PathAccessException catch (error) {
      lastError = error;
      await Future<void>.delayed(delay);
    }
  }

  if (lastError != null) {
    // Windows + Isar close 可能在测试销毁后短暂持有文件句柄；这里做 best-effort 清理，
    // 避免把已经完成的启动 proof 伪打红。
    return;
  }
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  // Settle any mixed real/fake async Isar operations kicked off by the
  // HomeScreen post-frame notifier inits (continuity/garden reads, account
  // installation-id write). Their native completions need a real event loop
  // (tester.runAsync) while their Dart continuations are microtasks parked on
  // the fake-async queue (drained by tester.pump). Alternating both repeatedly
  // lets the transactions fully commit and release the practice Isar lock, so
  // repository.close(deleteFromDisk: true) does not deadlock during teardown.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 12),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for expected widget.');
}

/// 用于测试：模拟返回 malformed account JSON（accepted_pending_sync 但无 session）
class _MalformedSecureStorage extends FlutterSecureStorage {
  const _MalformedSecureStorage();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return '{"consentState":"accepted_pending_sync","session":null}';
  }
}

class _SignedOutSecureStorage extends FlutterSecureStorage {
  const _SignedOutSecureStorage();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null;
}

class _GeneratedProjectionAccountGate {
  _GeneratedProjectionAccountGate(this.accountContext);

  final String accountContext;
  bool _available = true;

  Future<String?> load() async => _available ? accountContext : null;

  void armColdBoot() {
    _available = false;
  }

  void release() {
    _available = true;
  }
}

class _ReadTrackingSecureStorage extends FlutterSecureStorage {
  _ReadTrackingSecureStorage({required this.onRead});

  final VoidCallback onRead;
  final Map<String, String> _values = <String, String>{};
  final Completer<void> _readGate = Completer<void>();
  bool wasRead = false;

  void releaseRead() {
    if (!_readGate.isCompleted) {
      _readGate.complete();
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    wasRead = true;
    await _readGate.future;
    onRead();
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

GeneratedCareMoment _generatedColdBootMoment() {
  return generatedCareMomentFixture(
    generatedContentId: 'fixture_generated_cold_boot',
    sceneId: 'fixture_scene',
    spaceId: 'fixture_generated_space',
    momentId: 'fixture_moment',
    activityId: 'fixture_generated_activity',
    title: '测试照护时刻',
    sceneTag: 'fixture',
    coachTip: '慢慢回应',
    utteranceIdPrefix: 'fixture_utterance',
    phraseIdPrefix: 'fixture_phrase',
    englishForSuffix: (suffix) => 'A calm fixture phrase $suffix.',
    chinese: '测试照护短句',
    pronunciation: 'fixture',
    tprActionZh: '轻轻靠近',
    deliveryGuidanceZh: '放慢语速',
    providerName: 'fixture_provider',
    modelName: 'fixture_model',
  );
}
