---
phase: 41
slug: mobile-v2-runnable-vertical-slice
status: draft
nyquist_compliant: true
wave_0_plan_ready: true
created: 2026-06-16
---

# Phase 41 - Validation Strategy

> Per-phase validation contract for the runnable `mobile_v2` first micro-ritual slice.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter widget tests with `flutter_test`; repo-owned Dart verifier CLIs |
| **Config file** | `mobile_v2/pubspec.yaml` |
| **Quick run command** | Run the focused test touched by the current task, for example `cd mobile_v2 && flutter test test/first_micro_ritual_entry_orientation_test.dart` for the app shell / First Entry path. |
| **Full suite command** | `cd mobile_v2 && flutter test`; `dart run tool/verify_mobile_v2_semantic_firewall.dart`; `dart run tool/verify_activation_governor_contract.dart` |
| **Estimated runtime** | Focused per-task commands target <=30 seconds after Flutter command-health is restored; full wave/final gates can take longer. |

---

## Sampling Rate

- **After every task commit:** Run the focused `mobile_v2` widget or fixture test touched by the task.
- **After every plan wave:** Run `cd mobile_v2 && flutter test`, then both Phase 39 and Phase 40 verifier CLIs.
- **Before `$gsd-verify-work`:** Full `mobile_v2` test suite, semantic firewall, and Activation Governor / Garden Memory verifier must be green.
- **Max feedback latency:** <=30 seconds for focused per-task commands once Flutter command-health is fixed; full `cd mobile_v2 && flutter test` plus verifier CLIs are wave/final gates and may exceed the per-task latency target.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Plan Coverage | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|---------------|--------|
| 41-01-01 | 41-01 | 0 | R058-R065 | T-41-01 / T-41-02 | Flutter and Dart commands run from the correct `mobile_v2` and repo roots, not the root Flutter wrapper that delegates to old `mobile/`. | command health | `cd mobile_v2 && flutter test --help`; `dart --version` | Covered by 41-01 Task 1 | planned |
| 41-01-02 | 41-01 | 0 | R058-R065 | T-41-01 / T-41-02 | Final verifier commands and direct SDK fallbacks are documented before runtime files change. | command map | `Select-String -Path .planning/phases/41-mobile-v2-runnable-vertical-slice/41-COMMAND-HEALTH.md -Pattern 'Phase 41 Final Gate'` | Covered by 41-01 Task 2 | planned |
| 41-02-01 | 41-02 | 1 | R058, R059, R060, R063 | T-41-01 / T-41-02 | RED tests encode the one-room fixture and local lens controller contract before source exists. | fixture/controller TDD RED | `cd mobile_v2 && flutter test test/first_micro_ritual_fixture_test.dart test/ritual_lens_controller_test.dart` | Test files planned by 41-02 Task 1 | planned |
| 41-02-02 | 41-02 | 1 | R058, R059, R060, R063 | T-41-01 / T-41-02 | Local fixture truth is one active Ritual Room backed by fake Context Seed, Joinability hypothesis, and explicit fake Governor `allow_activation`. | fixture/controller TDD GREEN | `cd mobile_v2 && flutter test test/first_micro_ritual_fixture_test.dart test/ritual_lens_controller_test.dart` | Runtime files planned by 41-02 Task 2 | planned |
| 41-02-03 | 41-02 | 1 | R058-R065 | T-41-01 / T-41-02 | Fixture/controller naming passes semantic firewall and Activation Governor checks. | verifier TDD REFACTOR | `dart run tool/verify_mobile_v2_semantic_firewall.dart`; `dart run tool/verify_activation_governor_contract.dart` | Guard cleanup planned by 41-02 Task 3 | planned |
| 41-03-01 | 41-03 | 2 | R058, R059, R060, R063 | T-41-01 / T-41-02 | The `mobile_v2` app shell compiles and renders First Entry without importing old `mobile/` runtime code. | app-shell widget smoke | `cd mobile_v2 && flutter test test/first_micro_ritual_entry_orientation_test.dart` | App shell smoke planned by 41-03 Task 1 | planned |
| 41-03-02 | 41-03 | 2 | R058, R059, R060, R063 | T-41-01 / T-41-02 | Runnable app opens First Entry and Today Orientation without phrase/activity/completion/streak/progress semantics. | widget flow + verifier | `cd mobile_v2 && flutter test test/first_micro_ritual_entry_orientation_test.dart`; `dart run tool/verify_mobile_v2_semantic_firewall.dart`; `dart run tool/verify_activation_governor_contract.dart` | Entry/orientation tests planned by 41-03 Task 2 | planned |
| 41-04-01 | 41-04 | 2 | R059, R064, R065 | T-41-02 / T-41-03 | Room Support stays action-bound and does not train, record, score, or complete the ritual. | widget flow + verifier | `cd mobile_v2 && flutter test test/room_support_memory_lens_test.dart`; `dart run tool/verify_mobile_v2_semantic_firewall.dart` | Room Support tests planned by 41-04 Task 1 | planned |
| 41-04-02 | 41-04 | 2 | R059, R064, R065 | T-41-02 / T-41-03 | Memory Lens stays low-pressure, parent-confirmed, and free of production Garden transition mechanics. | widget flow + verifier | `cd mobile_v2 && flutter test test/room_support_memory_lens_test.dart`; `dart run tool/verify_activation_governor_contract.dart` | Memory Lens tests planned by 41-04 Task 2 | planned |
| 41-05-01 | 41-05 | 3 | R058-R065 | T-41-01 / T-41-02 / T-41-03 | The full First Entry -> Today Orientation -> Room Support -> Memory Lens path is runnable in one app shell. | end-to-end widget flow + verifier | `cd mobile_v2 && flutter test test/first_micro_ritual_flow_test.dart`; `dart run tool/verify_mobile_v2_semantic_firewall.dart`; `dart run tool/verify_activation_governor_contract.dart` | End-to-end flow planned by 41-05 Task 1 | planned |
| 41-05-02 | 41-05 | 3 | R058-R065 | T-41-01 / T-41-02 / T-41-03 | Final source tree contains no old mobile imports, forbidden old semantics, ungoverned activation intent, backend/AI/runtime integration, or production Garden transition state. | full gate + proof | `cd mobile_v2 && flutter test`; `dart run tool/verify_mobile_v2_semantic_firewall.dart`; `dart run tool/verify_activation_governor_contract.dart` | Accessibility/proof planned by 41-05 Task 2 | planned |

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
| Parent-facing tone feels warm, low-pressure, and action-bound | R058, R059, R064 | Automated tests can catch forbidden copy, but not whether the slice feels naturally parent-supportive. | Review the four-lens flow on a phone-sized viewport and confirm copy does not feel like teaching, scoring, checking in, or proving baby learning. |

---

## Validation Sign-Off

- [x] All planned tasks have automated verification.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 maps to real Plan `41-01` and covers command-health proof and final command-map readiness.
- [ ] No watch-mode flags.
- [ ] Focused per-task feedback latency <=30s after command-health remediation; full wave/final gates may take longer.
- [x] `nyquist_compliant: true` set in frontmatter after the verification map was aligned to plans `41-01` through `41-05`; this does not assert execution completion.

**Approval:** pending
