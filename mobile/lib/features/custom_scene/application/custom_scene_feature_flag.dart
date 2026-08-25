import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Production builds expose custom-scene entry by default.
///
/// `BABY_TALK_CUSTOM_SCENE_ENABLED=false` remains available for an explicitly
/// disabled development or rollback build. Release gates must prove the
/// default stays enabled and that production backend routing is agentic.
const customSceneFeatureEnabledByDefault = bool.fromEnvironment(
  'BABY_TALK_CUSTOM_SCENE_ENABLED',
  defaultValue: true,
);

final customSceneFeatureEnabledProvider = Provider<bool>((ref) {
  return customSceneFeatureEnabledByDefault;
});
