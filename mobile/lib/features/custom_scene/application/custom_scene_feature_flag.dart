import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Release remains opt-in until #23/#24/#25/#26/#27 gates are complete.
const customSceneFeatureEnabledByDefault = bool.fromEnvironment(
  'BABY_TALK_CUSTOM_SCENE_ENABLED',
  defaultValue: false,
);

final customSceneFeatureEnabledProvider = Provider<bool>((ref) {
  return customSceneFeatureEnabledByDefault;
});
