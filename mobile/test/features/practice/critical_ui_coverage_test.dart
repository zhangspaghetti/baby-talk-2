import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_flower_stage.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';
import 'package:mobile/features/garden/presentation/garden_fertilizer_notifier.dart';
import 'package:mobile/app/widgets/app_celebration_overlay.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/practice/presentation/widgets/activation_frame.dart';
import 'package:mobile/features/practice/presentation/widgets/phrase_card.dart';
import 'package:mobile/features/practice/presentation/widgets/home_garden_mini_entry.dart';
import 'package:mobile/features/practice/presentation/widgets/home_growth_summary_card.dart';
import 'package:mobile/features/practice/presentation/widgets/home_recent_result_card.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';
import 'package:mobile/features/share/presentation/share_notifier.dart';
import 'package:mobile/features/share/presentation/widgets/share_callout_card.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:mobile/features/shell/presentation/screens/discover_screen.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_continue_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_hero_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_patch_card.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Practice fallback and activation affordances stay visible', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      PracticeSessionScreen(routeEntry: PracticeRouteEntry.fromObject(null)),
      scaffold: false,
    );

    expect(find.byKey(const Key('practice-safe-fallback')), findsOneWidget);
    expect(find.textContaining('照护入口暂时打不开'), findsOneWidget);
    expect(find.textContaining('练习入口'), findsNothing);
    expect(find.textContaining('practice route 参数'), findsNothing);

    await _pumpApp(
      tester,
      ActivationFrame(
        stepLabel: '第 2 句',
        title: '现在试试这一句',
        child: const Text('Hello wave'),
      ),
    );

    expect(find.byKey(const Key('activation-frame')), findsOneWidget);
    expect(find.text('跟着宝宝节奏来'), findsOneWidget);
    expect(find.text('现在试试这一句'), findsOneWidget);
    expect(find.text('第 2 句'), findsOneWidget);
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

  testWidgets('Practice session screen renders provider loading and error', (
    tester,
  ) async {
    final pendingRepository = Completer<PracticeRepository>();
    final routeEntry = PracticeRouteEntry.fromObject(
      const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time'),
    );

    await _pumpApp(
      tester,
      PracticeSessionScreen(routeEntry: routeEntry),
      scaffold: false,
      overrides: [
        practiceRepositoryProvider.overrideWith(
          (ref) => pendingRepository.future,
        ),
      ],
    );

    expect(
      find.byKey(const Key('practice-repository-loading')),
      findsOneWidget,
    );
    pendingRepository.completeError(StateError('disposed'));
    await tester.pumpWidget(const SizedBox.shrink());

    await _pumpApp(
      tester,
      PracticeSessionScreen(routeEntry: routeEntry),
      scaffold: false,
      overrides: [
        practiceRepositoryProvider.overrideWith(
          (ref) => throw StateError('repo down'),
        ),
      ],
    );
    await _pumpFrames(tester, count: 3);

    expect(find.byKey(const Key('practice-safe-fallback')), findsOneWidget);
  });

  testWidgets(
    'Practice session screen renders one-turn care path UI and records reaction',
    (tester) async {
      final repository = _CarePathScreenPracticeRepository();
      final notifier = CarePathNotifier(
        repository: CarePathRepository(
          practiceRepository: repository,
          gardenGrowthRepository: _ScreenGardenGrowthRepository(
            _gardenSnapshot(spaces: [_gardenPatch()]),
          ),
        ),
      );
      final audioController = _ScreenPracticeAudioController();
      final routeEntry = PracticeRouteEntry.fromObject(
        const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time'),
      );

      await _pumpApp(
        tester,
        PracticeSessionScreen(
          routeEntry: routeEntry,
          audioControllerFactory: () => audioController,
        ),
        scaffold: false,
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      await _pumpFrames(tester, count: 8);

      expect(find.text('Warm water.'), findsOneWidget);
      expect(find.text('温温的水。'), findsOneWidget);
      expect(find.text('wɔːrm ˈwɔːtər'), findsOneWidget);
      expect(find.text('听一下'), findsOneWidget);
      expect(find.text('我说了'), findsOneWidget);
      expect(find.text('先说动作，再慢慢等待宝宝回应。'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('session-progress')), findsNothing);
      expect(find.byKey(const Key('practice-progress-text')), findsNothing);
      expect(find.byKey(const Key('practice-completion-view')), findsNothing);
      expect(find.text('第 1 / 3 句'), findsNothing);
      expect(find.byKey(const Key('care-reaction-cooperating')), findsNothing);

      await tester.tap(find.text('听一下'));
      await tester.pump();
      expect(
        audioController.playedAssets.single,
        'audio/phrases/bath_time_warm_water.mp3',
      );
      audioController.completePlayback();
      await tester.pump();
      expect(find.text('已听过一次'), findsOneWidget);

      await tester.tap(find.text('我说了'));
      await tester.pump();
      expect(
        find.byKey(const Key('care-reaction-cooperating')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
      await _pumpFrames(tester, count: 8);

      expect(repository.recordedEvents, hasLength(1));
      expect(find.text('下一句照护支持'), findsOneWidget);
      expect(find.text('Splash splash.'), findsOneWidget);
      expect(find.text('花圃醒来了'), findsOneWidget);
      expect(find.text('配合了 hello。'), findsOneWidget);
    },
  );

  for (final viewportCase in _careTurnViewportCases) {
    testWidgets(
      'Practice session screen fits ${viewportCase.label} with 48dp controls',
      (tester) async {
        _setViewport(
          tester,
          viewportCase.size,
          textScale: viewportCase.textScale,
        );
        final repository = _CarePathScreenPracticeRepository();
        final notifier = CarePathNotifier(
          repository: CarePathRepository(
            practiceRepository: repository,
            gardenGrowthRepository: _ScreenGardenGrowthRepository(
              _gardenSnapshot(spaces: [_gardenPatch()]),
            ),
          ),
        );
        final routeEntry = PracticeRouteEntry.fromObject(
          const PracticeRouteArgs(
            spaceId: 'daily_care',
            activityId: 'bath_time',
          ),
        );

        await _pumpApp(
          tester,
          PracticeSessionScreen(routeEntry: routeEntry),
          scaffold: false,
          overrides: [
            practiceRepositoryProvider.overrideWith((ref) async => repository),
            carePathNotifierProvider.overrideWith((ref) => notifier),
          ],
        );
        await _pumpFrames(tester, count: 8);

        _expectNoFlutterException(tester);
        await tester.ensureVisible(
          find.byKey(const Key('care-turn-current-utterance')),
        );
        await tester.ensureVisible(
          find.byKey(const Key('care-turn-listen-once')),
        );
        await tester.ensureVisible(
          find.byKey(const Key('care-turn-said-button')),
        );
        _expectMinTouchTarget(tester, const Key('care-turn-listen-once'));
        _expectMinTouchTarget(tester, const Key('care-turn-said-button'));

        await tester.tap(find.byKey(const Key('care-turn-said-button')));
        await tester.pump();
        _expectNoFlutterException(tester);

        const reactionKeys = [
          Key('care-reaction-cooperating'),
          Key('care-reaction-hesitant'),
          Key('care-reaction-resisting'),
          Key('care-reaction-no_response'),
          Key('care-reaction-other'),
        ];
        for (final key in reactionKeys) {
          await tester.ensureVisible(find.byKey(key));
          _expectMinTouchTarget(tester, key);
        }

        await tester.tap(find.byKey(reactionKeys.first));
        await _pumpFrames(tester, count: 8);
        _expectNoFlutterException(tester);

        await tester.ensureVisible(
          find.byKey(const Key('care-turn-next-support')),
        );
        await tester.ensureVisible(
          find.byKey(const Key('care-turn-garden-trace')),
        );

        expect(find.text('Warm water.'), findsOneWidget);
        expect(find.text('温温的水。'), findsOneWidget);
        expect(find.text('听一下'), findsOneWidget);
        expect(find.text('我说了'), findsOneWidget);
        expect(find.text('下一句照护支持'), findsOneWidget);
        expect(find.text('花园留痕'), findsOneWidget);
      },
    );
  }

  testWidgets('Practice session screen exposes care-turn semantics only', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = _CarePathScreenPracticeRepository();
      final notifier = CarePathNotifier(
        repository: CarePathRepository(
          practiceRepository: repository,
          gardenGrowthRepository: _ScreenGardenGrowthRepository(
            _gardenSnapshot(spaces: [_gardenPatch()]),
          ),
        ),
      );
      final routeEntry = PracticeRouteEntry.fromObject(
        const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time'),
      );

      await _pumpApp(
        tester,
        PracticeSessionScreen(routeEntry: routeEntry),
        scaffold: false,
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      await _pumpFrames(tester, count: 8);

      expect(find.bySemanticsLabel('Warm water.'), findsOneWidget);
      expect(find.bySemanticsLabel('温温的水。'), findsOneWidget);
      expect(find.bySemanticsLabel('听一下'), findsOneWidget);
      expect(find.bySemanticsLabel('我说了'), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();

      expect(find.bySemanticsLabel('宝宝刚刚是什么反应？'), findsOneWidget);
      for (final label in ['配合', '犹豫', '不想', '没反应', '其他']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      for (final blocked in [
        'cooperating',
        'hesitant',
        'resisting',
        'no_response',
        'session-progress',
        'practice-progress-text',
        'practice-completion-view',
        'PracticeSessionNotifier',
        'practice route 参数',
        '第 1 /',
        '完成总结',
      ]) {
        expect(find.bySemanticsLabel(blocked), findsNothing);
      }

      await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
      await _pumpFrames(tester, count: 8);

      expect(find.bySemanticsLabel('下一句照护支持'), findsOneWidget);
      expect(find.bySemanticsLabel('Splash splash.'), findsOneWidget);
      expect(find.bySemanticsLabel('花园留痕'), findsOneWidget);
      expect(find.bySemanticsLabel('花圃醒来了'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'Practice session screen does not restart moment on repeated pump with same args',
    (tester) async {
      final repository = _CarePathScreenPracticeRepository();
      final notifier = _TrackingCarePathNotifier(
        repository: CarePathRepository(practiceRepository: repository),
      );
      final routeEntry = PracticeRouteEntry.fromObject(
        const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time'),
      );

      await _pumpApp(
        tester,
        PracticeSessionScreen(routeEntry: routeEntry),
        scaffold: false,
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      await _pumpFrames(tester, count: 8);

      expect(notifier.startMomentCalls, ['daily_care/bath_time']);

      await _pumpFrames(tester, count: 8);
      expect(notifier.startMomentCalls, ['daily_care/bath_time']);
    },
  );

  testWidgets(
    'Practice session screen keeps utterance speakable when audio is missing',
    (tester) async {
      final repository = _CarePathScreenPracticeRepository(
        activitySnapshots: {
          'daily_care/bath_time': _screenActivitySnapshotWithoutFirstAudio(),
        },
      );
      final notifier = CarePathNotifier(
        repository: CarePathRepository(practiceRepository: repository),
      );
      final audioController = _ScreenPracticeAudioController();
      final routeEntry = PracticeRouteEntry.fromObject(
        const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time'),
      );

      await _pumpApp(
        tester,
        PracticeSessionScreen(
          routeEntry: routeEntry,
          audioControllerFactory: () => audioController,
        ),
        scaffold: false,
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      await _pumpFrames(tester, count: 8);

      await tester.tap(find.text('听一下'));
      await tester.pump();

      expect(audioController.playedAssets, isEmpty);
      expect(find.text('这句暂时没有音频，可以直接说。'), findsOneWidget);
      expect(find.text('Warm water.'), findsOneWidget);

      await tester.tap(find.text('我说了'));
      await tester.pump();

      expect(
        find.byKey(const Key('care-reaction-cooperating')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Practice session screen route start replaces provider initialization',
    (tester) async {
      final repository = _GatedContinuityCarePathScreenPracticeRepository();
      final notifier = _TrackingCarePathNotifier(
        repository: CarePathRepository(practiceRepository: repository),
      );
      final initializeFuture = notifier.initialize();
      final routeEntry = PracticeRouteEntry.fromObject(
        const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time'),
      );

      await _pumpApp(
        tester,
        PracticeSessionScreen(routeEntry: routeEntry),
        scaffold: false,
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      await _pumpFrames(tester, count: 8);

      expect(repository.continuityRequested, isTrue);
      expect(notifier.startMomentCalls, ['daily_care/bath_time']);
      expect(find.text('Warm water.'), findsOneWidget);

      repository.releaseContinuity();
      await initializeFuture;
      await tester.pump();

      expect(find.text('Warm water.'), findsOneWidget);
      expect(notifier.startMomentCalls, ['daily_care/bath_time']);
    },
  );

  testWidgets(
    'Practice session screen starts a new moment when route args change',
    (tester) async {
      final repository = _CarePathScreenPracticeRepository();
      final notifier = _TrackingCarePathNotifier(
        repository: CarePathRepository(practiceRepository: repository),
      );
      final hostState = ValueNotifier<_PracticeSessionHostState>(
        _PracticeSessionHostState(
          routeEntry: PracticeRouteEntry.fromObject(
            const PracticeRouteArgs(
              spaceId: 'daily_care',
              activityId: 'bath_time',
            ),
          ),
        ),
      );
      addTearDown(hostState.dispose);

      await _pumpApp(
        tester,
        _PracticeSessionHost(state: hostState),
        scaffold: false,
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      await _pumpFrames(tester, count: 8);

      expect(notifier.startMomentCalls, ['daily_care/bath_time']);
      expect(find.text('Warm water.'), findsOneWidget);

      hostState.value = _PracticeSessionHostState(
        routeEntry: PracticeRouteEntry.fromObject(
          const PracticeRouteArgs(spaceId: 'home', activityId: 'song_time'),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('practice-repository-loading')),
        findsOneWidget,
      );
      expect(find.text('Warm water.'), findsNothing);
      await _pumpFrames(tester, count: 8);

      expect(notifier.startMomentCalls, [
        'daily_care/bath_time',
        'home/song_time',
      ]);
      expect(find.text('Hello wave.'), findsOneWidget);
    },
  );

  testWidgets(
    'Practice session screen reopen starts cleanly without stale reaction state',
    (tester) async {
      final repository = _CarePathScreenPracticeRepository();
      final notifier = _TrackingCarePathNotifier(
        repository: CarePathRepository(practiceRepository: repository),
      );
      final hostState = ValueNotifier<_PracticeSessionHostState>(
        _PracticeSessionHostState(
          routeEntry: PracticeRouteEntry.fromObject(
            const PracticeRouteArgs(
              spaceId: 'daily_care',
              activityId: 'bath_time',
            ),
          ),
        ),
      );
      addTearDown(hostState.dispose);

      await _pumpApp(
        tester,
        _PracticeSessionHost(state: hostState),
        scaffold: false,
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      await _pumpFrames(tester, count: 8);

      await tester.tap(find.text('我说了'));
      await tester.pump();
      expect(
        find.byKey(const Key('care-reaction-cooperating')),
        findsOneWidget,
      );

      hostState.value = _PracticeSessionHostState(
        routeEntry: hostState.value.routeEntry,
        showScreen: false,
      );
      await _pumpFrames(tester, count: 4);

      hostState.value = _PracticeSessionHostState(
        routeEntry: hostState.value.routeEntry,
      );
      await tester.pump();
      expect(
        find.byKey(const Key('practice-repository-loading')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('care-reaction-cooperating')), findsNothing);
      await _pumpFrames(tester, count: 8);

      expect(notifier.startMomentCalls, [
        'daily_care/bath_time',
        'daily_care/bath_time',
      ]);
      expect(find.text('Warm water.'), findsOneWidget);
      expect(find.text('我说了'), findsOneWidget);
      expect(find.byKey(const Key('care-reaction-cooperating')), findsNothing);
    },
  );

  testWidgets('Active PhraseCard stacks play affordance at high text scale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await _pumpApp(
      tester,
      PhraseCard(
        phrase: _screenActivitySnapshot.phrases.first,
        isActive: true,
        isCompleted: false,
        playbackStatus: PracticePlaybackStatus.idle,
        saveStatus: PracticeSaveStatus.idle,
        playbackMessage: null,
        saveMessage: null,
        canPlay: true,
        canSubmitReaction: true,
        onPlay: () {},
        onReactionSelected: (_) {},
      ),
    );

    expect(
      find.byKey(const Key('phrase-action-stacked-bath_time_warm_water')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('phrase-action-row-bath_time_warm_water')),
      findsNothing,
    );
    expect(find.text('听小禾读'), findsOneWidget);
    expect(find.text('等宝宝反应'), findsOneWidget);

    final playButtonSize = tester.getSize(
      find.byKey(const Key('play-bath_time_warm_water')),
    );
    expect(
      playButtonSize.height,
      greaterThanOrEqualTo(AppLayoutConstants.minTouchTarget),
    );
    expect(
      playButtonSize.width,
      greaterThanOrEqualTo(AppLayoutConstants.minTouchTarget),
    );
  });

  testWidgets('Active PhraseCard stacks play affordance in narrow width', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      SizedBox(
        width: 300,
        child: PhraseCard(
          phrase: _screenActivitySnapshot.phrases.first,
          isActive: true,
          isCompleted: false,
          playbackStatus: PracticePlaybackStatus.idle,
          saveStatus: PracticeSaveStatus.idle,
          playbackMessage: null,
          saveMessage: null,
          canPlay: true,
          canSubmitReaction: true,
          onPlay: () {},
          onReactionSelected: (_) {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('phrase-action-stacked-bath_time_warm_water')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('phrase-action-row-bath_time_warm_water')),
      findsNothing,
    );
  });

  testWidgets('HomeScreen renders current care node surface', (tester) async {
    final gardenSnapshot = _gardenSnapshot(spaces: [_gardenPatch()]);
    final continuitySnapshot = _continuitySnapshot();

    await _pumpApp(
      tester,
      const HomeScreen(),
      scaffold: false,
      overrides: [
        accountNotifierProvider.overrideWith((ref) {
          return AccountNotifier(repository: _ScreenAccountRepository());
        }),
        practiceContinuityNotifierProvider.overrideWith((ref) {
          return _homeContinuityNotifier(continuitySnapshot);
        }),
        carePathNotifierProvider.overrideWith((ref) {
          return _homeCarePathNotifier(continuitySnapshot);
        }),
        gardenGrowthNotifierProvider.overrideWith((ref) {
          return GardenGrowthNotifier(
            repository: _HomeGardenGrowthRepository(gardenSnapshot),
            refreshTimeout: Duration.zero,
          );
        }),
        householdNotifierProvider.overrideWith((ref) {
          return HouseholdNotifier(repository: _HomeHouseholdRepository());
        }),
        shareNotifierProvider.overrideWith((ref) {
          return ShareNotifier(
            repository: _HomeShareRepository(),
            initialGrowthSnapshot: gardenSnapshot,
            initialContinuitySnapshot: continuitySnapshot,
          );
        }),
      ],
    );
    await _pumpFrames(tester, count: 10);

    expect(find.byKey(const Key('home-today-care-node-card')), findsOneWidget);
    expect(
      find.byKey(const Key('home-today-care-moment-title')),
      findsOneWidget,
    );
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('唱一小段'), findsOneWidget);
    expect(find.text('Hello wave.'), findsWidgets);
    expect(find.byKey(const Key('home-today-primary-cta')), findsOneWidget);
    expect(find.text('现在说一句'), findsWidgets);
  });

  testWidgets('HomeScreen carries onboarding first seed into care node', (
    tester,
  ) async {
    final gardenSnapshot = _gardenSnapshot(spaces: [_gardenPatch()]);
    final continuitySnapshot = _continuitySnapshot();
    final stageMatch = StageMatchCatalog.forAgeBucket(
      OnboardingAgeBucket.sevenToTwelve,
    );
    final onboardingSnapshot = OnboardingSnapshot(
      childDisplayName: '米米',
      ageBucket: OnboardingAgeBucket.sevenToTwelve,
      approxMonths: stageMatch.approxMonths,
      currentStage: stageMatch.stageId,
      starterSpaceId: 'home',
      starterActivityId: 'song_time',
      starterPhraseId: 'hello_wave',
      consentState: OnboardingConsentState.localOnly,
      completedAt: DateTime.utc(2026, 4, 8, 8),
    );

    await _pumpApp(
      tester,
      HomeScreen(onboardingSnapshot: onboardingSnapshot),
      scaffold: false,
      overrides: [
        accountNotifierProvider.overrideWith((ref) {
          return AccountNotifier(repository: _ScreenAccountRepository());
        }),
        practiceContinuityNotifierProvider.overrideWith((ref) {
          return _homeContinuityNotifier(continuitySnapshot);
        }),
        carePathNotifierProvider.overrideWith((ref) {
          return _homeCarePathNotifier(continuitySnapshot);
        }),
        gardenGrowthNotifierProvider.overrideWith((ref) {
          return GardenGrowthNotifier(
            repository: _HomeGardenGrowthRepository(gardenSnapshot),
            refreshTimeout: Duration.zero,
          );
        }),
        householdNotifierProvider.overrideWith((ref) {
          return HouseholdNotifier(repository: _HomeHouseholdRepository());
        }),
        shareNotifierProvider.overrideWith((ref) {
          return ShareNotifier(
            repository: _HomeShareRepository(),
            initialGrowthSnapshot: gardenSnapshot,
            initialContinuitySnapshot: continuitySnapshot,
          );
        }),
      ],
    );
    await _pumpFrames(tester, count: 10);

    expect(find.byKey(const Key('home-today-care-node-card')), findsOneWidget);
    expect(
      find.byKey(const Key('home-today-utterance-english')),
      findsOneWidget,
    );
    expect(find.text('Hello wave.'), findsWidgets);
    expect(find.text('温温的水。'), findsNothing);
  });

  testWidgets('HomeScreen primary care CTA opens real one-turn route', (
    tester,
  ) async {
    final gardenSnapshot = _gardenSnapshot(spaces: [_gardenPatch()]);
    final continuitySnapshot = _continuitySnapshot();
    final repository = _HomeDefaultCarePathScreenPracticeRepository();
    final carePathNotifier = CarePathNotifier(
      repository: CarePathRepository(practiceRepository: repository),
    );
    PracticeRouteArgs? openedArgs;

    final router = GoRouter(
      initialLocation: AppRouteNames.home,
      routes: [
        GoRoute(
          path: AppRouteNames.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRouteNames.practice,
          builder: (context, state) {
            openedArgs = PracticeRouteArgs.maybeFromObject(state.extra);
            return PracticeSessionScreen(
              routeEntry: PracticeRouteEntry.fromObject(state.extra),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountNotifierProvider.overrideWith((ref) {
            return AccountNotifier(repository: _ScreenAccountRepository());
          }),
          practiceContinuityNotifierProvider.overrideWith((ref) {
            return _homeContinuityNotifier(continuitySnapshot);
          }),
          carePathNotifierProvider.overrideWith((ref) {
            return carePathNotifier;
          }),
          practiceRepositoryProvider.overrideWith((ref) async {
            return repository;
          }),
          gardenGrowthNotifierProvider.overrideWith((ref) {
            return GardenGrowthNotifier(
              repository: _HomeGardenGrowthRepository(gardenSnapshot),
              refreshTimeout: Duration.zero,
            );
          }),
          householdNotifierProvider.overrideWith((ref) {
            return HouseholdNotifier(repository: _HomeHouseholdRepository());
          }),
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
    await _pumpFrames(tester, count: 10);

    await tester.ensureVisible(find.byKey(const Key('home-today-primary-cta')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('home-today-primary-cta')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('care-turn-current-utterance')),
      findsOneWidget,
    );
    expect(find.text('听一下'), findsOneWidget);
    expect(find.text('我说了'), findsOneWidget);
    expect(openedArgs?.spaceId, 'home');
    expect(openedArgs?.activityId, 'song_time');
    expect(openedArgs?.entrySource, PracticeRouteEntrySource.inApp);
  });

  testWidgets('Discover scene CTA opens real one-turn route', (tester) async {
    _setViewport(tester, const Size(800, 1200));
    final repository = _CarePathScreenPracticeRepository();
    final notifier = CarePathNotifier(
      repository: CarePathRepository(practiceRepository: repository),
    );
    PracticeRouteArgs? openedArgs;

    final router = GoRouter(
      initialLocation: AppRouteNames.home,
      routes: [
        GoRoute(
          path: AppRouteNames.home,
          builder: (context, state) => Scaffold(
            body: DiscoverScreen(catalogLoader: repository.getActivityCatalog),
          ),
        ),
        GoRoute(
          path: AppRouteNames.practice,
          builder: (context, state) {
            openedArgs = PracticeRouteArgs.maybeFromObject(state.extra);
            return PracticeSessionScreen(
              routeEntry: PracticeRouteEntry.fromObject(state.extra),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
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

    await tester.ensureVisible(find.text('现在说一句').first);
    await tester.pump();
    await tester.tap(find.text('现在说一句').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('care-turn-current-utterance')),
      findsOneWidget,
    );
    expect(find.text('Warm water.'), findsOneWidget);
    expect(find.text('温温的水。'), findsOneWidget);
    expect(find.text('听一下'), findsOneWidget);
    expect(find.text('我说了'), findsOneWidget);
    expect(openedArgs?.spaceId, 'daily_care');
    expect(openedArgs?.activityId, 'bath_time');
    expect(openedArgs?.entrySource, PracticeRouteEntrySource.inApp);
  });

  testWidgets('Practice route re-entry and back exit stay one-turn clean', (
    tester,
  ) async {
    final repository = _CarePathScreenPracticeRepository();
    final notifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: repository,
        gardenGrowthRepository: _ScreenGardenGrowthRepository(
          _gardenSnapshot(spaces: [_gardenPatch()]),
        ),
      ),
    );
    final routeArgs = const PracticeRouteArgs(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    final router = GoRouter(
      initialLocation: AppRouteNames.home,
      routes: [
        GoRoute(
          path: AppRouteNames.home,
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('route-reentry-open'),
                onPressed: () => routeArgs.push<void>(context),
                child: const Text('open care turn'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRouteNames.practice,
          builder: (context, state) => PracticeSessionScreen(
            routeEntry: PracticeRouteEntry.fromObject(state.extra),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWith((ref) async => repository),
          carePathNotifierProvider.overrideWith((ref) => notifier),
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

    await tester.tap(find.byKey(const Key('route-reentry-open')));
    await tester.pumpAndSettle();
    expect(find.text('Warm water.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    expect(find.byKey(const Key('care-reaction-cooperating')), findsOneWidget);
    await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
    await _pumpFrames(tester, count: 8);
    expect(find.byKey(const Key('care-turn-next-support')), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-reentry-open')), findsOneWidget);
    expect(find.byKey(const Key('practice-completion-view')), findsNothing);
    expect(find.text('完成总结'), findsNothing);

    await tester.tap(find.byKey(const Key('route-reentry-open')));
    await tester.pumpAndSettle();

    expect(find.text('Splash splash.'), findsOneWidget);
    expect(find.byKey(const Key('care-turn-next-support')), findsNothing);
    expect(find.byKey(const Key('care-reaction-cooperating')), findsNothing);
    expect(find.byKey(const Key('practice-completion-view')), findsNothing);
    expect(find.text('完成总结'), findsNothing);
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
    expect(find.text('有一小段练习记录暂时没整理好，花圃先保留可用结果。'), findsOneWidget);
    expect(find.textContaining('有 1 条记录'), findsNothing);

    await _pumpApp(tester, HomeGrowthSummaryCard(notifier: notifier));

    expect(find.byKey(const Key('home-growth-summary')), findsOneWidget);
    expect(find.text('花圃醒来了'), findsOneWidget);
    expect(find.text('配合了 hello。'), findsOneWidget);
    expect(
      find.byKey(const Key('home-growth-summary-warning')),
      findsOneWidget,
    );
  });

  testWidgets('Garden continuation copy stays parent-facing', (tester) async {
    final continuitySnapshot = _continuitySnapshot();
    final continuityNotifier = _homeContinuityNotifier(continuitySnapshot);
    final gardenSnapshot = _gardenSnapshot(spaces: [_gardenPatch()]);

    await _pumpApp(
      tester,
      GardenHeroCard(
        snapshot: gardenSnapshot,
        status: GardenGrowthLoadStatus.ready,
        continuityNotifier: continuityNotifier,
        continuitySnapshot: continuitySnapshot,
        continuityActivity: _homeActivitySnapshot,
      ),
    );

    expect(find.textContaining('接着刚才练过的场景'), findsOneWidget);
    expect(find.byKey(const Key('garden-continuity-status')), findsNothing);
    expect(find.textContaining('continuity'), findsNothing);
    expect(find.textContaining('recommendation'), findsNothing);
    expect(find.textContaining('activity'), findsNothing);

    await _pumpApp(
      tester,
      GardenContinueCard(
        practiceArgs: const PracticeRouteArgs(
          spaceId: 'home',
          activityId: 'song_time',
        ),
        continuityNotifier: continuityNotifier,
        continuitySnapshot: continuitySnapshot,
        continuityActivity: _homeActivitySnapshot,
      ),
    );

    expect(find.textContaining('接着刚才练过的场景'), findsOneWidget);
    expect(find.text('继续练习后，首页和花园会一起记住这次变化。'), findsOneWidget);
    expect(find.textContaining('continuity'), findsNothing);
    expect(find.textContaining('recommendation'), findsNothing);
    expect(find.textContaining('activity'), findsNothing);

    final reasonCases = <PracticeContinuityReason, String>{
      PracticeContinuityReason.recentActivity: '接着刚才练过的场景',
      PracticeContinuityReason.nextIncomplete: '接上还没说完的活动',
      PracticeContinuityReason.starterFallback: '回到第一颗种子',
      PracticeContinuityReason.safeCatalogFallback: '先从稳定活动开始',
    };

    for (final entry in reasonCases.entries) {
      final snapshot = _continuitySnapshot(
        reason: entry.key,
        fallbackReason: entry.key == PracticeContinuityReason.starterFallback
            ? '回到 starter activity。'
            : null,
      );
      await _pumpApp(
        tester,
        GardenContinueCard(
          practiceArgs: const PracticeRouteArgs(
            spaceId: 'home',
            activityId: 'song_time',
          ),
          continuityNotifier: _homeContinuityNotifier(snapshot),
          continuitySnapshot: snapshot,
          continuityActivity: _homeActivitySnapshot,
        ),
      );

      expect(find.text(entry.value), findsOneWidget);
      expect(find.textContaining('starter activity'), findsNothing);
      expect(find.textContaining('safe fallback'), findsNothing);
      if (entry.key == PracticeContinuityReason.starterFallback) {
        expect(find.text('已经为你换到一条稳定可继续的练习。'), findsOneWidget);
      }
    }

    final guardedSnapshot = _continuitySnapshot();
    final guardedNotifier = _homeContinuityNotifier(
      guardedSnapshot,
      warningMessage: 'continuity snapshot 有一条 activity 无法整理。',
      disabledReason: 'activity route args 不可用。',
    );

    await _pumpApp(
      tester,
      GardenContinueCard(
        practiceArgs: const PracticeRouteArgs(
          spaceId: 'home',
          activityId: 'song_time',
        ),
        continuityNotifier: guardedNotifier,
        continuitySnapshot: guardedSnapshot,
        continuityActivity: _homeActivitySnapshot,
      ),
    );

    expect(find.text('有一小段练习记录暂时没整理好，当前建议仍可继续。'), findsOneWidget);
    expect(find.text('这条继续练习暂时打不开，先回首页或稍后再试。'), findsOneWidget);
    expect(find.textContaining('continuity snapshot'), findsNothing);
    expect(find.textContaining('route args'), findsNothing);
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

    await _pumpApp(
      tester,
      HomeRecentResultCard(
        continuitySnapshot: _continuitySnapshot(
          fallbackReason: 'starter activity 作为 continuity fallback。',
          hasRecentResult: false,
        ),
      ),
    );

    expect(find.text('最近结果暂时没整理好，先为你保留一条可继续的练习。'), findsOneWidget);
    expect(find.textContaining('starter activity'), findsNothing);
    expect(find.textContaining('continuity fallback'), findsNothing);

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
    expect(find.text('花圃暂时没整理好，会先保留当前结果。'), findsOneWidget);
    expect(find.text('花园暂时不可用。'), findsNothing);
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
          onShare: (_) async {
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
          onShare: (_) async {
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
      await tester.pumpAndSettle();
      expect(shareCount, 0);
      expect(find.byKey(const Key('home-share-preview-sheet')), findsOneWidget);
      expect(find.text('今天有一个新尝试'), findsWidgets);
      expect(find.textContaining('宝宝跟着节奏配合了一次'), findsWidgets);
      expect(find.textContaining('不会包含手机号、设备标识'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('home-share-preview-confirm-button')),
      );
      await tester.pumpAndSettle();
      expect(shareCount, 1);

      await _pumpApp(
        tester,
        ShareCalloutCard(
          surfaceKeyPrefix: 'home',
          notifier: _ShareNotifierStub(currentDraft: draft, isSharing: true),
          sectionLabel: '分享给家人',
          emptyMessage: '暂无可分享内容。',
          onShare: (_) async {
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

  testWidgets('Shell drawer maps household phases to family-safe labels', (
    tester,
  ) async {
    final gardenSnapshot = _gardenSnapshot(spaces: [_gardenPatch()]);
    final continuitySnapshot = _continuitySnapshot();
    final householdNotifier = HouseholdNotifier(
      repository: _HomeHouseholdRepository(
        snapshot: const HouseholdLocalSnapshot(
          lastPhase: 'create_invite_created',
        ),
      ),
    );
    await householdNotifier.initialize();

    await _pumpApp(
      tester,
      AppShellScreen(
        onboardingSnapshot: OnboardingSnapshot(
          childDisplayName: '米米',
          ageBucket: OnboardingAgeBucket.oneToTwo,
          approxMonths: 15,
          currentStage: 'gesture_plus_words',
          starterSpaceId: 'home',
          starterActivityId: 'song_time',
          starterPhraseId: 'hello_wave',
          consentState: OnboardingConsentState.localOnly,
          completedAt: DateTime.utc(2026, 4, 8, 8),
        ),
      ),
      scaffold: false,
      overrides: [
        accountNotifierProvider.overrideWith((ref) {
          return AccountNotifier(repository: _ScreenAccountRepository());
        }),
        practiceContinuityNotifierProvider.overrideWith((ref) {
          return _homeContinuityNotifier(continuitySnapshot);
        }),
        carePathNotifierProvider.overrideWith((ref) {
          return _homeCarePathNotifier(continuitySnapshot);
        }),
        gardenGrowthNotifierProvider.overrideWith((ref) {
          return GardenGrowthNotifier(
            repository: _HomeGardenGrowthRepository(gardenSnapshot),
            refreshTimeout: Duration.zero,
          );
        }),
        householdNotifierProvider.overrideWith((ref) {
          return householdNotifier;
        }),
        gardenFertilizerNotifierProvider.overrideWith(
          (ref) =>
              _FertilizerNotifierStub(ref.watch(gardenGrowthNotifierProvider)),
        ),
        shareNotifierProvider.overrideWith((ref) {
          return ShareNotifier(
            repository: _HomeShareRepository(),
            initialGrowthSnapshot: gardenSnapshot,
            initialContinuitySnapshot: continuitySnapshot,
          );
        }),
      ],
    );
    await _pumpFrames(tester, count: 10);

    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await tester.pumpAndSettle();

    expect(find.text('create_invite_created'), findsNothing);
    expect(find.text('邀请待确认'), findsOneWidget);
  });

  testWidgets('Shell labels use Today/Scene and Garden remains index 2', (
    tester,
  ) async {
    final practiceRepository = _CarePathScreenPracticeRepository();
    final gardenSnapshot = _gardenSnapshot(spaces: [_gardenPatch()]);
    final continuitySnapshot = _continuitySnapshot();
    final householdNotifier = HouseholdNotifier(
      repository: _HomeHouseholdRepository(
        snapshot: const HouseholdLocalSnapshot(
          lastPhase: 'shared_context_ready',
        ),
      ),
    );
    await householdNotifier.initialize();

    await _pumpApp(
      tester,
      const AppShellScreen(customSceneEnabled: true),
      scaffold: false,
      overrides: [
        practiceRepositoryProvider.overrideWith(
          (ref) async => practiceRepository,
        ),
        accountNotifierProvider.overrideWith((ref) {
          return AccountNotifier(repository: _ScreenAccountRepository());
        }),
        practiceContinuityNotifierProvider.overrideWith((ref) {
          return _homeContinuityNotifier(continuitySnapshot);
        }),
        carePathNotifierProvider.overrideWith((ref) {
          return _homeCarePathNotifier(continuitySnapshot);
        }),
        gardenGrowthNotifierProvider.overrideWith((ref) {
          return GardenGrowthNotifier(
            repository: _HomeGardenGrowthRepository(gardenSnapshot),
            refreshTimeout: Duration.zero,
          );
        }),
        householdNotifierProvider.overrideWith((ref) {
          return householdNotifier;
        }),
        gardenFertilizerNotifierProvider.overrideWith(
          (ref) =>
              _FertilizerNotifierStub(ref.watch(gardenGrowthNotifierProvider)),
        ),
        shareNotifierProvider.overrideWith((ref) {
          return ShareNotifier(
            repository: _HomeShareRepository(),
            initialGrowthSnapshot: gardenSnapshot,
            initialContinuitySnapshot: continuitySnapshot,
          );
        }),
      ],
    );
    await _pumpFrames(tester, count: 10);

    expect(find.text('今天'), findsWidgets);
    expect(find.text('场景'), findsOneWidget);
    expect(find.byKey(const Key('shell-nav-home')), findsOneWidget);
    expect(find.byKey(const Key('shell-nav-discover')), findsOneWidget);
    expect(find.byKey(const Key('shell-nav-garden')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    // Home keeps the existing shell FAB behavior; T3 only changes IA labels.
    expect(find.byKey(const Key('shell-mentor-fab')), findsOneWidget);
    expect(find.byKey(const Key('shell-settings-gear')), findsNothing);

    // §5 规则3：场景 Tab 固定显示全局 FAB。
    tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .onDestinationSelected!(1);
    await _pumpFrames(tester, count: 6);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('场景'), findsWidgets);
    expect(find.byKey(const Key('shell-mentor-fab')), findsOneWidget);
    expect(find.byKey(const Key('shell-settings-gear')), findsNothing);

    final semantics = tester.ensureSemantics();
    try {
      final entryFinder = find.byKey(const Key('custom-scene-entry-scene'));
      await tester.ensureVisible(entryFinder);
      await tester.pumpAndSettle();
      final finalCardAction = tester.getSemantics(
        find.descendant(
          of: find.byKey(const Key('discover-phrase-card-song_time')),
          matching: find.byType(InkWell),
        ),
      );
      final entry = tester.getSemantics(entryFinder);
      final mentorFab = tester.getSemantics(
        find.byKey(const Key('shell-mentor-fab')),
      );
      final todayNavigation = tester.getSemantics(
        find.byKey(const Key('shell-nav-home')),
      );
      final traversal = tester.semantics
          .simulatedAccessibilityTraversal()
          .toList(growable: false);
      final finalCardIndex = traversal.indexWhere(
        (node) => node.id == finalCardAction.id,
      );
      final entryIndex = traversal.indexWhere((node) => node.id == entry.id);
      final todayIndex = traversal.indexWhere(
        (node) => node.id == todayNavigation.id,
      );
      final mentorFabIndex = traversal.indexWhere(
        (node) => node.id == mentorFab.id,
      );

      expect(
        <int>[
          finalCardIndex,
          entryIndex,
          todayIndex,
          mentorFabIndex,
        ].every((index) => index >= 0),
        isTrue,
      );
      expect(entryIndex, finalCardIndex + 1);
      expect(todayIndex, entryIndex + 1);
      expect(mentorFabIndex, greaterThan(todayIndex));

      final reverse = traversal.reversed.toList(growable: false);
      final reverseTodayIndex = reverse.indexWhere(
        (node) => node.id == todayNavigation.id,
      );
      final reverseEntryIndex = reverse.indexWhere(
        (node) => node.id == entry.id,
      );
      final reverseFinalCardIndex = reverse.indexWhere(
        (node) => node.id == finalCardAction.id,
      );
      expect(reverseEntryIndex, reverseTodayIndex + 1);
      expect(reverseFinalCardIndex, reverseEntryIndex + 1);
    } finally {
      semantics.dispose();
    }

    // §5 规则2：花园 Tab 隐藏全局 FAB（花园有自己的施肥交互）。
    tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .onDestinationSelected!(2);
    await _pumpFrames(tester, count: 6);
    // Scaffold 的 FAB 退出动画约 200ms+，再补一帧长 pump 让其完成移除。
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.byKey(const Key('shell-mentor-fab')), findsNothing);
    expect(find.byKey(const Key('shell-settings-gear')), findsNothing);

    // §4：我 Tab 顶栏右上角出现设置齿轮；FAB 恢复显示。
    tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .onDestinationSelected!(3);
    await _pumpFrames(tester, count: 6);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('shell-settings-gear')), findsOneWidget);
    expect(find.byKey(const Key('shell-mentor-fab')), findsOneWidget);
  });

  testWidgets('Shell household status labels cover sanitized phase families', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      Builder(
        builder: (context) {
          final l = AppLocalizations.of(context)!;

          expect(
            drawerHouseholdStatusLabel(l, 'shared_context_ready'),
            '共享已接通',
          );
          expect(
            drawerHouseholdStatusLabel(l, 'create_invite_created'),
            '邀请待确认',
          );
          expect(
            drawerHouseholdStatusLabel(l, 'accept_invite_timeout'),
            '共享暂时不可用',
          );
          expect(drawerHouseholdStatusLabel(l, 'read_only'), '仅可查看共享');
          expect(drawerHouseholdStatusLabel(l, null), '共享待同步');
          expect(
            drawerHouseholdStatusLabel(l, 'internal_debug_phase'),
            '共享待同步',
          );

          return const SizedBox.shrink();
        },
      ),
    );
  });
}

/// Static fertilizer notifier stub: renders the empty panel state without the
/// loading shimmer animation, so [WidgetTester.pumpAndSettle] can settle when
/// the shell embeds the garden tab off-stage.
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

Future<void> _pumpApp(
  WidgetTester tester,
  Widget child, {
  bool scaffold = true,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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

Future<void> _pumpFrames(
  WidgetTester tester, {
  int count = 6,
  Duration step = const Duration(milliseconds: 20),
}) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(step);
  }
}

void _setViewport(WidgetTester tester, Size size, {double textScale = 1.0}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.binding.platformDispatcher.clearTextScaleFactorTestValue);
}

void _expectMinTouchTarget(WidgetTester tester, Key key) {
  final size = tester.getSize(find.byKey(key));
  expect(size.width, greaterThanOrEqualTo(AppLayoutConstants.minTouchTarget));
  expect(size.height, greaterThanOrEqualTo(AppLayoutConstants.minTouchTarget));
}

void _expectNoFlutterException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

const _careTurnViewportCases = [
  _CareTurnViewportCase('427x952dp @ 1.0', Size(427, 952), 1.0),
  _CareTurnViewportCase('427x952dp @ 1.3', Size(427, 952), 1.3),
  _CareTurnViewportCase('390x844dp @ 1.3', Size(390, 844), 1.3),
];

class _CareTurnViewportCase {
  const _CareTurnViewportCase(this.label, this.size, this.textScale);

  final String label;
  final Size size;
  final double textScale;
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
      reactionType: BabyReactionType.cooperating,
      previousPatchStage: GardenPatchStage.quiet,
      currentPatchStage: GardenPatchStage.tended,
      previousFlowerStage: GardenFlowerStage.seed,
      currentFlowerStage: GardenFlowerStage.sprout,
      headline: '花圃醒来了',
      detail: '配合了 hello。',
    ),
    totalStoredEvents: 2,
    validEvents: 2,
    knownEvents: 2,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
    projectionWarning: projectionWarning,
  );
}

PracticeContinuitySnapshot _continuitySnapshot({
  PracticeContinuityReason reason = PracticeContinuityReason.recentActivity,
  String? fallbackReason,
  bool hasRecentResult = true,
}) {
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
    recentResult: hasRecentResult
        ? PracticeCatalogRecentResultSummary(
            phraseId: 'hello_wave',
            phraseEnglish: 'Hello wave',
            reactionType: BabyReactionType.cooperating,
            eventTime: DateTime.utc(2026, 5, 19, 8),
            totalEvents: 2,
          )
        : null,
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
      reason: reason,
      reasonLabel: reason.label,
      fallbackReason: fallbackReason,
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
    storyText: '宝宝跟着节奏配合了一次。',
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

class _ScreenPracticeAudioController implements PracticeAudioController {
  final StreamController<void> _controller = StreamController<void>.broadcast();
  final List<String> playedAssets = [];

  @override
  Stream<void> get completionStream => _controller.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    playedAssets.add(assetPath);
  }

  @override
  Future<void> stop() async {}

  void completePlayback() {
    _controller.add(null);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _PracticeSessionHost extends StatelessWidget {
  const _PracticeSessionHost({required this.state});

  final ValueNotifier<_PracticeSessionHostState> state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_PracticeSessionHostState>(
      valueListenable: state,
      builder: (context, currentState, _) {
        if (!currentState.showScreen) {
          return const SizedBox.shrink();
        }
        return PracticeSessionScreen(routeEntry: currentState.routeEntry);
      },
    );
  }
}

class _PracticeSessionHostState {
  const _PracticeSessionHostState({
    required this.routeEntry,
    this.showScreen = true,
  });

  final PracticeRouteEntry routeEntry;
  final bool showScreen;
}

class _TrackingCarePathNotifier extends CarePathNotifier {
  _TrackingCarePathNotifier({required super.repository});

  final List<String> startMomentCalls = [];

  @override
  Future<void> startMoment({
    required String spaceId,
    required String activityId,
  }) {
    startMomentCalls.add('$spaceId/$activityId');
    return super.startMoment(spaceId: spaceId, activityId: activityId);
  }
}

class _ScreenGardenGrowthRepository implements GardenGrowthRepository {
  const _ScreenGardenGrowthRepository(this.snapshot);

  final GardenGrowthSnapshot snapshot;

  @override
  Future<GardenGrowthSnapshot> buildSnapshot() async => snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CarePathScreenPracticeRepository implements PracticeRepository {
  _CarePathScreenPracticeRepository({
    Map<String, PracticeActivitySnapshot>? activitySnapshots,
  }) : activitySnapshots = activitySnapshots ?? _screenActivitySnapshots;

  final Map<String, PracticeActivitySnapshot> activitySnapshots;
  final List<InteractionEventPayload> recordedEvents = [];

  @override
  Future<PracticeContinuitySnapshot> getContinuitySnapshot({
    String? starterSpaceId,
    String? starterActivityId,
  }) async {
    final catalog = await getActivityCatalog();
    final activity =
        catalog.findActivity(
          spaceId: starterSpaceId ?? 'daily_care',
          activityId: starterActivityId ?? 'bath_time',
        ) ??
        catalog.activities.first;
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
        reason: PracticeContinuityReason.starterFallback,
        reasonLabel: PracticeContinuityReason.starterFallback.label,
      ),
      cadence: PracticeContinuityCadenceSummary(
        totalKnownEvents: recordedEvents.length,
        startedActivityCount: recordedEvents.isEmpty ? 0 : 1,
        lastEventTime: recordedEvents.isEmpty
            ? null
            : recordedEvents.last.clientTimestamp,
        headline: '从这一句开始',
        detail: '先保持一个照护节奏。',
      ),
    );
  }

  @override
  Future<PracticeRestoreSnapshot> restorePracticeState({
    required String spaceId,
    required String activityId,
  }) async {
    final activity = await getActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
    );
    return PracticeRestoreSnapshot(
      installationId: 'install_screen_test',
      activitySnapshot: activity,
      homeSummary: PracticeHomeSummary(
        spaceId: activity.spaceId,
        activityId: activity.activityId,
        activityTitle: activity.title,
        totalEvents: _eventsFor(spaceId, activityId).length,
        lastEventTime: _eventsFor(spaceId, activityId).isEmpty
            ? null
            : _eventsFor(spaceId, activityId).last.clientTimestamp,
        recentResult: _eventsFor(spaceId, activityId).isEmpty
            ? null
            : PracticeRecentResultSummary(
                activityId: activity.activityId,
                activityTitle: activity.title,
                phraseId: _eventsFor(spaceId, activityId).last.phraseId,
                phraseEnglish: activity.phrases
                    .firstWhere(
                      (phrase) =>
                          phrase.phraseId ==
                          _eventsFor(spaceId, activityId).last.phraseId,
                    )
                    .english,
                reactionType: _eventsFor(spaceId, activityId).last.reactionType,
                eventTime: _eventsFor(spaceId, activityId).last.clientTimestamp,
                totalEvents: _eventsFor(spaceId, activityId).length,
              ),
      ),
      resumeInfo: PracticeResumeInfo(
        activityId: activity.activityId,
        totalPhrases: activity.phrases.length,
        completedPhraseIds: _eventsFor(
          spaceId,
          activityId,
        ).map((event) => event.phraseId).toList(),
        nextPhraseId: _resolveNextPhraseId(activity),
        lastEventTime: _eventsFor(spaceId, activityId).isEmpty
            ? null
            : _eventsFor(spaceId, activityId).last.clientTimestamp,
      ),
      inspection: PracticeEventInspection(
        installationId: 'install_screen_test',
        storedEventCount: _eventsFor(spaceId, activityId).length,
        validEvents: List<InteractionEventPayload>.unmodifiable(
          _eventsFor(spaceId, activityId),
        ),
        skippedEventCount: 0,
      ),
      restoreMessage: _eventsFor(spaceId, activityId).isEmpty
          ? '未找到本地记录。'
          : '已从本地恢复。',
      hasRecoverableIssue: false,
    );
  }

  @override
  Future<PracticeActivityCatalog> getActivityCatalog() async {
    final activities = activitySnapshots.values.map((activity) {
      final events = _eventsFor(activity.spaceId, activity.activityId);
      return PracticeCatalogActivitySummary(
        spaceId: activity.spaceId,
        spaceTitle: activity.spaceId == 'daily_care' ? '日常照护' : '家里',
        activityId: activity.activityId,
        title: activity.title,
        summary: activity.summary,
        sceneTag: activity.sceneTag,
        coachTip: activity.coachTip,
        totalPhraseCount: activity.phrases.length,
        completedPhraseCount: events.length.clamp(0, activity.phrases.length),
        completedPhraseIds: events.map((event) => event.phraseId).toList(),
        nextPhraseId: _resolveNextPhraseId(activity),
        nextPhraseEnglish: _nextPhrase(activity)?.english,
        totalEvents: events.length,
        skippedUnknownPhraseCount: 0,
        skippedMalformedEventCount: 0,
        recentResult: events.isEmpty
            ? null
            : PracticeCatalogRecentResultSummary(
                phraseId: events.last.phraseId,
                phraseEnglish: activity.phrases
                    .firstWhere(
                      (phrase) => phrase.phraseId == events.last.phraseId,
                    )
                    .english,
                reactionType: events.last.reactionType,
                eventTime: events.last.clientTimestamp,
                totalEvents: events.length,
              ),
      );
    }).toList();

    return PracticeActivityCatalog(
      installationId: 'install_screen_test',
      spaces: const [],
      activities: activities,
      totalStoredEvents: recordedEvents.length,
      validEvents: recordedEvents.length,
      knownEvents: recordedEvents.length,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
  }

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    final activity = activitySnapshots['$spaceId/$activityId'];
    if (activity == null) {
      throw StateError('unknown activity $spaceId/$activityId');
    }
    return activity;
  }

  @override
  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async {
    final restored = await restorePracticeState(
      spaceId: spaceId,
      activityId: activityId,
    );
    return restored.resumeInfo;
  }

  @override
  Future<InteractionEventPayload> recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    String? generatedContentId,
    String? utteranceId,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    final event = InteractionEventPayload(
      localEventId: localEventId ?? 'evt_screen_${recordedEvents.length + 1}',
      installationId: 'install_screen_test',
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp:
          clientTimestamp ??
          DateTime.utc(2026, 5, 20, 8, recordedEvents.length),
    );
    recordedEvents.add(event);
    return event;
  }

  List<InteractionEventPayload> _eventsFor(String spaceId, String activityId) {
    return recordedEvents
        .where(
          (event) => event.spaceId == spaceId && event.activityId == activityId,
        )
        .toList();
  }

  String? _resolveNextPhraseId(PracticeActivitySnapshot activity) {
    final completedIds = _eventsFor(
      activity.spaceId,
      activity.activityId,
    ).map((event) => event.phraseId).toSet();
    for (final phrase in activity.phrases) {
      if (!completedIds.contains(phrase.phraseId)) {
        return phrase.phraseId;
      }
    }
    return null;
  }

  PracticePhrase? _nextPhrase(PracticeActivitySnapshot activity) {
    final nextPhraseId = _resolveNextPhraseId(activity);
    if (nextPhraseId == null) {
      return null;
    }
    return activity.phrases.firstWhere(
      (phrase) => phrase.phraseId == nextPhraseId,
    );
  }

  @override
  Future<void> close({bool deleteFromDisk = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeDefaultCarePathScreenPracticeRepository
    extends _CarePathScreenPracticeRepository {
  @override
  Future<PracticeContinuitySnapshot> getContinuitySnapshot({
    String? starterSpaceId,
    String? starterActivityId,
  }) {
    return super.getContinuitySnapshot(
      starterSpaceId: starterSpaceId ?? 'home',
      starterActivityId: starterActivityId ?? 'song_time',
    );
  }
}

class _GatedContinuityCarePathScreenPracticeRepository
    extends _CarePathScreenPracticeRepository {
  final Completer<void> _continuityGate = Completer<void>();
  bool continuityRequested = false;

  @override
  Future<PracticeContinuitySnapshot> getContinuitySnapshot({
    String? starterSpaceId,
    String? starterActivityId,
  }) async {
    continuityRequested = true;
    await _continuityGate.future;
    return super.getContinuitySnapshot(
      starterSpaceId: starterSpaceId,
      starterActivityId: starterActivityId,
    );
  }

  void releaseContinuity() {
    if (!_continuityGate.isCompleted) {
      _continuityGate.complete();
    }
  }
}

const _screenActivitySnapshot = PracticeActivitySnapshot(
  spaceId: 'daily_care',
  activityId: 'bath_time',
  title: '洗澡时间',
  summary: '用三句短语保持照护节奏。',
  sceneTag: 'bath',
  coachTip: '先说动作，再慢慢等待宝宝回应。',
  phrases: [
    PracticePhrase(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      phraseId: 'bath_time_warm_water',
      step: 1,
      english: 'Warm water.',
      chinese: '温温的水。',
      pronunciation: 'wɔːrm ˈwɔːtər',
      difficulty: 'starter',
      audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
    ),
    PracticePhrase(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      phraseId: 'bath_time_splash_splash',
      step: 2,
      english: 'Splash splash.',
      chinese: '哗啦哗啦。',
      pronunciation: 'splæʃ splæʃ',
      difficulty: 'starter',
      audioAsset: 'assets/audio/phrases/bath_time_splash_splash.mp3',
    ),
    PracticePhrase(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      phraseId: 'bath_time_all_clean',
      step: 3,
      english: 'All clean.',
      chinese: '洗干净啦。',
      pronunciation: 'ɔːl kliːn',
      difficulty: 'starter',
      audioAsset: 'assets/audio/phrases/bath_time_all_clean.mp3',
    ),
  ],
);

const _screenActivitySnapshots = <String, PracticeActivitySnapshot>{
  'daily_care/bath_time': _screenActivitySnapshot,
  'home/song_time': _homeActivitySnapshot,
};

PracticeActivitySnapshot _screenActivitySnapshotWithoutFirstAudio() {
  final firstPhrase = _screenActivitySnapshot.phrases.first;
  return PracticeActivitySnapshot(
    spaceId: _screenActivitySnapshot.spaceId,
    activityId: _screenActivitySnapshot.activityId,
    title: _screenActivitySnapshot.title,
    summary: _screenActivitySnapshot.summary,
    sceneTag: _screenActivitySnapshot.sceneTag,
    coachTip: _screenActivitySnapshot.coachTip,
    phrases: [
      firstPhrase.copyWith(audioAsset: ''),
      ..._screenActivitySnapshot.phrases.skip(1),
    ],
  );
}

PracticeContinuityNotifier _homeContinuityNotifier(
  PracticeContinuitySnapshot continuitySnapshot, {
  String? warningMessage,
  String? disabledReason,
}) {
  const recommendedArgs = PracticeRouteArgs(
    spaceId: 'home',
    activityId: 'song_time',
  );
  return PracticeContinuityNotifier(
    continuitySnapshotLoader: ({starterSpaceId, starterActivityId}) async {
      return continuitySnapshot;
    },
    activitySnapshotLoader: ({required spaceId, required activityId}) async {
      return _homeActivitySnapshot;
    },
    seedState: PracticeContinuitySeedState(
      snapshot: continuitySnapshot,
      activitySnapshot: _homeActivitySnapshot,
      recommendedArgs: recommendedArgs,
      status: PracticeContinuityLoadStatus.ready,
      warningMessage: warningMessage,
      disabledReason: disabledReason,
      lastRefreshReason: 'home_screen_test_seed',
    ),
    refreshTimeout: Duration.zero,
  );
}

CarePathNotifier _homeCarePathNotifier(
  PracticeContinuitySnapshot continuitySnapshot,
) {
  return CarePathNotifier(
    repository: CarePathRepository(
      practiceRepository: _HomeCarePathPracticeRepository(continuitySnapshot),
    ),
  )..loadCurrentUtterance(
    starterSpaceId: 'home',
    starterActivityId: 'song_time',
  );
}

const _homeActivitySnapshot = PracticeActivitySnapshot(
  spaceId: 'home',
  activityId: 'song_time',
  title: '唱一小段',
  summary: '短歌互动',
  sceneTag: 'music',
  coachTip: '放慢一点。',
  phrases: [
    PracticePhrase(
      spaceId: 'home',
      activityId: 'song_time',
      phraseId: 'hello_wave',
      step: 1,
      english: 'Hello wave.',
      chinese: '挥挥手说你好。',
      pronunciation: 'həˈloʊ weɪv',
      difficulty: 'starter',
      audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
    ),
    PracticePhrase(
      spaceId: 'home',
      activityId: 'song_time',
      phraseId: 'clap_hands',
      step: 2,
      english: 'Clap hands.',
      chinese: '拍拍手。',
      pronunciation: 'klæp hændz',
      difficulty: 'starter',
      audioAsset: 'assets/audio/phrases/bath_time_splash_splash.mp3',
    ),
  ],
);

class _HomeCarePathPracticeRepository implements PracticeRepository {
  const _HomeCarePathPracticeRepository(this.continuitySnapshot);

  final PracticeContinuitySnapshot continuitySnapshot;

  @override
  Future<PracticeContinuitySnapshot> getContinuitySnapshot({
    String? starterSpaceId,
    String? starterActivityId,
  }) async {
    return continuitySnapshot;
  }

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    return _homeActivitySnapshot;
  }

  @override
  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async {
    return PracticeResumeInfo(
      activityId: activityId,
      totalPhrases: _homeActivitySnapshot.phrases.length,
      completedPhraseIds: const [],
      nextPhraseId: 'hello_wave',
      lastEventTime: null,
    );
  }

  @override
  Future<void> close({bool deleteFromDisk = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeGardenGrowthRepository implements GardenGrowthRepository {
  const _HomeGardenGrowthRepository(this.snapshot);

  final GardenGrowthSnapshot snapshot;

  @override
  Future<GardenGrowthSnapshot> buildSnapshot() async => snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeHouseholdRepository implements HouseholdRepository {
  _HomeHouseholdRepository({
    this.snapshot = const HouseholdLocalSnapshot(
      lastPhase: 'home_screen_test_empty',
    ),
  });

  final HouseholdLocalSnapshot snapshot;

  @override
  Future<HouseholdLocalSnapshot> loadSnapshot() async {
    return snapshot;
  }

  @override
  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) async {
    return const HouseholdLocalSnapshot(lastPhase: 'home_screen_test_refresh');
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeShareRepository implements ShareRepository {
  @override
  ShareLinkDraft? buildDraft({
    GardenGrowthSnapshot? growthSnapshot,
    PracticeContinuitySnapshot? continuitySnapshot,
  }) {
    return _shareDraft();
  }

  @override
  Future<ShareExecutionResult> shareSnapshots({
    GardenGrowthSnapshot? growthSnapshot,
    PracticeContinuitySnapshot? continuitySnapshot,
  }) async {
    return ShareExecutionResult(
      status: ShareExecutionStatus.shared,
      phase: 'home_screen_test_shared',
      message: '已分享。',
      draft: _shareDraft(),
      shareUrl: 'https://share.example.test/home',
      token: 'share_home_test',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScreenAccountRepository implements AccountRepositoryContract {
  AccountLocalSnapshot _snapshot = AccountLocalSnapshot(
    consentState: AccountConsentState.acceptedPendingSync,
    session: AccountSession(
      accountId: 'acct_screen',
      sessionId: 'sess_screen',
      maskedPhoneNumber: '138****8000',
      createdAt: DateTime.utc(2026, 5, 20, 8),
      accessToken: 'access_screen',
      refreshToken: 'refresh_screen',
    ),
    lastSyncPhase: 'screen_test_seed',
  );

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => _snapshot;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => seedSnapshot ?? _snapshot;

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    _snapshot = revertToLocalOnly
        ? AccountLocalSnapshot.localOnly
        : AccountLocalSnapshot.signedOut;
    return _snapshot;
  }

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    _snapshot = _snapshot.copyWith(
      consentState: AccountConsentState.revoked,
      lastSyncPhase: 'screen_revoked',
    );
    return _snapshot;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async {
    _snapshot = _snapshot.copyWith(
      consentState: AccountConsentState.deleted,
      clearSession: true,
      lastSyncPhase: 'screen_deleted',
    );
    return _snapshot;
  }

  @override
  Future<void> close() async {}
}
