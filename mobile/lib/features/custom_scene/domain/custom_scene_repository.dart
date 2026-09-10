import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';

abstract interface class CustomSceneRepository {
  Future<GeneratedCareMoment> generate(CustomSceneDraft draft);
}
