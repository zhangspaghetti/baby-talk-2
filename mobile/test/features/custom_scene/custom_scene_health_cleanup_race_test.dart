import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_result.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';

void main() {
  test(
    'health cleanup survives immediate edit and preserves newer draft',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'custom_scene_health_cleanup_race_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final now = DateTime.utc(2026, 7, 28, 15);
      final draftStore = CustomSceneDraftStore(
        directoryResolver: () async => directory,
      );
      final continuation = _RecordingContinuationCoordinator(
        draftStore: draftStore,
        authContinuationCoordinator: AuthContinuationCoordinator(
          store: AuthContinuationStore(
            directoryResolver: () async => directory,
          ),
          clock: () => now,
          correlationIdGenerator: () => 'auth_continuation_1',
        ),
        clock: () => now,
        draftIdGenerator: () => 'draft_1',
      );
      final controller = CustomSceneSubmissionController(
        repository: _HealthRepository(),
        draftStore: draftStore,
        draftContinuationCoordinator: continuation,
        approvedContentRegistrar: _Registrar(),
        accountContextLoader: () async => 'account_a',
        clock: () => now,
        draftIdGenerator: () => 'draft_1',
      );
      addTearDown(controller.dispose);
      final draft = CustomSceneDraft(
        text: '宝宝现在不舒服。',
        entrySource: CustomSceneEntrySource.today,
        requestIdentity: CustomSceneRequestIdentity(
          clientRequestId: 'request_1',
        ),
      );
      await continuation.beginAuthentication(draft: draft);

      var replaced = false;
      controller.addListener(() {
        if (replaced ||
            controller.state.phase != CustomSceneSubmissionPhase.healthSafety) {
          return;
        }
        replaced = true;
        unawaited(controller.modifyDescription());
        unawaited(
          draftStore.write(
            CustomSceneStoredDraft(
              draftId: 'new_draft',
              text: '新的描述。',
              entrySource: CustomSceneEntrySource.today,
              requestIdentity: CustomSceneRequestIdentity(
                clientRequestId: 'new_request',
              ),
              state: CustomSceneStoredDraftState.editing,
              expectedAccountContext: 'account_a',
              createdAt: now,
              expiresAt: now.add(const Duration(minutes: 15)),
            ),
          ),
        );
      });

      await controller.submit(draft);

      expect(
        (await draftStore.readResult(now: now)).draft?.draftId,
        'new_draft',
      );
      expect(continuation.cleanupCalls, <String>[
        'draft_1|request_1|account_a',
      ]);
    },
  );
}

class _HealthRepository implements CustomSceneRepository {
  @override
  Future<CustomSceneResult> generate(CustomSceneDraft draft) async {
    return const HealthSafetyResult(
      HealthSafetyNotice(
        action: 'emergency',
        templateId: 'health-emergency-v1',
        policyVersion: generatedCareSafetyPolicyVersion,
        locale: 'zh-CN',
        titleZh: '先关注宝宝的身体状况',
        messageZh: '请联系儿科医生进行评估。',
      ),
    );
  }
}

class _Registrar implements CustomSceneApprovedContentRegistrar {
  @override
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  }) async {}
}

class _RecordingContinuationCoordinator
    extends CustomSceneDraftContinuationCoordinator {
  _RecordingContinuationCoordinator({
    required super.draftStore,
    required super.authContinuationCoordinator,
    required super.clock,
    required super.draftIdGenerator,
  });

  final List<String> cleanupCalls = <String>[];

  @override
  Future<void> clearAuthenticationContinuationIfMatches({
    required String draftId,
    required String clientRequestId,
    required String? expectedAccountContext,
  }) {
    cleanupCalls.add(
      '$draftId|$clientRequestId|${expectedAccountContext ?? '<none>'}',
    );
    return super.clearAuthenticationContinuationIfMatches(
      draftId: draftId,
      clientRequestId: clientRequestId,
      expectedAccountContext: expectedAccountContext,
    );
  }
}
