# REFACTOR-009 Repository Usecase Contract Map And Account Adapter Seam

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Task: REFACTOR-009  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-009 introduces the first repository/usecase seam in the account feature. `AccountNotifier` now depends on `AccountRepositoryContract` instead of the concrete data repository implementation. The concrete `AccountRepository` still backs the app's existing Provider/Riverpod wiring and now implements that contract.

This task is behavior-preserving. Account snapshots, sign-in, refresh, revoke, delete, clear-session, upgrade-link, API request, and persistence behavior are unchanged.

## Changed Production Files

| File | Change |
|---|---|
| `mobile/lib/features/account/data/repositories/account_repository_contract.dart` | Added the account repository contract and account runtime trigger wire surface |
| `mobile/lib/features/account/data/repositories/account_repository.dart` | Made the concrete repository implement the contract and re-export compatibility symbols |
| `mobile/lib/features/account/presentation/account_notifier.dart` | Narrowed constructor and private field types from concrete repository to contract |

## Added Tests

| File | Coverage |
|---|---|
| `mobile/test/features/account/account_repository_contract_test.dart` | Proves `AccountNotifier` can reload, sign in, and refresh runtime state through a contract-only fake |

## Contract Surface

| Method | Purpose |
|---|---|
| `loadSnapshot` | Load current account snapshot for presentation state |
| `signIn` | Sign in using phone and verification code |
| `refreshRuntimeState` | Refresh account/runtime sync status for app lifecycle triggers |
| `clearPlaceholderSession` | Clear local session state or return to local-only mode |
| `revokeConsent` | Revoke consent |
| `deleteAccount` | Delete account state |
| `close` | Release repository resources |

## Verification

| Command | Result |
|---|---|
| Focused analyzer and account/mentor tests | Pass |
| `flutter analyze` | Pass; no issues found |
| `flutter test` | Pass; 210 tests passed |
| `flutter test --coverage` | Pass; 210 tests passed |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 7129 |
| Lines found | 10759 |
| Line coverage | 66.26% |

## Scope Check

- Account snapshot semantics: unchanged.
- Account local persistence format: unchanged.
- Sign-in and runtime refresh behavior: unchanged.
- API payloads and auth headers: unchanged.
- Provider/Riverpod repository factories: unchanged.
- Household, practice, mentor, and share repositories: not migrated in this task.

## Residual Notes

- `AccountLocalSnapshot` still lives under the data/local surface; moving it is out of scope for this seam and should require a separate behavior-preserving model-location task.
- Existing account repository factory typedefs still mention the concrete repository because app bootstrap ownership remains concrete in this stage.
- Full test runs still emit the pre-existing nonfatal onboarding tap warning for `onboarding-name-continue`; tests pass.
- Isar inspector URLs in test output remain benign test runtime output.

## Follow-Up

- REFACTOR-010 was approved separately and completed as a practice repository characterization harness.
- Future repository/usecase seams can repeat this pattern for household, mentor, practice, and share after characterization coverage is in place.