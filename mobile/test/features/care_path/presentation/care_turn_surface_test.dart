import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
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
    'generated branch transition cancels a pre-mounted starter load',
    (tester) async {
      final generatedNotifier = CarePathNotifier(
        repository: _GeneratedBranchCarePathRepository(),
      );
      addTearDown(generatedNotifier.dispose);
      await generatedNotifier.startMoment(
        spaceId: 'generated_space',
        activityId: 'generated_activity',
      );
      final audio = _DeferredCareAudioPlaybackController();
      await tester.pumpWidget(
        _generatedSurfaceTestApp(notifier: generatedNotifier, audio: audio),
      );

      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await audio.requested(_GeneratedBranchCarePathRepository.starterSource);
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
      await tester.pump();

      expect(audio.stopCalls, 1);
      audio.complete(_GeneratedBranchCarePathRepository.starterSource);
      await tester.pump();
      expect(audio.playedSources, isEmpty);
    },
  );

  testWidgets(
    'stale completion cannot finish an already-playing generated support',
    (tester) async {
      final generatedNotifier = CarePathNotifier(
        repository: _GeneratedBranchCarePathRepository(),
      );
      addTearDown(generatedNotifier.dispose);
      await generatedNotifier.startMoment(
        spaceId: 'generated_space',
        activityId: 'generated_activity',
      );
      final audio = _DeferredCareAudioPlaybackController();
      await tester.pumpWidget(
        _generatedSurfaceTestApp(notifier: generatedNotifier, audio: audio),
      );

      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await audio.requested(_GeneratedBranchCarePathRepository.starterSource);
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-turn-listen-once')));
      await audio.requested(_GeneratedBranchCarePathRepository.supportSource);

      audio.complete(_GeneratedBranchCarePathRepository.supportSource);
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
        audio.sessionFor(_GeneratedBranchCarePathRepository.starterSource),
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
        audio.sessionFor(_GeneratedBranchCarePathRepository.supportSource),
      );
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('care-turn-audio-error')))
            .properties
            .label,
        '已听过一次',
      );
      audio.complete(_GeneratedBranchCarePathRepository.starterSource);
      await tester.pump();
      expect(audio.playedSources, <CareAudioSource>[
        _GeneratedBranchCarePathRepository.supportSource,
      ]);
    },
  );

  testWidgets('replacing notifier cancels pending generated audio', (
    tester,
  ) async {
    final firstNotifier = CarePathNotifier(
      repository: _GeneratedBranchCarePathRepository(),
    );
    final replacementNotifier = CarePathNotifier(
      repository: _GeneratedBranchCarePathRepository(),
    );
    addTearDown(firstNotifier.dispose);
    addTearDown(replacementNotifier.dispose);
    await firstNotifier.startMoment(
      spaceId: 'generated_space',
      activityId: 'generated_activity',
    );
    await replacementNotifier.startMoment(
      spaceId: 'generated_space',
      activityId: 'generated_activity',
    );
    final audio = _DeferredCareAudioPlaybackController();
    await tester.pumpWidget(
      _generatedSurfaceTestApp(notifier: firstNotifier, audio: audio),
    );

    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await audio.requested(_GeneratedBranchCarePathRepository.starterSource);
    await tester.pumpWidget(
      _generatedSurfaceTestApp(notifier: replacementNotifier, audio: audio),
    );
    await tester.pump();

    expect(audio.stopCalls, 1);
    audio.complete(_GeneratedBranchCarePathRepository.starterSource);
    await tester.pump();
    expect(audio.playedSources, isEmpty);
  });

  testWidgets('failed stop blocks a new generated support playback', (
    tester,
  ) async {
    final generatedNotifier = CarePathNotifier(
      repository: _GeneratedBranchCarePathRepository(),
    );
    addTearDown(generatedNotifier.dispose);
    await generatedNotifier.startMoment(
      spaceId: 'generated_space',
      activityId: 'generated_activity',
    );
    final audio = _DeferredCareAudioPlaybackController(failStop: true);
    await tester.pumpWidget(
      _generatedSurfaceTestApp(notifier: generatedNotifier, audio: audio),
    );

    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await audio.requested(_GeneratedBranchCarePathRepository.starterSource);
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
      audio.wasRequested(_GeneratedBranchCarePathRepository.supportSource),
      isFalse,
    );

    audio.complete(_GeneratedBranchCarePathRepository.starterSource);
    await tester.pump();
    expect(audio.playedSources, <CareAudioSource>[
      _GeneratedBranchCarePathRepository.starterSource,
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
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CareTurnSurface(
        notifier: notifier,
        audioControllerFactory: _SilentPracticeAudioController.new,
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
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CareTurnSurface(
        notifier: notifier,
        careAudioControllerFactory: () => audio,
      ),
    ),
  );
}

class _SilentPracticeAudioController implements PracticeAudioController {
  final StreamController<void> _completion = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _completion.stream;

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _completion.close();
}

class _FailingCareAudioPlaybackController
    implements CareAudioPlaybackController {
  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  int playCalls = 0;

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
}

class _HeldCareAudioPlaybackController implements CareAudioPlaybackController {
  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  final Completer<void> _playback = Completer<void>();

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

  Completer<void> _requestFor(CareAudioSource source) {
    return _requested.putIfAbsent(source, Completer<void>.new);
  }

  Completer<void> _responseFor(CareAudioSource source) {
    return _responses.putIfAbsent(source, Completer<void>.new);
  }
}

class _GeneratedBranchCarePathRepository extends CarePathRepository {
  _GeneratedBranchCarePathRepository()
    : super(practiceRepository: _MemoryPracticeRepository());

  static const starterSource = GeneratedCareAudioSource(
    generatedContentId: 'generated_1',
    utteranceId: 'starter_1',
  );
  static const supportSource = GeneratedCareAudioSource(
    generatedContentId: 'generated_1',
    utteranceId: 'support_cooperating_1',
  );
  static const _moment = CareMoment(
    spaceId: 'generated_space',
    activityId: 'generated_activity',
    spaceTitle: '生成照护',
    title: '生成时刻',
    sceneTag: 'generated',
    careActionLabel: '先回应宝宝。',
    coachTip: '现在可以说。',
    nodeState: CarePathNodeState.current,
    contentSource: PracticeContentSource.generated,
    generatedContentId: 'generated_1',
  );
  static const _starter = CareUtterance(
    phraseId: 'starter_phrase',
    english: 'Starter.',
    chinese: '开场。',
    pronunciation: 'starter',
    audioAsset: null,
    whenToSay: '现在可以说。',
    isFallback: false,
    audioSource: starterSource,
  );
  static const _support = CareUtterance(
    phraseId: 'support_cooperating_phrase',
    english: 'Support.',
    chinese: '支持。',
    pronunciation: 'support',
    audioAsset: null,
    whenToSay: '现在可以说。',
    isFallback: false,
    audioSource: supportSource,
  );

  @override
  Future<CareTurnSnapshot> startMoment({
    required String spaceId,
    required String activityId,
  }) async => const CareTurnSnapshot(
    moment: _moment,
    currentUtterance: _starter,
    selectedReaction: null,
    nextSupportUtterance: null,
    phase: CareTurnPhase.utteranceReady,
    traceEventKey: null,
    latestGardenImpact: null,
    message: null,
  );

  @override
  Future<CareTurnSnapshot> recordReaction({
    required CareTurnSnapshot turn,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async => turn.copyWith(
    currentUtterance: _support,
    selectedReaction: reactionType,
    nextSupportUtterance: _support,
    phase: CareTurnPhase.nextSupportReady,
    traceEventKey: 'generated_trace',
    message: null,
  );
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
