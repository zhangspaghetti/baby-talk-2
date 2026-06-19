---
phase: 41
slug: mobile-v2-runnable-vertical-slice
status: draft
nyquist_compliant: true
wave_0_plan_ready: true
created: 2026-06-16
---

# Phase 41 - Validation Strategy

> Per-phase validation contract for the runnable `mobile_v2` Ritual Room slice.

## 2026-06-17 Product Correction Override

This validation strategy is controlled by `41-SCHEMATIC-DESIGN.md` wherever older rows describe First Entry, Today Orientation, a four-lens tap-through path, or direct local fixture ownership. The final Phase 41 proof should validate the direct mock-API-backed `Ritual Room Support` surface with anchor phrase, phrase set, action / TPR cues, audio labels, no-response reassurance, quiet exit, and no forbidden old semantics.

## 2026-06-19 Interaction Engine Override

Validation must also follow `41-INTERACTION-ENGINE-CONTRACT.md`. Final proof
must cover the separate room-content and interaction repositories, typed
multi-channel input contract, executable handling of every normalized channel,
submitting/retry state, mixed-channel monotonic revisions, in-place utterance
updates, and UI exposure limited to approved reaction controls.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter widget tests with `flutter_test`; repo-owned Dart verifier CLIs |
| **Config file** | `mobile_v2/pubspec.yaml` |
| **Quick run command** | Run the focused test touched by the current task, for example `cd mobile_v2 && flutter test test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`. |
| **Full suite command** | From `mobile_v2`: `dart format --output=none --set-exit-if-changed .`; `flutter analyze`; `flutter test`; `dart run ../tool/verify_mobile_v2_semantic_firewall.dart`; `dart run ../tool/verify_activation_governor_contract.dart` |
| **Estimated runtime** | Focused per-task commands target <=30 seconds after Flutter command-health is restored; full wave/final gates can take longer. |

---

## Sampling Rate

- **After every task commit:** Run the focused `mobile_v2` widget or fixture test touched by the task.
- **After every plan wave:** Run the focused tests plus both Phase 39 and Phase 40 verifier CLIs.
- **Before `$gsd-verify-work`:** Format check, analyzer, full `mobile_v2` test suite, semantic firewall, and Activation Governor / Garden Memory verifier must be green.
- **Max feedback latency:** <=30 seconds for focused per-task commands once Flutter command-health is fixed; full `cd mobile_v2 && flutter test` plus verifier CLIs are wave/final gates and may exceed the per-task latency target.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Plan Coverage | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|---------------|--------|
| 41-01-01 | 41-01 | 0 | R058, R059, R060, R063, R064, R065, R067 | T-41-01 / T-41-02 | Flutter and Dart commands run from the correct `mobile_v2` and repo roots, not the root Flutter wrapper that delegates to old `mobile/`. | command health | `cd mobile_v2 && flutter test --help`; `dart --version` | Covered by 41-01 Task 1 | planned |
| 41-01-02 | 41-01 | 0 | R058, R059, R060, R063, R064, R065, R067 | T-41-01 / T-41-02 | Final verifier commands and direct SDK fallbacks are documented before runtime files change. | command map | `Select-String -Path .planning/phases/41-mobile-v2-runnable-vertical-slice/41-COMMAND-HEALTH.md -Pattern 'Phase 41 Final Gate'` | Covered by 41-01 Task 2 | planned |
| 41-02-01 | 41-02 | 1 | R058, R059, R060, R063, R067 | T-41-01 / T-41-02 | RED tests encode content and capability-complete interaction APIs, request/response DTOs, mappers, repositories, loading/submitting/error states, and one-room controller before source exists. | API/controller TDD RED | `cd mobile_v2 && flutter test test/features/ritual_room/data test/features/ritual_room/presentation/controllers/ritual_room_controller_test.dart` | Test files planned by 41-02 | planned |
| 41-02-02 | 41-02 | 1 | R058, R059, R060, R063, R067 | T-41-01 / T-41-02 | Content bootstrap returns one active room; every normalized input channel maps to a request and advances an immutable snapshot; a mixed-channel sequence increments revision and evolves strategy while preserving fake Governor `allow_activation`. | API/controller TDD GREEN | `cd mobile_v2 && flutter test test/features/ritual_room/data test/features/ritual_room/presentation/controllers/ritual_room_controller_test.dart` | Runtime files planned by 41-02 | planned |
| 41-02-03 | 41-02 | 1 | R058, R059, R060, R063, R064, R065, R067 | T-41-01 / T-41-02 | Fixture/controller naming and capability-complete contracts pass semantic firewall and Activation Governor checks; no channel is rejected, stubbed, or left as a typed-only placeholder. | verifier TDD REFACTOR | `cd mobile_v2 && dart run ../tool/verify_mobile_v2_semantic_firewall.dart`; `cd mobile_v2 && dart run ../tool/verify_activation_governor_contract.dart` | Guard cleanup planned by 41-02 Task 3 | planned |
| 41-03-01 | 41-03 | 3 | R058, R059, R060, R063, R067 | T-41-01 / T-41-02 | The `mobile_v2` app shell compiles and opens direct `Ritual Room Support` without importing old `mobile/` runtime code. | app-shell widget smoke | `cd mobile_v2 && flutter test test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart` | App shell smoke planned by 41-03 | planned |
| 41-03-02 | 41-03 | 3 | R058, R059, R060, R063, R067 | T-41-01 / T-41-02 | Runnable app renders repository-owned room content plus evolving interaction snapshots and no First Entry / Today Orientation page. | widget flow + verifier | `cd mobile_v2 && flutter test test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`; `cd mobile_v2 && dart run ../tool/verify_mobile_v2_semantic_firewall.dart`; `cd mobile_v2 && dart run ../tool/verify_activation_governor_contract.dart` | Support surface tests planned by 41-03 | planned |
| 41-04-01 | 41-04 | 2 | R059, R064, R065, R067 | T-41-02 / T-41-03 | Stable Ritual identity, current utterance focus, neutral context input, and in-place revised output work without navigation, training, or progress semantics. | widget flow + verifier | `cd mobile_v2 && flutter test test/features/ritual_room/presentation/widgets/ritual_action_beat_list_test.dart`; `cd mobile_v2 && dart run ../tool/verify_mobile_v2_semantic_firewall.dart` | Room Support tests planned by 41-04 | planned |
| 41-04-02 | 41-04 | 2 | R059, R064, R065 | T-41-02 / T-41-03 | Optional Memory Lens, if implemented, appears only after quiet exit and stays free of production Garden transition mechanics. | widget flow + verifier | `cd mobile_v2 && flutter test test/features/ritual_room/presentation/screens/ritual_memory_lens_screen_test.dart`; `cd mobile_v2 && dart run ../tool/verify_activation_governor_contract.dart` | Optional memory tests planned by 41-04 | planned |
| 41-05-01 | 41-05 | 4 | R058, R059, R060, R063, R064, R065, R067 | T-41-01 / T-41-02 / T-41-03 | The `shoes_on` Interaction Engine slice is runnable and satisfies the approved single-screen multi-state design gate, including first-viewport hierarchy, payload substitution, sequential revision, and in-place update. | end-to-end widget flow + verifier | `cd mobile_v2 && flutter test test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`; `cd mobile_v2 && dart run ../tool/verify_mobile_v2_semantic_firewall.dart`; `cd mobile_v2 && dart run ../tool/verify_activation_governor_contract.dart` | Final flow planned by 41-05 | planned |
| 41-05-02 | 41-05 | 4 | R058, R059, R060, R063, R064, R065, R067 | T-41-01 / T-41-02 / T-41-03 | Final source tree contains no old mobile imports, forbidden old semantics, ungoverned activation intent, ritual-content hardcoding, channel stubs/rejections, extra hidden-channel UI controls, deployed backend/AI integration, or production Garden transition state. | full gate + proof | `cd mobile_v2 && dart format --output=none --set-exit-if-changed .`; `cd mobile_v2 && flutter analyze`; `cd mobile_v2 && flutter test`; `cd mobile_v2 && dart run ../tool/verify_mobile_v2_semantic_firewall.dart`; `cd mobile_v2 && dart run ../tool/verify_activation_governor_contract.dart` | Accessibility/proof planned by 41-05 Task 2 | planned |

*Status: pending, green, red, flaky*

---

## Wave 0 Plan Readiness

- Plan `41-01` is the real Wave 0 plan. It creates `41-COMMAND-HEALTH.md` and locks the final verification command map before runtime files change.
- App/widget tests are planned under `mobile_v2/test` by plans `41-02` through `41-05`; this validation strategy does not claim those files already exist before execution.
- Execution status remains `planned` until `$gsd-execute-phase 41` runs the submitted plans and records summaries.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Parent-facing tone feels warm, low-pressure, and action-bound | R058, R059, R064 | Automated tests can catch forbidden copy, but not whether the slice feels naturally parent-supportive. | Review the single Ritual Room Support surface on a phone-sized viewport and confirm copy does not feel like teaching, scoring, checking in, TPR command testing, or proving baby learning. |

---

## Validation Sign-Off

- [x] All planned tasks have automated verification.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 maps to real Plan `41-01` and covers command-health proof and final command-map readiness.
- [ ] No watch-mode flags.
- [ ] Focused per-task feedback latency <=30s after command-health remediation; full wave/final gates may take longer.
- [x] `nyquist_compliant: true` set in frontmatter after the verification map was aligned to plans `41-01` through `41-05`; this does not assert execution completion.

**Approval:** pending
