# Task 6A report

## Delivered

- Controller exhaustively branches `GeneratedSceneResult`, `HealthSafetyResult`, and `AssessmentUnavailableResult`.
- Added `healthSafety` / `assessmentUnavailable` terminal phases, `safetyNotice`, operation epoch invalidation, account/dispose/modify guards, and injected `CustomSceneAudioStopper` with a 250 ms bound.
- Safety publishes Chinese notice before best effort draft/auth cleanup; no registration, handoff, generated ID, or generated resume survives.
- Draft storage carries provenance only for generated pending/ready states and rejects missing, stale, or unknown policy/epoch on decode.
- Generated local store and registry persist and validate `health-safety-v1` plus content refresh epoch `2`; invalid records are quarantined before lookup.
- Updated Task5 union fixtures and focused tests.

## Verification

Passed:

```text
flutter test test/features/custom_scene/custom_scene_submission_controller_test.dart test/features/custom_scene/custom_scene_draft_continuation_test.dart test/features/custom_scene/custom_scene_input_screen_test.dart test/features/practice/generated/generated_care_moment_local_store_test.dart test/features/practice/generated/generated_practice_content_registry_test.dart test/app/custom_scene_recovery_coordinator_test.dart
dart analyze lib/features/custom_scene lib/features/practice/data/generated test/features/custom_scene test/features/practice/generated
git diff --check
```

Generated `mobile/windows/flutter` files were restored after Flutter runs.

Commit: `feat(mobile): add health safety terminal state`

## Short contract

Safety/unavailable result stops owned audio within 250 ms, invalidates old callbacks, exposes Chinese terminal notice, and clears durable custom-scene continuation best effort. Generated content is accepted only with policy `health-safety-v1` and epoch `2`; all other persisted generated content is unavailable and cannot reach handoff or audio.

## Round 1 fixes

- Added synchronous `invalidateForAccountChange()` and account generation tokens; recovery invokes it on account scope changes. Late old results cannot write or delete a newer account draft, and route failures cannot alter a newer account route.
- Captured operation tokens before enqueue for submit/retry/auth resume/restore. Cancellation during account load, draft I/O, audio stop, or registration invalidates every later state/write step.
- Added exact `draftId`/request/account conditional cleanup, best effort cancel with editing in `finally`, explicit generated-draft provenance validation, and late registration/dispose/modify tests.

Round 1 focused tests, analyzer, and diff checks pass. Flutter-generated Windows files were restored.

## Round 2 fixes

- Recovery now advances scope generation and invalidates controller synchronously before queueing work. A→B→A events invalidate stale restore and route completions.
- Added compare-and-delete for draft and authentication continuation identity/account tuples. Profile/corrupt/expired cleanup checks operation ownership and never runs unscoped cancellation for stale work.
- Exposed `safetyAudioStopTimeout` as exact 250 ms constant; tests assert exact value and retain bounded wall-clock tolerance.

Round 2 focused tests passed. Also passed:

```text
dart format --output=none --set-exit-if-changed lib/features/custom_scene/application/custom_scene_submission_controller.dart lib/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart lib/features/custom_scene/data/custom_scene_draft_store.dart lib/features/custom_scene/domain/custom_scene_stored_draft.dart lib/app/custom_scene_recovery_coordinator.dart test/features/custom_scene/custom_scene_submission_controller_test.dart test/features/custom_scene/custom_scene_draft_continuation_test.dart test/features/custom_scene/custom_scene_handoff_confirmation_coordinator_test.dart test/app/custom_scene_recovery_coordinator_test.dart test/features/practice/generated/generated_care_moment_local_store_test.dart test/features/practice/generated/generated_practice_content_registry_test.dart
dart analyze lib/features/custom_scene lib/features/practice/data/generated test/features/custom_scene test/features/practice/generated
git diff --check
```

Windows Flutter generated files were restored after verification.
