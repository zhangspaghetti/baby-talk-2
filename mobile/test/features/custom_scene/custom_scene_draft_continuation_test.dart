import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';

void main() {
  group('CustomSceneDraftContinuationCoordinator', () {
    late Directory tempDir;
    late DateTime now;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('custom_scene_draft_');
      now = DateTime.utc(2026, 7, 28, 12);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'persists raw text only in draft store and binds first signed account',
      () async {
        final draftStore = CustomSceneDraftStore(
          directoryResolver: () async => tempDir,
        );
        final authStore = AuthContinuationStore(
          directoryResolver: () async => tempDir,
        );
        final coordinator = _coordinator(
          draftStore: draftStore,
          authStore: authStore,
          clock: () => now,
        );
        final draft = _draft();

        final pending = await coordinator.beginAuthentication(draft: draft);

        expect(
          pending.state,
          CustomSceneStoredDraftState.awaitingAuthentication,
        );
        final authRaw = await File(
          '${tempDir.path}/auth_continuation.json',
        ).readAsString();
        expect(authRaw, isNot(contains(draft.text)));
        final draftRaw = await File(
          '${tempDir.path}/custom_scene_draft.json',
        ).readAsString();
        expect(draftRaw, contains(draft.text));

        final restartedCoordinator = _coordinator(
          draftStore: draftStore,
          authStore: authStore,
          clock: () => now,
        );
        final resumed = await restartedCoordinator.readForAuthenticatedResume(
          accountContext: 'account_a',
        );

        expect(
          resumed.status,
          CustomSceneDraftContinuationStatus.readyForSubmission,
        );
        expect(resumed.draft?.draftId, pending.draftId);
        expect(
          resumed.draft?.state,
          CustomSceneStoredDraftState.authenticationResolved,
        );
        expect(resumed.draft?.expectedAccountContext, 'account_a');
        expect(
          resumed.draft?.requestIdentity.clientRequestId,
          'custom_request_1',
        );
      },
    );

    test('account switch clears both records before any submission', () async {
      final draftStore = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      final authStore = AuthContinuationStore(
        directoryResolver: () async => tempDir,
      );
      final coordinator = _coordinator(
        draftStore: draftStore,
        authStore: authStore,
        clock: () => now,
      );
      await coordinator.beginAuthentication(
        draft: _draft(),
        expectedAccountContext: 'account_a',
      );

      final result = await coordinator.readForAuthenticatedResume(
        accountContext: 'account_b',
      );

      expect(result.status, CustomSceneDraftContinuationStatus.accountMismatch);
      expect(
        (await draftStore.readResult(now: now)).status,
        CustomSceneDraftReadStatus.notFound,
      );
      expect(
        (await authStore.readResult(now: now)).status,
        AuthContinuationReadStatus.notFound,
      );
    });

    test(
      'double-tap reuses the first pending draft and request identity',
      () async {
        final draftStore = CustomSceneDraftStore(
          directoryResolver: () async => tempDir,
        );
        final authStore = AuthContinuationStore(
          directoryResolver: () async => tempDir,
        );
        final coordinator = _coordinator(
          draftStore: draftStore,
          authStore: authStore,
          clock: () => now,
        );

        final results = await Future.wait(<Future<CustomSceneStoredDraft>>[
          coordinator.beginAuthentication(
            draft: _draft(clientRequestId: 'custom_request_first'),
          ),
          coordinator.beginAuthentication(
            draft: _draft(
              text: '第二次点击不能替换第一笔请求。',
              clientRequestId: 'custom_request_second',
            ),
          ),
        ]);

        expect(results[1].draftId, results[0].draftId);
        expect(
          results[1].requestIdentity.clientRequestId,
          'custom_request_first',
        );
        final resumed = await Future.wait(
          List<Future<CustomSceneDraftContinuationResult>>.generate(
            2,
            (_) => coordinator.readForAuthenticatedResume(
              accountContext: 'account_a',
            ),
          ),
        );
        expect(
          resumed.map((result) => result.status),
          everyElement(CustomSceneDraftContinuationStatus.readyForSubmission),
        );
        expect(
          resumed.map(
            (result) => result.draft?.requestIdentity.clientRequestId,
          ),
          everyElement('custom_request_first'),
        );
      },
    );

    test('expiry and cancel clear raw text and continuation', () async {
      final draftStore = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      final authStore = AuthContinuationStore(
        directoryResolver: () async => tempDir,
      );
      final coordinator = _coordinator(
        draftStore: draftStore,
        authStore: authStore,
        clock: () => now,
      );
      await coordinator.beginAuthentication(draft: _draft());
      now = now.add(const Duration(minutes: 16));

      final expired = await coordinator.readForAuthenticatedResume(
        accountContext: 'account_a',
      );

      expect(expired.status, CustomSceneDraftContinuationStatus.expired);
      expect(
        (await draftStore.readResult(now: now)).status,
        CustomSceneDraftReadStatus.notFound,
      );

      now = DateTime.utc(2026, 7, 28, 13);
      await coordinator.beginAuthentication(draft: _draft());
      await coordinator.cancel();
      expect(
        (await draftStore.readResult(now: now)).status,
        CustomSceneDraftReadStatus.notFound,
      );
      expect(
        (await authStore.readResult(now: now)).status,
        AuthContinuationReadStatus.notFound,
      );
    });
  });
}

CustomSceneDraftContinuationCoordinator _coordinator({
  required CustomSceneDraftStore draftStore,
  required AuthContinuationStore authStore,
  required DateTime Function() clock,
}) {
  return CustomSceneDraftContinuationCoordinator(
    draftStore: draftStore,
    authContinuationCoordinator: AuthContinuationCoordinator(
      store: authStore,
      clock: clock,
      correlationIdGenerator: () => 'auth_custom_scene_1',
    ),
    clock: clock,
    draftIdGenerator: () => 'draft_1',
  );
}

CustomSceneDraft _draft({
  String text = '宝宝洗澡时一直躲水。',
  String clientRequestId = 'custom_request_1',
}) {
  return CustomSceneDraft(
    text: text,
    entrySource: CustomSceneEntrySource.today,
    requestIdentity: CustomSceneRequestIdentity(
      clientRequestId: clientRequestId,
    ),
  );
}
