import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/care_path/presentation/widgets/care_turn_surface.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
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
