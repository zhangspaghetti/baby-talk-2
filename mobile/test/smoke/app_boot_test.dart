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
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_input_screen.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import '../support/isar_test_library.dart';

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
    expect(find.byType(OnboardingFlowScreen), findsOneWidget);
    expect(find.text('宝宝正在做什么？'), findsOneWidget);
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
      'feeding_time',
      'bedtime',
    ]);
    expect(allPhrases, hasLength(9));

    for (final phrase in allPhrases) {
      final audioBytes = await rootBundle.load(phrase.audioAsset);
      expect(audioBytes.lengthInBytes, greaterThan(0));
    }
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

  testWidgets(
    'persisted care turn resumes the selected moment without writing an event',
    (WidgetTester tester) async {
      final harness = (await tester.runAsync<_AppBootHarness>(() async {
        final created = await _createHarness();
        await _onboardingRepositoryFor(
          created,
        ).saveFlowSnapshot(_resumableFlow(step: OnboardingFlowStep.careTurn));
        return created;
      }))!;
      addTearDown(harness.close);
      addTearDown(() async {
        await _disposeWidgetTree(tester);
      });

      await tester.pumpWidget(
        _bootApp(harness, completedSnapshotLoader: () async => null),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('care-turn-said-button')),
      );

      expect(find.byKey(const Key('boot-route-onboarding')), findsOneWidget);
      expect(
        await tester.runAsync(harness.repository.listEventHistory),
        isEmpty,
      );
    },
  );

  testWidgets('persisted trace resumes without writing a duplicate event', (
    WidgetTester tester,
  ) async {
    late String traceEventKey;
    final harness = (await tester.runAsync<_AppBootHarness>(() async {
      final created = await _createHarness();
      final event = await created.repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.hesitant,
        clientTimestamp: DateTime.utc(2026, 7, 24, 12),
        localEventId: 'evt_boot_trace_resume',
      );
      traceEventKey = event.eventKey;
      await _onboardingRepositoryFor(created).saveFlowSnapshot(
        _resumableFlow(
          step: OnboardingFlowStep.trace,
          traceEventKey: traceEventKey,
        ),
      );
      return created;
    }))!;
    addTearDown(harness.close);
    addTearDown(() async {
      await _disposeWidgetTree(tester);
    });

    await tester.pumpWidget(
      _bootApp(harness, completedSnapshotLoader: () async => null),
    );
    await _pumpUntilFound(tester, find.text('刚才这句话，已经留在你们的花园里。'));

    final events = (await tester.runAsync(
      harness.repository.listEventHistory,
    ))!;
    expect(events, hasLength(1));
    expect(events.single.eventKey, traceEventKey);
  });

  testWidgets(
    'confirmed next support resumes at trace without writing a duplicate event',
    (WidgetTester tester) async {
      late String traceEventKey;
      final harness = (await tester.runAsync<_AppBootHarness>(() async {
        final created = await _createHarness();
        final event = await created.repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.hesitant,
          clientTimestamp: DateTime.utc(2026, 7, 24, 12),
          localEventId: 'evt_boot_next_support_resume',
        );
        traceEventKey = event.eventKey;
        await _onboardingRepositoryFor(created).saveFlowSnapshot(
          _resumableFlow(
            step: OnboardingFlowStep.careTurn,
            traceEventKey: traceEventKey,
          ),
        );
        return created;
      }))!;
      addTearDown(harness.close);
      addTearDown(() async {
        await _disposeWidgetTree(tester);
      });

      await tester.pumpWidget(
        _bootApp(harness, completedSnapshotLoader: () async => null),
      );
      await _pumpUntilFound(tester, find.text('刚才这句话，已经留在你们的花园里。'));

      final events = (await tester.runAsync(
        harness.repository.listEventHistory,
      ))!;
      expect(events, hasLength(1));
      expect(events.single.eventKey, traceEventKey);
    },
  );

  testWidgets(
    'persisted account invitation resumes without writing a duplicate event',
    (WidgetTester tester) async {
      late String traceEventKey;
      final harness = (await tester.runAsync<_AppBootHarness>(() async {
        final created = await _createHarness();
        final event = await created.repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.hesitant,
          clientTimestamp: DateTime.utc(2026, 7, 24, 12),
          localEventId: 'evt_boot_account_resume',
        );
        traceEventKey = event.eventKey;
        await _onboardingRepositoryFor(created).saveFlowSnapshot(
          _resumableFlow(
            step: OnboardingFlowStep.accountInvitation,
            traceEventKey: traceEventKey,
          ),
        );
        return created;
      }))!;
      addTearDown(harness.close);
      addTearDown(() async {
        await _disposeWidgetTree(tester);
      });

      await tester.pumpWidget(
        _bootApp(harness, completedSnapshotLoader: () async => null),
      );
      await _pumpUntilFound(tester, find.text('把这些照护时刻保存到账号'));

      final events = (await tester.runAsync(
        harness.repository.listEventHistory,
      ))!;
      expect(events, hasLength(1));
      expect(events.single.eventKey, traceEventKey);
    },
  );

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
        flowStore: OnboardingFlowStore(
          directoryResolver: () async => created.tempDir,
        ),
      );
      completedSnapshot = await onboardingRepository.completeOnboarding(
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
              flowStore: OnboardingFlowStore(
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
        completedSnapshot = await _onboardingRepositoryFor(created)
            .completeOnboarding(
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
        await sink.handoff(handoff);
        await _pumpUntilFound(tester, find.byType(PracticeSessionScreen));
        final screen = tester.widget<PracticeSessionScreen>(
          find.byType(PracticeSessionScreen),
        );
        expect(
          screen.routeEntry.generatedArgs?.generatedContentId,
          'generated_reconciled',
        );
      }

      await expectGeneratedHandoff();
      Navigator.of(tester.element(find.byType(PracticeSessionScreen))).pop();
      await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
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
          flowStore: OnboardingFlowStore(
            directoryResolver: () async => created.tempDir,
          ),
        );
        completedSnapshot = await onboardingRepository.completeOnboarding(
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
                flowStore: OnboardingFlowStore(
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
        flowStore: OnboardingFlowStore(
          directoryResolver: () async => created.tempDir,
        ),
      );
      completedSnapshot = await onboardingRepository.completeOnboarding(
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
              flowStore: OnboardingFlowStore(
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

OnboardingRepository _onboardingRepositoryFor(_AppBootHarness harness) {
  return OnboardingRepository(
    snapshotStore: OnboardingSnapshotStore(
      directoryResolver: () async => harness.tempDir,
    ),
    flowStore: OnboardingFlowStore(
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

OnboardingFlowSnapshot _resumableFlow({
  required OnboardingFlowStep step,
  String? traceEventKey,
}) {
  final hasTrace = traceEventKey?.trim().isNotEmpty == true;
  return OnboardingFlowSnapshot(
    step: step,
    ageBucket: OnboardingAgeBucket.oneToTwo,
    selectedSceneIds: const ['bath_time'],
    supportGoal: OnboardingSupportGoal.moreNatural,
    selectedSpaceId: 'daily_care',
    selectedActivityId: 'bath_time',
    starterPhraseId: 'bath_time_warm_water',
    selectedReaction: hasTrace ? BabyReactionType.hesitant : null,
    traceEventKey: traceEventKey,
    updatedAt: DateTime.utc(2026, 7, 24, 12),
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
