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
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';

void main() {
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

class _Registrar implements CustomSceneApprovedContentRegistrar {
  @override
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  }) async {
    throw UnimplementedError('recovery must not register');
  }
}
