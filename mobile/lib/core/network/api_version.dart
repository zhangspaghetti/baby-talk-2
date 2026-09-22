/// Single client API-version default shared by every authenticated and guest
/// transport. Build-time overrides remain available for QA and production.
const String defaultAppApiVersion = String.fromEnvironment(
  'BABY_TALK_API_VERSION',
  defaultValue: '1.3.0',
);
