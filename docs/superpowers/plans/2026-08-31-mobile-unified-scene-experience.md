# Mobile Unified Scene Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the new mobile client that loads published preset scenes, routes every signed-in preset practice through unified generation, retains curated fallback, and shows household role/profile state clearly.

**Architecture:** Add one source-tagged scene-generation transport/repository used by custom and preset entry points. Put a generation gate in the central practice route so Today, Discover, share/invite reentry, and continuity cannot bypass personalization; generated preset events retain stable activity identity while bundled content remains an explicit fallback.

**Tech Stack:** Flutter, Dart, Riverpod 2.6.1, GoRouter 14.8.1, Dio 5.7, file-backed atomic JSON caches, existing Isar practice events, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-31-unified-scene-generation-household-profile-design.md`

## Global Constraints

- Complete both backend plans first; this plan requires `GET /api/v1/practice/preset-scenes` and `POST /api/v1/practice/scene-generations`.
- Set the mobile API version constant to `1.3.0`; do not call the removed discovery generation contract.
- Never send `babyProfileId`, `ageRange`, `parentGoal`, baby name, household ID, or role.
- `generationBrief` never appears in mobile DTOs, stores, logs, or UI.
- Remote catalog order is remote response, then last-good atomic cache, then `assets/content/seed_content.json`.
- Bundled phrases/audio are labeled generic fallback and are never registered as generated personalized content.
- Registration/onboarding uses `OnboardingCareTurnRouteArgs` and remains curated static preview.
- All `PracticeRouteArgs` entering the signed-in app pass through the preset generation gate; `GeneratedCareTurnRouteArgs` bypasses it.
- Add user-visible copy to `mobile/lib/l10n/app_zh.arb`, then regenerate localization files; do not hand-edit generated localization Dart.
- Preserve unrelated worktree changes; never commit `mobile/windows/flutter/generated_plugin_registrant.*` or `generated_plugins.cmake` for this feature.

---

## File Structure

### Unified generation feature

- Create `mobile/lib/features/scene_generation/domain/scene_generation_source.dart`.
- Create `mobile/lib/features/scene_generation/domain/scene_generation_failure.dart`.
- Create `mobile/lib/features/scene_generation/domain/scene_generation_repository.dart`.
- Move `mobile/lib/features/custom_scene/domain/generated_care_moment.dart` to `mobile/lib/features/scene_generation/domain/generated_care_moment.dart` and extend source metadata.
- Create `mobile/lib/features/scene_generation/data/scene_generation_dtos.dart`.
- Create `mobile/lib/features/scene_generation/data/scene_generation_api.dart`.
- Create `mobile/lib/features/scene_generation/data/scene_generation_mapper.dart`.
- Create `mobile/lib/features/scene_generation/data/scene_generation_repository_impl.dart`.
- Create `mobile/lib/features/scene_generation/application/scene_generation_controller.dart`.
- Modify `mobile/lib/features/account/data/services/account_api_service.dart`: default API version `1.3.0`.

### Preset catalog and launch gate

- Create `mobile/lib/features/practice/domain/models/preset_scene_definition.dart`.
- Create `mobile/lib/features/practice/data/remote/preset_scene_catalog_api.dart`.
- Create `mobile/lib/features/practice/data/local/preset_scene_catalog_store.dart`.
- Create `mobile/lib/features/practice/data/repositories/preset_scene_catalog_repository.dart`.
- Create `mobile/lib/features/practice/presentation/screens/preset_scene_generation_gate_screen.dart`.
- Modify `practice_route_args.dart`, `app_go_router.dart`, `PracticeRepository`, and generated registry/store.

### Custom flow and household UI

- Modify custom draft/controller/repository/screens to use the unified repository.
- Delete `custom_scene_profile_context_resolver.dart` and its two tests.
- Remove shared-profile-context additions from `household_api_service.dart` and providers.
- Modify custom entry gating, Home, Discover, AppShell, Me screen, error CTA, and localization ARB.

---

### Task 1: Add the strict unified scene-generation client

**Files:**
- Create: `mobile/lib/features/scene_generation/domain/scene_generation_source.dart`
- Create: `mobile/lib/features/scene_generation/domain/scene_generation_failure.dart`
- Create: `mobile/lib/features/scene_generation/domain/scene_generation_repository.dart`
- Move: `mobile/lib/features/custom_scene/domain/generated_care_moment.dart` to `mobile/lib/features/scene_generation/domain/generated_care_moment.dart`
- Create: `mobile/lib/features/scene_generation/data/scene_generation_dtos.dart`
- Create: `mobile/lib/features/scene_generation/data/scene_generation_api.dart`
- Create: `mobile/lib/features/scene_generation/data/scene_generation_mapper.dart`
- Create: `mobile/lib/features/scene_generation/data/scene_generation_repository_impl.dart`
- Create tests under `mobile/test/features/scene_generation/`.
- Modify: `mobile/lib/features/account/data/services/account_api_service.dart`
- Modify: `mobile/test/core/network/bearer_authorization_header_test.dart`

**Interfaces:**
- Produces: `Future<GeneratedCareMoment> SceneGenerationRepository.generate({required SceneGenerationSource source, required String clientRequestId})`.

- [ ] **Step 1: Write failing exact-JSON and mapping tests**

Define sources:

```dart
sealed class SceneGenerationSource {
  const SceneGenerationSource();
}

final class CustomSceneGenerationSource extends SceneGenerationSource {
  const CustomSceneGenerationSource(this.text);
  final String text;
}

final class PresetSceneGenerationSource extends SceneGenerationSource {
  const PresetSceneGenerationSource(this.presetSceneId);
  final String presetSceneId;
}
```

Assert preset JSON contains only `source`, `locale`, `installationId`, `clientRequestId`, with source keys `type/presetSceneId`. Assert custom source keys are `type/text`. Explicitly assert absence of `babyProfileId`, `ageRange`, `parentGoal`, and `generationBrief`.

- [ ] **Step 2: Run tests and verify RED**

```bash
cd mobile
flutter test test/features/scene_generation
```

Expected: missing files/types.

- [ ] **Step 3: Define response/source metadata**

Extend `GeneratedCareMoment` with:

```dart
enum SceneGenerationSourceType { custom, preset }

final SceneGenerationSourceType inputSource;
final String? presetSceneId;
final int? presetSceneVersion;
```

Validate custom has null preset metadata and preset has non-empty ID/positive version. Keep six-utterance/provenance validation unchanged.

- [ ] **Step 4: Implement API and repository**

POST to `/api/v1/practice/scene-generations` through `AuthenticatedApiClient`. Change the shared constant to:

```dart
const String defaultAccountApiVersion = String.fromEnvironment(
  'BABY_TALK_API_VERSION',
  defaultValue: '1.3.0',
);
```

The repository loads session, locale, installation ID, and request ID; it does not depend on baby profile or household repositories.

- [ ] **Step 5: Map stable error kinds**

Support exact failure kinds:

```dart
enum SceneGenerationFailureKind {
  authenticationRequired,
  profileUnavailable,
  sharedProfileUnavailable,
  householdAccessRequired,
  presetSceneUnavailable,
  invalidInput,
  requestConflict,
  requestTerminal,
  generationInProgress,
  rateLimited,
  unavailable,
  timeout,
  network,
  malformedResponse,
  rejected,
  unexpected,
}
```

Preserve `generatedContentId`, `retryable`, and `requiresNewClientRequestId` recovery metadata.

- [ ] **Step 6: Run tests and verify GREEN**

Run Step 2. Expected: exit 0.

- [ ] **Step 7: Commit Task 1**

```bash
git add mobile/lib/features/scene_generation mobile/lib/features/custom_scene/domain/generated_care_moment.dart mobile/lib/features/account/data/services/account_api_service.dart mobile/test/features/scene_generation mobile/test/core/network/bearer_authorization_header_test.dart
git commit -m "feat(mobile): add unified scene client"
```

---

### Task 2: Add remote-first published preset catalog

**Files:**
- Create: `preset_scene_definition.dart`
- Create: `preset_scene_catalog_api.dart`
- Create: `preset_scene_catalog_store.dart`
- Create: `preset_scene_catalog_repository.dart`
- Modify: `asset_phrase_service.dart`
- Modify: `practice_repository.dart`
- Create tests for API, store, repository, and practice catalog merge.

**Interfaces:**
- Produces: `Future<PresetSceneCatalogSnapshot> loadCatalog()` with source `remote/cache/bundled`.

- [ ] **Step 1: Write failing priority and strict-contract tests**

Test remote success persists and returns remote; remote failure returns last-good cache; malformed cache is quarantined and falls back to bundled; first-install offline returns all five bundled scenes; public JSON containing `generationBrief` is rejected as malformed.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd mobile
flutter test test/features/practice/preset_scene_catalog_api_test.dart test/features/practice/preset_scene_catalog_store_test.dart test/features/practice/preset_scene_catalog_repository_test.dart
```

- [ ] **Step 3: Implement immutable models and API**

```dart
class PresetSceneDefinition {
  const PresetSceneDefinition({
    required this.presetSceneId,
    required this.publishedVersion,
    required this.spaceId,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.sortOrder,
  });
  final String presetSceneId;
  final int publishedVersion;
  final String spaceId;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final int sortOrder;
}
```

Use exact-key parsing and reject unknown fields.

- [ ] **Step 4: Implement atomic last-good store**

Use a versioned JSON root, temporary sibling file, flush, and replace pattern matching `custom_scene_draft_store.dart`. Never overwrite last-good data with malformed/empty remote data. Quarantine malformed files with a bounded suffix.

- [ ] **Step 5: Merge published metadata with bundled fallback phrases**

Inject the catalog repository into `PracticeRepository`. Build activity summaries from published title/summary/tag/tip/order while retaining matching bundled phrases only for generic fallback. Remote scene IDs missing from bundled content remain browsable/generatable but have no offline fallback.

- [ ] **Step 6: Run focused and repository tests**

```bash
flutter test test/features/practice/preset_scene_catalog_api_test.dart test/features/practice/preset_scene_catalog_store_test.dart test/features/practice/preset_scene_catalog_repository_test.dart test/features/practice/practice_repository_test.dart
```

Expected: exit 0.

- [ ] **Step 7: Commit Task 2**

```bash
git add mobile/lib/features/practice/domain/models/preset_scene_definition.dart mobile/lib/features/practice/data/remote/preset_scene_catalog_api.dart mobile/lib/features/practice/data/local/preset_scene_catalog_store.dart mobile/lib/features/practice/data/repositories/preset_scene_catalog_repository.dart mobile/lib/features/practice/data/repositories/practice_repository.dart mobile/lib/features/practice/data/services/asset_phrase_service.dart mobile/test/features/practice/preset_scene_catalog_api_test.dart mobile/test/features/practice/preset_scene_catalog_store_test.dart mobile/test/features/practice/preset_scene_catalog_repository_test.dart mobile/test/features/practice/practice_repository_test.dart
git commit -m "feat(mobile): cache published preset scenes"
```

---

### Task 3: Rewire custom scenes onto the unified client

**Files:**
- Modify: `custom_scene_submission_controller.dart`
- Modify: `custom_scene_repository.dart`
- Modify: `custom_scene_repository_impl.dart`
- Delete: `custom_scene_profile_context_resolver.dart`
- Delete: `custom_scene_profile_context_resolver_test.dart`
- Delete: `custom_scene_profile_context_resolver_network_test.dart`
- Remove old custom API/DTO/mapper files after all imports move to `scene_generation`.
- Modify: `repository_providers.dart`
- Modify: `household_api_service.dart`
- Modify existing custom-scene tests.

**Interfaces:**
- Consumes: unified `SceneGenerationRepository` from Task 1.
- Produces: existing custom draft/auth/recovery UX with the new transport.

- [ ] **Step 1: Rewrite tests to assert one request and no profile preflight**

Use a fake `SceneGenerationRepository` and assert:

```dart
expect(fake.sources.single, isA<CustomSceneGenerationSource>());
expect(householdApi.requestCount, 0);
expect(babyProfileRepository.loadCount, 0);
```

Remove tests whose only contract is resolving age/goal/profile on the client.

- [ ] **Step 2: Run custom tests and verify RED**

```bash
cd mobile
flutter test test/features/custom_scene
```

Expected: old repository still performs profile preflight or missing unified adapter.

- [ ] **Step 3: Make custom repository a thin adapter**

`CustomSceneRepository.generate(CustomSceneDraft)` validates request ID, then delegates:

```dart
return _sceneGenerationRepository.generate(
  source: CustomSceneGenerationSource(draft.text),
  clientRequestId: draft.requestIdentity.clientRequestId,
);
```

Keep draft persistence, auth continuation, unknown-result recovery, and approved-content handoff behavior.

- [ ] **Step 4: Remove the rejected two-request implementation**

Delete the profile context resolver and its tests. Remove `fetchSharedProfileContext`, `HouseholdSharedProfileContextResponse`, and `HouseholdCustomSceneSharedProfileContextSource`. Providers must construct only the unified repository plus custom adapter.

- [ ] **Step 5: Update deterministic error recovery**

`profileUnavailable`, `sharedProfileUnavailable`, `householdAccessRequired`, and `presetSceneUnavailable` occur before generation reservation and clear unsent attempts. Timeout/network/in-progress keep recovery state.

- [ ] **Step 6: Run custom tests and verify GREEN**

Run Step 2. Expected: exit 0.

- [ ] **Step 7: Commit Task 3**

```bash
git add mobile/lib/features/custom_scene mobile/lib/features/household/data/services/household_api_service.dart mobile/lib/app/providers/repository_providers.dart mobile/test/features/custom_scene
git commit -m "refactor(mobile): use unified custom generation"
```

---

### Task 4: Put preset generation in the central practice route

**Files:**
- Create: `scene_generation_controller.dart`
- Create: `preset_scene_generation_gate_screen.dart`
- Modify: `practice_route_args.dart`
- Modify: `app_go_router.dart`
- Modify: router, gate screen, Home, Discover, and continuity tests.

**Interfaces:**
- Produces: all `PracticeRouteArgs` go through generation; `GeneratedCareTurnRouteArgs` and `OnboardingCareTurnRouteArgs` remain direct.

- [ ] **Step 1: Write failing route/gate tests**

Assert:

- `PracticeRouteArgs(spaceId:'daily_care', activityId:'bath_time')` renders generation progress first.
- success replaces route entry with `GeneratedCareTurnRouteArgs`.
- generation failure shows retry and, when bundled content exists, “使用通用内容”.
- selecting generic content renders `PracticeSessionScreen` with original `PracticeRouteArgs` without re-entering the gate.
- onboarding args never invoke generation.

- [ ] **Step 2: Run tests and verify RED**

```bash
cd mobile
flutter test test/features/practice/preset_scene_generation_gate_screen_test.dart test/app/router/app_go_router_test.dart
```

- [ ] **Step 3: Add a route-entry policy**

Extend `PracticeRouteEntry`:

```dart
enum PracticeEntryKind { preset, generated, onboarding, invalid }

PracticeEntryKind get kind {
  if (args != null) return PracticeEntryKind.preset;
  if (generatedArgs != null) return PracticeEntryKind.generated;
  if (onboardingArgs != null) return PracticeEntryKind.onboarding;
  return PracticeEntryKind.invalid;
}
```

- [ ] **Step 4: Implement the generic controller**

`SceneGenerationController.generate(source, clientRequestId)` exposes idle/submitting/success/recoverableError/unknownOutcome states and delegates only to `SceneGenerationRepository`. Register approved bundles before reporting success.

- [ ] **Step 5: Implement the gate screen and central router branch**

In the practice route builder:

```dart
return switch (routeEntry.kind) {
  PracticeEntryKind.preset => PresetSceneGenerationGateScreen(routeEntry: routeEntry),
  PracticeEntryKind.generated || PracticeEntryKind.onboarding || PracticeEntryKind.invalid =>
      PracticeSessionScreen(routeEntry: routeEntry),
};
```

The gate owns a local `useGenericFallback` state so fallback renders the static session directly instead of pushing another preset route.

- [ ] **Step 6: Verify Today, Discover, share/invite, and continuity use `PracticeRouteArgs`**

Update tests at each launcher. No page may directly instantiate `PracticeSessionScreen` for preset content.

- [ ] **Step 7: Run route and launcher tests**

```bash
flutter test test/features/practice/preset_scene_generation_gate_screen_test.dart test/features/shell/discover_screen_test.dart test/features/practice/critical_ui_coverage_test.dart test/features/practice/generated_care_turn_handoff_readiness_test.dart
```

Expected: exit 0.

- [ ] **Step 8: Commit Task 4**

```bash
git add mobile/lib/features/scene_generation/application/scene_generation_controller.dart mobile/lib/features/practice/presentation/practice_route_args.dart mobile/lib/features/practice/presentation/screens/preset_scene_generation_gate_screen.dart mobile/lib/features/practice/presentation/screens/home_screen.dart mobile/lib/features/shell/presentation/screens/discover_screen.dart mobile/lib/app/router/app_go_router.dart mobile/test/features/practice/preset_scene_generation_gate_screen_test.dart mobile/test/app/router/app_go_router_test.dart mobile/test/features/shell/discover_screen_test.dart mobile/test/features/practice/critical_ui_coverage_test.dart mobile/test/features/practice/generated_care_turn_handoff_readiness_test.dart
git commit -m "feat(mobile): generate preset scenes on launch"
```

---

### Task 5: Attribute generated preset practice to stable catalog progress

**Files:**
- Modify: `generated_care_moment.dart`
- Modify: `generated_care_moment_local_store.dart`
- Modify: `generated_practice_content_registry.dart`
- Modify: `practice_repository.dart`
- Modify: `practice_activity_catalog.dart` only if source metadata is required in summaries.
- Modify generated registry/store/repository tests.

**Interfaces:**
- Consumes: generated preset metadata from Task 1.
- Produces: preset generated events update stable activity statistics and do not appear as standalone custom activities.

- [ ] **Step 1: Write failing attribution tests**

Register a preset bundle with `presetSceneId='bath_time'`, record an event with its `generatedContentId`, and assert:

```dart
expect(catalog.findActivity(spaceId: 'daily_care', activityId: 'bath_time')!.totalEvents, 1);
expect(catalog.activities.where((item) => item.generatedContentId != null), isEmpty);
```

Register a custom bundle and assert it remains a separate generated continuity activity.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd mobile
flutter test test/features/practice/generated/generated_practice_content_registry_test.dart test/features/practice/practice_repository_test.dart
```

- [ ] **Step 3: Version the local generated store**

Write source metadata in the next store schema. Read legacy records missing `inputSource` as custom so existing custom history survives upgrade. Reject preset records missing ID/version.

- [ ] **Step 4: Filter preset bundles from standalone projections**

`listGeneratedActivities()` returns only custom bundles. `resolveGeneratedContent()` continues returning both source types so route loading/audio work.

- [ ] **Step 5: Merge preset generated events into stable activity state**

When `_matchesGeneratedEvent` finds a preset bundle, call a dedicated `_CatalogActivityState.recordGeneratedPreset(event, snapshot)` for the stable activity instead of incrementing `knownGeneratedEvents` and skipping the catalog state. Keep phrase identity validation against the generated bundle.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run Step 2. Expected: exit 0.

- [ ] **Step 7: Commit Task 5**

```bash
git add mobile/lib/features/scene_generation/domain/generated_care_moment.dart mobile/lib/features/practice/data/generated/generated_care_moment_local_store.dart mobile/lib/features/practice/data/generated/generated_practice_content_registry.dart mobile/lib/features/practice/data/repositories/practice_repository.dart mobile/lib/features/practice/domain/models/practice_activity_catalog.dart mobile/test/features/practice/generated/generated_practice_content_registry_test.dart mobile/test/features/practice/practice_repository_test.dart
git commit -m "fix(mobile): attribute preset generated practice"
```

---

### Task 6: Expose household role and actionable generation errors

**Files:**
- Modify: `custom_scene_entry.dart`
- Modify: `home_screen.dart`
- Modify: `app_shell_screen.dart`
- Modify: `discover_screen.dart`
- Modify: `me_screen.dart`
- Modify: `custom_scene_input_screen.dart`
- Modify: `app_zh.arb`
- Regenerate: `app_localizations.dart`, `app_localizations_zh.dart`
- Modify related widget tests.

**Interfaces:**
- Produces: role-visible Me page and no caregiver entry hiding.

- [ ] **Step 1: Write failing UI tests**

Cover role labels:

```dart
expect(find.text('次照护者'), findsOneWidget);
expect(find.text('使用家庭共享宝宝档案'), findsOneWidget);
```

Also cover primary, loading, no membership, caregiver custom entry visibility, `sharedProfileUnavailable` copy/CTA, `householdAccessRequired` CTA, and personal `profileUnavailable` CTA.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd mobile
flutter test test/features/shell/me_screen_test.dart test/features/custom_scene/custom_scene_entry_test.dart test/features/custom_scene/custom_scene_input_screen_test.dart
```

- [ ] **Step 3: Remove role-based entry gating**

Delete `isCustomSceneEntryAllowedForRole` and stop reading household role solely to hide the entry in Home/AppShell/Discover. Feature flag remains the only entry-visibility gate.

- [ ] **Step 4: Add Me role presentation**

Watch `householdNotifierProvider` in `MeScreen` and pass a typed display model into `_UserInfoSection`:

```dart
typedef HouseholdIdentityLabel = ({String badge, String? detail});
```

Map loaded caregiver, loaded primary, loading/not-loaded, and loaded/no-membership to approved copy.

- [ ] **Step 5: Add recovery actions**

Expose failure kind/recovery action from submission state. Render “查看家庭状态” for household/shared-profile failures and navigate to existing account surface; render “完善宝宝档案” for personal profile failure.

- [ ] **Step 6: Add ARB strings and regenerate localization**

Run:

```bash
cd mobile
flutter gen-l10n
```

Do not hand-edit generated localization Dart.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run Step 2. Expected: exit 0.

- [ ] **Step 8: Commit Task 6**

```bash
git add mobile/lib/features/custom_scene/presentation/custom_scene_entry.dart mobile/lib/features/custom_scene/presentation/custom_scene_input_screen.dart mobile/lib/features/custom_scene/domain/custom_scene_failure.dart mobile/lib/features/practice/presentation/screens/home_screen.dart mobile/lib/features/shell/presentation/app_shell_screen.dart mobile/lib/features/shell/presentation/screens/discover_screen.dart mobile/lib/features/shell/presentation/screens/me_screen.dart mobile/lib/l10n/app_zh.arb mobile/lib/l10n/app_localizations.dart mobile/lib/l10n/app_localizations_zh.dart mobile/test/features/custom_scene/custom_scene_entry_test.dart mobile/test/features/custom_scene/custom_scene_input_screen_test.dart mobile/test/features/shell/me_screen_test.dart
git commit -m "feat(mobile): show family generation identity"
```

---

### Task 7: Clear revoked household content and verify the new client

**Files:**
- Modify: `generated_practice_content_registry.dart`
- Modify: household repository/notifier only at the membership-change seam.
- Modify: `repository_providers.dart` and local clearance registry if a new catalog store needs lifecycle deletion.
- Modify: lifecycle, household, generated registry, bearer header, and smoke tests.

**Interfaces:**
- Produces: cache eviction on observed membership loss plus full mobile verification.

- [ ] **Step 1: Write failing revocation-clearance tests**

Start with caregiver household snapshot and stored family-generated preset/custom bundles. Refresh to no active membership. Assert family generated bundles and resume markers clear, bundled catalog remains, and unrelated standalone local practice events remain.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd mobile
flutter test test/features/household/household_repository_test.dart test/features/practice/generated/generated_practice_content_registry_test.dart test/app/local_sensitive_data_clearance_registry_test.dart
```

- [ ] **Step 3: Add family-scoped clearance**

Persist household/profile scope metadata with stored generated records. Add `clearForHouseholdScope(String householdScope)` to generated store/registry. On a server-confirmed transition from active membership to no/changed membership, invoke it after the new household snapshot is durable. Offline state alone must not guess revocation.

- [ ] **Step 4: Register preset catalog cache lifecycle deletion**

Add the catalog store's `clearForLifecycle` primitive to the central local sensitive data clearance registry so account deletion/device erasure removes remote content metadata.

- [ ] **Step 5: Run all targeted feature tests**

```bash
flutter test test/features/scene_generation test/features/custom_scene test/features/practice test/features/household test/features/shell/me_screen_test.dart
```

Expected: exit 0.

- [ ] **Step 6: Run static and full test verification**

```bash
flutter analyze
flutter test
```

Expected: both commands exit 0.

- [ ] **Step 7: Inspect request/privacy evidence**

Run API tests and confirm request bodies contain no profile/household fields or generation brief. Confirm error `toString()` values contain no baby name, scene input, phone, token, or account ID.

- [ ] **Step 8: Commit verification fixes**

```bash
git add mobile/lib/features/practice/data/generated/generated_practice_content_registry.dart mobile/lib/features/practice/data/generated/generated_care_moment_local_store.dart mobile/lib/features/practice/data/generated/generated_care_turn_resume_marker_store.dart mobile/lib/features/household/data/repositories/household_repository.dart mobile/lib/app/providers/repository_providers.dart mobile/lib/app/local_sensitive_data_clearance_registry.dart mobile/test/features/household/household_repository_test.dart mobile/test/features/practice/generated/generated_practice_content_registry_test.dart mobile/test/app/local_sensitive_data_clearance_registry_test.dart
git commit -m "test(mobile): verify unified scene experience"
```

Skip the commit when verification required no file changes.
