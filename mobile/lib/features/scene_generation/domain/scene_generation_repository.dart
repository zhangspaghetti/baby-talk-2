import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

abstract interface class SceneGenerationRepository {
  Future<GeneratedCareMoment> generate({
    required SceneGenerationSource source,
    required String clientRequestId,
  });
}
