import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';

typedef CustomSceneHandoffAccountContextLoader = Future<String?> Function();

/// Confirms only an interactively established Care Turn. This coordinator owns
/// durable-intent cleanup; a destination never deletes custom-scene storage.
class CustomSceneHandoffConfirmationCoordinator {
  CustomSceneHandoffConfirmationCoordinator({
    required CustomSceneDraftContinuationCoordinator
    draftContinuationCoordinator,
    required CustomSceneHandoffAccountContextLoader accountContextLoader,
  }) : _draftContinuationCoordinator = draftContinuationCoordinator,
       _accountContextLoader = accountContextLoader;

  final CustomSceneDraftContinuationCoordinator _draftContinuationCoordinator;
  final CustomSceneHandoffAccountContextLoader _accountContextLoader;

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
      );
    } on Object {
      return false;
    }
  }
}
