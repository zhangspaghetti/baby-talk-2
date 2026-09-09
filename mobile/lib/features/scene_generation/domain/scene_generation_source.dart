enum SceneGenerationSourceType {
  custom('custom'),
  preset('preset');

  const SceneGenerationSourceType(this.wireValue);

  final String wireValue;

  static SceneGenerationSourceType parse(String value) {
    for (final candidate in values) {
      if (candidate.wireValue == value) {
        return candidate;
      }
    }
    throw const FormatException('unsupported scene generation source type');
  }
}

sealed class SceneGenerationSource {
  const SceneGenerationSource();
}

final class CustomSceneGenerationSource extends SceneGenerationSource {
  const CustomSceneGenerationSource(this.text);

  final String text;
}

final class PresetSceneGenerationSource extends SceneGenerationSource {
  const PresetSceneGenerationSource(
    this.presetSceneId, {
    this.presetSceneVersion,
    this.spaceId,
    this.activityId,
  });

  final String presetSceneId;

  /// Optional route metadata used to validate the generated response. These
  /// fields are client-side identity expectations and are not request content.
  final int? presetSceneVersion;
  final String? spaceId;
  final String? activityId;

  bool get hasCompleteIdentity =>
      presetSceneId.trim().isNotEmpty &&
      presetSceneVersion != null &&
      presetSceneVersion! > 0 &&
      spaceId?.trim().isNotEmpty == true &&
      activityId?.trim().isNotEmpty == true;
}
