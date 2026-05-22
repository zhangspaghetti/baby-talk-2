import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
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
    expect(find.textContaining('练习入口暂时打不开'), findsOneWidget);
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
    'Practice session screen renders loaded flow and records reaction',
    (tester) async {
      final repository = _ScreenPracticeRepository();
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
          practiceRepositoryProvider.overrideWith((ref) async {
            return repository;
          }),
          accountNotifierProvider.overrideWith((ref) {
            return AccountNotifier(repository: _ScreenAccountRepository());
          }),
        ],
      );
      await _pumpFrames(tester, count: 8);

      expect(find.byKey(const Key('session-progress')), findsOneWidget);
      expect(find.byKey(const Key('practice-progress-text')), findsOneWidget);
      expect(find.text('第 1 / 3 句'), findsOneWidget);
      expect(find.text('现在试试这一句'), findsOneWidget);
      expect(find.text('发音可播放'), findsOneWidget);
      expect(find.text('等宝宝反应'), findsOneWidget);
      expect(find.textContaining('idle'), findsNothing);
      expect(find.textContaining('C3'), findsNothing);
      expect(find.textContaining('STEP'), findsNothing);
      expect(
        find.byKey(const Key('phrase-card-bath_time_warm_water')),
        findsOneWidget,
      );

      final playButton = find.byKey(const Key('play-bath_time_warm_water'));
      await tester.ensureVisible(playButton);
      await tester.pump();
      await tester.tap(playButton);
      await tester.pump();

      expect(audioController.playedAssets.single, endsWith('warm_water.mp3'));
      audioController.completePlayback();
      await tester.pump();

      expect(find.byKey(const Key('playback-banner')), findsOneWidget);

      final reactionButton = find.byKey(
        const Key('reaction-bath_time_warm_water-calm'),
      );
      await tester.ensureVisible(reactionButton);
      await tester.pump();
      await tester.tap(reactionButton);
      await _pumpFrames(tester, count: 8);

      expect(find.byKey(const Key('save-banner')), findsOneWidget);
      expect(repository._events, hasLength(1));
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
    expect(find.text('发音可播放'), findsOneWidget);
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

  testWidgets(
    'HomeScreen renders resolved continuity surface and lower cards',
    (tester) async {
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

      expect(
        find.byKey(const ValueKey('home-hero-activity-song_time')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-start-practice')), findsOneWidget);
      expect(find.byKey(const Key('home-restore-banner')), findsOneWidget);
      expect(find.byKey(const Key('home-mentor-fab')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('home-share-card')),
        320,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 8,
      );
      expect(find.byKey(const Key('home-garden-mini-entry')), findsOneWidget);
      expect(find.byKey(const Key('home-growth-summary')), findsOneWidget);
      expect(find.byKey(const Key('home-share-card')), findsOneWidget);
    },
  );

  testWidgets('HomeScreen carries onboarding first seed and daily phrase cue', (
    tester,
  ) async {
    final gardenSnapshot = _gardenSnapshot(spaces: [_gardenPatch()]);
    final continuitySnapshot = _continuitySnapshot();
    final stageMatch = StageMatchCatalog.forAgeBucket(
      OnboardingAgeBucket.sixToTwelve,
    );
    final onboardingSnapshot = OnboardingSnapshot(
      childDisplayName: '米米',
      ageBucket: OnboardingAgeBucket.sixToTwelve,
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

    expect(find.byKey(const Key('home-local-only-banner')), findsOneWidget);
    expect(find.byKey(const Key('home-starter-seed')), findsOneWidget);
    expect(find.byKey(const Key('home-daily-phrase-cue')), findsOneWidget);
    expect(find.text('今天继续这一句'), findsOneWidget);
    expect(find.text('Hello wave.'), findsWidgets);
    expect(find.text('挥挥手说你好。'), findsOneWidget);
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
    expect(find.text('宝宝模仿了 hello。'), findsOneWidget);
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
      expect(find.textContaining('宝宝跟着节奏模仿了一次'), findsWidgets);
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
          ageBucket: OnboardingAgeBucket.twelveToEighteen,
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
        gardenGrowthNotifierProvider.overrideWith((ref) {
          return GardenGrowthNotifier(
            repository: _HomeGardenGrowthRepository(gardenSnapshot),
            refreshTimeout: Duration.zero,
          );
        }),
        householdNotifierProvider.overrideWith((ref) {
          return householdNotifier;
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

    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await tester.pumpAndSettle();

    expect(find.text('create_invite_created'), findsNothing);
    expect(find.text('邀请待确认'), findsOneWidget);
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
            reactionType: BabyReactionType.imitated,
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

class _ScreenPracticeRepository implements PracticeRepository {
  final List<InteractionEventPayload> _events = [];

  @override
  Future<PracticeRestoreSnapshot> restorePracticeState({
    required String spaceId,
    required String activityId,
  }) async {
    return PracticeRestoreSnapshot(
      installationId: 'install_screen_test',
      activitySnapshot: _screenActivitySnapshot,
      homeSummary: PracticeHomeSummary(
        spaceId: _screenActivitySnapshot.spaceId,
        activityId: _screenActivitySnapshot.activityId,
        activityTitle: _screenActivitySnapshot.title,
        totalEvents: _events.length,
        lastEventTime: _events.isEmpty ? null : _events.last.clientTimestamp,
        recentResult: _events.isEmpty
            ? null
            : PracticeRecentResultSummary(
                activityId: _screenActivitySnapshot.activityId,
                activityTitle: _screenActivitySnapshot.title,
                phraseId: _events.last.phraseId,
                phraseEnglish: _screenActivitySnapshot.phrases
                    .firstWhere(
                      (phrase) => phrase.phraseId == _events.last.phraseId,
                    )
                    .english,
                reactionType: _events.last.reactionType,
                eventTime: _events.last.clientTimestamp,
                totalEvents: _events.length,
              ),
      ),
      resumeInfo: PracticeResumeInfo(
        activityId: _screenActivitySnapshot.activityId,
        totalPhrases: _screenActivitySnapshot.phrases.length,
        completedPhraseIds: _events.map((event) => event.phraseId).toList(),
        nextPhraseId: _resolveNextPhraseId(),
        lastEventTime: _events.isEmpty ? null : _events.last.clientTimestamp,
      ),
      inspection: PracticeEventInspection(
        installationId: 'install_screen_test',
        storedEventCount: _events.length,
        validEvents: List<InteractionEventPayload>.unmodifiable(_events),
        skippedEventCount: 0,
      ),
      restoreMessage: _events.isEmpty ? '未找到本地记录。' : '已从本地恢复。',
      hasRecoverableIssue: false,
    );
  }

  @override
  Future<InteractionEventPayload> recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    final event = InteractionEventPayload(
      localEventId: localEventId ?? 'evt_screen_${_events.length + 1}',
      installationId: 'install_screen_test',
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp:
          clientTimestamp ?? DateTime.utc(2026, 5, 20, 8, _events.length),
    );
    _events.add(event);
    return event;
  }

  String? _resolveNextPhraseId() {
    final completedIds = _events.map((event) => event.phraseId).toSet();
    for (final phrase in _screenActivitySnapshot.phrases) {
      if (!completedIds.contains(phrase.phraseId)) {
        return phrase.phraseId;
      }
    }
    return null;
  }

  @override
  Future<void> close({bool deleteFromDisk = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
