import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:mobile/features/care_entry/presentation/onboarding_conversation_controller.dart';
import 'package:mobile/features/care_entry/presentation/widgets/care_entry_entry_surface.dart';

void main() {
  testWidgets(
    'renders four entries, tile only selects, and primary CTA reveals exact first utterance',
    (tester) async {
      final repository = _MemoryConversationRepository();
      final scheduler = _ManualScheduler();
      final ids = <String>[
        'event.phrase_said.widget',
        'completion.widget',
        'completion.widget.retry',
      ];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => ids.removeAt(0),
      );
      final audioPlayer = _RecordingAudioPlayer();
      var todayExits = 0;
      var gardenExits = 0;
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      await tester.pumpWidget(
        MaterialApp(
          home: CareEntryEntrySurface(
            controller: controller,
            audioControllerFactory: () => audioPlayer,
            onToday: () => todayExits += 1,
            onGarden: () => gardenExits += 1,
          ),
        ),
      );

      expect(find.byKey(const Key('care-entry-grid')), findsOneWidget);
      expect(find.byType(CareEntryTile), findsNWidgets(4));
      expect(find.text("I'm right here."), findsNothing);
      expect(
        find.byKey(const Key('care-entry-primary-action')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('care-entry-tile-care.post_cry_soothing')),
      );
      await tester.pump();

      expect(controller.state.phase, OnboardingConversationPhase.selection);
      expect(controller.state.selectedEntryId?.value, 'care.post_cry_soothing');
      expect(find.text("I'm right here."), findsNothing);

      await tester.tap(find.byKey(const Key('care-entry-primary-action')));
      await tester.pump();

      expect(
        controller.state.phase,
        OnboardingConversationPhase.firstUtterance,
      );
      expect(find.text("I'm right here."), findsOneWidget);
      expect(find.text('我就在这里。'), findsOneWidget);
      expect(find.text('aɪm raɪt hɪr'), findsOneWidget);
      expect(
        find.byKey(const Key('care-entry-first-utterance-audio')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('care-entry-first-utterance-audio')),
      );
      await tester.pump();

      expect(audioPlayer.playedAssets, <String>['audio/phrases/test_3.mp3']);

      await tester.tap(find.byKey(const Key('care-entry-said-action')));
      await tester.pumpAndSettle();

      expect(repository.phraseSaidWrites, 1);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.reactionPrompt,
      );
      expect(
        find.byKey(const Key('care-entry-reaction-prompt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('care-entry-reaction-other-text')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('care-entry-reaction-other')));
      await tester.pump();

      expect(controller.state.selectedReaction, isNull);
      expect(
        find.byKey(const Key('care-entry-reaction-other-text')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('care-entry-reaction-hesitant')));
      await tester.pump();
      expect(find.byKey(const Key('care-entry-next-support')), findsNothing);

      scheduler.elapse(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-entry-next-support')), findsOneWidget);
      expect(find.text('Support hesitant.'), findsOneWidget);
      expect(find.text('继续说下去'), findsOneWidget);
      expect(find.text('今天先到这里'), findsOneWidget);

      repository.failNextCompletion = true;
      await tester.tap(find.byKey(const Key('care-entry-finish-today-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('care-entry-garden-trace')), findsNothing);
      expect(todayExits, 0);
      expect(gardenExits, 0);

      await tester.tap(find.byKey(const Key('care-entry-finish-today-action')));
      await tester.pumpAndSettle();

      expect(repository.completionWrites, 1);
      expect(find.byKey(const Key('care-entry-garden-trace')), findsOneWidget);
      expect(find.text('第一句已经留在你的小花园里。'), findsOneWidget);
      expect(find.textContaining('宝宝'), findsOneWidget);
      expect(find.text('开始今天的小时间'), findsOneWidget);
      expect(find.text('看看花园'), findsOneWidget);
      await tester.tap(find.byKey(const Key('care-entry-open-today-action')));
      await tester.tap(find.byKey(const Key('care-entry-open-garden-action')));
      expect(todayExits, 1);
      expect(gardenExits, 1);
    },
  );

  testWidgets(
    'remote playback failure degrades gently and keeps said enabled',
    (tester) async {
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: _MemoryConversationRepository(),
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'request.remote.audio',
        conversationGateway: _ImmediateConversationGateway(),
        installationIdLoader: () async => 'install-test-1234',
      );
      final audioPlayer = _FailingAudioPlayer();
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();

      await tester.pumpWidget(
        MaterialApp(
          home: CareEntryEntrySurface(
            controller: controller,
            audioControllerFactory: () => audioPlayer,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('care-entry-first-utterance-audio')),
      );
      await tester.pumpAndSettle();

      expect(find.text('今天先看着读也可以。'), findsOneWidget);
      final said = tester.widget<FilledButton>(
        find.byKey(const Key('care-entry-said-action')),
      );
      expect(said.onPressed, isNotNull);
      expect(audioPlayer.conversationId, 'onbc_remote_1');
      expect(audioPlayer.utteranceId, 'utterance-remote-1');
    },
  );

  testWidgets('leaving first utterance stops in-flight audio', (tester) async {
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: _MemoryConversationRepository(),
      scheduler: _ManualScheduler(),
      clock: () => DateTime.utc(2026, 8, 14, 12),
      idGenerator: () => 'event.audio.stop',
    );
    final audioPlayer = _BlockingAudioPlayer();
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
    await controller.startSelected();

    await tester.pumpWidget(
      MaterialApp(
        home: CareEntryEntrySurface(
          controller: controller,
          audioControllerFactory: () => audioPlayer,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('care-entry-first-utterance-audio')));
    await tester.pump();
    expect(audioPlayer.playStarted, isTrue);

    await tester.tap(find.byKey(const Key('care-entry-said-action')));
    await tester.pump();

    expect(audioPlayer.stopCalls, 1);
    expect(controller.state.phase, OnboardingConversationPhase.reactionPrompt);
    audioPlayer.completePlay();
    await tester.pump();
  });

  testWidgets('defer navigates only after the checkpoint is durable', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository();
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: repository,
      scheduler: _ManualScheduler(),
      clock: () => DateTime.utc(2026, 8, 14, 20),
      idGenerator: () => 'defer-widget-1',
      visibleSlots: 4,
    );
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
    var exits = 0;
    repository.failNextDefer = true;

    await tester.pumpWidget(
      MaterialApp(
        home: CareEntryEntrySurface(
          controller: controller,
          onDefer: () async {
            if (await controller.defer()) exits += 1;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('care-entry-defer-action')));
    await tester.pumpAndSettle();
    expect(exits, 0);
    expect(repository.snapshot?.status, OnboardingConversationStatus.active);

    await tester.tap(find.byKey(const Key('care-entry-defer-action')));
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(repository.snapshot?.status, OnboardingConversationStatus.deferred);
  });
}

final class _MemoryConversationRepository
    implements OnboardingConversationRepository {
  OnboardingConversationSnapshot? snapshot;
  int phraseSaidWrites = 0;
  int completionWrites = 0;
  bool failNextDefer = false;
  bool failNextCompletion = false;

  @override
  Future<OnboardingConversationSnapshot?> read() async => snapshot;

  @override
  Future<OnboardingConversationSnapshot> save(
    OnboardingConversationSnapshot checkpoint,
  ) async => snapshot = checkpoint;

  @override
  Future<OnboardingConversationSnapshot?> saveNextSupport(
    OnboardingConversationSnapshot checkpoint, {
    required bool Function() commitIfCurrent,
  }) async => commitIfCurrent() ? snapshot = checkpoint : snapshot;

  @override
  Future<OnboardingConversationSnapshot> defer({
    required OnboardingConversationSnapshot checkpoint,
    required DateTime deferredAt,
  }) async {
    if (failNextDefer) {
      failNextDefer = false;
      throw StateError('simulated defer failure');
    }
    return snapshot = checkpoint.copyWith(
      status: OnboardingConversationStatus.deferred,
      deferredAt: deferredAt,
    );
  }

  @override
  Future<OnboardingConversationSnapshot> recordPhraseSaid({
    required OnboardingConversationSnapshot checkpoint,
    required String eventId,
    required DateTime occurredAt,
  }) async {
    phraseSaidWrites += 1;
    return snapshot = checkpoint.copyWith(
      phase: OnboardingCheckpointPhase.reactionPrompt,
      phraseSaidEventId: eventId,
      phraseSaidAt: occurredAt,
    );
  }

  @override
  Future<OnboardingConversationSnapshot> complete({
    required OnboardingConversationSnapshot checkpoint,
    required String completionId,
    required DateTime completedAt,
  }) async {
    if (failNextCompletion) {
      failNextCompletion = false;
      throw StateError('simulated completion failure');
    }
    final existing = snapshot;
    if (existing?.completionId != null) return existing!;
    completionWrites += 1;
    return snapshot = checkpoint.copyWith(
      status: OnboardingConversationStatus.completed,
      phase: OnboardingCheckpointPhase.completed,
      completionId: completionId,
      gardenTraceId: checkpoint.phraseSaidEventId,
      completedAt: completedAt,
      deferredAt: null,
    );
  }
}

final class _ManualScheduler implements OnboardingDelayScheduler {
  final List<_ManualScheduledTask> _tasks = <_ManualScheduledTask>[];

  @override
  OnboardingScheduledTask schedule(Duration delay, void Function() action) {
    final task = _ManualScheduledTask(delay, action);
    _tasks.add(task);
    return task;
  }

  void elapse(Duration duration) {
    for (final task in List<_ManualScheduledTask>.from(_tasks)) {
      task.elapse(duration);
    }
    _tasks.removeWhere((task) => !task.isActive);
  }
}

final class _ManualScheduledTask implements OnboardingScheduledTask {
  _ManualScheduledTask(this._remaining, this._action);

  Duration _remaining;
  final void Function() _action;
  bool isActive = true;

  void elapse(Duration duration) {
    if (!isActive) return;
    _remaining -= duration;
    if (_remaining <= Duration.zero) {
      isActive = false;
      _action();
    }
  }

  @override
  void cancel() => isActive = false;
}

final class _RecordingAudioPlayer implements CareEntryAudioPlayer {
  final List<String> playedAssets = <String>[];

  @override
  Future<void> play({
    required OnboardingUtterance utterance,
    required String? conversationId,
  }) async {
    playedAssets.add(utterance.localAudioAsset!.replaceFirst('assets/', ''));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _FailingAudioPlayer implements CareEntryAudioPlayer {
  String? conversationId;
  String? utteranceId;

  @override
  Future<void> play({
    required OnboardingUtterance utterance,
    required String? conversationId,
  }) async {
    this.conversationId = conversationId;
    utteranceId = utterance.utteranceId;
    throw StateError('simulated audio failure');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _BlockingAudioPlayer implements CareEntryAudioPlayer {
  final Completer<void> _play = Completer<void>();
  bool playStarted = false;
  int stopCalls = 0;

  void completePlay() => _play.complete();

  @override
  Future<void> play({
    required OnboardingUtterance utterance,
    required String? conversationId,
  }) {
    playStarted = true;
    return _play.future;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    throw StateError('simulated stop failure');
  }

  @override
  Future<void> dispose() async {}
}

final class _ImmediateConversationGateway
    implements GuestOnboardingConversationGateway {
  @override
  Future<GuestOnboardingConversation> create(
    CreateGuestOnboardingConversation request,
  ) async => GuestOnboardingConversation(
    conversationId: 'onbc_remote_1',
    expiresAt: DateTime.utc(2026, 8, 15),
    utterance: const OnboardingUtterance(
      utteranceId: 'utterance-remote-1',
      english: 'Remote hello.',
      chinese: '远端首句。',
      pronunciation: 'remote',
      source: OnboardingUtteranceSource.remoteGenerated,
      remoteAudioAvailable: true,
    ),
  );

  @override
  Future<GuestOnboardingConversation> nextSupport(
    NextGuestOnboardingTurn request,
  ) async => throw StateError('not used');
}

final class _MemoryRegistry implements CareEntryRegistry {
  const _MemoryRegistry(this.resolution);

  final CareEntryResolution resolution;

  @override
  Future<CareEntryResolution> resolve({
    required CareEntryPlacementId placement,
    required int visibleSlots,
    required DateTime localTime,
  }) async => resolution;
}

CareEntryResolution _resolution() {
  final entries = <ResolvedCareEntry>[
    _entry(
      id: 'care.bedtime_soothing',
      title: '哄睡中',
      english: 'Time to sleep.',
      chinese: '该睡觉啦。',
      pronunciation: 'taɪm tə sliːp',
      visualToken: 'route.moon',
      order: 1,
      recommended: true,
    ),
    _entry(
      id: 'care.feeding_now',
      title: '正在喂奶',
      english: 'Open wide.',
      chinese: '张大嘴巴。',
      pronunciation: 'ˈoʊ.pən waɪd',
      visualToken: 'route.bottle',
      order: 2,
      recommended: false,
    ),
    _entry(
      id: 'care.post_cry_soothing',
      title: '宝宝刚哭过',
      english: "I'm right here.",
      chinese: '我就在这里。',
      pronunciation: 'aɪm raɪt hɪr',
      visualToken: 'route.soothing',
      order: 3,
      recommended: false,
    ),
    _entry(
      id: 'care.diaper_change',
      title: '换尿布',
      english: 'Clean bottom.',
      chinese: '擦干净屁屁。',
      pronunciation: 'kliːn ˈbɑː.t̬əm',
      visualToken: 'route.diaper',
      order: 4,
      recommended: false,
    ),
  ];
  return CareEntryResolution(
    schemaVersion: 1,
    revision: 'test.1',
    placement: const CareEntryPlacementId('onboarding.primary'),
    entries: entries,
    recommendedEntryId: entries.first.id,
  );
}

ResolvedCareEntry _entry({
  required String id,
  required String title,
  required String english,
  required String chinese,
  required String pronunciation,
  required String visualToken,
  required int order,
  required bool recommended,
}) {
  return ResolvedCareEntry(
    id: CareEntryId(id),
    title: title,
    subtitle: '现在就能说',
    visualToken: visualToken,
    order: order,
    isRecommended: recommended,
    seed: CareMomentSeed(
      generationRef: GenerationSceneRef(
        id: GenerationSceneId('generation.$order'),
        namespace: 'babytalk.care',
        key: 'scene_$order',
        version: 1,
        facets: const <String, String>{'parentTonePreference': 'short_gentle'},
      ),
      fallback: CatalogFallbackRef(
        id: CatalogFallbackId('fallback.$order'),
        spaceId: 'space',
        activityId: 'activity',
        phraseId: 'phrase_$order',
      ),
      firstUtterance: CareFirstUtterance(
        english: english,
        chinese: chinese,
        pronunciation: pronunciation,
        audioAsset: 'assets/audio/phrases/test_$order.mp3',
        audioReview: AudioReview.reviewed,
      ),
      nextSupports: CareLocalNextSupportSet(
        whenAbsent: CareNextSupportUtterance(
          id: CareSupportId('support.$order.absent'),
          english: 'Support absent.',
          chinese: '没有选择也可以。',
        ),
        byReaction: <CareReaction, CareNextSupportUtterance>{
          for (final reaction in CareReaction.values)
            reaction: CareNextSupportUtterance(
              id: CareSupportId('support.$order.${reaction.wireValue}'),
              english: 'Support ${reaction.wireValue}.',
              chinese: '接住这一刻。',
            ),
        },
      ),
    ),
  );
}
