# REFACTOR-041 Destructive Lifecycle Target Proof And Replay

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Created: 2026-05-20  
Status: complete locally; target runner evidence still partially pending

## Goal

Advance the next R4 gates after HDR-R4-003 approval: wire the approved account deletion product-flow entry to real-store local sensitive data clearance, strengthen iOS backup proof source, replay target integration flows locally, and attempt release/profile performance replay.

## Scope

In scope:

- Record HDR-R4-003 option 3 approval for account deletion/device erasure local sensitive data clearance.
- Add a second confirmation dialog before account deletion can trigger destructive local clearance.
- Inject the verified real-store clearance registry into the account deletion product flow through app composition.
- Update the R4 release-gate policy so only the HDR-R4-003 account deletion entry is allowed.
- Add iOS XCTest source that verifies `isExcludedFromBackupKey` after the native backup exclusion helper runs.
- Replay S01, S02, S03, and S06 integration flows locally.
- Attempt release/profile R4 full performance replay and document Flutter tool limitations.

Out of scope:

- Claiming final production readiness.
- Claiming live GitHub CI evidence without a remote workflow run.
- Claiming iOS runtime proof from Windows; the new XCTest must run on a macOS/iOS target runner.
- Adding additional destructive entry points beyond account deletion.

## Regression Requirements

- [x] Account deletion requires a second confirmation before the notifier is called.
- [x] Confirmed account deletion triggers `LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed`.
- [x] App bootstrap-created `AccountNotifier` and default Riverpod account notifier both inject the approved real-store clearance path.
- [x] R4 policy permits only the HDR-R4-003 account deletion destructive marker and blocks other feature-level destructive markers.
- [x] iOS backup proof includes an XCTest source that writes and reads `isExcludedFromBackupKey`.
- [x] Target integration flows pass when replayed individually locally.
- [x] Flutter release/profile performance replay limitations are documented truthfully.

## Verification Log

| Command | Result |
|---|---|
| `runTests` for `account_entry_screen_test.dart`, `r4_release_gate_policy_test.dart`, and `local_sensitive_data_clearance_registry_test.dart` | Passed; 17 tests |
| `runTests` for backup posture/protection tests | Passed; 6 tests |
| `runTests` for account, policy, registry, backup posture, and app boot focused slice | Passed; 20 tests |
| `flutter test integration_test/s01_guest_practice_flow_test.dart ... s06_full_chain_release_flow_test.dart` | S01 passed before Flutter tool finalization failed on S02 temp listener cleanup; command exited 1 from tool cleanup, not app assertion |
| `flutter test integration_test/s02_personalized_onboarding_flow_test.dart` | Passed individually |
| `flutter test integration_test/s03_account_sync_restore_flow_test.dart` | Passed individually |
| `flutter test integration_test/s06_full_chain_release_flow_test.dart` | Passed individually |
| `flutter test integration_test/r4_performance_benchmark_test.dart --release ...` | Not supported; `flutter test` has no `--release` option |
| `flutter drive ... --release ...` | Not supported; Flutter Driver says non-web release mode is unsupported |
| `flutter drive ... --profile ...` | Built and installed profile APK, then Windows batch terminated before benchmark output; no profile measurements captured |
| `flutter analyze` from `mobile/` after R41 docs/code updates | Passed; no issues found |
| `bash ci/mobile-r4-release-gates.sh` from repo root after account entry test was added | Passed; Mobile R4 Release Gates PASSED |

## Remaining Gaps

- Live GitHub CI evidence after the workflow/script changes is still pending; local script replay passes.
- iOS XCTest must be executed on a macOS/iOS target runner to convert source proof into runtime proof.
- R4 full performance profile still needs approved target/profile evidence or a non-Flutter-Driver performance path that can complete on the target runner.
- Final production release remains blocked pending human approval.

## Standard Git Commit Message

```text
feat(mobile): wire approved account deletion clearance
```