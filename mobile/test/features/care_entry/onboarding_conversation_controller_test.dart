import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:mobile/features/care_entry/presentation/onboarding_conversation_controller.dart';

void main() {
  test('remote first utterance wins before the four-second deadline', () async {
    final scheduler = _ManualScheduler();
    final gateway = _HeldConversationGateway();
    final repository = _MemoryConversationRepository();
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime(2026, 8, 14, 20),
      idGenerator: () => 'request-1234',
      conversationGateway: gateway,
      installationIdLoader: () async => 'install-test-1234',
      visibleSlots: 1,
    );
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

    final pending = controller.startSelected();
    await Future<void>.delayed(Duration.zero);
    expect(
      controller.state.phase,
      OnboardingConversationPhase.resolvingFirstUtterance,
    );
    gateway.complete(_remoteConversation('Remote hello.'));
    await pending;

    expect(controller.state.phase, OnboardingConversationPhase.firstUtterance);
    expect(controller.state.activeUtterance?.english, 'Remote hello.');
    expect(controller.state.conversationId, 'conversation-1');
    expect(
      controller.state.activeUtterance?.source,
      OnboardingUtteranceSource.remoteGenerated,
    );
    expect(gateway.request?.localEventId, 'onboarding-request-1234');
    expect(
      repository.snapshot?.conversationRequestEventId,
      'onboarding-request-1234',
    );
    expect(gateway.request?.generationScene.key, 'bedtime');
  });

  test(
    'four-second local fallback is sticky against a late response',
    () async {
      final scheduler = _ManualScheduler();
      final gateway = _HeldConversationGateway();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: _MemoryConversationRepository(),
        scheduler: scheduler,
        clock: () => DateTime(2026, 8, 14, 20),
        idGenerator: () => 'request-1234',
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-test-1234',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      final pending = controller.startSelected();
      await Future<void>.delayed(Duration.zero);
      scheduler.elapse(const Duration(seconds: 4));
      await pending;
      expect(controller.state.activeUtterance?.english, 'Time to sleep.');
      expect(
        controller.state.activeUtterance?.source,
        OnboardingUtteranceSource.localFallback,
      );

      gateway.complete(_remoteConversation('Too late.'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.activeUtterance?.english, 'Time to sleep.');
    },
  );

  test(
    'network waits for durable request identity and timeout remains local',
    () async {
      final scheduler = _ManualScheduler();
      final gateway = _HeldConversationGateway();
      final repository = _MemoryConversationRepository();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime(2026, 8, 14, 20),
        idGenerator: () => 'request-1234',
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-test-1234',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      final blockedSave = repository.holdNextSave();
      final pending = controller.startSelected();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.request, isNull);
      blockedSave.release();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.request?.localEventId, 'onboarding-request-1234');
      scheduler.elapse(const Duration(seconds: 4));
      await pending;

      expect(controller.state.activeUtterance?.english, 'Time to sleep.');
      expect(
        controller.state.activeUtterance?.source,
        OnboardingUtteranceSource.localFallback,
      );
      gateway.complete(_remoteConversation('Too late after timeout.'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.activeUtterance?.english, 'Time to sleep.');
    },
  );

  test('concurrent starts reuse one durable request and one future', () async {
    final repository = _MemoryConversationRepository();
    final gateway = _HeldConversationGateway();
    var generatedIds = 0;
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: repository,
      scheduler: _ManualScheduler(),
      clock: () => DateTime(2026, 8, 14, 20),
      idGenerator: () => 'request-${++generatedIds}',
      conversationGateway: gateway,
      installationIdLoader: () async => 'install-test-1234',
      visibleSlots: 1,
    );
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

    final blockedSave = repository.holdNextSave();
    final first = controller.startSelected();
    final second = controller.startSelected();

    expect(identical(first, second), isTrue);
    expect(
      controller.state.phase,
      OnboardingConversationPhase.resolvingFirstUtterance,
    );
    expect(generatedIds, 1);

    blockedSave.release();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    gateway.complete(_remoteConversation('Only once.'));
    await Future.wait(<Future<void>>[first, second]);

    expect(gateway.calls, 1);
    expect(gateway.request?.localEventId, 'onboarding-request-1');
  });

  test('dispose completes a pending first utterance race', () async {
    final gateway = _HeldConversationGateway();
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: _MemoryConversationRepository(),
      scheduler: _ManualScheduler(),
      clock: () => DateTime(2026, 8, 14, 20),
      idGenerator: () => 'request-1234',
      conversationGateway: gateway,
      installationIdLoader: () async => 'install-test-1234',
      visibleSlots: 1,
    );
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

    final pending = controller.startSelected();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();

    await pending.timeout(const Duration(seconds: 1));
    expect(gateway.calls, 1);
  });

  test('selection transitions stay retryable when persistence fails', () async {
    final repository = _MemoryConversationRepository();
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: repository,
      scheduler: _ManualScheduler(),
      clock: () => DateTime.utc(2026, 8, 14, 12),
      idGenerator: () => 'unused',
      visibleSlots: 1,
    );
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

    repository.failNextSave = true;
    await controller.startSelected();

    expect(controller.state.phase, OnboardingConversationPhase.selection);
    expect(controller.state.activeEntry, isNull);
    expect(controller.state.errorMessage, '这一刻还没保存好，请再试一次。');
  });

  test(
    'markPhraseSaid persists before reaction controls become observable',
    () async {
      final repository = _MemoryConversationRepository();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'event.phrase_said.1',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);

      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();

      final write = repository.holdPhraseSaidWrite();
      final pending = controller.markPhraseSaid();

      expect(
        controller.state.phase,
        OnboardingConversationPhase.savingPhraseSaid,
      );
      expect(controller.state.phraseSaidEventId, isNull);

      write.release();
      await pending;

      expect(repository.phraseSaidWrites, 1);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.reactionPrompt,
      );
      expect(controller.state.phraseSaidEventId, 'event.phrase_said.1');
    },
  );

  test(
    'canonical reaction advances to its local support after 500 ms',
    () async {
      final repository = _MemoryConversationRepository();
      final scheduler = _ManualScheduler();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'event.phrase_said.1',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);

      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();
      await controller.markPhraseSaid();
      await controller.selectReaction(CareReaction.hesitant);

      expect(
        controller.state.phase,
        OnboardingConversationPhase.reactionPrompt,
      );
      expect(controller.state.selectedReaction, CareReaction.hesitant);
      expect(controller.state.nextSupport, isNull);

      scheduler.elapse(const Duration(milliseconds: 499));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.reactionPrompt,
      );

      scheduler.elapse(const Duration(milliseconds: 1));
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.phase,
        OnboardingConversationPhase.nextSupportReady,
      );
      expect(
        controller.state.nextSupport?.id.value,
        'support.bedtime.hesitant',
      );
    },
  );

  test(
    'latest reaction wins when persistence completes out of order',
    () async {
      final repository = _MemoryConversationRepository();
      final scheduler = _ManualScheduler();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'event.phrase_said.concurrent',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();
      await controller.markPhraseSaid();

      final firstWrite = repository.holdNextSave();
      final secondWrite = repository.holdNextSave();
      final first = controller.selectReaction(CareReaction.cooperating);
      final second = controller.selectReaction(CareReaction.hesitant);

      firstWrite.release();
      await first;
      expect(scheduler.activeTaskCount, 1);

      secondWrite.release();
      await second;
      expect(scheduler.activeTaskCount, 1);
      scheduler.elapse(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.selectedReaction, CareReaction.hesitant);
      expect(
        controller.state.nextSupport?.id.value,
        'support.bedtime.hesitant',
      );
    },
  );

  test(
    'reaction delay starts at intent while persistence remains durable',
    () async {
      final repository = _MemoryConversationRepository();
      final scheduler = _ManualScheduler();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'event.phrase_said.delayed',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();
      await controller.markPhraseSaid();

      final write = repository.holdNextSave();
      final pending = controller.selectReaction(CareReaction.hesitant);
      scheduler.elapse(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.phase,
        OnboardingConversationPhase.reactionPrompt,
      );
      expect(controller.state.nextSupport, isNull);

      write.release();
      await pending;

      expect(
        controller.state.phase,
        OnboardingConversationPhase.nextSupportReady,
      );
      expect(
        controller.state.nextSupport?.id.value,
        'support.bedtime.hesitant',
      );
    },
  );

  test(
    'reaction absence advances after four seconds without inventing a value',
    () async {
      final repository = _MemoryConversationRepository();
      final scheduler = _ManualScheduler();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'event.phrase_said.1',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);

      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();
      await controller.markPhraseSaid();

      scheduler.elapse(const Duration(milliseconds: 3999));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.reactionPrompt,
      );

      scheduler.elapse(const Duration(milliseconds: 1));
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.phase,
        OnboardingConversationPhase.nextSupportReady,
      );
      expect(controller.state.selectedReaction, isNull);
      expect(controller.state.nextSupport?.id.value, 'support.bedtime.absent');
      expect(repository.snapshot?.selectedReaction, isNull);
    },
  );

  test('manual next advances immediately with reaction absent', () async {
    final repository = _MemoryConversationRepository();
    final scheduler = _ManualScheduler();
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: repository,
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 8, 14, 12),
      idGenerator: () => 'event.phrase_said.1',
      visibleSlots: 1,
    );
    addTearDown(controller.dispose);

    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
    await controller.startSelected();
    await controller.markPhraseSaid();
    await controller.continueWithoutReaction();

    expect(
      controller.state.phase,
      OnboardingConversationPhase.nextSupportReady,
    );
    expect(controller.state.selectedReaction, isNull);
    expect(controller.state.nextSupport?.id.value, 'support.bedtime.absent');

    scheduler.elapse(const Duration(seconds: 4));
    await Future<void>.delayed(Duration.zero);
    expect(repository.snapshot?.nextSupportId?.value, 'support.bedtime.absent');
  });

  test(
    'five reactions work and private text is accepted only for other',
    () async {
      for (final reaction in CareReaction.values) {
        final repository = _MemoryConversationRepository();
        final scheduler = _ManualScheduler();
        final controller = OnboardingConversationController(
          registry: _MemoryRegistry(_resolution()),
          repository: repository,
          scheduler: scheduler,
          clock: () => DateTime.utc(2026, 8, 14, 12),
          idGenerator: () => 'event.phrase_said.${reaction.wireValue}',
          visibleSlots: 1,
        );
        addTearDown(controller.dispose);
        await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
        await controller.startSelected();
        await controller.markPhraseSaid();

        await controller.selectReaction(
          reaction,
          otherText: reaction == CareReaction.other ? '刚才有点打喷嚏' : null,
        );
        scheduler.elapse(const Duration(milliseconds: 500));
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.selectedReaction, reaction);
        expect(
          controller.state.nextSupport?.id.value,
          'support.bedtime.${reaction.wireValue}',
        );
        expect(repository.snapshot?.selectedReaction, reaction);
      }

      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: _MemoryConversationRepository(),
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'event.phrase_said.invalid_text',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();
      await controller.markPhraseSaid();

      expect(
        controller.selectReaction(CareReaction.cooperating, otherText: '不应保存'),
        throwsArgumentError,
      );
      expect(
        controller.selectReaction(
          CareReaction.other,
          otherText: List<String>.filled(201, 'x').join(),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'terminal completion publishes one Garden Trace only after durable write',
    () async {
      final repository = _MemoryConversationRepository();
      final ids = <String>['event.phrase_said.1', 'completion.1'];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => ids.removeAt(0),
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);

      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();
      await controller.markPhraseSaid();
      await controller.continueWithoutReaction();

      final write = repository.holdCompletionWrite();
      final pending = controller.complete();

      expect(controller.state.phase, OnboardingConversationPhase.completing);
      expect(controller.state.gardenTraceId, isNull);

      write.release();
      await pending;

      expect(controller.state.phase, OnboardingConversationPhase.completed);
      expect(controller.state.gardenTraceId, 'event.phrase_said.1');
      expect(repository.completionWrites, 1);

      await controller.complete();
      expect(repository.completionWrites, 1);
      expect(controller.state.gardenTraceId, 'event.phrase_said.1');
      expect(
        repository.snapshot?.gardenTrace?.careEntryId.value,
        'care.bedtime_soothing',
      );
    },
  );

  test(
    'restored reaction prompt resumes the four-second absent path',
    () async {
      final repository = _MemoryConversationRepository()
        ..snapshot = OnboardingConversationSnapshot(
          registryRevision: 'test.1',
          phase: OnboardingCheckpointPhase.reactionPrompt,
          selectedEntryId: const CareEntryId('care.bedtime_soothing'),
          activeEntryId: const CareEntryId('care.bedtime_soothing'),
          phraseSaidEventId: 'event.phrase_said.restored',
          phraseSaidAt: DateTime.utc(2026, 8, 14, 11),
        );
      final scheduler = _ManualScheduler();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'unused',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);

      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      expect(
        controller.state.phase,
        OnboardingConversationPhase.reactionPrompt,
      );

      scheduler.elapse(const Duration(seconds: 4));
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.phase,
        OnboardingConversationPhase.nextSupportReady,
      );
      expect(controller.state.nextSupport?.id.value, 'support.bedtime.absent');
    },
  );

  test('snapshot v2 restores every durable local checkpoint', () async {
    final occurredAt = DateTime.utc(2026, 8, 14, 11);
    final completedAt = DateTime.utc(2026, 8, 14, 12);
    final checkpoints = <OnboardingConversationSnapshot>[
      const OnboardingConversationSnapshot(
        registryRevision: 'test.1',
        phase: OnboardingCheckpointPhase.selection,
        selectedEntryId: CareEntryId('care.bedtime_soothing'),
      ),
      const OnboardingConversationSnapshot(
        registryRevision: 'test.1',
        phase: OnboardingCheckpointPhase.firstUtterance,
        selectedEntryId: CareEntryId('care.bedtime_soothing'),
        activeEntryId: CareEntryId('care.bedtime_soothing'),
      ),
      OnboardingConversationSnapshot(
        registryRevision: 'test.1',
        phase: OnboardingCheckpointPhase.nextSupportReady,
        selectedEntryId: const CareEntryId('care.bedtime_soothing'),
        activeEntryId: const CareEntryId('care.bedtime_soothing'),
        phraseSaidEventId: 'event.phrase_said.restored',
        phraseSaidAt: occurredAt,
        selectedReaction: CareReaction.hesitant,
        nextSupportId: const CareSupportId('support.bedtime.hesitant'),
      ),
      OnboardingConversationSnapshot(
        registryRevision: 'test.1',
        phase: OnboardingCheckpointPhase.completed,
        selectedEntryId: const CareEntryId('care.bedtime_soothing'),
        activeEntryId: const CareEntryId('care.bedtime_soothing'),
        phraseSaidEventId: 'event.phrase_said.restored',
        phraseSaidAt: occurredAt,
        nextSupportId: const CareSupportId('support.bedtime.absent'),
        completionId: 'completion.restored',
        gardenTraceId: 'event.phrase_said.restored',
        completedAt: completedAt,
      ),
    ];

    for (final checkpoint in checkpoints) {
      final repository = _MemoryConversationRepository()..snapshot = checkpoint;
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: _ManualScheduler(),
        clock: () => completedAt,
        idGenerator: () => 'unused',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);

      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      expect(controller.state.phase.name, checkpoint.phase.name);
      expect(controller.state.activeEntry?.id, checkpoint.activeEntryId);
      expect(controller.state.nextSupport?.id, checkpoint.nextSupportId);
      expect(controller.state.gardenTraceId, checkpoint.gardenTraceId);
    }
  });
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

final class _HeldConversationGateway
    implements GuestOnboardingConversationGateway {
  final Completer<GuestOnboardingConversation> _response = Completer();
  CreateGuestOnboardingConversation? request;
  int calls = 0;

  @override
  Future<GuestOnboardingConversation> create(
    CreateGuestOnboardingConversation request,
  ) {
    calls += 1;
    this.request = request;
    return _response.future;
  }

  void complete(GuestOnboardingConversation value) => _response.complete(value);
}

GuestOnboardingConversation _remoteConversation(String english) =>
    GuestOnboardingConversation(
      conversationId: 'conversation-1',
      expiresAt: DateTime.utc(2026, 8, 15, 12),
      utterance: OnboardingUtterance(
        utteranceId: 'utterance-remote-1',
        english: english,
        chinese: '远端首句。',
        pronunciation: 'remote',
        source: OnboardingUtteranceSource.remoteGenerated,
      ),
    );

final class _MemoryConversationRepository
    implements OnboardingConversationRepository {
  OnboardingConversationSnapshot? snapshot;
  int phraseSaidWrites = 0;
  int completionWrites = 0;
  bool failNextSave = false;
  _HeldWrite? _heldWrite;
  _HeldWrite? _heldCompletionWrite;
  final List<_HeldWrite> _heldSaves = <_HeldWrite>[];

  _HeldWrite holdPhraseSaidWrite() => _heldWrite = _HeldWrite();

  _HeldWrite holdCompletionWrite() => _heldCompletionWrite = _HeldWrite();

  _HeldWrite holdNextSave() {
    final write = _HeldWrite();
    _heldSaves.add(write);
    return write;
  }

  @override
  Future<OnboardingConversationSnapshot?> read() async => snapshot;

  @override
  Future<OnboardingConversationSnapshot> save(
    OnboardingConversationSnapshot next,
  ) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('simulated persistence failure');
    }
    final heldSave = _heldSaves.isEmpty ? null : _heldSaves.removeAt(0);
    await heldSave?.future;
    return snapshot = next;
  }

  @override
  Future<OnboardingConversationSnapshot> recordPhraseSaid({
    required OnboardingConversationSnapshot checkpoint,
    required String eventId,
    required DateTime occurredAt,
  }) async {
    phraseSaidWrites += 1;
    await _heldWrite?.future;
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
    final existing = snapshot;
    if (existing?.completionId != null) return existing!;
    completionWrites += 1;
    await _heldCompletionWrite?.future;
    return snapshot = checkpoint.copyWith(
      phase: OnboardingCheckpointPhase.completed,
      completionId: completionId,
      gardenTraceId: checkpoint.phraseSaidEventId,
      completedAt: completedAt,
    );
  }
}

final class _HeldWrite {
  final _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void release() => _completer.complete();
}

final class _ManualScheduler implements OnboardingDelayScheduler {
  final List<_ManualScheduledTask> _tasks = <_ManualScheduledTask>[];

  int get activeTaskCount => _tasks.where((task) => task.isActive).length;

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

CareEntryResolution _resolution() {
  final entry = ResolvedCareEntry(
    id: const CareEntryId('care.bedtime_soothing'),
    title: '哄睡中',
    subtitle: '轻一点开始',
    visualToken: 'route.moon',
    order: 1,
    isRecommended: true,
    seed: CareMomentSeed(
      generationRef: const GenerationSceneRef(
        id: GenerationSceneId('generation.bedtime'),
        namespace: 'babytalk.care',
        key: 'bedtime',
        version: 1,
        facets: <String, String>{'parentTonePreference': 'short_gentle'},
      ),
      fallback: const CatalogFallbackRef(
        id: CatalogFallbackId('fallback.bedtime.time_to_sleep'),
        spaceId: 'family_rhythm',
        activityId: 'bedtime',
        phraseId: 'bedtime_time_to_sleep',
      ),
      firstUtterance: const CareFirstUtterance(
        english: 'Time to sleep.',
        chinese: '该睡觉啦。',
        pronunciation: 'taɪm tə sliːp',
        audioAsset: 'assets/audio/phrases/bedtime_time_to_sleep.mp3',
        audioReview: AudioReview.reviewed,
      ),
      nextSupports: CareLocalNextSupportSet(
        whenAbsent: const CareNextSupportUtterance(
          id: CareSupportId('support.bedtime.absent'),
          english: "I'm here. It's sleep time.",
          chinese: '我在这里，该睡觉了。',
        ),
        byReaction: {
          for (final reaction in CareReaction.values)
            reaction: CareNextSupportUtterance(
              id: CareSupportId('support.bedtime.${reaction.wireValue}'),
              english: 'Support ${reaction.wireValue}.',
              chinese: '接住这一刻。',
            ),
        },
      ),
    ),
  );
  return CareEntryResolution(
    schemaVersion: 1,
    revision: 'test.1',
    placement: const CareEntryPlacementId('onboarding.primary'),
    entries: [entry],
    recommendedEntryId: entry.id,
  );
}
