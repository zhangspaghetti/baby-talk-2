---
phase: 41
slug: mobile-v2-runnable-vertical-slice
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| **Quick run command** | `cd mobile_v2 && flutter test test/first_micro_ritual_flow_test.dart test/first_micro_ritual_fixture_test.dart` |
| **Full suite command** | `cd mobile_v2 && flutter test`; `dart run tool/verify_mobile_v2_semantic_firewall.dart`; `dart run tool/verify_activation_governor_contract.dart` |
| **Estimated runtime** | ~60 seconds after Flutter CLI health is restored |

---

## Sampling Rate

- **After every task commit:** Run the focused `mobile_v2` widget or fixture test touched by the task.
- **After every plan wave:** Run `cd mobile_v2 && flutter test`, then both Phase 39 and Phase 40 verifier CLIs.
- **Before `$gsd-verify-work`:** Full `mobile_v2` test suite, semantic firewall, and Activation Governor / Garden Memory verifier must be green.
- **Max feedback latency:** 90 seconds once Flutter command-health is fixed.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 41-W0-01 | 00 | 0 | R058-R065 | T-41-01 / T-41-02 | Flutter and Dart commands run from the correct `mobile_v2` and repo roots, not the root Flutter wrapper that delegates to old `mobile/`. | command health | `cd mobile_v2 && flutter test --help`; `dart --version` | Missing W0 | pending |
| 41-01-01 | 01 | 1 | R058, R059, R060, R063 | T-41-01 / T-41-02 | Local fixture truth is one active Ritual Room backed by fake Context Seed, Joinability hypothesis, and explicit fake Governor `allow_activation`. | fixture unit/widget | `cd mobile_v2 && flutter test test/first_micro_ritual_fixture_test.dart` | Missing W0 | pending |
| 41-02-01 | 02 | 1 | R058, R059, R063 | T-41-01 / T-41-02 | Runnable app opens First Entry and Today Orientation without phrase/activity/completion/streak/progress semantics. | widget flow | `cd mobile_v2 && flutter test test/first_micro_ritual_flow_test.dart` | Missing W0 | pending |
| 41-03-01 | 03 | 2 | R059, R064, R065 | T-41-02 / T-41-03 | Room Support and Memory Lens stay low-pressure, do not score or complete the ritual, and preserve parent-confirmed memory framing. | widget flow + verifier | `cd mobile_v2 && flutter test`; `dart run tool/verify_activation_governor_contract.dart` | Missing W0 / guard exists | pending |
| 41-04-01 | 04 | 3 | R058-R065 | T-41-01 / T-41-02 / T-41-03 | Final source tree contains no old mobile imports, forbidden old semantics, ungoverned activation intent, backend/AI/runtime integration, or production Garden transition state. | full gate | `dart run tool/verify_mobile_v2_semantic_firewall.dart`; `dart run tool/verify_activation_governor_contract.dart` | Guards exist | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] `mobile_v2/test/first_micro_ritual_flow_test.dart` - tap-through First Entry -> Today Orientation -> Room Support -> Memory Lens.
- [ ] `mobile_v2/test/first_micro_ritual_fixture_test.dart` - fixture field and forbidden old-semantics assertions.
- [ ] Optional `mobile_v2/test/accessibility_smoke_test.dart` - tap target and semantics-label smoke coverage if practical in the executor environment.
- [ ] Command-health proof for Flutter/Dart in this workspace, because research found current CLI/cache execution issues.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Parent-facing tone feels warm, low-pressure, and action-bound | R058, R059, R064 | Automated tests can catch forbidden copy, but not whether the slice feels naturally parent-supportive. | Review the four-lens flow on a phone-sized viewport and confirm copy does not feel like teaching, scoring, checking in, or proving baby learning. |

---

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing test files and command-health proof.
- [ ] No watch-mode flags.
- [ ] Feedback latency < 90s after command-health remediation.
- [ ] `nyquist_compliant: true` set in frontmatter after Wave 0 proof exists.

**Approval:** pending
