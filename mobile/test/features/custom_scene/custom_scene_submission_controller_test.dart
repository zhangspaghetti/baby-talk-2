import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_failure.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  group('CustomSceneSubmissionController', () {
    late Directory tempDir;
    late DateTime now;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('custom_scene_submit_');
      now = DateTime.utc(2026, 7, 28, 15);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'persists ready handoff before any route and restores same content',
      () async {
        final gate = Completer<void>();
        final requestStarted = Completer<void>();
        final repository = _FakeRepository((draft) async {
          requestStarted.complete();
          await gate.future;
          return _moment();
        });
        final registrar = _FakeRegistrar();
        final harness = _harness(
          tempDir: tempDir,
          clock: () => now,
          repository: repository,
          registrar: registrar,
          handoff: _FakeHandoffSink(),
        );
        final draft = _draft();

        final first = harness.controller.submit(draft);
        final second = harness.controller.submit(draft);
        await requestStarted.future;
        expect(repository.received, hasLength(1));
        expect(
          repository.received.single.requestIdentity.clientRequestId,
          'request_1',
        );
        gate.complete();
        await Future.wait(<Future<void>>[first, second]);

        expect(registrar.moments, hasLength(1));
        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.readyForHandoff,
        );
        expect(
          (await harness.draftStore.readResult(now: now)).draft?.state,
          CustomSceneStoredDraftState.readyForHandoff,
        );
        expect(
          (await harness.draftStore.readResult(
            now: now,
          )).draft?.registeredContentId,
          'generated_1',
        );

        final restartedRepository = _FakeRepository((_) async => _moment());
        final restarted = _harness(
          tempDir: tempDir,
          clock: () => now,
          repository: restartedRepository,
          registrar: _FakeRegistrar(),
          handoff: _FakeHandoffSink(),
        );
        await restarted.controller.restore(accountContext: 'account_a');
        expect(
          restarted.controller.state.phase,
          CustomSceneSubmissionPhase.readyForHandoff,
        );
        expect(restarted.controller.state.generatedContentId, 'generated_1');
        expect(restartedRepository.received, isEmpty);
      },
    );

    test(
      'unknown outcome retries with the original client request identity',
      () async {
        final repository = _FakeRepository(
          (_) async => throw const CustomSceneFailure(
            kind: CustomSceneFailureKind.timeout,
            retryable: true,
          ),
        );
        final harness = _harness(
          tempDir: tempDir,
          clock: () => now,
          repository: repository,
          registrar: _FakeRegistrar(),
          handoff: _FakeHandoffSink(),
        );

        await harness.controller.submit(_draft());
        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.unknownOutcome,
        );
        expect(harness.controller.state.canCancelRetainedDraft, isFalse);
        expect(
          (await harness.draftStore.readResult(now: now)).draft?.state,
          CustomSceneStoredDraftState.unknownOutcome,
        );

        final reconciler = _FakeRepository((_) async => _moment());
        final restarted = _harness(
          tempDir: tempDir,
          clock: () => now,
          repository: reconciler,
          registrar: _FakeRegistrar(),
          handoff: _FakeHandoffSink(),
        );
        await restarted.controller.restore(accountContext: 'account_a');
        expect(
          restarted.controller.state.phase,
          CustomSceneSubmissionPhase.unknownOutcome,
        );
        await restarted.controller.retry();
        expect(
          <CustomSceneDraft>[
            ...repository.received,
            ...reconciler.received,
          ].map((draft) => draft.requestIdentity.clientRequestId).toSet(),
          <String>{'request_1'},
        );
        expect(
          restarted.controller.state.phase,
          CustomSceneSubmissionPhase.readyForHandoff,
        );
      },
    );

    test(
      'terminal request failure exposes retained draft cancellation',
      () async {
        var attempts = 0;
        final repository = _FakeRepository((_) async {
          attempts += 1;
          if (attempts == 1) {
            throw const CustomSceneFailure(
              kind: CustomSceneFailureKind.requestTerminal,
              retryable: false,
              requiresNewClientRequestId: true,
            );
          }
          return _moment();
        });
        final harness = _harness(
          tempDir: tempDir,
          clock: () => now,
          repository: repository,
          registrar: _FakeRegistrar(),
          handoff: _FakeHandoffSink(),
        );

        await harness.controller.submit(_draft());

        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.recoverableError,
        );
        expect(harness.controller.state.canCancelRetainedDraft, isTrue);
        expect(
          (await harness.draftStore.readResult(
            now: now,
          )).draft?.requestIdentity.clientRequestId,
          'request_1',
        );

        await harness.controller.cancel();
        expect(
          (await harness.draftStore.readResult(now: now)).status,
          CustomSceneDraftReadStatus.notFound,
        );

        await harness.controller.submit(
          CustomSceneDraft(
            text: '宝宝穿衣服时不愿意伸手。',
            entrySource: CustomSceneEntrySource.today,
            requestIdentity: CustomSceneRequestIdentity(
              clientRequestId: 'request_2',
            ),
          ),
        );

        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.readyForHandoff,
        );
        expect(
          repository.received.map(
            (draft) => draft.requestIdentity.clientRequestId,
          ),
          <String>['request_1', 'request_2'],
        );
      },
    );

    test(
      'cancel stops waiting but retains a late request for reconciliation',
      () async {
        final gate = Completer<void>();
        final requestStarted = Completer<void>();
        final repository = _FakeRepository((_) async {
          requestStarted.complete();
          await gate.future;
          return _moment();
        });
        final registrar = _FakeRegistrar();
        final harness = _harness(
          tempDir: tempDir,
          clock: () => now,
          repository: repository,
          registrar: registrar,
          handoff: _FakeHandoffSink(),
        );

        final submission = harness.controller.submit(_draft());
        await requestStarted.future;
        await harness.controller.cancel();
        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.editing,
        );

        gate.complete();
        await submission;
        expect(registrar.moments, isEmpty);
        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.editing,
        );
        expect(
          (await harness.draftStore.readResult(now: now)).draft?.state,
          CustomSceneStoredDraftState.unknownOutcome,
        );
      },
    );

    test(
      'registration retry does not make another generation request',
      () async {
        final repository = _FakeRepository((_) async => _moment());
        final registrar = _FakeRegistrar(shouldFail: true);
        final harness = _harness(
          tempDir: tempDir,
          clock: () => now,
          repository: repository,
          registrar: registrar,
          handoff: _FakeHandoffSink(),
        );

        await harness.controller.submit(_draft());
        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.recoverableError,
        );
        expect(
          (await harness.draftStore.readResult(now: now)).draft?.state,
          CustomSceneStoredDraftState.approvedPendingRegistration,
        );

        registrar.shouldFail = false;
        await harness.controller.retry();
        expect(repository.received, hasLength(1));
        expect(registrar.moments, hasLength(2));
        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.readyForHandoff,
        );
        expect(
          (await harness.continuation.readForAuthenticatedResume(
            accountContext: 'account_a',
          )).status,
          CustomSceneDraftContinuationStatus.notFound,
        );
      },
    );

    test(
      'authenticated continuation resumes once and preserves the request',
      () async {
        final repository = _FakeRepository((_) async => _moment());
        final harness = _harness(
          tempDir: tempDir,
          clock: () => now,
          repository: repository,
          registrar: _FakeRegistrar(),
          handoff: _FakeHandoffSink(),
        );
        await harness.continuation.beginAuthentication(draft: _draft());

        await Future.wait(<Future<void>>[
          harness.controller.resumeAfterAuthentication(
            accountContext: 'account_a',
          ),
          harness.controller.resumeAfterAuthentication(
            accountContext: 'account_a',
          ),
        ]);

        expect(repository.received, hasLength(1));
        expect(
          repository.received.single.requestIdentity.clientRequestId,
          'request_1',
        );
        expect(
          harness.controller.state.phase,
          CustomSceneSubmissionPhase.readyForHandoff,
        );
      },
    );
  });
}

class _Harness {
  const _Harness({
    required this.controller,
    required this.draftStore,
    required this.continuation,
  });

  final CustomSceneSubmissionController controller;
  final CustomSceneDraftStore draftStore;
  final CustomSceneDraftContinuationCoordinator continuation;
}

_Harness _harness({
  required Directory tempDir,
  required DateTime Function() clock,
  required _FakeRepository repository,
  required _FakeRegistrar registrar,
  required _FakeHandoffSink handoff,
}) {
  final draftStore = CustomSceneDraftStore(
    directoryResolver: () async => tempDir,
  );
  final continuation = CustomSceneDraftContinuationCoordinator(
    draftStore: draftStore,
    authContinuationCoordinator: AuthContinuationCoordinator(
      store: AuthContinuationStore(directoryResolver: () async => tempDir),
      clock: clock,
      correlationIdGenerator: () => 'auth_continuation_1',
    ),
    clock: clock,
    draftIdGenerator: () => 'draft_1',
  );
  return _Harness(
    controller: CustomSceneSubmissionController(
      repository: repository,
      draftStore: draftStore,
      draftContinuationCoordinator: continuation,
      approvedContentRegistrar: registrar,
      accountContextLoader: () async => 'account_a',
      clock: clock,
      draftIdGenerator: () => 'draft_1',
    ),
    draftStore: draftStore,
    continuation: continuation,
  );
}

class _FakeRepository implements CustomSceneRepository {
  _FakeRepository(this._generate);

  final Future<GeneratedCareMoment> Function(CustomSceneDraft draft) _generate;
  final List<CustomSceneDraft> received = <CustomSceneDraft>[];

  @override
  Future<GeneratedCareMoment> generate(CustomSceneDraft draft) {
    received.add(draft);
    return _generate(draft);
  }
}

class _FakeRegistrar implements CustomSceneApprovedContentRegistrar {
  _FakeRegistrar({this.shouldFail = false});

  bool shouldFail;
  final List<GeneratedCareMoment> moments = <GeneratedCareMoment>[];

  @override
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  }) async {
    moments.add(moment);
    if (shouldFail) {
      throw StateError('registration unavailable');
    }
  }
}

class _FakeHandoffSink implements CustomSceneCareTurnHandoffSink {
  final List<String> generatedContentIds = <String>[];

  @override
  Future<CustomSceneCareTurnRouteAttempt> handoff(
    CustomSceneCareTurnHandoff handoff,
  ) async {
    generatedContentIds.add(handoff.generatedContentId);
    return CustomSceneCareTurnRouteAttempt(
      routeCompletion: Future<void>.value(),
    );
  }
}

CustomSceneDraft _draft() {
  return CustomSceneDraft(
    text: '宝宝洗澡时一直躲水。',
    entrySource: CustomSceneEntrySource.today,
    requestIdentity: CustomSceneRequestIdentity(clientRequestId: 'request_1'),
  );
}

GeneratedCareMoment _moment() {
  GeneratedCareUtterance utterance(
    String suffix, {
    required GeneratedCareUtteranceRole role,
    required BabyReactionType? reaction,
    required int displayOrder,
  }) {
    return GeneratedCareUtterance(
      utteranceId: 'utterance_$suffix',
      phraseId: 'phrase_$suffix',
      english: 'Warm water',
      chinese: '温水来了',
      pronunciation: 'wɔːm',
      tprActionZh: '靠近宝宝',
      deliveryGuidanceZh: '慢慢说',
      difficulty: 'starter',
      source: 'generated',
      role: role,
      reaction: reaction,
      displayOrder: displayOrder,
      providerProvenance: GeneratedCareProviderProvenance(
        origin: GeneratedCareProviderOrigin.providerGenerated,
        providerName: 'provider',
        modelName: 'model',
        attemptNumber: 1,
      ),
    );
  }

  return GeneratedCareMoment(
    schemaVersion: generatedCareMomentSchemaVersion,
    generatedContentId: 'generated_1',
    sceneId: 'scene_1',
    spaceId: 'space_1',
    momentId: 'moment_1',
    activityId: 'activity_1',
    title: '洗澡',
    sceneTag: 'bath',
    coachTip: '慢慢来',
    source: 'generated',
    starter: utterance(
      'starter',
      role: GeneratedCareUtteranceRole.starter,
      reaction: null,
      displayOrder: 1,
    ),
    reactionSupports:
        GeneratedReactionSupportMap(<BabyReactionType, GeneratedCareUtterance>{
          for (final reaction in BabyReactionType.values)
            reaction: utterance(
              reaction.name,
              role: GeneratedCareUtteranceRole.reactionSupport,
              reaction: reaction,
              displayOrder: BabyReactionType.values.indexOf(reaction) + 2,
            ),
        }),
  );
}
