import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_failure.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_repository.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

class CustomSceneRepositoryImpl implements CustomSceneRepository {
  CustomSceneRepositoryImpl({
    required SceneGenerationRepository sceneGenerationRepository,
  }) : _sceneGenerationRepository = sceneGenerationRepository;

  final SceneGenerationRepository _sceneGenerationRepository;

  @override
  Future<GeneratedCareMoment> generate(CustomSceneDraft draft) async {
    _validateClientRequestId(draft.requestIdentity.clientRequestId);
    try {
      return await _sceneGenerationRepository.generate(
        source: CustomSceneGenerationSource(draft.text),
        clientRequestId: draft.requestIdentity.clientRequestId,
      );
    } on SceneGenerationFailure catch (failure) {
      throw _mapFailure(failure);
    }
  }

  void _validateClientRequestId(String value) {
    final validShape = RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$',
    ).hasMatch(value);
    final exposesPhoneLikeSequence = RegExp(r'[0-9]{11,}').hasMatch(value);
    if (!validShape || exposesPhoneLikeSequence) {
      throw const CustomSceneFailure(
        kind: CustomSceneFailureKind.invalidDraft,
        retryable: false,
      );
    }
  }

  CustomSceneFailure _mapFailure(SceneGenerationFailure failure) {
    final kind = switch (failure.kind) {
      SceneGenerationFailureKind.authenticationRequired =>
        CustomSceneFailureKind.authenticationRequired,
      SceneGenerationFailureKind.profileUnavailable =>
        CustomSceneFailureKind.profileUnavailable,
      SceneGenerationFailureKind.sharedProfileUnavailable =>
        CustomSceneFailureKind.sharedProfileUnavailable,
      SceneGenerationFailureKind.householdAccessRequired =>
        CustomSceneFailureKind.householdAccessRequired,
      SceneGenerationFailureKind.presetSceneUnavailable =>
        CustomSceneFailureKind.presetSceneUnavailable,
      SceneGenerationFailureKind.invalidInput =>
        CustomSceneFailureKind.invalidDraft,
      SceneGenerationFailureKind.requestConflict =>
        CustomSceneFailureKind.requestConflict,
      SceneGenerationFailureKind.requestTerminal =>
        CustomSceneFailureKind.requestTerminal,
      SceneGenerationFailureKind.generationInProgress =>
        CustomSceneFailureKind.generationInProgress,
      SceneGenerationFailureKind.rateLimited =>
        CustomSceneFailureKind.rateLimited,
      SceneGenerationFailureKind.unavailable =>
        CustomSceneFailureKind.unavailable,
      SceneGenerationFailureKind.timeout => CustomSceneFailureKind.timeout,
      SceneGenerationFailureKind.network => CustomSceneFailureKind.network,
      SceneGenerationFailureKind.malformedResponse =>
        CustomSceneFailureKind.malformedResponse,
      SceneGenerationFailureKind.rejected => CustomSceneFailureKind.rejected,
      SceneGenerationFailureKind.unexpected =>
        CustomSceneFailureKind.unexpected,
    };
    return CustomSceneFailure(
      kind: kind,
      retryable: failure.retryable,
      generatedContentId: failure.generatedContentId,
      requiresNewClientRequestId: failure.requiresNewClientRequestId,
    );
  }
}
