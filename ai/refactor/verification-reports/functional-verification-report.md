# Functional Verification Report

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Task: REFACTOR-017, updated by REFACTOR-033
Created: 2026-05-19
Status: completed, integration blockers remediated locally; production gate blocked by remaining Phase 4 criteria

## Summary

Current unit, widget, and smoke-level Flutter tests remain green. The original R017 verification pass exposed core-flow integration blockers; REFACTOR-017A has now remediated those local blockers with behavior-preserving app and harness fixes.

Functional core-flow evidence is restored locally. REFACTOR-033 has measured the critical UI coverage slice above threshold, but production readiness remains blocked by non-functional Phase 4 criteria: global coverage target/exception, sensitive lifecycle completion, performance benchmark evidence, target-platform/CI replay, and final human approval.

## Command Evidence

| Check | Result | Evidence |
|---|---:|---|
| `flutter analyze` | Pass | `R017_COMMAND_EXIT flutter analyze 0`; no issues found |
| `flutter test` | Pass | `R017_COMMAND_EXIT flutter test 0`; 220 tests passed |
| `flutter test --coverage` | Pass | `R017_COMMAND_EXIT flutter test --coverage 0`; 220 tests passed |
| `flutter test integration_test/s01_guest_practice_flow_test.dart` | Fail | `R017_COMMAND_EXIT ... 1`; timed out waiting for expected widget |
| `flutter test integration_test/s02_personalized_onboarding_flow_test.dart` | Fail | `R017_COMMAND_EXIT ... 1`; timed out waiting for expected widget |
| `flutter test integration_test/s03_account_sync_restore_flow_test.dart` | Fail | `R017_COMMAND_EXIT ... 1`; timed out waiting for expected widget |
| `flutter test integration_test/s06_full_chain_release_flow_test.dart` | Fail | `R017_COMMAND_EXIT ... 1`; two timeout failures in full-chain flow |

## REFACTOR-017A Integration Remediation Evidence

| Check | Result | Evidence |
|---|---:|---|
| `..\flutter.cmd test integration_test/s01_guest_practice_flow_test.dart` | Pass | 1 test passed; local-only practice result restored after cold start |
| `..\flutter.cmd test integration_test/s02_personalized_onboarding_flow_test.dart` | Pass | 1 test passed; fresh install onboarding and cold-start restore verified |
| `..\flutter.cmd test integration_test/s03_account_sync_restore_flow_test.dart` | Pass | 1 test passed; offline practice sync and restore verified |
| `..\flutter.cmd test integration_test/s06_full_chain_release_flow_test.dart` | Pass | 3 tests passed; full-chain flow, malformed snapshot, and Mentor timeout verified |
| `..\flutter.cmd analyze` | Pass | No issues found |

## Core Flow Results

| Flow | Status | Failure Detail |
|---|---|---|
| Guest offline practice cold-start restore | Pass locally | `s01_guest_practice_flow_test.dart` passed after household repository injection and Home refresh/scroll hardening |
| Fresh install onboarding to personalized shell restore | Pass locally | `s02_personalized_onboarding_flow_test.dart` passed with current onboarding and shell expectations |
| Offline practice, sign-in sync, logout/login restore | Pass locally | `s03_account_sync_restore_flow_test.dart` passed with household repository injection |
| Full-chain fresh install to mentor blocked fallback | Pass locally | `s06_full_chain_release_flow_test.dart` passed with current combined tab, Mentor auth, and backend surface contract |
| Full-chain malformed snapshot boot failure surface | Pass locally | Boot failure surface remains visible for malformed completed snapshot |
| Mentor timeout visible banner and phase | Pass locally | Timeout banner, `provider_timeout` phase, and failed fact persistence verified |

## Interpretation

- The app's local unit and widget regression surface is stable; latest full `flutter test` passes 241 tests after REFACTOR-033.
- The integration suite now proves the required local end-to-end rescue flows in focused runs.
- The original timeout failures were a mix of stale harness assumptions and product integration defects: missing household bootstrap injection, async practice repository access, post-practice refresh timing, Mentor account/API split state, backend surface mismatch, and cross-test Mentor Isar store collision.
- R017A did not approve stale-test behavior changes; product contracts remain fresh-install onboarding, combined growth/garden tab, and login-gated online Mentor chat.

## Functional Exit Decision

Functional core-flow verification is locally restored. Production readiness is still not approved until the remaining Phase 4 gates are satisfied or explicitly excepted, and the focused integration evidence is replayed on approved target platforms or CI.