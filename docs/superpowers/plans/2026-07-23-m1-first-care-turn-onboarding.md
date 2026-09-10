# M1 First Care-turn Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy onboarding phrase loop with one resumable, real Care Path turn that persists a canonical reaction, resolves the next support utterance, produces a real Garden trace, optionally saves to an account after first value, and enters Today with the same care context.

**Architecture:** Keep `CarePathNotifier` as the single source of truth for the live care turn. Add a small persisted onboarding flow snapshot for progress and selections, a reusable authentication continuation store for the post-value account step, and an idempotent reaction reconciliation path in `PracticeRepository`/`CarePathRepository`. Route all onboarding traffic through one `OnboardingFlowScreen`, reuse a shared `CareTurnSurface` in both onboarding and the normal practice screen, then delete the legacy onboarding engine and routes.

**Tech Stack:** Flutter 3 / Dart 3.11.4, Riverpod 2.6.1, GoRouter 14.8.1, Isar 3.1.0, Freezed 2.5.2, `audioplayers` 6.5.1, Flutter test, build_runner.

## Global Constraints

- Baseline is `Develop` commit `f8fa0ec70191bc00dd3eed3f6059a87bcd5a8648`; approved design commit is `74cc0c2`.
- M1 must remain independently runnable, testable, acceptable, and releasable.
- M1 must not call Custom Scene, AI generation, dynamic TTS, or any M2 API.
- `CarePathNotifier` remains the live care-turn source of truth; onboarding must not create a second phrase/reaction/Garden engine.
- Canonical reactions are exactly `cooperating`, `hesitant`, `resisting`, `no_response`, and `other`; invalid wire values fail closed and never map to `other`.
- The first value sequence is mandatory: utterance → parent said it → canonical reaction → next support → real trace.
- Account entry is optional and appears only after the real trace. Local-only completion must never be blocked by authentication.
- The completed starter IDs must be the exact `spaceId`, `activityId`, and initial `phraseId` used in the real onboarding turn.
- A reaction retry must reuse one `localEventId`; if the first write succeeded but the result was lost, reconciliation must return the existing event instead of creating another event.
- Garden snapshot failure after a confirmed event must degrade the trace display, not roll back the event or block Today.
- No XP, points, coins, leaderboard, quest, hard streak, correctness, lesson, course, task, or completion framing may appear in user-visible M1 copy.
- Do not prebuild reward economy or Custom Scene contracts while implementing M1.
- Do not manually edit generated `*.freezed.dart`, `*.g.dart`, or generated localization Dart files; regenerate them with repository tooling.
- Run every task test from `mobile/` unless the command explicitly starts at the repository root.

---

## File Structure Map

### New production files

- `mobile/lib/features/onboarding/domain/models/onboarding_flow_models.dart` — immutable flow phase, support goal, selections, resumable event identity, and JSON contract.
- `mobile/lib/features/onboarding/data/local/onboarding_flow_store.dart` — atomic JSON persistence for the in-progress flow.
- `mobile/lib/features/onboarding/presentation/onboarding_flow_notifier.dart` — onboarding orchestration around the formal `CarePathNotifier`.
- `mobile/lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart` — single public onboarding route and step switcher.
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_flow_shell.dart` — common progress/header/body/CTA layout.
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_selection_steps.dart` — age, scene, goal, and current-moment selection surfaces.
- `mobile/lib/features/onboarding/presentation/widgets/onboarding_trace_step.dart` — real trace and optional account invitation surfaces.
- `mobile/lib/features/care_path/presentation/widgets/care_turn_surface.dart` — reusable formal care-turn UI shared by onboarding and practice.
- `mobile/lib/features/account/domain/models/auth_continuation.dart` — versioned pending authentication intent contract.
- `mobile/lib/features/account/data/local/auth_continuation_store.dart` — persisted pending intent with expiry.
- `mobile/lib/features/account/presentation/auth_continuation_coordinator.dart` — start/read/clear continuation operations.

### New tests

- `mobile/test/features/onboarding/domain/onboarding_flow_models_test.dart`
- `mobile/test/features/onboarding/data/onboarding_flow_store_test.dart`
- `mobile/test/features/onboarding/presentation/onboarding_flow_notifier_test.dart`
- `mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart`
- `mobile/test/features/account/auth_continuation_store_test.dart`
- `mobile/test/features/care_path/presentation/care_turn_surface_test.dart`
- `mobile/test/integration/onboarding_first_care_turn_integration_test.dart`

### Modified production files

- `mobile/lib/features/onboarding/domain/models/stage_match.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_snapshot.dart`
- `mobile/lib/features/onboarding/data/repositories/onboarding_repository.dart`
- `mobile/lib/features/practice/data/local/practice_local_data_source.dart`
- `mobile/lib/features/practice/data/repositories/practice_repository.dart`
- `mobile/lib/features/care_path/data/repositories/care_path_repository.dart`
- `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`
- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/lib/app/providers/repository_providers.dart`
- `mobile/lib/app/router/app_route_contract.dart`
- `mobile/lib/app/router/app_go_router.dart`
- `mobile/lib/app/app.dart`
- `mobile/lib/app/local_sensitive_data_clearance_registry.dart`
- `mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart`
- `mobile/lib/l10n/app_zh.arb`
- `mobile/test/tool/verify_care_path_copy_firewall_test.dart`

### Deleted legacy production files after all consumers migrate

- `mobile/lib/features/onboarding/data/services/scene_phrase_service.dart`
- `mobile/lib/features/onboarding/domain/models/baby_reaction.dart`
- `mobile/lib/features/onboarding/domain/models/onboarding_session.dart`
- `mobile/lib/features/onboarding/domain/models/practice_record.dart`
- `mobile/lib/features/onboarding/domain/models/practice_scene.dart`
- `mobile/lib/features/onboarding/presentation/onboarding_session_notifier.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart`
- `mobile/lib/features/onboarding/presentation/screens/onboarding_garden_welcome_screen.dart`
- `mobile/lib/features/onboarding/presentation/widgets/countdown_progress_bar.dart`
- `mobile/lib/features/onboarding/presentation/widgets/reaction_button.dart`

---

### Task 1: Canonical M1 Profile and Completed Snapshot Contract

**Files:**
- Modify: `mobile/lib/features/onboarding/domain/models/stage_match.dart:1-130`
- Modify: `mobile/lib/features/onboarding/domain/models/onboarding_snapshot.dart:1-161`
- Modify: `mobile/lib/features/onboarding/data/repositories/onboarding_repository.dart:1-126`
- Regenerate: `mobile/lib/generated/features/onboarding/domain/models/onboarding_snapshot.freezed.dart`
- Test: `mobile/test/features/onboarding/onboarding_repository_test.dart`
- Test: `mobile/test/generated/generated_code_canary_test.dart`
- Test: callers constructing `OnboardingSnapshot` found by `rg -l 'OnboardingSnapshot\(' mobile/test`

**Interfaces:**
- Produces: `OnboardingAgeBucket` with four user-facing ranges and backward-compatible parsing.
- Produces: `OnboardingSupportGoal` with `firstWords`, `moreNatural`, and `dailyHabit`.
- Produces: `OnboardingRepository.completeOnboarding(...)` requiring actual starter IDs and `firstTraceEventKey`.
- Consumes: existing `StageMatchCatalog`, `OnboardingSnapshotStore`.

- [ ] **Step 1: Write failing age-range and snapshot tests**

Add these tests before changing production code:

```dart
test('M1 exposes four low-pressure age ranges and parses legacy wire values', () {
  expect(OnboardingAgeBucket.values, <OnboardingAgeBucket>[
    OnboardingAgeBucket.zeroToSix,
    OnboardingAgeBucket.sevenToTwelve,
    OnboardingAgeBucket.oneToTwo,
    OnboardingAgeBucket.twoToThree,
  ]);
  expect(parseOnboardingAgeBucket('6-12'), OnboardingAgeBucket.sevenToTwelve);
  expect(parseOnboardingAgeBucket('12-18'), OnboardingAgeBucket.oneToTwo);
  expect(parseOnboardingAgeBucket('18-24'), OnboardingAgeBucket.oneToTwo);
  expect(parseOnboardingAgeBucket('24-36'), OnboardingAgeBucket.twoToThree);
});

test('new completion persists actual turn identity, preferences, goal, and trace', () async {
  final snapshot = await onboardingRepository.completeOnboarding(
    childDisplayName: '宝宝',
    ageBucket: OnboardingAgeBucket.oneToTwo,
    selectedSceneIds: const ['bath_time', 'bedtime'],
    supportGoal: OnboardingSupportGoal.moreNatural,
    starterSpaceId: 'family_rhythm',
    starterActivityId: 'bedtime',
    starterPhraseId: 'bedtime_dim_the_lights',
    firstTraceEventKey: 'install_onboarding_test:evt_onboarding_first',
    completedAt: DateTime.utc(2026, 7, 23, 12),
  );

  expect(snapshot.schemaVersion, 2);
  expect(snapshot.selectedSceneIds, ['bath_time', 'bedtime']);
  expect(snapshot.supportGoal, OnboardingSupportGoal.moreNatural);
  expect(snapshot.starterSpaceId, 'family_rhythm');
  expect(snapshot.starterActivityId, 'bedtime');
  expect(snapshot.starterPhraseId, 'bedtime_dim_the_lights');
  expect(snapshot.firstTraceEventKey, 'install_onboarding_test:evt_onboarding_first');
  expect(snapshot.isCompleted, isTrue);
});

test('new completion rejects missing real trace identity', () async {
  await expectLater(
    onboardingRepository.completeOnboarding(
      childDisplayName: '宝宝',
      ageBucket: OnboardingAgeBucket.zeroToSix,
      selectedSceneIds: const ['bath_time'],
      supportGoal: OnboardingSupportGoal.firstWords,
      starterSpaceId: 'daily_care',
      starterActivityId: 'bath_time',
      starterPhraseId: 'bath_time_warm_water',
      firstTraceEventKey: '   ',
    ),
    throwsFormatException,
  );
});
```

- [ ] **Step 2: Run the focused tests and confirm failure**

Run:

```bash
cd mobile
flutter test test/features/onboarding/onboarding_repository_test.dart
```

Expected: compilation failure because `sevenToTwelve`, `oneToTwo`, `twoToThree`, `OnboardingSupportGoal`, and the new completion parameters do not exist.

- [ ] **Step 3: Replace the age contract and add support-goal wire semantics**

Use this exact public contract in `stage_match.dart`:

```dart
enum OnboardingAgeBucket { zeroToSix, sevenToTwelve, oneToTwo, twoToThree }

enum OnboardingSupportGoal { firstWords, moreNatural, dailyHabit }

extension OnboardingAgeBucketWire on OnboardingAgeBucket {
  String get wireValue => switch (this) {
    OnboardingAgeBucket.zeroToSix => '0-6',
    OnboardingAgeBucket.sevenToTwelve => '7-12',
    OnboardingAgeBucket.oneToTwo => '12-24',
    OnboardingAgeBucket.twoToThree => '24-36',
  };

  String get label => switch (this) {
    OnboardingAgeBucket.zeroToSix => '0–6 个月',
    OnboardingAgeBucket.sevenToTwelve => '7–12 个月',
    OnboardingAgeBucket.oneToTwo => '1–2 岁',
    OnboardingAgeBucket.twoToThree => '2–3 岁',
  };
}

OnboardingAgeBucket parseOnboardingAgeBucket(String value) => switch (value.trim()) {
  '0-6' => OnboardingAgeBucket.zeroToSix,
  '7-12' || '6-12' => OnboardingAgeBucket.sevenToTwelve,
  '12-24' || '12-18' || '18-24' => OnboardingAgeBucket.oneToTwo,
  '24-36' => OnboardingAgeBucket.twoToThree,
  final unknown => throw FormatException('未知月龄档: $unknown'),
};

extension OnboardingSupportGoalWire on OnboardingSupportGoal {
  String get wireValue => switch (this) {
    OnboardingSupportGoal.firstWords => 'first_words',
    OnboardingSupportGoal.moreNatural => 'more_natural',
    OnboardingSupportGoal.dailyHabit => 'daily_habit',
  };
}

OnboardingSupportGoal parseOnboardingSupportGoal(String value) => switch (value.trim()) {
  'first_words' => OnboardingSupportGoal.firstWords,
  'more_natural' => OnboardingSupportGoal.moreNatural,
  'daily_habit' => OnboardingSupportGoal.dailyHabit,
  final unknown => throw FormatException('未知 onboarding supportGoal: $unknown'),
};
```

Keep four canonical `StageMatch` entries with approximate months `3`, `9`, `18`, and `30`. Keep `maybeForStageId('mini_scene_imitation')` as a legacy alias for the 1–2-year match so old local snapshots remain readable.

- [ ] **Step 4: Extend `OnboardingSnapshot` with a versioned M1 completion proof**

Add these fields to the Freezed factory:

```dart
const factory OnboardingSnapshot({
  @Default(1) int schemaVersion,
  required String childDisplayName,
  required OnboardingAgeBucket ageBucket,
  required int approxMonths,
  required String currentStage,
  required String starterSpaceId,
  required String starterActivityId,
  required String starterPhraseId,
  @Default(<String>[]) List<String> selectedSceneIds,
  @Default(OnboardingSupportGoal.firstWords) OnboardingSupportGoal supportGoal,
  String? firstTraceEventKey,
  required OnboardingConsentState consentState,
  DateTime? birthDate,
  DateTime? completedAt,
}) = _OnboardingSnapshot;
```

Deserialize absent new fields as legacy defaults. Define completion as:

```dart
bool get isCompleted {
  final legacyCoreComplete = childDisplayName.trim().isNotEmpty &&
      currentStage.trim().isNotEmpty &&
      starterSpaceId.trim().isNotEmpty &&
      starterActivityId.trim().isNotEmpty &&
      starterPhraseId.trim().isNotEmpty &&
      completedAt != null;
  if (!legacyCoreComplete) return false;
  if (schemaVersion < 2) return true;
  return firstTraceEventKey?.trim().isNotEmpty ?? false;
}
```

This preserves old completed local profiles while requiring real-trace proof for all M1 snapshots.

- [ ] **Step 5: Replace configured-starter completion with actual-turn completion**

Change `OnboardingRepository.completeOnboarding` to this signature:

```dart
Future<OnboardingSnapshot> completeOnboarding({
  required String childDisplayName,
  required OnboardingAgeBucket ageBucket,
  required List<String> selectedSceneIds,
  required OnboardingSupportGoal supportGoal,
  required String starterSpaceId,
  required String starterActivityId,
  required String starterPhraseId,
  required String firstTraceEventKey,
  OnboardingConsentState consentState = OnboardingConsentState.localOnly,
  DateTime? completedAt,
})
```

Validate every ID and `firstTraceEventKey` with one `_requiredTrimmed` helper, deduplicate scene IDs while preserving order, set `schemaVersion: 2`, and remove `resolveStarterSeed()` from the completion path. Keep `resolveStarterSeed()` temporarily until Task 9 removes legacy tests and dead consumers.

- [ ] **Step 6: Regenerate Freezed code**

Run:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

Expected: `onboarding_snapshot.freezed.dart` changes; no generator error.

- [ ] **Step 7: Update all direct snapshot constructors and rerun tests**

Use `rg -n 'OnboardingAgeBucket\.(sixToTwelve|twelveToEighteen|eighteenToTwentyFour|twentyFourToThirtySix)' mobile/lib mobile/test` and replace every old enum value with the correct new range. Add `firstTraceEventKey` only to schema-version-2 test fixtures; legacy fixtures may retain `schemaVersion: 1`.

Run:

```bash
cd mobile
flutter test test/features/onboarding/onboarding_repository_test.dart test/generated/generated_code_canary_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/onboarding mobile/lib/generated/features/onboarding mobile/test
git commit -m "feat(onboarding): define first care-turn completion contract"
```

---

### Task 2: Resumable Onboarding Flow Snapshot and Persistence

**Files:**
- Create: `mobile/lib/features/onboarding/domain/models/onboarding_flow_models.dart`
- Create: `mobile/lib/features/onboarding/data/local/onboarding_flow_store.dart`
- Modify: `mobile/lib/features/onboarding/data/repositories/onboarding_repository.dart`
- Test: `mobile/test/features/onboarding/domain/onboarding_flow_models_test.dart`
- Test: `mobile/test/features/onboarding/data/onboarding_flow_store_test.dart`
- Modify: `mobile/test/app/local_sensitive_data_clearance_registry_test.dart`

**Interfaces:**
- Produces: `OnboardingFlowStep`, `OnboardingFlowSnapshot`, `OnboardingMomentChoice`.
- Produces: `OnboardingFlowStore.read/write/deleteIfExists`.
- Produces: `OnboardingRepository.readFlowSnapshot/saveFlowSnapshot/clearFlowSnapshot/clearAllLocalState`.
- Consumes: Task 1 age/support-goal types.

- [ ] **Step 1: Write failing model round-trip and validation tests**

```dart
test('flow snapshot round-trips the stable event identity without phrase copy', () {
  final snapshot = OnboardingFlowSnapshot(
    step: OnboardingFlowStep.careTurn,
    ageBucket: OnboardingAgeBucket.oneToTwo,
    selectedSceneIds: const ['bath_time', 'bedtime'],
    supportGoal: OnboardingSupportGoal.moreNatural,
    selectedSpaceId: 'family_rhythm',
    selectedActivityId: 'bedtime',
    starterPhraseId: 'bedtime_dim_the_lights',
    pendingLocalEventId: 'evt_onboarding_fixed',
    selectedReaction: BabyReactionType.hesitant,
    traceEventKey: null,
    updatedAt: DateTime.utc(2026, 7, 23, 12),
  );

  final restored = OnboardingFlowSnapshot.fromJsonMap(snapshot.toJsonMap());
  expect(restored, snapshot);
  expect(snapshot.toJsonMap().values, isNot(contains('Dim the lights.')));
});

test('invalid flow wire reaction fails closed', () {
  final json = OnboardingFlowSnapshot(
    step: OnboardingFlowStep.careTurn,
    ageBucket: OnboardingAgeBucket.oneToTwo,
    selectedSceneIds: const ['bath_time'],
    supportGoal: OnboardingSupportGoal.moreNatural,
    selectedSpaceId: 'daily_care',
    selectedActivityId: 'bath_time',
    starterPhraseId: 'bath_time_warm_water',
    pendingLocalEventId: 'evt_onboarding_fixed',
    selectedReaction: BabyReactionType.hesitant,
    updatedAt: DateTime.utc(2026, 7, 23, 12),
  ).toJsonMap()
    ..['selectedReaction'] = 'calm';

  expect(() => OnboardingFlowSnapshot.fromJsonMap(json), throwsFormatException);
});
```

- [ ] **Step 2: Run focused tests and confirm missing-type failure**

```bash
cd mobile
flutter test test/features/onboarding/domain/onboarding_flow_models_test.dart
```

Expected: compilation failure because the flow model does not exist.

- [ ] **Step 3: Implement the immutable flow contract**

Create these public types:

```dart
enum OnboardingFlowStep {
  welcome,
  age,
  scenePreferences,
  supportGoal,
  currentMoment,
  careTurn,
  trace,
  accountInvitation,
  completing,
}

class OnboardingMomentChoice {
  const OnboardingMomentChoice({
    required this.spaceId,
    required this.activityId,
    required this.spaceTitle,
    required this.title,
    required this.summary,
  });

  final String spaceId;
  final String activityId;
  final String spaceTitle;
  final String title;
  final String summary;
}

class OnboardingFlowSnapshot {
  const OnboardingFlowSnapshot({
    this.schemaVersion = 1,
    this.step = OnboardingFlowStep.welcome,
    this.ageBucket,
    this.selectedSceneIds = const <String>[],
    this.supportGoal,
    this.selectedSpaceId,
    this.selectedActivityId,
    this.starterPhraseId,
    this.pendingLocalEventId,
    this.selectedReaction,
    this.traceEventKey,
    required this.updatedAt,
  });

  final int schemaVersion;
  final OnboardingFlowStep step;
  final OnboardingAgeBucket? ageBucket;
  final List<String> selectedSceneIds;
  final OnboardingSupportGoal? supportGoal;
  final String? selectedSpaceId;
  final String? selectedActivityId;
  final String? starterPhraseId;
  final String? pendingLocalEventId;
  final BabyReactionType? selectedReaction;
  final String? traceEventKey;
  final DateTime updatedAt;

  bool get hasSelectedMoment =>
      selectedSpaceId?.trim().isNotEmpty == true &&
      selectedActivityId?.trim().isNotEmpty == true;

  bool get hasConfirmedTrace => traceEventKey?.trim().isNotEmpty == true;

  factory OnboardingFlowSnapshot.initial(DateTime now) =>
      OnboardingFlowSnapshot(updatedAt: now.toUtc());

  static const Object _notProvided = Object();

  OnboardingFlowSnapshot copyWith({
    int? schemaVersion,
    OnboardingFlowStep? step,
    Object? ageBucket = _notProvided,
    List<String>? selectedSceneIds,
    Object? supportGoal = _notProvided,
    Object? selectedSpaceId = _notProvided,
    Object? selectedActivityId = _notProvided,
    Object? starterPhraseId = _notProvided,
    Object? pendingLocalEventId = _notProvided,
    Object? selectedReaction = _notProvided,
    Object? traceEventKey = _notProvided,
    DateTime? updatedAt,
  }) {
    return OnboardingFlowSnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      step: step ?? this.step,
      ageBucket: identical(ageBucket, _notProvided)
          ? this.ageBucket
          : ageBucket as OnboardingAgeBucket?,
      selectedSceneIds: selectedSceneIds ?? this.selectedSceneIds,
      supportGoal: identical(supportGoal, _notProvided)
          ? this.supportGoal
          : supportGoal as OnboardingSupportGoal?,
      selectedSpaceId: identical(selectedSpaceId, _notProvided)
          ? this.selectedSpaceId
          : selectedSpaceId as String?,
      selectedActivityId: identical(selectedActivityId, _notProvided)
          ? this.selectedActivityId
          : selectedActivityId as String?,
      starterPhraseId: identical(starterPhraseId, _notProvided)
          ? this.starterPhraseId
          : starterPhraseId as String?,
      pendingLocalEventId: identical(pendingLocalEventId, _notProvided)
          ? this.pendingLocalEventId
          : pendingLocalEventId as String?,
      selectedReaction: identical(selectedReaction, _notProvided)
          ? this.selectedReaction
          : selectedReaction as BabyReactionType?,
      traceEventKey: identical(traceEventKey, _notProvided)
          ? this.traceEventKey
          : traceEventKey as String?,
      updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
    );
  }

  Map<String, Object?> toJsonMap();
  factory OnboardingFlowSnapshot.fromJsonMap(Map<String, dynamic> json);

  @override
  bool operator ==(Object other) {
    return other is OnboardingFlowSnapshot &&
        other.schemaVersion == schemaVersion &&
        other.step == step &&
        other.ageBucket == ageBucket &&
        listEquals(other.selectedSceneIds, selectedSceneIds) &&
        other.supportGoal == supportGoal &&
        other.selectedSpaceId == selectedSpaceId &&
        other.selectedActivityId == selectedActivityId &&
        other.starterPhraseId == starterPhraseId &&
        other.pendingLocalEventId == pendingLocalEventId &&
        other.selectedReaction == selectedReaction &&
        other.traceEventKey == traceEventKey &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    schemaVersion,
    step,
    ageBucket,
    Object.hashAll(selectedSceneIds),
    supportGoal,
    selectedSpaceId,
    selectedActivityId,
    starterPhraseId,
    pendingLocalEventId,
    selectedReaction,
    traceEventKey,
    updatedAt,
  ]);
}
```

Implement explicit wire parsers for `OnboardingFlowStep` and reuse `parseBabyReactionType`; never catch an unknown reaction and substitute `other`.

- [ ] **Step 4: Write failing persistence tests**

```dart
test('store writes atomically and restores the last complete JSON object', () async {
  final store = OnboardingFlowStore(directoryResolver: () async => tempDir);
  final snapshot = OnboardingFlowSnapshot.initial(DateTime.utc(2026, 7, 23));
  await store.write(snapshot);
  expect(await store.read(), snapshot);
  expect(File('${tempDir.path}/onboarding_flow_snapshot.json').existsSync(), isTrue);
  expect(File('${tempDir.path}/onboarding_flow_snapshot.json.tmp').existsSync(), isFalse);
});

test('corrupt flow file is deleted by repository and restarts safely', () async {
  await File('${tempDir.path}/onboarding_flow_snapshot.json').writeAsString('{bad');
  expect(await onboardingRepository.readFlowSnapshot(), isNull);
  expect(File('${tempDir.path}/onboarding_flow_snapshot.json').existsSync(), isFalse);
});
```

- [ ] **Step 5: Implement atomic store writes**

`OnboardingFlowStore.write` must write `${fileName}.tmp`, flush it, then rename it over the destination. On Windows, delete the existing destination before rename only after the temporary file is complete. Wrap I/O errors in `OnboardingFlowPersistenceException` and preserve `FormatException` from JSON validation.

- [ ] **Step 6: Wire the flow store into `OnboardingRepository`**

Add a required `OnboardingFlowStore flowStore` constructor parameter and these methods:

```dart
Future<OnboardingFlowSnapshot?> readFlowSnapshot() async {
  try {
    return await _flowStore.read();
  } on FormatException {
    await _flowStore.deleteIfExists();
    return null;
  }
}

Future<OnboardingFlowSnapshot> saveFlowSnapshot(OnboardingFlowSnapshot snapshot) async {
  await _flowStore.write(snapshot);
  return snapshot;
}

Future<void> clearFlowSnapshot() => _flowStore.deleteIfExists();

Future<void> clearAllLocalState() async {
  await _flowStore.deleteIfExists();
  await _snapshotStore.deleteIfExists();
}
```

Update every `OnboardingRepository(...)` construction in production and tests to pass the flow store.

- [ ] **Step 7: Run model, store, repository, and clearance tests**

```bash
cd mobile
flutter test \
  test/features/onboarding/domain/onboarding_flow_models_test.dart \
  test/features/onboarding/data/onboarding_flow_store_test.dart \
  test/features/onboarding/onboarding_repository_test.dart \
  test/app/local_sensitive_data_clearance_registry_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/onboarding mobile/test/features/onboarding mobile/test/app/local_sensitive_data_clearance_registry_test.dart
git commit -m "feat(onboarding): persist resumable first-turn flow"
```

---

### Task 3: Idempotent Reaction Write and Unknown-Outcome Reconciliation

**Files:**
- Modify: `mobile/lib/features/practice/data/local/practice_local_data_source.dart:70-81`
- Modify: `mobile/lib/features/practice/data/repositories/practice_repository.dart:583-613,687-743`
- Modify: `mobile/lib/features/care_path/data/repositories/care_path_repository.dart:104-159`
- Test: `mobile/test/features/practice/practice_repository_test.dart`
- Test: `mobile/test/features/care_path/data/care_path_repository_test.dart`
- Test: `mobile/test/features/care_path/presentation/care_path_notifier_test.dart`

**Interfaces:**
- Produces: `PracticeRepository.findEventByLocalEventId(String)`.
- Produces: idempotent `PracticeRepository.recordReaction` for an identical existing event.
- Produces: conflict failure for reused ID with different event facts.
- Consumes: existing Isar unique `localEventId` and `eventKey` indexes.

- [ ] **Step 1: Write failing repository idempotency tests**

```dart
test('same localEventId and same immutable facts reconcile to one event', () async {
  final first = await repository.recordReaction(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    phraseId: 'bath_time_warm_water',
    reactionType: BabyReactionType.hesitant,
    localEventId: 'evt_reconcile_same',
    clientTimestamp: DateTime.utc(2026, 7, 23, 12),
  );
  final second = await repository.recordReaction(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    phraseId: 'bath_time_warm_water',
    reactionType: BabyReactionType.hesitant,
    localEventId: 'evt_reconcile_same',
    clientTimestamp: DateTime.utc(2026, 7, 23, 12, 1),
  );

  expect(second.eventKey, first.eventKey);
  expect(await repository.listEventHistory(), hasLength(1));
});

test('same localEventId with different facts fails closed', () async {
  await repository.recordReaction(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    phraseId: 'bath_time_warm_water',
    reactionType: BabyReactionType.hesitant,
    localEventId: 'evt_reconcile_conflict',
  );
  await expectLater(
    repository.recordReaction(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      phraseId: 'bath_time_warm_water',
      reactionType: BabyReactionType.resisting,
      localEventId: 'evt_reconcile_conflict',
    ),
    throwsA(isA<FormatException>().having(
      (error) => error.message,
      'message',
      contains('localEventId 已绑定不同事件事实'),
    )),
  );
});
```

- [ ] **Step 2: Confirm failure**

```bash
cd mobile
flutter test test/features/practice/practice_repository_test.dart --plain-name "same localEventId"
```

Expected: first test fails because duplicate append throws.

- [ ] **Step 3: Add exact event lookup**

Add to `PracticeLocalDataSource`:

```dart
Future<InteractionEventPayload?> getInteractionEventByLocalEventId(
  String localEventId,
) async {
  final normalized = localEventId.trim();
  if (normalized.isEmpty) return null;
  final entity = await _isar
      .collection<InteractionEventEntity>()
      .getByLocalEventId(normalized);
  return entity == null ? null : payloadFromEntity(entity);
}
```

Expose it from `PracticeRepository` as:

```dart
Future<InteractionEventPayload?> findEventByLocalEventId(String localEventId) {
  return _localDataSource.getInteractionEventByLocalEventId(localEventId);
}
```

- [ ] **Step 4: Make `recordReaction` reconcile before append and after append failure**

Add these exact reconciliation helpers. They deliberately ignore timestamp differences during retry and fail closed when the stable ID is reused for different facts:

```dart
bool _sameImmutableEventFacts(
  InteractionEventPayload existing,
  InteractionEventPayload requested,
) {
  return existing.spaceId == requested.spaceId &&
      existing.activityId == requested.activityId &&
      existing.phraseId == requested.phraseId &&
      existing.reactionType == requested.reactionType;
}

InteractionEventPayload _reconcileOrThrow(
  InteractionEventPayload existing,
  InteractionEventPayload requested,
) {
  if (!_sameImmutableEventFacts(existing, requested)) {
    throw StateError(
      'localEventId ${requested.localEventId} already belongs to different reaction facts',
    );
  }
  return existing;
}
```

Use this exact algorithm around the append:

```dart
final normalizedLocalEventId = localEventId?.trim();
if (normalizedLocalEventId != null && normalizedLocalEventId.isNotEmpty) {
  final existing = await findEventByLocalEventId(normalizedLocalEventId);
  if (existing != null) return _reconcileOrThrow(existing, payload);
}

try {
  await _localDataSource.appendInteractionEvent(payload);
  return payload;
} catch (error) {
  if (normalizedLocalEventId == null || normalizedLocalEventId.isEmpty) rethrow;
  final existing = await findEventByLocalEventId(normalizedLocalEventId);
  if (existing == null) rethrow;
  return _reconcileOrThrow(existing, payload);
}
```

Do not match on `eventKey` supplied by UI; derive it from installation ID plus the stable local ID.

- [ ] **Step 5: Add a Care Path test proving retry returns the same trace and next support**

```dart
test('recordReaction retry with the same event id returns next support without duplicate trace', () async {
  final turn = await repository.startMoment(
    spaceId: 'daily_care',
    activityId: 'bath_time',
  );
  final first = await repository.recordReaction(
    turn: turn,
    reactionType: BabyReactionType.hesitant,
    localEventId: 'evt_care_path_reconcile',
  );
  final retry = await repository.recordReaction(
    turn: turn,
    reactionType: BabyReactionType.hesitant,
    localEventId: 'evt_care_path_reconcile',
  );

  expect(retry.traceEventKey, first.traceEventKey);
  expect(retry.phase, CareTurnPhase.nextSupportReady);
  expect(retry.nextSupportUtterance, isNotNull);
  expect(await practiceRepository.listEventHistory(), hasLength(1));
});
```

- [ ] **Step 6: Run all reaction-path tests**

```bash
cd mobile
flutter test \
  test/features/practice/practice_repository_test.dart \
  test/features/care_path/data/care_path_repository_test.dart \
  test/features/care_path/presentation/care_path_notifier_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/practice mobile/lib/features/care_path mobile/test/features/practice mobile/test/features/care_path
git commit -m "fix(care-path): reconcile repeated reaction events"
```

---

### Task 4: Shared Formal Care-turn Surface

**Files:**
- Create: `mobile/lib/features/care_path/presentation/widgets/care_turn_surface.dart`
- Modify: `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart:78-520`
- Test: `mobile/test/features/care_path/presentation/care_turn_surface_test.dart`
- Modify: `mobile/test/features/practice/critical_ui_coverage_test.dart`

**Interfaces:**
- Produces: `CareTurnSurface` driven by a supplied `CarePathNotifier`.
- Produces: callbacks `onTraceReady` and `onQuietExit` without owning navigation.
- Consumes: `PracticeAudioController`, `CareTurnSnapshot`, `SceneReactionChipRow`.

- [ ] **Step 1: Write a failing shared-surface widget test**

```dart
late PracticeRepositoryCharacterizationHarness harness;
late CarePathNotifier notifier;

setUp(() async {
  harness = await PracticeRepositoryCharacterizationHarness.create();
  notifier = CarePathNotifier(
    repository: CarePathRepository(practiceRepository: harness.repository),
  );
});

tearDown(() async {
  notifier.dispose();
  await harness.dispose();
});

testWidgets(
  'shared surface drives said, canonical reaction, next support, and trace callback',
  (tester) async {
    var traceReadyCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CareTurnSurface(
            notifier: notifier,
            audioControllerFactory: _SilentPracticeAudioController.new,
            onTraceReady: (_) => traceReadyCount += 1,
            onQuietExit: () {},
          ),
        ),
      ),
    );

    await notifier.startMoment(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('care-turn-next-support')), findsOneWidget);
    expect(traceReadyCount, 1);
  },
);

class _SilentPracticeAudioController implements PracticeAudioController {
  final StreamController<void> _completion = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _completion.stream;

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _completion.close();
}
```

- [ ] **Step 2: Confirm missing-widget failure**

```bash
cd mobile
flutter test test/features/care_path/presentation/care_turn_surface_test.dart
```

Expected: compilation failure because `CareTurnSurface` does not exist.

- [ ] **Step 3: Extract the formal care-turn UI without changing behavior**

Create:

```dart
typedef CareTurnTraceReady = void Function(CareTurnSnapshot snapshot);

class CareTurnSurface extends StatefulWidget {
  const CareTurnSurface({
    super.key,
    required this.notifier,
    this.audioControllerFactory,
    this.onTraceReady,
    this.onQuietExit,
    this.showQuietExit = true,
  });

  final CarePathNotifier notifier;
  final PracticeAudioController Function()? audioControllerFactory;
  final CareTurnTraceReady? onTraceReady;
  final VoidCallback? onQuietExit;
  final bool showQuietExit;
}
```

Move current utterance, local asset playback, “我说了”, reaction selector, saving state, next-support, Garden impact, error, and quiet-exit rendering from `_PracticeSessionBodyState` into this widget. Rename keys from `practice-*` to neutral `care-turn-*` and preserve temporary aliases only in tests if needed during the same task.

The widget must call `onTraceReady` exactly once per distinct non-empty `traceEventKey`. Track the last notified key in state; do not infer success from animation or Garden availability.

- [ ] **Step 4: Reduce `PracticeSessionScreen` to route startup plus the shared surface**

After repository readiness and `startMoment`, render:

```dart
CareTurnSurface(
  notifier: ref.watch(carePathNotifierProvider),
  audioControllerFactory: widget.audioControllerFactory,
  onQuietExit: () => Navigator.of(context).maybePop(),
)
```

Keep route validation and safe fallback scaffolds in `PracticeSessionScreen`. Do not move GoRouter logic into `CareTurnSurface`.

- [ ] **Step 5: Run shared surface and current one-turn regression tests**

```bash
cd mobile
flutter test \
  test/features/care_path/presentation/care_turn_surface_test.dart \
  test/features/practice/critical_ui_coverage_test.dart \
  test/features/practice/widgets/scene_reaction_chip_row_test.dart
```

Expected: PASS with the existing formal one-turn behavior preserved.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/care_path mobile/lib/features/practice/presentation/screens/practice_session_screen.dart mobile/test/features/care_path mobile/test/features/practice
git commit -m "refactor(care-path): share the formal care-turn surface"
```

---

### Task 5: Persistent Authentication Continuation

**Files:**
- Create: `mobile/lib/features/account/domain/models/auth_continuation.dart`
- Create: `mobile/lib/features/account/data/local/auth_continuation_store.dart`
- Create: `mobile/lib/features/account/presentation/auth_continuation_coordinator.dart`
- Modify: `mobile/lib/features/account/presentation/screens/account_entry_screen.dart:19-21,530-760`
- Modify: `mobile/lib/app/providers/repository_providers.dart:183-253`
- Modify: `mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart:12-19,327-344`
- Modify: `mobile/lib/app/local_sensitive_data_clearance_registry.dart:8-65`
- Test: `mobile/test/features/account/auth_continuation_store_test.dart`
- Modify: `mobile/test/features/account/account_entry_screen_test.dart`
- Modify: `mobile/test/app/local_sensitive_data_clearance_registry_test.dart`

**Interfaces:**
- Produces: `AuthContinuationIntent.saveOnboardingMemory`.
- Produces: `AuthContinuationCoordinator.begin/readPending/clear`.
- Produces: `AccountEntryResult.signedIn` returned by `/account` after successful sign-in when a continuation is pending.
- Consumes: `AccountNotifier.submitSignIn()`.

- [ ] **Step 1: Write failing continuation persistence tests**

```dart
test('save-onboarding continuation round-trips and expires fail-closed', () async {
  final store = AuthContinuationStore(directoryResolver: () async => tempDir);
  final pending = AuthContinuation(
    schemaVersion: 1,
    intent: AuthContinuationIntent.saveOnboardingMemory,
    correlationId: 'auth_onboarding_123',
    createdAt: DateTime.utc(2026, 7, 23, 12),
    expiresAt: DateTime.utc(2026, 7, 23, 12, 15),
  );
  await store.write(pending);
  expect(await store.read(now: DateTime.utc(2026, 7, 23, 12, 5)), pending);
  expect(await store.read(now: DateTime.utc(2026, 7, 23, 12, 16)), isNull);
  expect(File('${tempDir.path}/auth_continuation.json').existsSync(), isFalse);
});
```

- [ ] **Step 2: Confirm missing-type failure**

```bash
cd mobile
flutter test test/features/account/auth_continuation_store_test.dart
```

Expected: compilation failure.

- [ ] **Step 3: Implement the versioned intent and atomic store**

Use this exact initial enum:

```dart
enum AuthContinuationIntent { saveOnboardingMemory }
```

The JSON shape must be:

```json
{
  "schemaVersion": 1,
  "intent": "save_onboarding_memory",
  "correlationId": "auth_onboarding_123",
  "createdAt": "2026-07-23T12:00:00.000Z",
  "expiresAt": "2026-07-23T12:15:00.000Z"
}
```

Reject unknown intent strings. `AuthContinuationStore.read(now:)` deletes corrupt or expired files and returns `null`. Use atomic temporary-file replacement as in Task 2.

- [ ] **Step 4: Implement the coordinator**

```dart
class AuthContinuationCoordinator {
  AuthContinuationCoordinator({
    required AuthContinuationStore store,
    DateTime Function()? clock,
    String Function()? correlationIdGenerator,
    this.ttl = const Duration(minutes: 15),
  }) : _store = store,
       _clock = clock ?? DateTime.now,
       _correlationIdGenerator = correlationIdGenerator ?? _defaultId;

  final Duration ttl;

  Future<AuthContinuation> beginSaveOnboardingMemory();
  Future<AuthContinuation?> readPending();
  Future<void> clear();
}
```

`beginSaveOnboardingMemory` always overwrites an older pending onboarding intent with a fresh correlation ID. Do not consume the intent on login success; onboarding clears it only after the completed snapshot is safely written.

- [ ] **Step 5: Add provider graph and lifecycle clearance**

Create `authContinuationStoreProvider` from `appDirectoryProvider` and `authContinuationCoordinatorProvider` from the store. Add `LocalSensitiveDataTarget.authContinuation` and include it in:

```dart
logoutSessionOnly
consentWithdrawalConfirmed
accountDeletionConfirmed
deviceEraseConfirmed
staffPlusVerificationOnly
```

Add a registry step whose primitive is `AuthContinuationCoordinator.clear`. Do not clear the completed onboarding snapshot on ordinary logout.

- [ ] **Step 6: Return a typed login result from `AccountEntryScreen`**

Add:

```dart
enum AccountEntryResult { signedIn }
```

After `submitSignIn()` returns true:

```dart
final pending = await ref.read(authContinuationCoordinatorProvider).readPending();
if (!context.mounted) return;
if (pending != null) {
  context.pop(AccountEntryResult.signedIn);
  return;
}
showAppToast(context, l.accountEntrySubmitMessage);
```

The screen must remain usable from My when no continuation exists.

- [ ] **Step 7: Run account and clearance tests**

```bash
cd mobile
flutter test \
  test/features/account/auth_continuation_store_test.dart \
  test/features/account/account_entry_screen_test.dart \
  test/app/local_sensitive_data_clearance_registry_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/account mobile/lib/app/providers/repository_providers.dart mobile/lib/app/local_sensitive_data_clearance_registry.dart mobile/lib/core/local_data_lifecycle mobile/test/features/account mobile/test/app/local_sensitive_data_clearance_registry_test.dart
git commit -m "feat(account): persist resumable authentication intent"
```

---

### Task 6: Onboarding Flow Notifier Around the Formal Care Path

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/onboarding_flow_notifier.dart`
- Modify: `mobile/lib/app/providers/repository_providers.dart`
- Test: `mobile/test/features/onboarding/presentation/onboarding_flow_notifier_test.dart`

**Interfaces:**
- Produces: `OnboardingFlowNotifier.initialize`, selection methods, `markSaid`, `selectReaction`, `chooseLocalOnly`, `beginAccountSave`, and `handleAccountReturn`.
- Consumes: `OnboardingRepository`, `PracticeRepository`, `CarePathNotifier`, `AccountNotifier`, `AuthContinuationCoordinator`.
- Does not store a second `CareTurnSnapshot`; exposes `carePathNotifier.snapshot` as a read-through getter.

- [ ] **Step 1: Write the state-machine tests first**

Add this scripted repository and fixtures at the bottom of the test file. Construct the real `CarePathNotifier` with this repository in `setUp`; use `PracticeRepositoryCharacterizationHarness.repository` only to satisfy the superclass dependency.

```dart
const _bedtimeMoment = CareMoment(
  spaceId: 'family_rhythm',
  activityId: 'bedtime',
  spaceTitle: '家庭节奏',
  title: '睡前时间',
  sceneTag: 'Bedtime',
  careActionLabel: 'Get ready for sleep.',
  coachTip: 'Say it while dimming the lights.',
  nodeState: CarePathNodeState.current,
);

const _starterUtterance = CareUtterance(
  phraseId: 'bedtime_dim_the_lights',
  english: 'Let’s dim the lights.',
  chinese: '我们把灯调暗一点。',
  pronunciation: 'lets dim the lights',
  audioAsset: 'assets/audio/bedtime_dim_the_lights.mp3',
  whenToSay: '调暗灯光时说。',
  isFallback: false,
);

const _supportUtterance = CareUtterance(
  phraseId: 'bedtime_take_it_slowly',
  english: 'We can take it slowly.',
  chinese: '我们可以慢慢来。',
  pronunciation: 'we can take it slowly',
  audioAsset: 'assets/audio/bedtime_take_it_slowly.mp3',
  whenToSay: '宝宝犹豫或抗拒时说。',
  isFallback: false,
);

CareTurnSnapshot _starterSnapshot() => const CareTurnSnapshot(
  moment: _bedtimeMoment,
  currentUtterance: _starterUtterance,
  selectedReaction: null,
  nextSupportUtterance: null,
  phase: CareTurnPhase.utteranceReady,
  traceEventKey: null,
  latestGardenImpact: null,
  message: null,
);

CareTurnSnapshot _nextSupportSnapshot() => const CareTurnSnapshot(
  moment: _bedtimeMoment,
  currentUtterance: _starterUtterance,
  selectedReaction: BabyReactionType.hesitant,
  nextSupportUtterance: _supportUtterance,
  phase: CareTurnPhase.nextSupportReady,
  traceEventKey: 'trace_onboarding_1',
  latestGardenImpact: null,
  message: null,
);

class _ScriptedCarePathRepository extends CarePathRepository {
  _ScriptedCarePathRepository({required PracticeRepository practiceRepository})
      : super(practiceRepository: practiceRepository);

  bool completeReactionWithError = false;
  CareTurnSnapshot nextSnapshot = _nextSupportSnapshot();
  final List<String?> receivedLocalEventIds = <String?>[];

  @override
  Future<CareTurnSnapshot> startMoment({
    required String spaceId,
    required String activityId,
  }) async {
    if (spaceId != _bedtimeMoment.spaceId ||
        activityId != _bedtimeMoment.activityId) {
      throw StateError('unexpected moment: $spaceId/$activityId');
    }
    return _starterSnapshot();
  }

  @override
  Future<CareTurnSnapshot> recordReaction({
    required CareTurnSnapshot turn,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    receivedLocalEventIds.add(localEventId);
    if (completeReactionWithError) {
      throw StateError('simulated unknown write result');
    }
    return nextSnapshot.copyWith(selectedReaction: reactionType);
  }
}
```

The test `setUp` must create `scriptedCarePathRepository`, wrap it in the real `CarePathNotifier`, create temporary Task 2 stores, and inject a deterministic `localEventIdGenerator` returning `evt_onboarding_fixed`.

Add explicit tests for these cases:

```dart
test('cannot advance without required age, scenes, goal, and moment', () async {
  await notifier.initialize();
  expect(notifier.step, OnboardingFlowStep.welcome);
  await notifier.continueFromWelcome();
  expect(notifier.step, OnboardingFlowStep.age);
  await notifier.continueFromAge();
  expect(notifier.step, OnboardingFlowStep.age);
  expect(notifier.message, '先选一个适合宝宝的年龄范围。');
});

test('selected moment starts the formal Care Path and stores the actual phrase id', () async {
  await notifier.initialize();
  await notifier.continueFromWelcome();
  await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
  await notifier.continueFromAge();
  await notifier.toggleScenePreference('bedtime');
  await notifier.continueFromScenePreferences();
  await notifier.selectSupportGoal(OnboardingSupportGoal.moreNatural);
  await notifier.continueFromSupportGoal();
  await notifier.selectCurrentMoment(
    const OnboardingMomentChoice(
      spaceId: 'family_rhythm',
      activityId: 'bedtime',
      spaceTitle: '家庭节奏',
      title: '睡前时间',
      summary: '准备睡觉',
    ),
  );
  expect(notifier.step, OnboardingFlowStep.careTurn);
  expect(notifier.careTurn?.moment.activityId, 'bedtime');
  expect(notifier.flowSnapshot.starterPhraseId, 'bedtime_dim_the_lights');
});

test('reaction persists localEventId before write and retry reuses it', () async {
  await notifier.initialize();
  await notifier.continueFromWelcome();
  await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
  await notifier.continueFromAge();
  await notifier.toggleScenePreference('bedtime');
  await notifier.continueFromScenePreferences();
  await notifier.selectSupportGoal(OnboardingSupportGoal.moreNatural);
  await notifier.continueFromSupportGoal();
  await notifier.selectCurrentMoment(
    const OnboardingMomentChoice(
      spaceId: 'family_rhythm',
      activityId: 'bedtime',
      spaceTitle: '家庭节奏',
      title: '睡前时间',
      summary: '准备睡觉',
    ),
  );
  notifier.markSaid();
  scriptedCarePathRepository.completeReactionWithError = true;
  await notifier.selectReaction(BabyReactionType.resisting);
  final firstId = notifier.flowSnapshot.pendingLocalEventId;
  scriptedCarePathRepository.completeReactionWithError = false;
  await notifier.selectReaction(BabyReactionType.resisting);
  expect(scriptedCarePathRepository.receivedLocalEventIds, [firstId, firstId]);
});

test('confirmed event plus unavailable Garden still advances to trace', () async {
  await notifier.initialize();
  await notifier.continueFromWelcome();
  await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
  await notifier.continueFromAge();
  await notifier.toggleScenePreference('bedtime');
  await notifier.continueFromScenePreferences();
  await notifier.selectSupportGoal(OnboardingSupportGoal.moreNatural);
  await notifier.continueFromSupportGoal();
  await notifier.selectCurrentMoment(
    const OnboardingMomentChoice(
      spaceId: 'family_rhythm',
      activityId: 'bedtime',
      spaceTitle: '家庭节奏',
      title: '睡前时间',
      summary: '准备睡觉',
    ),
  );
  notifier.markSaid();
  scriptedCarePathRepository.nextSnapshot = _nextSupportSnapshot();
  await notifier.selectReaction(BabyReactionType.noResponse);
  expect(notifier.step, OnboardingFlowStep.trace);
  expect(notifier.flowSnapshot.traceEventKey, isNotEmpty);
  expect(notifier.gardenTraceDegraded, isTrue);
});

test('local completion writes actual starter and enters completed state', () async {
  await notifier.initialize();
  await notifier.continueFromWelcome();
  await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
  await notifier.continueFromAge();
  await notifier.toggleScenePreference('bedtime');
  await notifier.continueFromScenePreferences();
  await notifier.selectSupportGoal(OnboardingSupportGoal.moreNatural);
  await notifier.continueFromSupportGoal();
  await notifier.selectCurrentMoment(
    const OnboardingMomentChoice(
      spaceId: 'family_rhythm',
      activityId: 'bedtime',
      spaceTitle: '家庭节奏',
      title: '睡前时间',
      summary: '准备睡觉',
    ),
  );
  notifier.markSaid();
  await notifier.selectReaction(BabyReactionType.hesitant);
  await notifier.continueFromTrace();
  final completed = await notifier.chooseLocalOnly();
  expect(completed.starterSpaceId, 'family_rhythm');
  expect(completed.starterActivityId, 'bedtime');
  expect(completed.starterPhraseId, 'bedtime_dim_the_lights');
  expect(completed.firstTraceEventKey, isNotEmpty);
  expect(await onboardingRepository.readFlowSnapshot(), isNull);
});
```

- [ ] **Step 2: Confirm compilation failure**

```bash
cd mobile
flutter test test/features/onboarding/presentation/onboarding_flow_notifier_test.dart
```

Expected: `OnboardingFlowNotifier` missing.

- [ ] **Step 3: Implement notifier construction and single-source care-turn state**

Use this constructor contract:

```dart
class OnboardingFlowNotifier extends ChangeNotifier {
  OnboardingFlowNotifier({
    required OnboardingRepository onboardingRepository,
    required PracticeRepository practiceRepository,
    required CarePathNotifier carePathNotifier,
    required AccountNotifier accountNotifier,
    required AuthContinuationCoordinator authContinuationCoordinator,
    DateTime Function()? clock,
    String Function()? localEventIdGenerator,
  });

  OnboardingFlowSnapshot get flowSnapshot;
  OnboardingFlowStep get step => flowSnapshot.step;
  CareTurnSnapshot? get careTurn => _carePathNotifier.snapshot;
  List<OnboardingMomentChoice> get availableMoments;
  String? get message;
  bool get isBusy;
  bool get gardenTraceDegraded;
}
```

Attach one listener to `CarePathNotifier` and remove it in `dispose`. Never copy `CareTurnSnapshot` into the flow snapshot.

- [ ] **Step 4: Implement initialization and recovery**

`initialize()` must:

1. load `PracticeActivityCatalog`;
2. map each activity into `OnboardingMomentChoice`;
3. read the persisted flow snapshot or create `initial(clock())`;
4. if a selected moment exists and step is `careTurn`, `trace`, or `accountInvitation`, call `startMoment` with the persisted IDs;
5. if a trace key already exists, keep `trace`/`accountInvitation` and never write another event;
6. if the account is signed in and pending continuation is `saveOnboardingMemory`, complete onboarding from the persisted trace;
7. persist every phase transition before notifying the UI.

- [ ] **Step 5: Implement profile selection transitions**

Expose:

```dart
Future<void> continueFromWelcome();
Future<void> selectAgeBucket(OnboardingAgeBucket value);
Future<void> continueFromAge();
Future<void> toggleScenePreference(String activityId);
Future<void> continueFromScenePreferences();
Future<void> selectSupportGoal(OnboardingSupportGoal value);
Future<void> continueFromSupportGoal();
Future<void> selectCurrentMoment(OnboardingMomentChoice value);
```

Scene preference selection is multi-select. Current moment selection is single-select and must be one catalog activity; if preferred scenes exist, order matching activities first but keep all catalog activities available.

- [ ] **Step 6: Implement the real care-turn actions**

`markSaid()` delegates directly to `_carePathNotifier.markSaid()`.

`selectReaction()` must:

1. reject calls unless the formal turn is in `reactionPrompt`;
2. create one stable `pendingLocalEventId` and persist it before repository I/O;
3. persist the selected canonical reaction;
4. call `_carePathNotifier.selectReaction(reaction, localEventId: stableId)`;
5. advance to `trace` only when the resulting snapshot has a non-empty `traceEventKey` and either `nextSupportReady` or `heldWithFallback`;
6. retain the same ID and selection after errors for manual retry.

Use an ID such as `evt_onboarding_${utcMicros}_${32BitHex}`; inject the generator in tests.

- [ ] **Step 7: Implement trace acknowledgement and account decision**

Expose:

```dart
Future<void> continueFromTrace();
Future<void> beginAccountSave();
Future<OnboardingSnapshot?> handleAccountReturn(AccountEntryResult? result);
Future<OnboardingSnapshot> chooseLocalOnly();
```

`continueFromTrace()` moves to `accountInvitation`. `beginAccountSave()` persists the continuation and leaves the flow on `accountInvitation`; the screen performs the route push. `handleAccountReturn` completes only if `result == signedIn` and `AccountNotifier.isSignedIn` is true. `chooseLocalOnly` clears any pending continuation and completes immediately.

Completion must call Task 1’s `completeOnboarding` with the exact formal turn moment, starter phrase ID, selected scenes, support goal, and persisted trace key. Write the completed snapshot first, then clear flow and continuation stores.

- [ ] **Step 8: Register the notifier provider**

Add a non-auto-dispose `ChangeNotifierProvider<OnboardingFlowNotifier>` with explicit dependencies on the onboarding repository, practice repository, care path notifier, account notifier, and auth continuation coordinator. Call `initialize()` once in the provider constructor.

- [ ] **Step 9: Run notifier tests**

```bash
cd mobile
flutter test test/features/onboarding/presentation/onboarding_flow_notifier_test.dart
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/onboarding_flow_notifier.dart mobile/lib/app/providers/repository_providers.dart mobile/test/features/onboarding/presentation/onboarding_flow_notifier_test.dart
git commit -m "feat(onboarding): orchestrate one real care turn"
```

---

### Task 7: Single-screen Onboarding UI and User-visible Copy

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart`
- Create: `mobile/lib/features/onboarding/presentation/widgets/onboarding_flow_shell.dart`
- Create: `mobile/lib/features/onboarding/presentation/widgets/onboarding_selection_steps.dart`
- Create: `mobile/lib/features/onboarding/presentation/widgets/onboarding_trace_step.dart`
- Modify: `mobile/lib/l10n/app_zh.arb`
- Test: `mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart`

**Interfaces:**
- Produces: `OnboardingFlowScreen(audioControllerFactory:)`.
- Consumes: `onboardingFlowNotifierProvider`, `CareTurnSurface`, `/account` typed result.
- Does not call repositories directly.

- [ ] **Step 1: Add the exact M1 localization keys**

Add these keys to `app_zh.arb` with the exact values shown:

```json
"onboardingWelcomeTitle": "宝宝正在做什么？",
"onboardingWelcomeBody": "我们给你一句现在就能说的英语。",
"onboardingStart": "开始",
"onboardingAgeTitle": "宝宝现在多大？",
"onboardingAgeRequired": "先选一个适合宝宝的年龄范围。",
"onboardingScenesTitle": "哪些照护时刻最常出现？",
"onboardingScenesBody": "可以多选，之后仍能随时看看其他场景。",
"onboardingScenesRequired": "至少选一个常见照护时刻。",
"onboardingGoalTitle": "你希望我们怎么帮你？",
"onboardingGoalFirstWords": "我不知道该怎么说",
"onboardingGoalNatural": "我会一点，想说得更自然",
"onboardingGoalHabit": "我想把英语放进日常照护",
"onboardingMomentTitle": "现在正在发生什么？",
"onboardingCareTurnTitle": "现在就能说",
"onboardingTraceTitle": "刚才这句话，已经留在你们的花园里。",
"onboardingTraceDegraded": "刚才的照护时刻已经记下，花园会稍后整理出来。",
"onboardingTraceContinue": "继续",
"onboardingAccountTitle": "把这些照护时刻保存到账号",
"onboardingAccountBody": "换手机后，也能继续看到刚才留下的痕迹。",
"onboardingSaveAccount": "保存并继续",
"onboardingContinueLocal": "暂时不用",
"onboardingRetry": "再试一次",
"onboardingSafeMomentFallback": "刚才没有准备好，换一个场景试试。"
```

Do not add step counts, progress percentages, completion congratulations, XP, streak, or task copy.

- [ ] **Step 2: Write failing widget-flow tests**

Cover these exact behaviors:

```dart
testWidgets('selection cards do not advance until the bottom CTA is pressed', (tester) async {
  await harness.pumpAtStep(tester, OnboardingFlowStep.age);
  await tester.tap(find.byKey(const Key('onboarding-age-1-2')));
  await tester.pump();
  expect(harness.notifier.step, OnboardingFlowStep.age);
  await tester.tap(find.byKey(const Key('onboarding-primary-action')));
  await tester.pump();
  expect(harness.notifier.step, OnboardingFlowStep.scenePreferences);
});

testWidgets('care turn uses formal reaction keys and reaches a real trace', (tester) async {
  await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);
  await tester.tap(find.byKey(const Key('care-turn-said-button')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
  await tester.pumpAndSettle();
  expect(harness.notifier.step, OnboardingFlowStep.trace);
  expect(harness.notifier.flowSnapshot.traceEventKey, isNotEmpty);
});

testWidgets('audio failure keeps the said action enabled', (tester) async {
  harness.audioController.failNextPlay = true;
  await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);
  await tester.tap(find.byKey(const Key('care-turn-audio-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('care-turn-audio-error')), findsOneWidget);
  expect(tester.widget<ElevatedButton>(find.byKey(const Key('care-turn-said-button'))).onPressed, isNotNull);
});

testWidgets('account save returns from typed account route and enters shell', (tester) async {
  await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);
  await tester.tap(find.byKey(const Key('onboarding-primary-action')));
  await tester.pumpAndSettle();
  expect(harness.accountRoutePushCount, 1);
  harness.completeAccountRoute(AccountEntryResult.signedIn);
  await tester.pumpAndSettle();
  expect(harness.shellNavigationCount, 1);
});

testWidgets('temporary local choice completes without opening account', (tester) async {
  await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);
  await tester.tap(find.byKey(const Key('onboarding-secondary-action')));
  await tester.pumpAndSettle();
  expect(harness.accountRoutePushCount, 0);
  expect(harness.shellNavigationCount, 1);
});

testWidgets('1.3 text scale remains scrollable at 390 by 844', (tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await harness.pumpAtStep(
    tester,
    OnboardingFlowStep.scenePreferences,
    textScaler: const TextScaler.linear(1.3),
  );
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('onboarding-primary-action')), findsOneWidget);
});
```



Add this test-only harness in the same file. It must construct real `OnboardingFlowNotifier` and `CarePathNotifier` instances over temporary stores; only navigation and audio are faked:

```dart
abstract interface class OnboardingFlowScreenTestHarness {
  OnboardingFlowNotifier get notifier;
  _ControllablePracticeAudioController get audioController;
  int get accountRoutePushCount;
  int get shellNavigationCount;

  Future<void> pumpAtStep(
    WidgetTester tester,
    OnboardingFlowStep step, {
    TextScaler textScaler = TextScaler.noScaling,
  });

  void completeAccountRoute(AccountEntryResult result);
}

class _ControllablePracticeAudioController implements PracticeAudioController {
  final StreamController<void> _completion = StreamController<void>.broadcast();
  bool failNextPlay = false;

  @override
  Stream<void> get completionStream => _completion.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    if (failNextPlay) {
      failNextPlay = false;
      throw StateError('audio unavailable');
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _completion.close();
}
```

Implement `OnboardingFlowScreenTestHarness` in the test file with `PracticeRepositoryCharacterizationHarness`, temporary `OnboardingFlowStore`/`OnboardingSnapshotStore`, the Task 5 in-memory account repository, and a `MaterialApp.router` whose `/account` route completes from a `Completer<AccountEntryResult>` and whose shell route increments `shellNavigationCount`. `pumpAtStep` must drive public notifier methods from `welcome` to the requested phase; it must not mutate notifier internals.

- [ ] **Step 3: Confirm missing-screen failure**

```bash
cd mobile
flutter test test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart
```

Expected: compilation failure.

- [ ] **Step 4: Implement the common shell**

`OnboardingFlowShell` must provide:

```dart
class OnboardingFlowShell extends StatelessWidget {
  const OnboardingFlowShell({
    super.key,
    required this.progress,
    required this.body,
    this.primaryLabel,
    this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.isBusy = false,
  });

  final double progress;
  final Widget body;
  final String? primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool isBusy;
}
```

Use `SafeArea`, a scrollable body, and a bottom action region that never hides content. Progress is a quiet line derived from the flow phase; do not render numeric step text.

- [ ] **Step 5: Implement selection widgets with stable keys**

Use these testable keys:

```text
onboarding-age-0-6
onboarding-age-7-12
onboarding-age-1-2
onboarding-age-2-3
onboarding-scene-{activityId}
onboarding-goal-first-words
onboarding-goal-more-natural
onboarding-goal-daily-habit
onboarding-moment-{spaceId}-{activityId}
onboarding-primary-action
onboarding-secondary-action
```

Card taps only select. Only the bottom CTA advances.

- [ ] **Step 6: Implement the single screen step switch**

`OnboardingFlowScreen` watches one notifier and switches on `notifier.step`. For `careTurn`, embed:

```dart
CareTurnSurface(
  notifier: ref.watch(carePathNotifierProvider),
  audioControllerFactory: audioControllerFactory,
  showQuietExit: false,
  onTraceReady: (_) {},
)
```

The flow notifier advances to trace from its care-path listener; the widget callback is informational only.

For account save:

```dart
await notifier.beginAccountSave();
if (!context.mounted) return;
final result = await context.push<AccountEntryResult>(AppRouteNames.account);
if (!context.mounted) return;
final completed = await notifier.handleAccountReturn(result);
if (completed != null && context.mounted) {
  context.go(AppRouteNames.shell, extra: completed);
}
```

For local completion, call `chooseLocalOnly()` and navigate with the returned snapshot.

- [ ] **Step 7: Run UI tests**

```bash
cd mobile
flutter gen-l10n
flutter test test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/onboarding/presentation mobile/lib/l10n mobile/test/features/onboarding/presentation
git commit -m "feat(onboarding): add the first care-turn flow UI"
```

---

### Task 8: Route, Boot, Provider, and Account Integration Cutover

**Files:**
- Modify: `mobile/lib/app/app.dart:277-465,475-525`
- Modify: `mobile/lib/app/router/app_route_contract.dart:1-30`
- Modify: `mobile/lib/app/router/app_go_router.dart:1-65`
- Modify: `mobile/lib/app/providers/repository_providers.dart:286-313`
- Modify: `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- Test: `mobile/test/app/app_route_contract_test.dart`
- Test: `mobile/test/smoke/app_boot_test.dart`
- Test: `mobile/test/widget_test.dart`
- Test: `mobile/test/app/app_composition_characterization_test.dart`

**Interfaces:**
- Produces: one public onboarding route `/onboarding`.
- Produces: old onboarding paths redirecting to `/onboarding`.
- Produces: `/account` rendering `AccountEntryScreen` backed by `AccountNotifier`.
- Consumes: Task 6/7 providers and screen.

- [ ] **Step 1: Write failing route-contract tests**

Update expectations to:

```dart
expect(AppRouteNames.canonicalPaths, <String>{
  AppRouteNames.shell,
  AppRouteNames.onboarding,
  AppRouteNames.practice,
  AppRouteNames.account,
  AppRouteNames.meSettings,
  AppRouteNames.meGrowth,
});
expect(AppRouteNames.legacyOnboardingPaths, <String>{
  '/onboarding/name',
  '/onboarding/scene',
  '/onboarding/practice',
  '/onboarding/complete',
  '/onboarding/garden-welcome',
});
```

Add a router test proving every legacy path resolves to the one `OnboardingFlowScreen` route.

- [ ] **Step 2: Confirm route tests fail**

```bash
cd mobile
flutter test test/app/app_route_contract_test.dart
```

Expected: old paths are still canonical and no redirect set exists.

- [ ] **Step 3: Replace route constants**

Keep only canonical `/onboarding`. Add:

```dart
static const legacyOnboardingPaths = <String>{
  '/onboarding/name',
  '/onboarding/scene',
  '/onboarding/practice',
  '/onboarding/complete',
  '/onboarding/garden-welcome',
};
```

Legacy paths are migration inputs, not canonical destinations.

- [ ] **Step 4: Update both router compositions**

In `BabyTalkApp`’s router and `app_go_router.dart`:

- route `/onboarding` to `OnboardingFlowScreen(audioControllerFactory: ...)`;
- add explicit legacy routes whose `redirect` returns `AppRouteNames.onboarding`;
- route `/account` to `const AccountEntryScreen()`;
- remove imports of all legacy onboarding screens and `AuthScreen`.

Do not use nested onboarding child routes. The flow phase belongs to the notifier, not the URL.

- [ ] **Step 5: Build both onboarding stores during boot**

In `_loadLaunchState`, construct both stores from the protected application directory:

```dart
final onboardingRepository = OnboardingRepository(
  snapshotStore: OnboardingSnapshotStore(directoryResolver: () async => directory),
  flowStore: OnboardingFlowStore(directoryResolver: () async => directory),
  practiceRepository: practiceRepository,
  starterSpaceId: widget.bootState.primarySpaceId!,
  starterActivityId: widget.bootState.primaryActivityId!,
);
```

Keep the existing configured starter fields only for legacy snapshot fallback until Task 9 removes `resolveStarterSeed`; they must not influence new M1 completion.

- [ ] **Step 6: Override the repository provider and ensure onboarding dependencies resolve**

Keep the current nested `ProviderScope` override for `onboardingRepositoryProvider`. Ensure `onboardingFlowNotifierProvider` is constructed inside that scope and receives the same global `carePathNotifierProvider` later used by Today.

- [ ] **Step 7: Add boot tests for fresh, interrupted, and completed states**

Add these scenarios:

1. no completed snapshot/no flow snapshot → `/onboarding` welcome;
2. persisted flow at `careTurn` → `/onboarding` resumes selected moment;
3. persisted trace/account invitation → no duplicate event is written;
4. completed M1 snapshot → shell starts with its actual starter IDs;
5. legacy completed snapshot remains shell-compatible;
6. legacy onboarding deep link redirects to `/onboarding`.

- [ ] **Step 8: Run composition and boot tests**

```bash
cd mobile
flutter test \
  test/app/app_route_contract_test.dart \
  test/smoke/app_boot_test.dart \
  test/widget_test.dart \
  test/app/app_composition_characterization_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/app mobile/lib/features/account/presentation/screens/account_entry_screen.dart mobile/test/app mobile/test/smoke mobile/test/widget_test.dart
git commit -m "feat(app): cut onboarding over to the real care path"
```

---

### Task 9: Legacy Onboarding Removal and Semantic Firewall

**Files:**
- Delete: legacy files listed in the file map.
- Modify: `mobile/lib/app/providers/repository_providers.dart`
- Modify: `mobile/lib/features/onboarding/data/repositories/onboarding_repository.dart`
- Modify: `mobile/test/tool/verify_care_path_copy_firewall_test.dart`
- Delete: `mobile/test/features/onboarding/data/services/scene_phrase_service_test.dart`
- Delete: `mobile/test/features/onboarding/domain/models/practice_record_test.dart`
- Delete: `mobile/test/features/onboarding/domain/models/practice_scene_test.dart`
- Delete: `mobile/test/features/onboarding/presentation/onboarding_session_notifier_test.dart`
- Delete: `mobile/test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart`
- Delete: `mobile/test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart`

**Interfaces:**
- Produces: one onboarding implementation with no legacy runtime imports.
- Consumes: Tasks 1–8 replacement flow.

- [ ] **Step 1: Strengthen the firewall before deleting legacy code**

Add a test scanning `lib/features/onboarding` and route files for these blocked runtime symbols:

```dart
const blockedLegacySymbols = <String>[
  'OnboardingSessionNotifier',
  'ScenePhraseService',
  'BabyReaction.responded',
  'BabyReaction.noResponse',
  'PracticeRecord',
  'OnboardingPracticeScreen',
  'OnboardingCompleteScreen',
  'OnboardingGardenWelcomeScreen',
  "context.push('/onboarding/",
];
```

Add user-visible blocked terms for onboarding localization keys:

```dart
const blockedOnboardingCopy = <String>[
  '练习', '课程', '任务', '完成', '正确', '错误', '积分', '金币', '排行榜',
  'XP', 'streak', 'lesson', 'exercise', 'progress', '1 of 3',
];
```

Limit the Chinese word `错误` check to user-visible onboarding keys; internal exception messages may contain it.

- [ ] **Step 2: Run firewall and confirm it fails against legacy code**

```bash
cd mobile
flutter test test/tool/verify_care_path_copy_firewall_test.dart
```

Expected: FAIL listing legacy symbols and/or blocked old onboarding copy.

- [ ] **Step 3: Remove legacy providers and starter resolution**

Delete `scenePhraseServiceProvider` and `onboardingSessionProvider`. Remove `resolveStarterSeed()` and `OnboardingStarterSeed` after confirming no production consumer remains:

```bash
rg -n "OnboardingStarterSeed|resolveStarterSeed|onboardingSessionProvider|scenePhraseServiceProvider" mobile/lib mobile/test
```

Expected after cleanup: no match.

- [ ] **Step 4: Delete legacy files and tests**

Delete only after all references are migrated. Keep `onboarding_design_widgets.dart`, `scene_button.dart`, and any neutral assets still used by the new flow; delete them only if `rg` confirms no consumer.

- [ ] **Step 5: Prove no legacy route or runtime symbol remains**

Run:

```bash
rg -n "OnboardingSessionNotifier|ScenePhraseService|BabyReaction\.|PracticeRecord|OnboardingPracticeScreen|OnboardingCompleteScreen|OnboardingGardenWelcomeScreen" mobile/lib
```

Expected: no output.

Run:

```bash
cd mobile
flutter test test/tool/verify_care_path_copy_firewall_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A mobile/lib/features/onboarding mobile/lib/app/providers/repository_providers.dart mobile/test/features/onboarding mobile/test/tool/verify_care_path_copy_firewall_test.dart
git commit -m "refactor(onboarding): remove the legacy phrase loop"
```

---

### Task 10: End-to-end M1 Proof, Accessibility, and Release Gate

**Files:**
- Create: `mobile/test/integration/onboarding_first_care_turn_integration_test.dart`
- Modify: `mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart`
- Modify: `mobile/test/smoke/app_boot_test.dart`
- Modify: `docs/superpowers/specs/2026-07-23-duolingo-like-care-path-three-milestone-roadmap-design.md` only to add implementation proof links/status; do not rewrite approved product decisions.
- Create: `docs/superpowers/verification/2026-07-23-m1-first-care-turn-onboarding-verification.md`

**Interfaces:**
- Produces: executable proof that a fresh user reaches Today through one real event and one real trace.
- Consumes: all M1 production interfaces.

- [ ] **Step 1: Write the integration test with real local repositories**

The test must use a temporary application directory, bundled seed content, real Isar `PracticeLocalDataSource`, real `PracticeRepository`, real `GardenGrowthRepository`, real `CarePathRepository`, real stores, and the real flow notifier. The essential assertions are:

```dart
expect(await practiceRepository.listEventHistory(), isEmpty);

await flow.initialize();
await flow.continueFromWelcome();
await flow.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
await flow.continueFromAge();
await flow.toggleScenePreference('bedtime');
await flow.continueFromScenePreferences();
await flow.selectSupportGoal(OnboardingSupportGoal.moreNatural);
await flow.continueFromSupportGoal();
await flow.selectCurrentMoment(bedtimeChoice);
flow.markSaid();
await flow.selectReaction(BabyReactionType.hesitant);
await flow.continueFromTrace();
final completed = await flow.chooseLocalOnly();

final events = await practiceRepository.listEventHistory();
expect(events, hasLength(1));
expect(events.single.reactionType, BabyReactionType.hesitant);
expect(completed.firstTraceEventKey, events.single.eventKey);
expect(completed.starterSpaceId, 'family_rhythm');
expect(completed.starterActivityId, 'bedtime');
expect(completed.starterPhraseId, 'bedtime_dim_the_lights');

final continuity = await carePathRepository.loadCurrentTurn(
  starterSpaceId: completed.starterSpaceId,
  starterActivityId: completed.starterActivityId,
);
expect(continuity.moment.activityId, 'bedtime');
```

Add a second test that calls the same reaction twice with the persisted local ID and asserts one stored event.

- [ ] **Step 2: Run integration proof**

```bash
cd mobile
flutter test test/integration/onboarding_first_care_turn_integration_test.dart
```

Expected: PASS.

- [ ] **Step 3: Add accessibility and viewport assertions**

In widget tests, verify:

- 390×844 at 1.3 text scale can scroll to the primary CTA;
- every age, scene, goal, reaction, listen, said, retry, account, and local-only action has a semantic button label;
- decorative onboarding images are excluded from semantics;
- reaction order is cooperating, hesitant, resisting, no response, other;
- after next support appears, semantic focus can reach the new English sentence before the trace action;
- reduced-motion mode does not hide any state transition.

Use `tester.ensureVisible`, `tester.getSemantics`, and `SemanticsTester`; do not rely on golden images for semantics.

- [ ] **Step 4: Run all focused M1 suites**

```bash
cd mobile
flutter test \
  test/features/onboarding \
  test/features/care_path \
  test/features/account/auth_continuation_store_test.dart \
  test/features/account/account_entry_screen_test.dart \
  test/app/app_route_contract_test.dart \
  test/app/local_sensitive_data_clearance_registry_test.dart \
  test/smoke/app_boot_test.dart \
  test/integration/onboarding_first_care_turn_integration_test.dart \
  test/tool/verify_care_path_copy_firewall_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run code generation, format, analysis, and the entire mobile test suite**

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Expected: generator succeeds, formatter exits 0, analyzer reports no issues, all tests pass.

- [ ] **Step 6: Run repository local CI from a clean worktree**

First commit any generated changes from the task, then ensure the worktree is clean:

```bash
git status --short
```

Expected: no output.

Run:

```bash
bash ci/full-ci.sh
```

Expected: every gate prints success and the script exits 0. If the environment lacks Docker/Flutter/JDK prerequisites, record the exact blocked gate in the verification document and do not claim full CI passed.

- [ ] **Step 7: Perform Android UAT and record evidence**

Validate on:

```text
Pixel 9 Pro: 427×952 dp
Narrow viewport: 390×844 dp
Real Android device
Text scale: 1.3x
TalkBack enabled
Reduce motion enabled
Offline seed flow
Audio asset failure and retry
Reaction write failure and same-ID retry
Process restart at care turn, trace, and account invitation
```

Record actual build identifier, device, viewport, pass/fail, and evidence path in the verification document. Do not mark a row passed without observed evidence.

- [ ] **Step 8: Write the verification document**

Use this exact structure:

```markdown
# M1 First Care-turn Onboarding Verification

- Baseline:
- Implementation commit:
- Flutter version:
- Android build:

## Automated gates
| Gate | Command | Result | Evidence |

## Contract proof
| Requirement | Test or code proof | Result |

## Device UAT
| Device/state | Result | Evidence |

## Known limitations
```

Link the approved roadmap spec, this implementation plan, focused tests, copy firewall, full CI output, and device evidence.

- [ ] **Step 9: Commit the proof**

```bash
git add mobile docs/superpowers/specs/2026-07-23-duolingo-like-care-path-three-milestone-roadmap-design.md docs/superpowers/verification/2026-07-23-m1-first-care-turn-onboarding-verification.md
git commit -m "test(onboarding): prove the first care-turn release gate"
```

---

## Final M1 Exit Checklist

Before declaring M1 complete, verify all statements are true with fresh evidence:

- [ ] `/onboarding` is the only canonical onboarding route.
- [ ] Every legacy onboarding deep link redirects to `/onboarding`.
- [ ] The legacy phrase service, session notifier, reaction enum, practice record, and completion screens are absent from production code.
- [ ] The first utterance comes from `CarePathRepository.startMoment` for the user-selected catalog moment.
- [ ] “我说了” moves the formal Care Path into `reactionPrompt`.
- [ ] The reaction uses the canonical five-value contract.
- [ ] One stable `localEventId` is persisted before reaction I/O.
- [ ] Retry or unknown outcome reconciles the same event and never creates a duplicate.
- [ ] A non-empty real `traceEventKey` exists before onboarding can complete.
- [ ] Garden snapshot failure degrades copy but does not roll back the confirmed event.
- [ ] The completed snapshot stores the actual starter space, activity, and phrase.
- [ ] Today loads continuity from those exact starter IDs.
- [ ] Account save appears only after the real trace.
- [ ] Local-only completion works without opening account entry.
- [ ] Account entry uses `AccountNotifier`/`AccountRepository`, returns a typed result, and retains continuation across process restart.
- [ ] Account continuation is cleared on success, local skip, logout, consent withdrawal, account deletion, and device erase.
- [ ] M1 contains no Custom Scene or generated-audio implementation.
- [ ] User-visible onboarding copy passes the semantic firewall.
- [ ] 390×844, 427×952, 1.3x text, TalkBack, and reduced-motion checks have recorded evidence.
- [ ] `flutter analyze`, `flutter test`, and the relevant local CI gate have fresh results.
