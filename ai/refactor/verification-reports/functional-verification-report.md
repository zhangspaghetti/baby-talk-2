# Functional Verification Report

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Task: REFACTOR-017
Created: 2026-05-19
Status: completed, production functional gate blocked

## Summary

Current unit, widget, and smoke-level Flutter tests remain green, but the local integration checks documented for Phase 4 expose core-flow blockers. No mobile production code or tests were changed during this verification pass.

Functional release readiness is blocked until the integration-flow timeouts are fixed or formally excepted with replacement evidence.

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

## Core Flow Results

| Flow | Status | Failure Detail |
|---|---|---|
| Guest offline practice cold-start restore | Blocked | `s01_guest_practice_flow_test.dart` failed in `_pumpUntilFound` at line 171: timed out waiting for expected widget |
| Fresh install onboarding to personalized shell restore | Blocked | `s02_personalized_onboarding_flow_test.dart` failed in `_pumpUntilFound` at line 286: timed out waiting for expected widget |
| Offline practice, sign-in sync, logout/login restore | Blocked | `s03_account_sync_restore_flow_test.dart` failed in `_pumpUntilFound` at line 400: timed out waiting for expected widget |
| Full-chain fresh install to mentor blocked fallback | Blocked | `s06_full_chain_release_flow_test.dart` failed waiting for fresh install onboarding banner |
| Full-chain malformed snapshot boot failure surface | Pass inside failing file | `s06_full_chain_release_flow_test.dart` reported one passing test before later failure |
| Mentor timeout visible banner and phase | Blocked | `s06_full_chain_release_flow_test.dart` failed waiting for onboarding start button |

## Interpretation

- The app's local unit and widget regression surface is stable at 220 passing tests.
- The integration suite currently cannot prove the required end-to-end rescue flows.
- The repeated timeout shape suggests the integration harness or fresh-install app state is not reaching expected onboarding/practice surfaces in the current environment.
- R017 does not approve a product behavior change to work around these failures.

## Functional Exit Decision

Functional verification is not production-ready. The next Phase 4 work must either fix the integration blockers, produce equivalent passing core-flow evidence on approved target platforms, or obtain an explicit human exception before release readiness can be reconsidered.