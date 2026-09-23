import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_result.dart';

abstract interface class CustomSceneRepository {
  Future<CustomSceneResult> generate(CustomSceneDraft draft);
}
