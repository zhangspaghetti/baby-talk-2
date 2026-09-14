import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/application/care_audio_session_coordinator.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/care_path/presentation/widgets/care_turn_surface.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CarePathNotifier notifier;

  setUp(() {
    notifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: _MemoryPracticeRepository(),
      ),
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  testWidgets(
    'shared surface drives said, canonical reaction, next support, and trace callback',
    (tester) async {
      var traceReadyCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CareTurnSurface(
              notifier: notifier,
              audioControllerFactory: _SilentPracticeAudioController.new,
              onTraceReady: (_) => traceReadyCount += 1,
              onQuietExit: () {},
            ),
          ),
        ),
      );

      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
      for (var index = 0; index < 8; index += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(const Key('care-turn-next-support')), findsOneWidget);
      expect(traceReadyCount, 1);
    },
  );

  testWidgets(
    'late trace callback receives an already-ready trace exactly once',
    (tester) async {
      var traceReadyCount = 0;
      await tester.pumpWidget(_surfaceTestApp(notifier: notifier));

      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
      for (var index = 0; index < 8; index += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(notifier.snapshot?.traceEventKey, isNotEmpty);
      expect(traceReadyCount, 0);

      await tester.pumpWidget(
        _surfaceTestApp(
          notifier: notifier,
          onTraceReady: (_) => traceReadyCount += 1,
        ),
      );
      await tester.pump();
      expect(traceReadyCount, 1);

      await tester.pump();
      expect(traceReadyCount, 1);
    },
  );

  testWidgets('optional reaction callback receives the canonical selection', (
    tester,
  ) async {
    final selections = <BabyReactionType>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CareTurnSurface(
            notifier: notifier,
            audioControllerFactory: _SilentPracticeAudioController.new,
            onReactionSelected: (reaction) async {
              selections.add(reaction);
            },
          ),
        ),
      ),
    );

    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();

    expect(selections, <BabyReactionType>[BabyReactionType.hesitant]);
  });

  testWidgets('reaction write failure exposes a retry action', (tester) async {
    var retried = 0;
    final errorNotifier = CarePathNotifier(
      repository: _FailingReactionCarePathRepository(
        practiceRepository: _MemoryPracticeRepository(),
      ),
    );
    addTearDown(errorNotifier.dispose);
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: errorNotifier,
        onRetryReaction: () async => retried += 1,
      ),
    );

    await errorNotifier.startMoment(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();

    expect(find.byKey(const Key('care-turn-retry-reaction')), findsOneWidget);
    expect(find.text('暂时无法完成这次回应，请再试一次。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('care-turn-retry-reaction')));
    expect(retried, 1);
  });

  testWidgets('audio failure restores Listen Once and exposes fallback', (
    tester,
  ) async {
    final audio = _FailingCareAudioPlaybackController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CareTurnSurface(
            notifier: notifier,
            careAudioControllerFactory: () => audio,
          ),
        ),
      ),
    );

    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();

    expect(audio.playCalls, 1);
    expect(find.byKey(const Key('care-turn-audio-error')), findsOneWidget);
    expect(find.text('音频暂时不可用'), findsOneWidget);
    final errorStatus = tester.widget<Semantics>(
      find.byKey(const Key('care-turn-audio-error')),
    );
    expect(errorStatus.properties.liveRegion, isTrue);
    expect(errorStatus.properties.label, '音频暂时不可用');
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('care-turn-listen-once')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('audio loading and playback status use a live region', (
    tester,
  ) async {
    final audio = _HeldCareAudioPlaybackController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CareTurnSurface(
            notifier: notifier,
            careAudioControllerFactory: () => audio,
          ),
        ),
      ),
    );

    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();

    final loadingStatus = tester.widget<Semantics>(
      find.byKey(const Key('care-turn-audio-error')),
    );
    expect(loadingStatus.properties.liveRegion, isTrue);
    expect(loadingStatus.properties.label, '正在准备音频…');

    audio.completePlayback();
    await tester.pump();
    final playingStatus = tester.widget<Semantics>(
      find.byKey(const Key('care-turn-audio-error')),
    );
    expect(playingStatus.properties.label, '正在播放音频…');
  });

  testWidgets(
    'autoplay starts only when the matching Care Turn becomes interactive',
    (tester) async {
      final audio = _ControllableCareAudioPlaybackController();
      await tester.pumpWidget(
        _surfaceTestApp(
          notifier: notifier,
          careAudio: audio,
          playbackPolicy: const CareTurnAudioPlaybackPolicy(
            autoPlayEnabled: true,
            playbackRate: 2.0,
          ),
        ),
      );

      expect(audio.requests, isEmpty);
      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await tester.pump();
      await tester.pump();

      expect(audio.requests, hasLength(1));
      expect(audio.requests.single.playbackRate, 2.0);
      expect(
        audio.requests.single.source,
        isA<CareAssetAudioSource>().having(
          (source) => source.assetPath,
          'asset path',
          'assets/audio/phrases/bath_time_warm_water.mp3',
        ),
      );
    },
  );

  testWidgets(
    'audio controls pause, resume, and replay with localized semantics',
    (tester) async {
      final audio = _ControllableCareAudioPlaybackController();
      await tester.pumpWidget(
        _surfaceTestApp(
          notifier: notifier,
          careAudio: audio,
          playbackPolicy: const CareTurnAudioPlaybackPolicy(
            autoPlayEnabled: false,
            playbackRate: 0.5,
          ),
        ),
      );
      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await tester.pump();
      expect(audio.requests, isEmpty);

      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await tester.pump();
      expect(audio.requests.single.playbackRate, 0.5);
      expect(find.byKey(const Key('care-turn-pause-audio')), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const Key('care-turn-audio-pause-control')),
            )
            .properties
            .label,
        '暂停音频',
      );

      await tester.tap(find.byKey(const Key('care-turn-pause-audio')));
      await tester.pump();
      expect(audio.pauseCalls, 1);
      expect(find.byKey(const Key('care-turn-resume-audio')), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-turn-resume-audio')));
      await tester.pump();
      expect(audio.resumeCalls, 1);
      audio.completeLastPlayback();
      await tester.pump();
      expect(find.text('重播'), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await tester.pump();
      expect(audio.requests, hasLength(2));
    },
  );

  testWidgets(
    'legacy asset playback does not claim autoplay or pause capabilities',
    (tester) async {
      final legacy = _SilentPracticeAudioController();
      await tester.pumpWidget(
        _surfaceTestApp(
          notifier: notifier,
          audioControllerFactory: () => legacy,
          playbackPolicy: const CareTurnAudioPlaybackPolicy(
            autoPlayEnabled: true,
            playbackRate: 2.0,
          ),
        ),
      );

      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await tester.pump();
      await tester.pump();

      expect(legacy.playCalls, 0);
      expect(find.byKey(const Key('care-turn-pause-audio')), findsNothing);

      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await tester.pump();
      expect(legacy.playCalls, 1);
      expect(find.byKey(const Key('care-turn-pause-audio')), findsNothing);
    },
  );

  testWidgets(
    'generated branch transition cancels a pre-mounted starter load',
    (tester) async {
      final generatedNotifier = CarePathNotifier(
        repository: CarePathRepository(
          practiceRepository: _GeneratedBranchPracticeRepository(),
        ),
      );
      addTearDown(generatedNotifier.dispose);
      await generatedNotifier.startGeneratedMoment(
        generatedContentId:
            _GeneratedBranchPracticeRepository.generatedContentId,
      );
      final audio = _DeferredCareAudioPlaybackController();
      await tester.pumpWidget(
        _generatedSurfaceTestApp(notifier: generatedNotifier, audio: audio),
      );

      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await audio.requested(_GeneratedBranchPracticeRepository.starterSource);
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
      await tester.pump();

      expect(audio.stopCalls, 1);
      audio.complete(_GeneratedBranchPracticeRepository.starterSource);
      await tester.pump();
      expect(audio.playedSources, isEmpty);
    },
  );

  testWidgets(
    'stale completion cannot finish an already-playing generated support',
    (tester) async {
      final generatedNotifier = CarePathNotifier(
        repository: CarePathRepository(
          practiceRepository: _GeneratedBranchPracticeRepository(),
        ),
      );
      addTearDown(generatedNotifier.dispose);
      await generatedNotifier.startGeneratedMoment(
        generatedContentId:
            _GeneratedBranchPracticeRepository.generatedContentId,
      );
      final audio = _DeferredCareAudioPlaybackController();
      await tester.pumpWidget(
        _generatedSurfaceTestApp(notifier: generatedNotifier, audio: audio),
      );

      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await audio.requested(_GeneratedBranchPracticeRepository.starterSource);
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
      await tester.pump();
      expect(find.text('Support.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await audio.requested(_GeneratedBranchPracticeRepository.supportSource);

      audio.complete(_GeneratedBranchPracticeRepository.supportSource);
      await tester.pump();
      final status = tester.widget<Semantics>(
        find.byKey(const Key('care-turn-audio-error')),
      );
      expect(status.properties.label, '正在播放音频…');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('care-turn-listen-once')),
            )
            .onPressed,
        isNull,
      );

      audio.emitCompletion(
        audio.sessionFor(_GeneratedBranchPracticeRepository.starterSource),
      );
      await tester.pump();
      final afterOldCompletion = tester.widget<Semantics>(
        find.byKey(const Key('care-turn-audio-error')),
      );
      expect(afterOldCompletion.properties.label, '正在播放音频…');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('care-turn-listen-once')),
            )
            .onPressed,
        isNull,
      );

      audio.emitCompletion(
        audio.sessionFor(_GeneratedBranchPracticeRepository.supportSource),
      );
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('care-turn-audio-error')))
            .properties
            .label,
        '已听过一次',
      );
      audio.complete(_GeneratedBranchPracticeRepository.starterSource);
      await tester.pump();
      expect(audio.playedSources, <CareAudioSource>[
        _GeneratedBranchPracticeRepository.supportSource,
      ]);
    },
  );

  testWidgets('replacing notifier cancels pending generated audio', (
    tester,
  ) async {
    final firstNotifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: _GeneratedBranchPracticeRepository(),
      ),
    );
    final replacementNotifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: _GeneratedBranchPracticeRepository(),
      ),
    );
    addTearDown(firstNotifier.dispose);
    addTearDown(replacementNotifier.dispose);
    await firstNotifier.startGeneratedMoment(
      generatedContentId: _GeneratedBranchPracticeRepository.generatedContentId,
    );
    await replacementNotifier.startGeneratedMoment(
      generatedContentId: _GeneratedBranchPracticeRepository.generatedContentId,
    );
    final audio = _DeferredCareAudioPlaybackController();
    await tester.pumpWidget(
      _generatedSurfaceTestApp(notifier: firstNotifier, audio: audio),
    );

    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await audio.requested(_GeneratedBranchPracticeRepository.starterSource);
    await tester.pumpWidget(
      _generatedSurfaceTestApp(notifier: replacementNotifier, audio: audio),
    );
    await tester.pump();

    expect(audio.stopCalls, 1);
    audio.complete(_GeneratedBranchPracticeRepository.starterSource);
    await tester.pump();
    expect(audio.playedSources, isEmpty);
  });

  testWidgets('surface ownership unregister keeps newer surface active', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final first = _ControllableCareAudioPlaybackController();
    final second = _ControllableCareAudioPlaybackController();

    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: first,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pumpWidget(
      KeyedSubtree(
        key: const Key('replacement-surface'),
        child: _surfaceTestApp(
          notifier: notifier,
          careAudio: second,
          careAudioSessionCoordinator: coordinator,
        ),
      ),
    );

    await coordinator.stopActive();

    expect(first.stopCalls, 1);
    expect(second.stopCalls, 1);
  });

  testWidgets('coordinator invalidation suppresses late surface completion', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final audio = _ControllableCareAudioPlaybackController();
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: audio,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();

    await coordinator.stopActive();
    audio.completeLastPlayback();
    await tester.pump();

    expect(find.text('已听过一次'), findsNothing);
  });

  testWidgets('ownership loss clears pause and blocks resume', (tester) async {
    final coordinator = CareAudioSessionCoordinator();
    final audio = _ControllableCareAudioPlaybackController();
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: audio,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-pause-audio')));
    await tester.pump();
    expect(find.byKey(const Key('care-turn-resume-audio')), findsOneWidget);

    await coordinator.stopActive();
    await tester.pump();

    expect(find.byKey(const Key('care-turn-resume-audio')), findsNothing);
    expect(find.byKey(const Key('care-turn-pause-audio')), findsNothing);
    expect(audio.resumeCalls, 0);
    expect(audio.requests, hasLength(1));
  });

  testWidgets('late pause success after ownership loss cannot restore resume', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final audio = _DeferredPauseCareAudioPlaybackController();
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: audio,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-pause-audio')));
    await audio.pauseStarted.future;

    await coordinator.stopActive();
    audio.finishPause.complete();
    await tester.pump();

    expect(find.byKey(const Key('care-turn-resume-audio')), findsNothing);
    expect(find.text('正在播放音频…'), findsNothing);
  });

  testWidgets('late resume error after ownership loss stays silent', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final audio = _DeferredResumeCareAudioPlaybackController(fail: true);
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: audio,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-pause-audio')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-resume-audio')));
    await audio.resumeStarted.future;

    await coordinator.stopActive();
    audio.finishResume.complete();
    await tester.pump();

    expect(find.text('音频暂时不可用'), findsNothing);
    expect(find.byKey(const Key('care-turn-resume-audio')), findsNothing);
  });

  testWidgets('care controller factory replacement disposes old owner', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final first = _ControllableCareAudioPlaybackController();
    final second = _ControllableCareAudioPlaybackController();

    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: first,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: second,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await coordinator.stopActive();
    for (var index = 0; index < 5 && first.disposeCalls == 0; index += 1) {
      await tester.pump();
    }

    expect(first.stopCalls, 1);
    expect(first.disposeCalls, 1);
    expect(second.stopCalls, 1);
    expect(second.disposeCalls, 0);
  });

  testWidgets('legacy audio factory replacement disposes old owner', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final first = _SilentPracticeAudioController();
    final second = _SilentPracticeAudioController();

    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        audioControllerFactory: () => first,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        audioControllerFactory: () => second,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await coordinator.stopActive();
    for (var index = 0; index < 5 && first.disposeCalls == 0; index += 1) {
      await tester.pump();
    }
    expect(first.stopCalls, 1);
    expect(first.disposeCalls, 1);
    expect(second.stopCalls, 1);
    expect(second.disposeCalls, 0);
  });

  testWidgets('replacement waits for old stop before new owner can play', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final first = _DeferredReplacementCareAudioPlaybackController();
    final second = _ControllableCareAudioPlaybackController();

    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: first,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: second,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await first.stopStarted.future;

    expect(first.disposeBeforeStop, isFalse);
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();
    expect(second.requests, isEmpty);

    first.finishStop.complete();
    await first.disposeFinished.future;
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('care-turn-listen-once')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();

    expect(first.disposeBeforeStop, isFalse);
    expect(second.requests, hasLength(1));
  });

  testWidgets('reused pending replacement controller remains current', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final first = _DeferredReplacementCareAudioPlaybackController();
    final reused = _ControllableCareAudioPlaybackController();

    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: first,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: reused,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await first.stopStarted.future;
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: reused,
        careAudioSessionCoordinator: coordinator,
      ),
    );

    first.finishStop.complete();
    await first.disposeFinished.future;
    await tester.pump();
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();

    expect(reused.disposeCalls, 0);
    expect(reused.requests, hasLength(1));
  });

  testWidgets('replacement waits for existing source stop barrier', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final replacementNotifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: _MemoryPracticeRepository(),
      ),
    );
    addTearDown(replacementNotifier.dispose);
    final first = _OrderedStopCareAudioPlaybackController();
    final second = _ControllableCareAudioPlaybackController();

    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await replacementNotifier.startMoment(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: first,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();

    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: replacementNotifier,
        careAudio: first,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await first.firstStopStarted.future;
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: replacementNotifier,
        careAudio: second,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pump();

    expect(first.secondStopStarted.isCompleted, isFalse);
    expect(first.disposeCalls, 0);
    first.finishFirstStop.complete();
    await first.secondStopStarted.future;
    expect(first.disposeCalls, 0);
    first.finishSecondStop.complete();
    for (var index = 0; index < 5 && first.disposeCalls == 0; index += 1) {
      await tester.pump();
    }

    expect(first.disposeCalls, 1);
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();
    expect(second.requests, hasLength(1));
  });

  testWidgets(
    'deferred source stop blocks all replacement factories until it settles',
    (tester) async {
      final coordinator = CareAudioSessionCoordinator();
      final replacementNotifier = CarePathNotifier(
        repository: CarePathRepository(
          practiceRepository: _MemoryPracticeRepository(),
        ),
      );
      addTearDown(replacementNotifier.dispose);
      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await replacementNotifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );

      final first = _OrderedStopCareAudioPlaybackController();
      var secondFactoryCalls = 0;
      var thirdFactoryCalls = 0;
      _ControllableCareAudioPlaybackController? third;
      CareAudioPlaybackController firstFactory() => first;
      CareAudioPlaybackController secondFactory() {
        secondFactoryCalls += 1;
        return _ControllableCareAudioPlaybackController();
      }

      CareAudioPlaybackController thirdFactory() {
        thirdFactoryCalls += 1;
        return third = _ControllableCareAudioPlaybackController();
      }

      await tester.pumpWidget(
        _surfaceTestApp(
          notifier: notifier,
          careAudioControllerFactory: firstFactory,
          careAudioSessionCoordinator: coordinator,
        ),
      );
      await tester.pumpWidget(
        _surfaceTestApp(
          notifier: replacementNotifier,
          careAudioControllerFactory: secondFactory,
          careAudioSessionCoordinator: coordinator,
        ),
      );
      await first.firstStopStarted.future;

      await tester.pumpWidget(
        _surfaceTestApp(
          notifier: replacementNotifier,
          careAudioControllerFactory: thirdFactory,
          careAudioSessionCoordinator: coordinator,
        ),
      );
      expect(first.disposeCalls, 0);
      expect(secondFactoryCalls, 0);
      expect(thirdFactoryCalls, 0);

      first.finishFirstStop.complete();
      for (
        var index = 0;
        index < 5 && !first.secondStopStarted.isCompleted;
        index += 1
      ) {
        await tester.pump();
      }
      expect(first.secondStopStarted.isCompleted, isTrue);
      expect(first.disposeCalls, 0);
      first.finishSecondStop.complete();
      for (var index = 0; index < 5 && thirdFactoryCalls == 0; index += 1) {
        await tester.pump();
      }

      expect(secondFactoryCalls, 0);
      expect(thirdFactoryCalls, 1);
      expect(third, isNotNull);
      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await tester.pump();
      expect(third!.requests, hasLength(1));
    },
  );

  testWidgets('A-B-C-B creates and attaches only latest B', (tester) async {
    final coordinator = CareAudioSessionCoordinator();
    final first = _DeferredReplacementCareAudioPlaybackController();
    final bControllers = <_ControllableCareAudioPlaybackController>[];
    final cControllers = <_ControllableCareAudioPlaybackController>[];
    CareAudioPlaybackController firstFactory() => first;
    CareAudioPlaybackController bFactory() {
      final controller = _ControllableCareAudioPlaybackController();
      bControllers.add(controller);
      return controller;
    }

    CareAudioPlaybackController cFactory() {
      final controller = _ControllableCareAudioPlaybackController();
      cControllers.add(controller);
      return controller;
    }

    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudioControllerFactory: firstFactory,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudioControllerFactory: bFactory,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await first.stopStarted.future;

    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudioControllerFactory: cFactory,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudioControllerFactory: bFactory,
        careAudioSessionCoordinator: coordinator,
      ),
    );

    expect(bControllers, isEmpty);
    expect(cControllers, isEmpty);
    first.finishStop.complete();
    await first.disposeFinished.future;
    for (var index = 0; index < 5 && bControllers.isEmpty; index += 1) {
      await tester.pump();
    }

    expect(bControllers, hasLength(1));
    expect(cControllers, isEmpty);
    expect(first.disposeCalls, 1);
    expect(bControllers.single.disposeCalls, 0);
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();
    expect(bControllers.single.requests, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    for (
      var index = 0;
      index < 5 && bControllers.single.disposeCalls == 0;
      index += 1
    ) {
      await tester.pump();
    }
    expect(bControllers.single.disposeCalls, 1);
    expect(
      cControllers.every((controller) => controller.disposeCalls <= 1),
      isTrue,
    );
  });

  testWidgets('late source-stop failure after ownership loss stays silent', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final replacementNotifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: _MemoryPracticeRepository(),
      ),
    );
    addTearDown(replacementNotifier.dispose);
    final audio = _DeferredStopFailureCareAudioPlaybackController();

    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await replacementNotifier.startMoment(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: audio,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pump();

    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: replacementNotifier,
        careAudio: audio,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await audio.stopStarted.future;
    final globalStop = coordinator.stopActive().catchError((_) {});
    audio.finishStop.complete();
    await globalStop;
    await tester.pump();

    expect(find.text('音频暂时不可用'), findsNothing);
    expect(find.byKey(const Key('care-turn-audio-error')), findsNothing);
  });

  testWidgets('late play failure after ownership loss stays silent', (
    tester,
  ) async {
    final coordinator = CareAudioSessionCoordinator();
    final audio = _LateFailureCareAudioPlaybackController();
    await tester.pumpWidget(
      _surfaceTestApp(
        notifier: notifier,
        careAudio: audio,
        careAudioSessionCoordinator: coordinator,
      ),
    );
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await audio.playStarted.future;

    await coordinator.stopActive();
    audio.finishPlay.complete();
    await tester.pump();

    expect(find.text('音频暂时不可用'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('failed stop blocks a new generated support playback', (
    tester,
  ) async {
    final generatedNotifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: _GeneratedBranchPracticeRepository(),
      ),
    );
    addTearDown(generatedNotifier.dispose);
    await generatedNotifier.startGeneratedMoment(
      generatedContentId: _GeneratedBranchPracticeRepository.generatedContentId,
    );
    final audio = _DeferredCareAudioPlaybackController(failStop: true);
    await tester.pumpWidget(
      _generatedSurfaceTestApp(notifier: generatedNotifier, audio: audio),
    );

    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await audio.requested(_GeneratedBranchPracticeRepository.starterSource);
    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
    await tester.pump();

    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('care-turn-audio-error')))
          .properties
          .label,
      '音频暂时不可用',
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('care-turn-listen-once')),
          )
          .onPressed,
      isNull,
    );
    expect(
      audio.wasRequested(_GeneratedBranchPracticeRepository.supportSource),
      isFalse,
    );

    audio.complete(_GeneratedBranchPracticeRepository.starterSource);
    await tester.pump();
    expect(audio.playedSources, <CareAudioSource>[
      _GeneratedBranchPracticeRepository.starterSource,
    ]);
  });

  testWidgets(
    'response-lost outcome preserves the phrase and selected reaction for retry',
    (tester) async {
      var retried = 0;
      final responseLostNotifier = CarePathNotifier(
        repository: CarePathRepository(
          practiceRepository: _MemoryPracticeRepository(),
          onReactionRecorded: (_) async {
            throw const CarePathResponseLostException();
          },
        ),
      );
      addTearDown(responseLostNotifier.dispose);
      await tester.pumpWidget(
        _surfaceTestApp(
          notifier: responseLostNotifier,
          onRetryReaction: () async => retried += 1,
        ),
      );

      await responseLostNotifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
      await tester.pump();

      expect(find.text('刚才的回应可能已经保存，正在确认。请再试一次。'), findsOneWidget);
      expect(find.text('Warm water.'), findsOneWidget);
      expect(find.text('已选：犹豫'), findsOneWidget);
      await tester.tap(find.byKey(const Key('care-turn-retry-reaction')));
      expect(retried, 1);
    },
  );

  testWidgets('confirmed fallback trace remains continuable', (tester) async {
    var continued = 0;
    final fallbackNotifier = CarePathNotifier(
      repository: _HeldReactionCarePathRepository(
        practiceRepository: _MemoryPracticeRepository(),
      ),
    );
    addTearDown(fallbackNotifier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CareTurnSurface(
            notifier: fallbackNotifier,
            audioControllerFactory: _SilentPracticeAudioController.new,
            onTraceContinue: () => continued += 1,
            traceContinueLabel: '继续',
          ),
        ),
      ),
    );

    await fallbackNotifier.startMoment(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('care-turn-trace-continue')));
    expect(continued, 1);
  });

  testWidgets(
    'semantic sort order follows the care-turn accessibility contract',
    (tester) async {
      await tester.pumpWidget(_surfaceTestApp(notifier: notifier));
      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();

      expect(_ordinalSortOrder(tester, 'care-turn-semantics-phrase'), 1);
      expect(_ordinalSortOrder(tester, 'care-turn-semantics-timing'), 3);
      expect(_ordinalSortOrder(tester, 'care-turn-semantics-actions'), 4);
      expect(_ordinalSortOrder(tester, 'care-turn-semantics-reaction'), 5);
      expect(_ordinalSortOrder(tester, 'care-turn-semantics-quiet-exit'), 6);
    },
  );

  testWidgets(
    'English and Chinese starter copy remain separate TalkBack focus nodes',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(_surfaceTestApp(notifier: notifier));
      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      await tester.pump();

      final englishNode = tester.getSemantics(
        find.byKey(const Key('care-turn-semantics-english')),
      );
      final chineseNode = tester.getSemantics(
        find.byKey(const Key('care-turn-semantics-chinese')),
      );

      expect(englishNode.label, 'Warm water.');
      expect(chineseNode.label, '温温的水。');
      expect(_ordinalSortOrder(tester, 'care-turn-semantics-english'), 1);
      expect(_ordinalSortOrder(tester, 'care-turn-semantics-chinese'), 2);
      semanticsHandle.dispose();
    },
  );

  testWidgets('care-turn title is visual only, not an extra TalkBack stop', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(_surfaceTestApp(notifier: notifier));
    await notifier.startMoment(spaceId: 'daily_care', activityId: 'bath_time');
    await tester.pump();

    final rootSemantics = tester.widget<Semantics>(
      find.byKey(const Key('care-turn-semantics-root')),
    );
    expect(rootSemantics.properties.label, isNull);
    expect(
      find.byKey(const Key('care-turn-appbar-title-exclude')),
      findsOneWidget,
    );
    semanticsHandle.dispose();
  });
}

double _ordinalSortOrder(WidgetTester tester, String key) {
  final semantics = tester.widget<Semantics>(find.byKey(Key(key)));
  return (semantics.properties.sortKey! as OrdinalSortKey).order;
}

Widget _surfaceTestApp({
  required CarePathNotifier notifier,
  CareTurnTraceReady? onTraceReady,
  CareTurnRetryReaction? onRetryReaction,
  CareAudioPlaybackController? careAudio,
  CareAudioPlaybackController Function()? careAudioControllerFactory,
  CareAudioSessionCoordinator? careAudioSessionCoordinator,
  PracticeAudioController Function()? audioControllerFactory,
  CareTurnAudioPlaybackPolicy playbackPolicy =
      CareTurnAudioPlaybackPolicy.disabled,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CareTurnSurface(
        notifier: notifier,
        audioControllerFactory:
            audioControllerFactory ?? _SilentPracticeAudioController.new,
        careAudioController: careAudioControllerFactory == null
            ? careAudio
            : null,
        careAudioControllerFactory: careAudioControllerFactory,
        careAudioSessionCoordinator: careAudioSessionCoordinator,
        playbackPolicy: playbackPolicy,
        onTraceReady: onTraceReady,
        onRetryReaction: onRetryReaction,
        onQuietExit: () {},
      ),
    ),
  );
}

Widget _generatedSurfaceTestApp({
  required CarePathNotifier notifier,
  required CareAudioPlaybackController audio,
  CareAudioSessionCoordinator? careAudioSessionCoordinator,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CareTurnSurface(
        notifier: notifier,
        careAudioController: audio,
        careAudioSessionCoordinator: careAudioSessionCoordinator,
      ),
    ),
  );
}

class _SilentPracticeAudioController implements PracticeAudioController {
  final StreamController<void> _completion = StreamController<void>.broadcast();
  int playCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<void> get completionStream => _completion.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    playCalls += 1;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _completion.close();
  }
}

class _FailingCareAudioPlaybackController
    implements CareAudioPlaybackController {
  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  int playCalls = 0;

  @override
  CareAudioPlaybackCapabilities get capabilities =>
      CareAudioPlaybackCapabilities.supported;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completion.stream;

  @override
  Future<void> dispose() => _completion.close();

  @override
  Future<void> play(CareAudioPlaybackRequest request) {
    playCalls += 1;
    return Future<void>.error(StateError('generated audio unavailable'));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}
}

class _HeldCareAudioPlaybackController implements CareAudioPlaybackController {
  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  final Completer<void> _playback = Completer<void>();

  @override
  CareAudioPlaybackCapabilities get capabilities =>
      CareAudioPlaybackCapabilities.supported;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completion.stream;

  void completePlayback() => _playback.complete();

  @override
  Future<void> dispose() => _completion.close();

  @override
  Future<void> play(CareAudioPlaybackRequest request) => _playback.future;

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}
}

class _DeferredCareAudioPlaybackController
    implements CareAudioPlaybackController {
  _DeferredCareAudioPlaybackController({this.failStop = false});

  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  final Map<CareAudioSource, Completer<void>> _requested =
      <CareAudioSource, Completer<void>>{};
  final Map<CareAudioSource, Completer<void>> _responses =
      <CareAudioSource, Completer<void>>{};
  final Map<CareAudioSource, int> _sessions = <CareAudioSource, int>{};
  final List<CareAudioSource> playedSources = <CareAudioSource>[];
  final bool failStop;
  int _generation = 0;
  int stopCalls = 0;

  @override
  CareAudioPlaybackCapabilities get capabilities =>
      CareAudioPlaybackCapabilities.supported;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completion.stream;

  Future<void> requested(CareAudioSource source) => _requestFor(source).future;

  bool wasRequested(CareAudioSource source) => _requested.containsKey(source);

  void complete(CareAudioSource source) => _responseFor(source).complete();

  int sessionFor(CareAudioSource source) => _sessions[source]!;

  void emitCompletion(int sessionId) {
    _completion.add(CareAudioPlaybackCompletion(sessionId: sessionId));
  }

  @override
  Future<void> dispose() => _completion.close();

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {
    final source = request.source;
    final generation = _generation;
    _sessions[source] = request.sessionId;
    _requestFor(source).complete();
    await _responseFor(source).future;
    if (generation == _generation) {
      playedSources.add(source);
    }
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (failStop) {
      throw StateError('native stop failed');
    }
    _generation += 1;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  Completer<void> _requestFor(CareAudioSource source) {
    return _requested.putIfAbsent(source, Completer<void>.new);
  }

  Completer<void> _responseFor(CareAudioSource source) {
    return _responses.putIfAbsent(source, Completer<void>.new);
  }
}

class _ControllableCareAudioPlaybackController
    implements CareAudioPlaybackController {
  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  final List<CareAudioPlaybackRequest> requests = <CareAudioPlaybackRequest>[];
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  CareAudioPlaybackCapabilities get capabilities =>
      CareAudioPlaybackCapabilities.supported;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completion.stream;

  void completeLastPlayback() {
    _completion.add(
      CareAudioPlaybackCompletion(sessionId: requests.last.sessionId),
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _completion.close();
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {
    requests.add(request);
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
  }

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

class _LateFailureCareAudioPlaybackController
    extends _ControllableCareAudioPlaybackController {
  final playStarted = Completer<void>();
  final finishPlay = Completer<void>();

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {
    requests.add(request);
    playStarted.complete();
    await finishPlay.future;
    throw StateError('late generated audio failure');
  }
}

class _DeferredPauseCareAudioPlaybackController
    extends _ControllableCareAudioPlaybackController {
  final pauseStarted = Completer<void>();
  final finishPause = Completer<void>();

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    pauseStarted.complete();
    await finishPause.future;
  }
}

class _DeferredResumeCareAudioPlaybackController
    extends _ControllableCareAudioPlaybackController {
  _DeferredResumeCareAudioPlaybackController({required this.fail});

  final bool fail;
  final resumeStarted = Completer<void>();
  final finishResume = Completer<void>();

  @override
  Future<void> resume() async {
    resumeCalls += 1;
    resumeStarted.complete();
    await finishResume.future;
    if (fail) {
      throw StateError('late resume failure');
    }
  }
}

class _DeferredReplacementCareAudioPlaybackController
    extends _ControllableCareAudioPlaybackController {
  final stopStarted = Completer<void>();
  final finishStop = Completer<void>();
  final disposeFinished = Completer<void>();
  bool stopCompleted = false;
  bool disposeBeforeStop = false;

  @override
  Future<void> stop() async {
    stopCalls += 1;
    stopStarted.complete();
    await finishStop.future;
    stopCompleted = true;
  }

  @override
  Future<void> dispose() async {
    disposeBeforeStop = !stopCompleted;
    await super.dispose();
    disposeFinished.complete();
  }
}

class _DeferredStopFailureCareAudioPlaybackController
    extends _ControllableCareAudioPlaybackController {
  final stopStarted = Completer<void>();
  final finishStop = Completer<void>();

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (!stopStarted.isCompleted) {
      stopStarted.complete();
    }
    await finishStop.future;
    throw StateError('late stop failure');
  }
}

class _OrderedStopCareAudioPlaybackController
    extends _ControllableCareAudioPlaybackController {
  final firstStopStarted = Completer<void>();
  final finishFirstStop = Completer<void>();
  final secondStopStarted = Completer<void>();
  final finishSecondStop = Completer<void>();

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (stopCalls == 1) {
      firstStopStarted.complete();
      await finishFirstStop.future;
      return;
    }
    secondStopStarted.complete();
    await finishSecondStop.future;
  }
}

class _GeneratedBranchPracticeRepository implements PracticeRepository {
  static const generatedContentId = 'generated_1';
  static const starterSource = GeneratedCareAudioSource(
    generatedContentId: generatedContentId,
    utteranceId: 'starter_1',
    safetyPolicyVersion: 'health-safety-v1',
    contentRefreshEpoch: 2,
  );
  static const supportSource = GeneratedCareAudioSource(
    generatedContentId: generatedContentId,
    utteranceId: 'support_cooperating_1',
    safetyPolicyVersion: 'health-safety-v1',
    contentRefreshEpoch: 2,
  );
  static const _activity = PracticeActivitySnapshot(
    spaceId: 'generated_space',
    activityId: 'generated_activity',
    title: '生成时刻',
    summary: '先回应宝宝。',
    sceneTag: 'generated',
    coachTip: '现在可以说。',
    contentSource: PracticeContentSource.generated,
    generatedContentId: generatedContentId,
    safetyPolicyVersion: 'health-safety-v1',
    contentRefreshEpoch: 2,
    phrases: <PracticePhrase>[
      PracticePhrase(
        spaceId: 'generated_space',
        activityId: 'generated_activity',
        phraseId: 'starter_phrase',
        step: 1,
        english: 'Starter.',
        chinese: '开场。',
        pronunciation: 'starter',
        difficulty: 'starter',
        audioAsset: '',
      ),
      PracticePhrase(
        spaceId: 'generated_space',
        activityId: 'generated_activity',
        phraseId: 'support_cooperating_phrase',
        step: 2,
        english: 'Support.',
        chinese: '支持。',
        pronunciation: 'support',
        difficulty: 'starter',
        audioAsset: '',
      ),
    ],
    utteranceIdsByPhraseId: <String, String>{
      'starter_phrase': 'starter_1',
      'support_cooperating_phrase': 'support_cooperating_1',
    },
    reactionSupportPhraseIds: <BabyReactionType, String>{
      BabyReactionType.cooperating: 'support_cooperating_phrase',
    },
  );

  @override
  Future<PracticeActivitySnapshot> getGeneratedActivitySnapshot({
    required String generatedContentId,
  }) async => _activity;

  @override
  Future<PracticeResumeInfo> getGeneratedResumeInfo({
    required String generatedContentId,
  }) async => const PracticeResumeInfo(
    activityId: 'generated_activity',
    totalPhrases: 2,
    completedPhraseIds: <String>[],
    nextPhraseId: 'starter_phrase',
    lastEventTime: null,
  );

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
  }) async => InteractionEventPayload(
    localEventId: localEventId ?? 'generated_trace',
    installationId: 'generated_surface_test',
    spaceId: spaceId,
    activityId: activityId,
    phraseId: phraseId,
    reactionType: reactionType,
    clientTimestamp: clientTimestamp ?? DateTime.utc(2026, 8, 9),
    generatedContentId: generatedContentId,
    utteranceId: utteranceId,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingReactionCarePathRepository extends CarePathRepository {
  _FailingReactionCarePathRepository({required super.practiceRepository});

  @override
  Future<CareTurnSnapshot> recordReaction({
    required CareTurnSnapshot turn,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) => Future<CareTurnSnapshot>.error(StateError('write failed'));
}

class _HeldReactionCarePathRepository extends CarePathRepository {
  _HeldReactionCarePathRepository({required super.practiceRepository});

  @override
  Future<CareTurnSnapshot> recordReaction({
    required CareTurnSnapshot turn,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async => turn.copyWith(
    phase: CareTurnPhase.heldWithFallback,
    selectedReaction: reactionType,
    traceEventKey: 'trace_held_fallback',
    message: '刚才这句话已经记下了。下一句暂时没有准备好，先这样就好。',
  );
}

class _MemoryPracticeRepository implements PracticeRepository {
  final List<InteractionEventPayload> _events = [];

  static const _activity = PracticeActivitySnapshot(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    title: '洗澡时间',
    summary: '温温的水。',
    sceneTag: 'Bath time',
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
        difficulty: 'easy',
        audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
      ),
      PracticePhrase(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_splash_splash',
        step: 2,
        english: 'Splash splash.',
        chinese: '扑通扑通。',
        pronunciation: 'splæʃ splæʃ',
        difficulty: 'easy',
        audioAsset: 'assets/audio/phrases/bath_time_splash_splash.mp3',
      ),
    ],
  );

  @override
  Future<PracticeActivityCatalog> getActivityCatalog() async {
    final completedPhraseIds = _events.map((event) => event.phraseId).toList();
    final nextPhrase = _nextPhrase(completedPhraseIds);
    return PracticeActivityCatalog(
      installationId: 'memory_surface_test',
      spaces: const [],
      activities: [
        PracticeCatalogActivitySummary(
          spaceId: _activity.spaceId,
          spaceTitle: '日常照护',
          activityId: _activity.activityId,
          title: _activity.title,
          summary: _activity.summary,
          sceneTag: _activity.sceneTag,
          coachTip: _activity.coachTip,
          totalPhraseCount: _activity.phrases.length,
          completedPhraseCount: completedPhraseIds.length,
          completedPhraseIds: completedPhraseIds,
          nextPhraseId: nextPhrase?.phraseId,
          nextPhraseEnglish: nextPhrase?.english,
          totalEvents: _events.length,
          skippedUnknownPhraseCount: 0,
          skippedMalformedEventCount: 0,
        ),
      ],
      totalStoredEvents: _events.length,
      validEvents: _events.length,
      knownEvents: _events.length,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
  }

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async => _activity;

  @override
  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async {
    final completedPhraseIds = _events.map((event) => event.phraseId).toList();
    final nextPhrase = _nextPhrase(completedPhraseIds);
    return PracticeResumeInfo(
      activityId: activityId,
      totalPhrases: _activity.phrases.length,
      completedPhraseIds: completedPhraseIds,
      nextPhraseId: nextPhrase?.phraseId,
      lastEventTime: _events.isEmpty ? null : _events.last.clientTimestamp,
    );
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
      localEventId: localEventId ?? 'surface_event_${_events.length + 1}',
      installationId: 'memory_surface_test',
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp ?? DateTime.utc(2026, 7, 24),
    );
    _events.add(event);
    return event;
  }

  PracticePhrase? _nextPhrase(List<String> completedPhraseIds) {
    for (final phrase in _activity.phrases) {
      if (!completedPhraseIds.contains(phrase.phraseId)) {
        return phrase;
      }
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
