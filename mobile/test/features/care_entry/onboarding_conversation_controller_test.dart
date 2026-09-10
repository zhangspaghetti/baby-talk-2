import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
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
    'held remote persistence cannot block six-second fallback or overwrite it',
    () async {
      final scheduler = _ManualScheduler();
      final gateway = _HeldConversationGateway();
      final repository = _MemoryConversationRepository();
      final ids = <String>['create-event-held', 'phrase-event-held'];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => ids.removeAt(0),
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-test-1234',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      final starting = controller.startSelected();
      await Future<void>.delayed(Duration.zero);
      gateway.complete(_remoteConversation('Remote first.'));
      await starting;
      await controller.markPhraseSaid();
      await controller.selectReaction(CareReaction.hesitant);
      scheduler.elapse(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      final heldRemoteSave = repository.holdNextSupportSave();
      final publishedSupports = <String?>[];
      controller.addListener(
        () => publishedSupports.add(controller.state.nextSupport?.english),
      );
      gateway.completeNext(_remoteConversation('Remote held next.'));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.resolvingNextSupport,
      );

      await controller.selectReaction(CareReaction.other, otherText: 'ignored');
      expect(gateway.nextCalls, 1);
      scheduler.elapse(const Duration(seconds: 6));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.phase,
        OnboardingConversationPhase.nextSupportReady,
      );
      expect(controller.state.nextSupport?.english, 'Support hesitant.');
      expect(
        repository.snapshot?.nextSupportSource,
        OnboardingUtteranceSource.localFallback,
      );
      heldRemoteSave.release();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.nextSupport?.english, 'Support hesitant.');
      expect(repository.snapshot?.nextSupportEnglish, 'Support hesitant.');
      expect(repository.snapshot?.selectedReaction, CareReaction.hesitant);
      expect(publishedSupports, isNot(contains('Remote held next.')));
    },
  );

  test(
    'remote commit claimed before replacement cannot be stolen by deadline',
    () async {
      final scheduler = _ManualScheduler();
      final gateway = _HeldConversationGateway();
      final repository = _MemoryConversationRepository();
      final ids = <String>['create-event-commit', 'phrase-event-commit'];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => ids.removeAt(0),
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-test-1234',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      final starting = controller.startSelected();
      await Future<void>.delayed(Duration.zero);
      gateway.complete(_remoteConversation('Remote first.'));
      await starting;
      await controller.markPhraseSaid();
      await controller.selectReaction(CareReaction.hesitant);
      scheduler.elapse(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      final heldReplacement = repository.holdNextSupportAfterCommit();
      gateway.completeNext(_remoteConversation('Remote committed next.'));
      await heldReplacement.waitUntilEntered;

      scheduler.elapse(const Duration(seconds: 6));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.resolvingNextSupport,
      );
      expect(repository.snapshot?.nextSupportEnglish, 'Support hesitant.');

      heldReplacement.release();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.nextSupportReady,
      );
      expect(controller.state.nextSupport?.english, 'Remote committed next.');
      expect(
        repository.snapshot?.nextSupportSource,
        OnboardingUtteranceSource.remoteGenerated,
      );
    },
  );

  test(
    'remote next support restores exact content and source after restart',
    () async {
      final scheduler = _ManualScheduler();
      final gateway = _HeldConversationGateway();
      final repository = _MemoryConversationRepository();
      final ids = <String>['create-event-restart', 'phrase-event-restart'];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => ids.removeAt(0),
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-test-1234',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      final starting = controller.startSelected();
      await Future<void>.delayed(Duration.zero);
      gateway.complete(_remoteConversation('Remote first.'));
      await starting;
      await controller.markPhraseSaid();
      await controller.selectReaction(CareReaction.cooperating);
      scheduler.elapse(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);
      gateway.completeNext(_remoteConversation('Exact remote next.'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final restored = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'unused',
        visibleSlots: 1,
      );
      addTearDown(restored.dispose);
      await restored.initialize(localTime: DateTime(2026, 8, 14, 20));

      expect(restored.state.nextSupport?.english, 'Exact remote next.');
      expect(
        repository.snapshot?.nextSupportSource,
        OnboardingUtteranceSource.remoteGenerated,
      );
    },
  );

  test(
    'defer publishes only after persistence and exact utterance resumes',
    () async {
      final repository = _MemoryConversationRepository();
      final gateway = _HeldConversationGateway();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'defer-event-1',
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-defer-1234',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      final starting = controller.startSelected();
      await Future<void>.delayed(Duration.zero);
      gateway.complete(_remoteConversation('Exact remote before defer.'));
      await starting;
      final exactEnglish = controller.state.activeUtterance!.english;
      expect(
        controller.state.activeUtterance?.source,
        OnboardingUtteranceSource.remoteGenerated,
      );

      repository.failNextDefer = true;
      expect(await controller.defer(), isFalse);
      expect(repository.snapshot?.status, OnboardingConversationStatus.active);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.firstUtterance,
      );

      expect(await controller.defer(), isTrue);
      expect(
        repository.snapshot?.status,
        OnboardingConversationStatus.deferred,
      );
      final resumed = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 13),
        idGenerator: () => 'unused',
        visibleSlots: 1,
      );
      addTearDown(resumed.dispose);
      await resumed.initialize(localTime: DateTime(2026, 8, 14, 21));
      expect(resumed.state.phase, OnboardingConversationPhase.firstUtterance);
      expect(resumed.state.activeUtterance?.english, exactEnglish);
      expect(
        resumed.state.activeUtterance?.source,
        OnboardingUtteranceSource.remoteGenerated,
      );
    },
  );

  test(
    'defer invalidates a first-utterance save before remote starts',
    () async {
      final scheduler = _ManualScheduler();
      final gateway = _HeldConversationGateway();
      final repository = _MemoryConversationRepository();
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 20),
        idGenerator: () => 'defer-race',
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-defer-race',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      final heldSave = repository.holdNextSave();

      final start = controller.startSelected();
      await heldSave.waitUntilEntered;
      final deferred = controller.defer();
      heldSave.release();

      expect(await deferred, isTrue);
      await start;
      expect(
        repository.snapshot?.status,
        OnboardingConversationStatus.deferred,
      );
      expect(gateway.request, isNull);
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
        OnboardingConversationPhase.savingReaction,
      );
      expect(controller.state.selectedReaction, CareReaction.hesitant);
      expect(controller.state.nextSupport, isNull);

      scheduler.elapse(const Duration(milliseconds: 499));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.savingReaction,
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
    'first reaction intent locks input before persistence completes',
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
      final first = controller.selectReaction(CareReaction.cooperating);
      await controller.selectReaction(CareReaction.hesitant);

      expect(
        controller.state.phase,
        OnboardingConversationPhase.savingReaction,
      );

      firstWrite.release();
      await first;
      expect(scheduler.activeTaskCount, 1);
      scheduler.elapse(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.selectedReaction, CareReaction.cooperating);
      expect(
        controller.state.nextSupport?.id.value,
        'support.bedtime.cooperating',
      );
      expect(repository.snapshot?.selectedReaction, CareReaction.cooperating);
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
        OnboardingConversationPhase.savingReaction,
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

  test('remote contextual next support wins before six seconds', () async {
    final scheduler = _ManualScheduler();
    final gateway = _HeldConversationGateway();
    final ids = <String>['create-event-1', 'phrase-event-1'];
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: _MemoryConversationRepository(),
      scheduler: scheduler,
      clock: () => DateTime.utc(2026, 8, 14, 12),
      idGenerator: () => ids.removeAt(0),
      conversationGateway: gateway,
      installationIdLoader: () async => 'install-test-1234',
      visibleSlots: 1,
    );
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
    final starting = controller.startSelected();
    await Future<void>.delayed(Duration.zero);
    gateway.complete(_remoteConversation('Remote first.'));
    await starting;
    await controller.markPhraseSaid();

    await controller.selectReaction(CareReaction.other, otherText: '宝宝想抱一会儿');
    scheduler.elapse(const Duration(milliseconds: 500));
    await Future<void>.delayed(Duration.zero);
    expect(gateway.nextRequest?.previousUtteranceId, 'utterance-remote-1');
    expect(gateway.nextRequest?.localEventId, 'phrase-event-1.next.other');
    expect(gateway.nextRequest?.reaction, CareReaction.other);
    expect(gateway.nextRequest?.reactionText, '宝宝想抱一会儿');
    expect(gateway.nextRequest?.generationScene.key, 'bedtime');

    gateway.completeNext(_remoteConversation('Remote next.'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.state.phase,
      OnboardingConversationPhase.nextSupportReady,
    );
    expect(controller.state.nextSupport?.english, 'Remote next.');
  });

  test(
    'six-second local next support is sticky against a late result',
    () async {
      final scheduler = _ManualScheduler();
      final gateway = _HeldConversationGateway();
      final ids = <String>['create-event-2', 'phrase-event-2'];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: _MemoryConversationRepository(),
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => ids.removeAt(0),
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-test-1234',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      final starting = controller.startSelected();
      await Future<void>.delayed(Duration.zero);
      gateway.complete(_remoteConversation('Remote first.'));
      await starting;
      await controller.markPhraseSaid();
      await controller.selectReaction(CareReaction.hesitant);
      scheduler.elapse(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      scheduler.elapse(const Duration(milliseconds: 5999));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.resolvingNextSupport,
      );
      scheduler.elapse(const Duration(milliseconds: 1));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.phase,
        OnboardingConversationPhase.nextSupportReady,
      );
      expect(controller.state.nextSupport?.english, 'Support hesitant.');
      gateway.completeNext(_remoteConversation('Too late next.'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.nextSupport?.english, 'Support hesitant.');
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
    'continue handoff keeps exact next support identity and source',
    () async {
      final scheduler = _ManualScheduler();
      final repository = _MemoryConversationRepository();
      final ids = <String>['phrase-for-handoff', 'completion-for-handoff'];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 20),
        idGenerator: () => ids.removeAt(0),
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();
      await controller.markPhraseSaid();
      final next = controller.continueWithoutReaction();
      await next;

      final support = controller.state.nextSupport!;
      final handoff = await controller.continueToCareTurn();

      expect(handoff, isNotNull);
      expect(handoff!.utteranceId, support.id.value);
      expect(handoff.english, support.english);
      expect(handoff.chinese, support.chinese);
      expect(handoff.source, OnboardingCareTurnSource.localFallback);
      expect(handoff.spaceId, 'family_rhythm');
      expect(handoff.activityId, 'bedtime');
      expect(repository.completionWrites, 1);
      expect(controller.state.phase, OnboardingConversationPhase.completed);
    },
  );

  test(
    'today finish succeeds while remote next support is unavailable',
    () async {
      final scheduler = _ManualScheduler();
      final gateway = _HeldConversationGateway();
      final repository = _MemoryConversationRepository();
      final ids = <String>[
        'request-before-finish',
        'phrase-before-finish',
        'completion-before-next',
      ];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 20),
        idGenerator: () => ids.removeAt(0),
        conversationGateway: gateway,
        installationIdLoader: () async => 'install-finish-before-next',
        visibleSlots: 1,
      );
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      final starting = controller.startSelected();
      await Future<void>.delayed(Duration.zero);
      gateway.complete(_remoteConversation('Remote first before finish.'));
      await starting;
      await controller.markPhraseSaid();
      final selecting = controller.selectReaction(CareReaction.hesitant);
      scheduler.elapse(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.resolvingNextSupport,
      );

      expect(await controller.complete(), isTrue);
      await selecting;

      expect(controller.state.phase, OnboardingConversationPhase.completed);
      expect(controller.state.gardenTraceId, 'phrase-before-finish');
      expect(repository.completionWrites, 1);
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

  test(
    'post-speech defer resumes without a duplicate PhraseSaid trace',
    () async {
      final repository = _MemoryConversationRepository();
      final ids = <String>['phrase-said-deferred', 'completion-deferred'];
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
      final phraseSaidId = controller.state.phraseSaidEventId;
      expect(repository.phraseSaidWrites, 1);
      expect(await controller.defer(), isTrue);

      final resumed = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 13),
        idGenerator: () => ids.removeAt(0),
        visibleSlots: 1,
      );
      addTearDown(resumed.dispose);
      await resumed.initialize(localTime: DateTime(2026, 8, 14, 21));
      expect(resumed.state.phase, OnboardingConversationPhase.reactionPrompt);
      expect(resumed.state.phraseSaidEventId, phraseSaidId);
      expect(repository.phraseSaidWrites, 1);

      await resumed.complete();
      expect(resumed.state.gardenTraceId, phraseSaidId);
      expect(repository.completionWrites, 1);
    },
  );

  test('pending selected reaction resumes to reviewed local support', () async {
    final repository = _MemoryConversationRepository()
      ..snapshot = OnboardingConversationSnapshot(
        status: OnboardingConversationStatus.deferred,
        deferredAt: DateTime.utc(2026, 8, 14, 11, 30),
        registryRevision: 'test.1',
        phase: OnboardingCheckpointPhase.reactionPrompt,
        selectedEntryId: const CareEntryId('care.bedtime_soothing'),
        activeEntryId: const CareEntryId('care.bedtime_soothing'),
        currentUtterance: OnboardingUtterance.local(
          utteranceId: 'bedtime-phrase',
          utterance: _resolution().entries.single.seed.firstUtterance,
        ),
        phraseSaidEventId: 'phrase-said-pending',
        phraseSaidAt: DateTime.utc(2026, 8, 14, 11),
        selectedReaction: CareReaction.hesitant,
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
    scheduler.elapse(const Duration(milliseconds: 500));
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.state.phase,
      OnboardingConversationPhase.nextSupportReady,
    );
    expect(controller.state.nextSupport?.english, 'Support hesitant.');
    expect(
      repository.snapshot?.nextSupportSource,
      OnboardingUtteranceSource.localFallback,
    );
  });

  test('snapshot v2 restores every durable local checkpoint', () async {
    final occurredAt = DateTime.utc(2026, 8, 14, 11);
    final completedAt = DateTime.utc(2026, 8, 14, 12);
    final checkpoints = <OnboardingConversationSnapshot>[
      OnboardingConversationSnapshot(
        registryRevision: 'test.1',
        phase: OnboardingCheckpointPhase.selection,
        selectedEntryId: CareEntryId('care.bedtime_soothing'),
      ),
      OnboardingConversationSnapshot(
        registryRevision: 'test.1',
        phase: OnboardingCheckpointPhase.firstUtterance,
        selectedEntryId: CareEntryId('care.bedtime_soothing'),
        activeEntryId: CareEntryId('care.bedtime_soothing'),
        currentUtterance: OnboardingUtterance.local(
          utteranceId: 'bedtime_time_to_sleep',
          utterance: CareFirstUtterance(
            english: 'Time to sleep.',
            chinese: '该睡觉啦。',
            pronunciation: 'taɪm tə sliːp',
            audioAsset: 'assets/audio/phrases/bedtime_time_to_sleep.mp3',
            audioReview: AudioReview.reviewed,
          ),
        ),
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
        status: OnboardingConversationStatus.completed,
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

  test(
    'incomplete first-utterance checkpoint restarts from durable selection',
    () async {
      final repository = _MemoryConversationRepository()
        ..snapshot = const OnboardingConversationSnapshot(
          registryRevision: 'test.1',
          phase: OnboardingCheckpointPhase.firstUtterance,
          selectedEntryId: CareEntryId('care.bedtime_soothing'),
          activeEntryId: CareEntryId('care.bedtime_soothing'),
        );
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: _ManualScheduler(),
        idGenerator: () => 'unused',
        clock: () => DateTime.utc(2026, 8, 14, 12),
      );
      addTearDown(controller.dispose);

      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      expect(controller.state.phase, OnboardingConversationPhase.selection);
      expect(controller.state.activeUtterance, isNull);
      expect(repository.snapshot?.phase, OnboardingCheckpointPhase.selection);
      expect(repository.snapshot?.activeEntryId, isNull);
    },
  );
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
  final Completer<GuestOnboardingConversation> _nextResponse = Completer();
  CreateGuestOnboardingConversation? request;
  NextGuestOnboardingTurn? nextRequest;
  int calls = 0;
  int nextCalls = 0;

  @override
  Future<GuestOnboardingConversation> create(
    CreateGuestOnboardingConversation request,
  ) {
    calls += 1;
    this.request = request;
    return _response.future;
  }

  void complete(GuestOnboardingConversation value) => _response.complete(value);

  @override
  Future<GuestOnboardingConversation> nextSupport(
    NextGuestOnboardingTurn request,
  ) {
    nextCalls += 1;
    nextRequest = request;
    return _nextResponse.future;
  }

  void completeNext(GuestOnboardingConversation value) =>
      _nextResponse.complete(value);
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
  bool failNextDefer = false;
  _HeldWrite? _heldWrite;
  _HeldWrite? _heldCompletionWrite;
  final List<_HeldWrite> _heldSaves = <_HeldWrite>[];
  final List<_HeldWrite> _heldNextSupportSaves = <_HeldWrite>[];
  final List<_HeldWrite> _heldNextSupportCommits = <_HeldWrite>[];
  Future<void> _nextSupportTail = Future<void>.value();
  Future<void>? _activeSave;

  _HeldWrite holdPhraseSaidWrite() => _heldWrite = _HeldWrite();

  _HeldWrite holdCompletionWrite() => _heldCompletionWrite = _HeldWrite();

  _HeldWrite holdNextSave() {
    final write = _HeldWrite();
    _heldSaves.add(write);
    return write;
  }

  _HeldWrite holdNextSupportSave() {
    final write = _HeldWrite();
    _heldNextSupportSaves.add(write);
    return write;
  }

  _HeldWrite holdNextSupportAfterCommit() {
    final write = _HeldWrite();
    _heldNextSupportCommits.add(write);
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
    final operation = () async {
      heldSave?.markEntered();
      await heldSave?.future;
      return snapshot = next;
    }();
    _activeSave = operation.then<void>((_) {});
    try {
      return await operation;
    } finally {
      _activeSave = null;
    }
  }

  @override
  Future<OnboardingConversationSnapshot?> saveNextSupport(
    OnboardingConversationSnapshot next, {
    required bool Function() commitIfCurrent,
  }) {
    final operation = _nextSupportTail.then((_) async {
      final heldSave = _heldNextSupportSaves.isEmpty
          ? null
          : _heldNextSupportSaves.removeAt(0);
      await heldSave?.future;
      if (!commitIfCurrent()) return snapshot;
      final heldCommit = _heldNextSupportCommits.isEmpty
          ? null
          : _heldNextSupportCommits.removeAt(0);
      heldCommit?.markEntered();
      await heldCommit?.future;
      return snapshot = next;
    });
    _nextSupportTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  @override
  Future<OnboardingConversationSnapshot> defer({
    required OnboardingConversationSnapshot checkpoint,
    required DateTime deferredAt,
  }) async {
    if (failNextDefer) {
      failNextDefer = false;
      throw StateError('simulated defer failure');
    }
    await _activeSave;
    final current = snapshot ?? checkpoint;
    return snapshot = current.copyWith(
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
      status: OnboardingConversationStatus.completed,
      phase: OnboardingCheckpointPhase.completed,
      completionId: completionId,
      gardenTraceId: checkpoint.phraseSaidEventId,
      completedAt: completedAt,
      deferredAt: null,
    );
  }
}

final class _HeldWrite {
  final _completer = Completer<void>();
  final _entered = Completer<void>();

  Future<void> get future => _completer.future;
  Future<void> get waitUntilEntered => _entered.future;

  void markEntered() {
    if (!_entered.isCompleted) _entered.complete();
  }

  void release() {
    markEntered();
    _completer.complete();
  }
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
