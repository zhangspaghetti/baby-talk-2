# REFACTOR-005 Auth And Consent Characterization

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 1  
Task: REFACTOR-005  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-005 added test-only characterization for current authenticated Mentor chat, mentor chat availability, and consent-state behavior. No production Flutter source was changed.

The tests intentionally described the pre-REFACTOR-007 behavior, including unsafe gaps reserved for approved follow-up implementation tasks. REFACTOR-006 later introduced the single Bearer JWT authenticated request-header behavior. REFACTOR-007 later superseded the unsafe Mentor consent characterization with the approved fail-closed gate requiring accepted consent and a JWT-capable session.

## Added And Extended Tests

| File | Coverage |
|---|---|
| `mobile/test/features/mentor/mentor_api_service_auth_characterization_test.dart` | Captures that signed-in Mentor chat currently routes through `AuthenticatedApiClient` but does not write an `Authorization` header on the outbound Dio request |
| `mobile/test/features/mentor/mentor_notifier_test.dart` | Captures that consent state currently does not gate Mentor chat submission, while offline preflight does prevent API calls |

## Existing Auth Coverage Reused

| File | Current Coverage |
|---|---|
| `mobile/test/features/account/jwt_session_refresh_test.dart` | Concurrent 401 single refresh, refresh timeout fail-closed behavior, replay 401 no second refresh, and legacy session missing-token fail-closed behavior |
| `mobile/test/features/household/household_repository_test.dart` | Household consent/session failure mapping, including missing JWT and consent-required phases |

## Protected API Inventory

| Surface | Current Behavior |
|---|---|
| `AuthenticatedApiClient` | Requires JWT token fields before protected sends, performs refresh/replay on first 401, and fails closed for missing credentials |
| `HouseholdApiService` | Uses `AuthenticatedApiClient` for protected household routes and maps auth failures to visible household errors |
| `MentorApiService` anonymous path | Sends `/api/v1/mentor/chat` without a session when the notifier has no signed-in session |
| `MentorApiService` authenticated path | Invokes `AuthenticatedApiClient` when a session exists, but the current outbound request does not include an `Authorization` header |
| `MentorNotifier` preflight | Blocks account-loading and offline states; does not currently block local-only, signed-out, revoked, or deleted consent states |

## Observed Mentor Consent Behavior

| Account Snapshot | Current Availability | API Call | Session Forwarded |
|---|---|---|---|
| `localOnly` without session | `ready` | yes | no |
| `signedOut` without session | `ready` | yes | no |
| `revoked` with session | `ready` | yes | yes |
| `deleted` with session | `ready` | yes | no |
| accepted session with offline phase | `offline` | no | no |

## Verification

| Command | Result |
|---|---|
| Targeted diagnostics for REFACTOR-005 test files | No errors found |
| Targeted REFACTOR-005 unit tests | Pass; 14 tests passed |
| Targeted REFACTOR-005 coverage run | Pass; 14 tests passed |
| `flutter analyze` | Pass; no issues found |
| `flutter test` | Pass; 204 tests passed |
| `flutter test --coverage` | Pass; 204 tests passed |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 6944 |
| Lines found | 10724 |
| Line coverage | 64.75% |

## Phase 2 Notes

- REFACTOR-006 changed the authenticated request contract to send Bearer JWT consistently for protected Account, Household, and Mentor service paths.
- REFACTOR-007 replaced the Mentor chat preflight with a fail-closed consent gate requiring accepted consent and JWT tokens before any Mentor/AI network request.
- The unsafe REFACTOR-005 consent characterization has been superseded by target-behavior tests in REFACTOR-007.
- The revoked-with-session scenario is the highest-risk observed gap because the current notifier forwards that session to Mentor chat.

## Scope Check

- Production Flutter source: unchanged.
- New runtime behavior: none.
- New coverage type: characterization-only unit tests.