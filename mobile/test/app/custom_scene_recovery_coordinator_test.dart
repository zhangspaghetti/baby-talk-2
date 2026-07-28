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
      );
      expect(handoff.ids, <String>['generated_1']);
      expect(controller.state.generatedContentId, 'generated_1');

      await coordinator.recoverForAuthenticatedAccount(
        accountContext: 'account_a',
      );
      expect(handoff.ids, <String>['generated_1']);
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
    'route failure retains intent and retry never generates again',
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

      handoff.shouldFail = false;
      await coordinator.openPreparedContent();
      expect(handoff.ids, <String>['generated_1', 'generated_1']);
      expect(controller.state.canOpenPreparedContent, isTrue);
    },
  );
}

CustomSceneStoredDraft _readyDraft(DateTime now) {
  return CustomSceneStoredDraft(
    draftId: 'draft_1',
    text: '洗澡时宝宝不想碰水。',
    entrySource: CustomSceneEntrySource.today,
    requestIdentity: CustomSceneRequestIdentity(clientRequestId: 'request_1'),
    state: CustomSceneStoredDraftState.readyForHandoff,
    expectedAccountContext: 'account_a',
    registeredContentId: 'generated_1',
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

  @override
  Future<void> handoff(CustomSceneCareTurnHandoff handoff) async {
    ids.add(handoff.generatedContentId);
    if (shouldFail) {
      throw StateError('route unavailable');
    }
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
