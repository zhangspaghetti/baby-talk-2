import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_handoff_confirmation_coordinator.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_stored_draft.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';

void main() {
  test('matching confirmation alone clears ready handoff intent', () async {
    final tempDir = await Directory.systemTemp.createTemp('custom_handoff_');
    addTearDown(() => tempDir.delete(recursive: true));
    final now = DateTime.utc(2026, 7, 29, 9);
    final draftStore = CustomSceneDraftStore(
      directoryResolver: () async => tempDir,
    );
    await draftStore.write(
      CustomSceneStoredDraft(
        draftId: 'draft_1',
        text: '洗澡时宝宝不想碰水。',
        entrySource: CustomSceneEntrySource.today,
        requestIdentity: CustomSceneRequestIdentity(
          clientRequestId: 'request_1',
        ),
        state: CustomSceneStoredDraftState.readyForHandoff,
        expectedAccountContext: 'account_a',
        registeredContentId: 'generated_1',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
      ),
    );
    final continuation = CustomSceneDraftContinuationCoordinator(
      draftStore: draftStore,
      authContinuationCoordinator: AuthContinuationCoordinator(
        store: AuthContinuationStore(directoryResolver: () async => tempDir),
        clock: () => now,
      ),
      clock: () => now,
    );
    final resumeStore = GeneratedCareTurnResumeMarkerStore(
      directoryResolver: () async => tempDir,
    );

    final wrongAccount = CustomSceneHandoffConfirmationCoordinator(
      draftContinuationCoordinator: continuation,
      accountContextLoader: () async => 'account_b',
      generatedCareTurnResumeStore: resumeStore,
      clock: () => now,
    );
    expect(
      await wrongAccount.confirm(generatedContentId: 'generated_1'),
      isFalse,
    );
    expect(
      (await draftStore.readResult(now: now)).draft?.registeredContentId,
      'generated_1',
    );
    expect(await resumeStore.readForAccount('account_b'), isNull);

    final unavailablePersistence = CustomSceneHandoffConfirmationCoordinator(
      draftContinuationCoordinator: continuation,
      accountContextLoader: () async => 'account_a',
      generatedCareTurnResumeStore: GeneratedCareTurnResumeMarkerStore(
        directoryResolver: () async => throw StateError('disk unavailable'),
      ),
      clock: () => now,
    );
    expect(
      await unavailablePersistence.confirm(generatedContentId: 'generated_1'),
      isFalse,
    );
    expect(
      (await draftStore.readResult(now: now)).draft?.registeredContentId,
      'generated_1',
    );

    final matchingAccount = CustomSceneHandoffConfirmationCoordinator(
      draftContinuationCoordinator: continuation,
      accountContextLoader: () async => 'account_a',
      generatedCareTurnResumeStore: resumeStore,
      clock: () => now,
    );
    expect(
      await matchingAccount.confirm(generatedContentId: 'generated_1'),
      isTrue,
    );
    expect(
      (await draftStore.readResult(now: now)).status,
      CustomSceneDraftReadStatus.notFound,
    );
    final resumeMarker = await resumeStore.readForAccount('account_a');
    expect(resumeMarker?.generatedContentId, 'generated_1');
    expect(resumeMarker?.confirmedAt, now);
    expect(
      await matchingAccount.confirm(generatedContentId: 'generated_1'),
      isFalse,
    );
  });
}
