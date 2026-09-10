import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/practice/domain/generated_care_turn_resume.dart';

typedef CustomSceneHandoffAccountContextLoader = Future<String?> Function();

/// Confirms only an interactively established Care Turn. This coordinator owns
/// durable-intent cleanup; a destination never deletes custom-scene storage.
class CustomSceneHandoffConfirmationCoordinator {
  CustomSceneHandoffConfirmationCoordinator({
    required CustomSceneDraftContinuationCoordinator
    draftContinuationCoordinator,
    required CustomSceneHandoffAccountContextLoader accountContextLoader,
    required GeneratedCareTurnResumeStore generatedCareTurnResumeStore,
    DateTime Function()? clock,
  }) : _draftContinuationCoordinator = draftContinuationCoordinator,
       _accountContextLoader = accountContextLoader,
       _generatedCareTurnResumeStore = generatedCareTurnResumeStore,
       _clock = clock ?? DateTime.now;

  final CustomSceneDraftContinuationCoordinator _draftContinuationCoordinator;
  final CustomSceneHandoffAccountContextLoader _accountContextLoader;
  final GeneratedCareTurnResumeStore _generatedCareTurnResumeStore;
  final DateTime Function() _clock;

  Future<bool> confirm({required String generatedContentId}) async {
    final normalizedContentId = generatedContentId.trim();
    if (normalizedContentId.isEmpty) {
      return false;
    }
    try {
      final accountContext = (await _accountContextLoader())?.trim();
      if (accountContext == null || accountContext.isEmpty) {
        return false;
      }
      return _draftContinuationCoordinator.completeHandoff(
        generatedContentId: normalizedContentId,
        accountContext: accountContext,
        beforeIntentCleanup: () => _generatedCareTurnResumeStore.write(
          accountContext: accountContext,
          generatedContentId: normalizedContentId,
          confirmedAt: _clock().toUtc(),
        ),
      );
    } on Object {
      return false;
    }
  }
}
