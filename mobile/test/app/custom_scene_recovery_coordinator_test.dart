import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/custom_scene_recovery_coordinator.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';

import '../support/generated_care_moment_fixture.dart';

void main() {
  test(
    'stable auth recovery transfers one valid durable intent exactly once',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 8, 12, 9);
      final draftStore = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      final authStore = AuthContinuationStore(
        directoryResolver: () async => tempDir,
      );
      final authContinuation = AuthContinuationCoordinator(
        store: authStore,
        clock: () => now,
        correlationIdGenerator: () => 'synthetic_auth_60',
      );
      final draftContinuation = CustomSceneDraftContinuationCoordinator(
        draftStore: draftStore,
        authContinuationCoordinator: authContinuation,
        clock: () => now,
        draftIdGenerator: () => 'synthetic_draft_60',
      );
      late CustomSceneDraftReadResult draftAtRepositoryBoundary;
      late AuthContinuationReadResult authAtRepositoryBoundary;
      final repository = _CallbackRepository((draft) async {
        draftAtRepositoryBoundary = await draftStore.readResult(now: now);
        authAtRepositoryBoundary = await authStore.readResult(now: now);
        return generatedCareMomentFixture(
          generatedContentId: 'synthetic_generated_60',
        );
      });
      final registrar = _SuccessfulRegistrar();
      final handoff = _HandoffSink();
      final controller = CustomSceneSubmissionController(
        repository: repository,
        draftStore: draftStore,
        draftContinuationCoordinator: draftContinuation,
        approvedContentRegistrar: registrar,
        accountContextLoader: () async => 'synthetic_account_b',
        clock: () => now,
      );
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: controller,
        handoffSink: handoff,
      );
      addTearDown(() {
        coordinator.dispose();
        controller.dispose();
      });
      final originalDraft = CustomSceneDraft(
        text: 'SYNTHETIC_BATH_SCENE',
        entrySource: CustomSceneEntrySource.today,
        requestIdentity: CustomSceneRequestIdentity(
          clientRequestId: 'synthetic_request_60',
        ),
      );
      await draftContinuation.beginAuthentication(draft: originalDraft);

      await Future.wait(<Future<void>>[
        coordinator.recoverForAuthenticatedAccount(
          accountContext: 'synthetic_account_b',
        ),
        coordinator.recoverForAuthenticatedAccount(
          accountContext: 'synthetic_account_b',
        ),
      ]);

      expect(repository.received, hasLength(1));
      expect(repository.received.single.text, originalDraft.text);
      expect(
        repository.received.single.requestIdentity.clientRequestId,
        originalDraft.requestIdentity.clientRequestId,
      );
      expect(
        draftAtRepositoryBoundary.draft?.state,
        CustomSceneStoredDraftState.submitting,
      );
      expect(
        draftAtRepositoryBoundary.draft?.expectedAccountContext,
        'synthetic_account_b',
      );
      expect(
        authAtRepositoryBoundary.status,
        AuthContinuationReadStatus.available,
      );
      expect(
        authAtRepositoryBoundary
            .continuation
            ?.customScene
            ?.expectedAccountContext,
        'synthetic_account_b',
      );
      final durableHandoff = await draftStore.readResult(now: now);
      expect(
        durableHandoff.draft?.state,
        CustomSceneStoredDraftState.readyForHandoff,
      );
      expect(
        durableHandoff.draft?.registeredContentId,
        'synthetic_generated_60',
      );
      expect(
        (await authStore.readResult(now: now)).status,
        AuthContinuationReadStatus.notFound,
      );
      expect(registrar.calls, 1);
      expect(handoff.ids, <String>['synthetic_generated_60']);
    },
  );

  test(
    'stable auth recovery rejects an account mismatch without side effects',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 8, 12, 9);
      final scenario = _authRecoveryScenario(
        tempDir: tempDir,
        clock: () => now,
      );
      addTearDown(scenario.dispose);
      await scenario.draftContinuation.beginAuthentication(
        draft: _syntheticAuthDraft(),
        expectedAccountContext: 'synthetic_account_a',
      );

      await scenario.coordinator.recoverForAuthenticatedAccount(
        accountContext: 'synthetic_account_b',
      );

      expect(scenario.repository.received, isEmpty);
      expect(scenario.registrar.calls, 0);
      expect(scenario.handoff.ids, isEmpty);
      expect(
        scenario.controller.state.phase,
        CustomSceneSubmissionPhase.recoverableError,
      );
      expect(
        (await scenario.draftStore.readResult(now: now)).draft?.state,
        CustomSceneStoredDraftState.awaitingAuthentication,
      );
      expect(
        (await scenario.authStore.readResult(now: now)).status,
        AuthContinuationReadStatus.available,
      );
    },
  );

  test(
    'stable auth recovery expires both durable records without submission',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final recoveryTime = DateTime.utc(2026, 8, 12, 9);
      var currentTime = recoveryTime.subtract(const Duration(minutes: 16));
      final scenario = _authRecoveryScenario(
        tempDir: tempDir,
        clock: () => currentTime,
      );
      addTearDown(scenario.dispose);
      await scenario.draftContinuation.beginAuthentication(
        draft: _syntheticAuthDraft(),
      );
      currentTime = recoveryTime;

      await scenario.coordinator.recoverForAuthenticatedAccount(
        accountContext: 'synthetic_account_b',
      );

      expect(scenario.repository.received, isEmpty);
      expect(scenario.registrar.calls, 0);
      expect(scenario.handoff.ids, isEmpty);
      expect(
        scenario.controller.state.phase,
        CustomSceneSubmissionPhase.editing,
      );
      expect(
        (await scenario.draftStore.readResult(now: recoveryTime)).status,
        CustomSceneDraftReadStatus.notFound,
      );
      expect(
        (await scenario.authStore.readResult(now: recoveryTime)).status,
        AuthContinuationReadStatus.notFound,
      );
    },
  );

  test(
    'submission-start storage failure preserves authenticated recovery',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 8, 12, 9);
      final draftStore = _FailingSubmittingDraftStore(
        directoryResolver: () async => tempDir,
      );
      final scenario = _authRecoveryScenario(
        tempDir: tempDir,
        clock: () => now,
        draftStore: draftStore,
      );
      addTearDown(scenario.dispose);
      await scenario.draftContinuation.beginAuthentication(
        draft: _syntheticAuthDraft(),
      );
      draftStore.failSubmittingWrite = true;

      await scenario.coordinator.recoverForAuthenticatedAccount(
        accountContext: 'synthetic_account_b',
      );

      expect(scenario.repository.received, isEmpty);
      expect(scenario.registrar.calls, 0);
      expect(scenario.handoff.ids, isEmpty);
      expect(
        scenario.controller.state.phase,
        CustomSceneSubmissionPhase.recoverableError,
      );
      final recoverableDraft = await scenario.draftStore.readResult(now: now);
      expect(
        recoverableDraft.draft?.state,
        CustomSceneStoredDraftState.authenticationResolved,
      );
      expect(
        recoverableDraft.draft?.expectedAccountContext,
        'synthetic_account_b',
      );
      final recoverableAuth = await scenario.authStore.readResult(now: now);
      expect(recoverableAuth.status, AuthContinuationReadStatus.available);
      expect(
        recoverableAuth.continuation?.customScene?.expectedAccountContext,
        'synthetic_account_b',
      );
    },
  );

  test(
    'recovery routes one persisted content identity without generation',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 7, 29, 9);
      final store = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      await store.write(_readyDraft(now));
      final controller = _controller(store: store, now: now);
      final handoff = _HandoffSink();
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: controller,
        handoffSink: handoff,
      );
      addTearDown(() {
        coordinator.dispose();
        controller.dispose();
      });

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
        resumableGeneratedContentId: 'generated_stale',
      );
      expect(handoff.ids, <String>['generated_1']);
      expect(controller.state.generatedContentId, 'generated_1');

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
        resumableGeneratedContentId: 'generated_stale',
      );
      expect(handoff.ids, <String>['generated_1']);
    },
  );

  test(
    'explicit reopen routes the same prepared content after recovery completes',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 7, 29, 9);
      final store = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      await store.write(_readyDraft(now));
      final controller = _controller(store: store, now: now);
      final handoff = _HandoffSink();
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: controller,
        handoffSink: handoff,
      );
      addTearDown(() {
        coordinator.dispose();
        controller.dispose();
      });

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
      );
      expect(handoff.ids, <String>['generated_1']);
      await handoff.completeLatestRoute();
      expect(
        (await store.readResult(now: now)).draft?.registeredContentId,
        'generated_1',
      );

      await coordinator.openPreparedContent();

      expect(handoff.ids, <String>['generated_1', 'generated_1']);
      expect(controller.state.generatedContentId, 'generated_1');
    },
  );

  test(
    'concurrent explicit reopen activation routes once then permits a later attempt',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 7, 29, 9);
      final store = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      await store.write(_readyDraft(now));
      final controller = _controller(store: store, now: now);
      final handoff = _HandoffSink();
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: controller,
        handoffSink: handoff,
      );
      addTearDown(() {
        coordinator.dispose();
        controller.dispose();
      });

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
      );
      expect(handoff.ids, <String>['generated_1']);
      await handoff.completeLatestRoute();

      final firstActivation = coordinator.openPreparedContent();
      final repeatedActivation = coordinator.openPreparedContent();
      await Future.wait(<Future<void>>[firstActivation, repeatedActivation]);
      expect(handoff.ids, <String>['generated_1', 'generated_1']);

      await handoff.completeLatestRoute();

      await coordinator.openPreparedContent();

      expect(handoff.ids, <String>[
        'generated_1',
        'generated_1',
        'generated_1',
      ]);
    },
  );

  test(
    'old account route exit cannot clear the new account route guard',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 7, 29, 9);
      final store = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      await store.write(_readyDraft(now));
      final controller = _controller(store: store, now: now);
      final handoff = _HandoffSink();
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: controller,
        handoffSink: handoff,
      );
      addTearDown(() {
        coordinator.dispose();
        controller.dispose();
      });

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
      );
      await store.write(
        _readyDraft(
          now,
          accountContext: 'account_b',
          draftId: 'draft_2',
          requestId: 'request_2',
          generatedContentId: 'generated_2',
        ),
      );
      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_b',
      );
      expect(handoff.ids, <String>['generated_1', 'generated_2']);

      await handoff.completeRoute(0);
      await coordinator.openPreparedContent();
      expect(handoff.ids, <String>['generated_1', 'generated_2']);

      await handoff.completeLatestRoute();
      await coordinator.openPreparedContent();
      expect(handoff.ids, <String>[
        'generated_1',
        'generated_2',
        'generated_2',
      ]);
    },
  );

  test(
    'account mismatch does not route another account prepared content',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 7, 29, 9);
      final store = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      await store.write(_readyDraft(now));
      final controller = _controller(store: store, now: now);
      final handoff = _HandoffSink();
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: controller,
        handoffSink: handoff,
      );
      addTearDown(() {
        coordinator.dispose();
        controller.dispose();
      });

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_b',
      );
      expect(handoff.ids, isEmpty);
      expect(
        controller.state.phase,
        CustomSceneSubmissionPhase.recoverableError,
      );
      expect(
        (await store.readResult(now: now)).draft?.registeredContentId,
        'generated_1',
      );

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
      );
      expect(handoff.ids, <String>['generated_1']);
    },
  );

  test(
    'route failure coalesces concurrent activation and retry never generates again',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 7, 29, 9);
      final store = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      await store.write(_readyDraft(now));
      final controller = _controller(store: store, now: now);
      final handoff = _HandoffSink(shouldFail: true);
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: controller,
        handoffSink: handoff,
      );
      addTearDown(() {
        coordinator.dispose();
        controller.dispose();
      });

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
      );
      expect(handoff.ids, <String>['generated_1']);
      expect(controller.state.phase, CustomSceneSubmissionPhase.handoffFailed);
      expect(
        (await store.readResult(now: now)).draft?.registeredContentId,
        'generated_1',
      );

      await Future.wait(<Future<void>>[
        coordinator.openPreparedContent(),
        coordinator.openPreparedContent(),
      ]);
      expect(handoff.ids, <String>['generated_1', 'generated_1']);

      handoff.shouldFail = false;
      await coordinator.openPreparedContent();
      expect(handoff.ids, <String>[
        'generated_1',
        'generated_1',
        'generated_1',
      ]);
      expect(controller.state.canOpenPreparedContent, isTrue);
    },
  );

  test(
    'cold start resumes generated continuity after handoff intent is cleared',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('custom_recovery_');
      addTearDown(() => tempDir.delete(recursive: true));
      final now = DateTime.utc(2026, 7, 29, 9);
      final store = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      final controller = _controller(store: store, now: now);
      final handoff = _HandoffSink();
      final coordinator = CustomSceneRecoveryCoordinator(
        controller: controller,
        handoffSink: handoff,
      );
      addTearDown(() {
        coordinator.dispose();
        controller.dispose();
      });

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
        resumableGeneratedContentId: 'generated_1',
      );

      expect(handoff.ids, <String>['generated_1']);

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
        resumableGeneratedContentId: 'generated_1',
      );
      expect(handoff.ids, <String>['generated_1']);
    },
  );
}

CustomSceneStoredDraft _readyDraft(
  DateTime now, {
  String accountContext = 'account_a',
  String draftId = 'draft_1',
  String requestId = 'request_1',
  String generatedContentId = 'generated_1',
}) {
  return CustomSceneStoredDraft(
    draftId: draftId,
    text: '洗澡时宝宝不想碰水。',
    entrySource: CustomSceneEntrySource.today,
    requestIdentity: CustomSceneRequestIdentity(clientRequestId: requestId),
    state: CustomSceneStoredDraftState.readyForHandoff,
    expectedAccountContext: accountContext,
    registeredContentId: generatedContentId,
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 15)),
  );
}

CustomSceneSubmissionController _controller({
  required CustomSceneDraftStore store,
  required DateTime now,
}) {
  return CustomSceneSubmissionController(
    repository: _Repository(),
    draftStore: store,
    draftContinuationCoordinator: CustomSceneDraftContinuationCoordinator(
      draftStore: store,
      authContinuationCoordinator: AuthContinuationCoordinator(
        store: AuthContinuationStore(
          directoryResolver: () async => Directory.systemTemp,
        ),
        clock: () => now,
      ),
      clock: () => now,
    ),
    approvedContentRegistrar: _Registrar(),
    accountContextLoader: () async => 'account_a',
    clock: () => now,
  );
}

class _HandoffSink implements CustomSceneCareTurnHandoffSink {
  _HandoffSink({this.shouldFail = false});

  bool shouldFail;
  final List<String> ids = <String>[];
  final List<Completer<void>> routeCompletions = <Completer<void>>[];

  @override
  Future<CustomSceneCareTurnRouteAttempt> handoff(
    CustomSceneCareTurnHandoff handoff,
  ) {
    ids.add(handoff.generatedContentId);
    if (shouldFail) {
      throw StateError('route unavailable');
    }
    final completion = Completer<void>();
    routeCompletions.add(completion);
    return Future<CustomSceneCareTurnRouteAttempt>.value(
      CustomSceneCareTurnRouteAttempt(routeCompletion: completion.future),
    );
  }

  Future<void> completeRoute(int index) async {
    routeCompletions[index].complete();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> completeLatestRoute() {
    return completeRoute(routeCompletions.length - 1);
  }
}

class _Repository implements CustomSceneRepository {
  @override
  Future<GeneratedCareMoment> generate(CustomSceneDraft draft) {
    throw UnimplementedError('recovery must not generate');
  }
}

class _CallbackRepository implements CustomSceneRepository {
  _CallbackRepository(this.handler);

  final Future<GeneratedCareMoment> Function(CustomSceneDraft draft) handler;
  final List<CustomSceneDraft> received = <CustomSceneDraft>[];

  @override
  Future<GeneratedCareMoment> generate(CustomSceneDraft draft) {
    received.add(draft);
    return handler(draft);
  }
}

class _SuccessfulRegistrar implements CustomSceneApprovedContentRegistrar {
  int calls = 0;

  @override
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  }) async {
    calls += 1;
  }
}

class _FailingSubmittingDraftStore extends CustomSceneDraftStore {
  _FailingSubmittingDraftStore({required super.directoryResolver});

  bool failSubmittingWrite = false;

  @override
  Future<void> write(CustomSceneStoredDraft draft) {
    if (failSubmittingWrite &&
        draft.state == CustomSceneStoredDraftState.submitting) {
      throw const CustomSceneDraftStoreException();
    }
    return super.write(draft);
  }
}

class _AuthRecoveryScenario {
  const _AuthRecoveryScenario({
    required this.draftStore,
    required this.authStore,
    required this.draftContinuation,
    required this.repository,
    required this.registrar,
    required this.handoff,
    required this.controller,
    required this.coordinator,
  });

  final CustomSceneDraftStore draftStore;
  final AuthContinuationStore authStore;
  final CustomSceneDraftContinuationCoordinator draftContinuation;
  final _CallbackRepository repository;
  final _SuccessfulRegistrar registrar;
  final _HandoffSink handoff;
  final CustomSceneSubmissionController controller;
  final CustomSceneRecoveryCoordinator coordinator;

  void dispose() {
    coordinator.dispose();
    controller.dispose();
  }
}

_AuthRecoveryScenario _authRecoveryScenario({
  required Directory tempDir,
  required DateTime Function() clock,
  CustomSceneDraftStore? draftStore,
}) {
  final resolvedDraftStore =
      draftStore ??
      CustomSceneDraftStore(directoryResolver: () async => tempDir);
  final authStore = AuthContinuationStore(
    directoryResolver: () async => tempDir,
  );
  final authContinuation = AuthContinuationCoordinator(
    store: authStore,
    clock: clock,
    correlationIdGenerator: () => 'synthetic_auth_failure_60',
  );
  final draftContinuation = CustomSceneDraftContinuationCoordinator(
    draftStore: resolvedDraftStore,
    authContinuationCoordinator: authContinuation,
    clock: clock,
    draftIdGenerator: () => 'synthetic_draft_failure_60',
  );
  final repository = _CallbackRepository(
    (_) async => generatedCareMomentFixture(
      generatedContentId: 'synthetic_generated_failure_60',
    ),
  );
  final registrar = _SuccessfulRegistrar();
  final handoff = _HandoffSink();
  final controller = CustomSceneSubmissionController(
    repository: repository,
    draftStore: resolvedDraftStore,
    draftContinuationCoordinator: draftContinuation,
    approvedContentRegistrar: registrar,
    accountContextLoader: () async => 'synthetic_account_b',
    clock: clock,
  );
  final coordinator = CustomSceneRecoveryCoordinator(
    controller: controller,
    handoffSink: handoff,
  );
  return _AuthRecoveryScenario(
    draftStore: resolvedDraftStore,
    authStore: authStore,
    draftContinuation: draftContinuation,
    repository: repository,
    registrar: registrar,
    handoff: handoff,
    controller: controller,
    coordinator: coordinator,
  );
}

CustomSceneDraft _syntheticAuthDraft() {
  return CustomSceneDraft(
    text: 'SYNTHETIC_BATH_SCENE',
    entrySource: CustomSceneEntrySource.today,
    requestIdentity: CustomSceneRequestIdentity(
      clientRequestId: 'synthetic_request_failure_60',
    ),
  );
}

class _Registrar implements CustomSceneApprovedContentRegistrar {
  @override
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  }) async {
    throw UnimplementedError('recovery must not register');
  }
}
