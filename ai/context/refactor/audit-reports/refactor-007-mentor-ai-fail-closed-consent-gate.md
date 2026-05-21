# REFACTOR-007 Mentor AI Fail Closed Consent Gate

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Task: REFACTOR-007  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-007 implements the approved Mentor/AI consent gate. Online Mentor chat now fails closed unless the account state is `acceptedPendingSync` and the account session has JWT tokens. Blocked states keep local Mentor suggestions available and record preflight denials as `chatFailed` facts without sending a Mentor API request.

REFACTOR-006 Bearer header behavior remains unchanged.

## Changed Production Files

| File | Change |
|---|---|
| `mobile/lib/features/mentor/presentation/mentor_notifier.dart` | Added login-required and consent-required availability states; requires accepted consent and JWT-capable session before chat submission; records preflight denials without calling Mentor API |

## Added And Updated Tests

| File | Coverage |
|---|---|
| `mobile/test/features/mentor/mentor_notifier_test.dart` | Supersedes unsafe REFACTOR-005 consent characterization; asserts local-only, signed-out, revoked, deleted, and missing-token states fail closed; keeps accepted JWT success, 401, timeout, and multi-turn coverage green |
| `mobile/test/features/mentor/mentor_shell_panel_test.dart` | Updates chat widget success path to use an accepted JWT session |

## Fail-Closed Matrix

| Account / Runtime State | Availability Code | API Call | Fact Behavior |
|---|---|---|---|
| Account state not loaded | `account-loading` | No | `chatFailed` on submit attempt |
| Offline phase | `offline` | No | `chatFailed` on submit attempt; offline fallback facts remain available from suggestions |
| `localOnly` | `login-required` | No | `chatFailed` on submit attempt |
| `signedOut` | `login-required` | No | `chatFailed` on submit attempt |
| `revoked` with or without session | `consent-required` | No | `chatFailed` on submit attempt |
| `deleted` with or without session | `consent-required` | No | `chatFailed` on submit attempt |
| `acceptedPendingSync` without session or JWT tokens | `login-required` | No | `chatFailed` on submit attempt |
| `acceptedPendingSync` with JWT tokens | `ready` | Yes | `chatRequested` then response/failure fact |

## Verification

| Command | Result |
|---|---|
| Targeted diagnostics for changed Dart files | No errors found |
| Targeted Mentor notifier and shell tests | Pass; 20 tests passed |
| `flutter analyze` | Pass; no issues found |
| `flutter test` | Pass; 207 tests passed |
| `flutter test --coverage` | Pass; 207 tests passed |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 7110 |
| Lines found | 10757 |
| Line coverage | 66.10% |

## Scope Check

- API payloads: unchanged.
- Endpoint paths: unchanged.
- Bearer header construction: unchanged from REFACTOR-006.
- Refresh/replay behavior: unchanged and covered by existing tests.
- Anonymous Mentor chat: intentionally disabled by approved REFACTOR-007 behavior.
- Local Mentor suggestions: preserved for blocked states.
- Route behavior: unchanged.

## Residual Notes

- Full test runs still emit the pre-existing nonfatal onboarding tap warning for `onboarding-name-continue` outside the default 800x600 viewport; tests pass.
- Isar inspector URLs in test output remain benign test runtime output.

## Follow-Up

- REFACTOR-008 was approved separately and completed as a behavior-preserving route contract pilot.
- Backend smoke can further verify deployed Mentor services accept the REFACTOR-006 Bearer header on the authenticated chat path.