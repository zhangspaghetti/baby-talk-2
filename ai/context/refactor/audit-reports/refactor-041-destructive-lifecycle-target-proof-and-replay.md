# REFACTOR-041 Destructive Lifecycle Target Proof And Replay Report

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Task: REFACTOR-041  
Created: 2026-05-20  
Status: complete locally; production readiness still blocked

## Summary

REFACTOR-041 uses the confirmed HDR-R4-003 option 3 decision to wire the existing account deletion product-flow entry into the verified real-store local sensitive data clearance registry. The UI now requires a second confirmation before deletion proceeds, and the account notifier clears all policy-default account deletion targets through app-injected clearance orchestration.

The task also strengthens iOS backup proof source by adding an XCTest that confirms `isExcludedFromBackupKey`, replays the R4 integration flows individually, and records the Flutter tool limitations around release/profile performance replay on the current Windows target.

## Changes

| Area | Change |
|---|---|
| Governance | HDR-R4-003 confirmed as option 3: account deletion/device erasure approval |
| Account deletion UX | Added a second confirmation dialog before account deletion runs |
| Lifecycle wiring | `AccountNotifier.deleteAccount` now invokes an injected `accountDeletionConfirmed` clearance runner after server/local account deletion |
| App composition | Default Riverpod provider and bootstrap-created notifier both inject Staff+ destructive authorization tied to `HDR-R4-003` |
| R4 policy | Release gate now allows only the approved account deletion destructive marker and blocks other feature-level destructive markers |
| iOS backup proof | Added `LocalSensitiveDataBackupExcluder` and an XCTest that writes and reads `isExcludedFromBackupKey` |
| CI gate | R4 release gate script now includes account entry screen coverage for the destructive confirmation path |

## Verification

| Command | Exit | Result |
|---|---:|---|
| `runTests` for `account_entry_screen_test.dart`, `r4_release_gate_policy_test.dart`, and `local_sensitive_data_clearance_registry_test.dart` | 0 | Pass; 17 tests |
| `runTests` for backup posture/protection tests | 0 | Pass; 6 tests |
| `runTests` for account, policy, registry, backup posture, and app boot focused slice | 0 | Pass; 20 tests |
| `flutter test integration_test/s02_personalized_onboarding_flow_test.dart` | 0 | Pass individually |
| `flutter test integration_test/s03_account_sync_restore_flow_test.dart` | 0 | Pass individually |
| `flutter test integration_test/s06_full_chain_release_flow_test.dart` | 0 | Pass individually |
| `flutter analyze` from `mobile/` after R41 updates | 0 | Pass; no issues found |
| `bash ci/mobile-r4-release-gates.sh` from repo root after account entry test was added | 0 | Pass; Mobile R4 Release Gates PASSED |

## Target Replay Notes

The combined local command for S01/S02/S03/S06 passed S01, then hit a Flutter tool finalization failure while cleaning a temporary Windows listener directory during S02. S02 passed when replayed individually, and S03/S06 also passed individually. This is acceptable local target evidence but not a substitute for live CI or an approved target-platform replay artifact.

## Performance Replay Notes

| Attempt | Result |
|---|---|
| `flutter test ... --release` | Rejected by Flutter tool because `flutter test` has no `--release` option |
| `flutter drive ... --release` | Rejected by Flutter Driver because non-web release mode is unsupported |
| `flutter drive ... --profile` | Built and installed `app-profile.apk`, then the Windows batch ended before benchmark output; no profile measurements captured |

The existing R40 local debug full profile remains the only full 0/100/1000/10000 measurement set. Approved target/profile performance proof is still pending.

## Risk Decision

The destructive lifecycle product-flow gate is materially stronger and now has an approved account deletion path with test coverage. Production readiness is still not approved because live CI, macOS/iOS runtime backup proof, approved target/profile performance measurements, and final human release confirmation remain open.