# REFACTOR-006 Single Bearer JWT Authenticated Client Interceptor

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Task: REFACTOR-006  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-006 introduced the approved Bearer JWT request-header behavior for protected mobile API calls. The change is intentionally narrow: existing access-token plumbing remains in place, refresh/replay semantics remain owned by `AuthenticatedApiClient`, and request payloads are unchanged.

REFACTOR-007 later completed the separate Mentor/AI consent preflight behavior change without altering this Bearer header contract.

## Changed Production Files

| File | Change |
|---|---|
| `mobile/lib/core/network/auth_headers.dart` | Added shared `Authorization` header name and Bearer value builder |
| `mobile/lib/features/account/data/services/account_api_service.dart` | Adds Bearer header when protected account service methods pass an access token |
| `mobile/lib/features/household/data/services/household_api_service.dart` | Adds Bearer header to authenticated household requests routed through `AuthenticatedApiClient` |
| `mobile/lib/features/mentor/data/services/mentor_api_service.dart` | Adds Bearer header to authenticated Mentor chat requests routed through `AuthenticatedApiClient` |

## Added And Updated Tests

| File | Coverage |
|---|---|
| `mobile/test/core/network/bearer_authorization_header_test.dart` | Shared helper behavior; Account protected endpoints; Household protected endpoints through `AuthenticatedApiClient` |
| `mobile/test/features/mentor/mentor_api_service_auth_characterization_test.dart` | Mentor authenticated chat writes `Authorization: Bearer access-live` |

## Protected Header Coverage

| Surface | Protected Paths Covered |
|---|---|
| Account | `/api/v1/consent/accept`, `/api/v1/consent/revoke`, `/api/v1/account`, `/api/v1/sync/events`, `/api/v1/bootstrap` |
| Household | `/api/v1/caregiver-invites`, `/api/v1/caregiver-invites/accept`, `/api/v1/household/shared-context` |
| Mentor | `/api/v1/mentor/chat` authenticated path |

## Verification

| Command | Result |
|---|---|
| Targeted diagnostics for changed Dart files | No errors found |
| Targeted auth/header tests | Pass; 8 tests passed |
| Additional account/household/mentor targeted tests | Pass |
| `flutter analyze` | Pass; no issues found |
| `flutter test` | Pass; 207 tests passed |
| `flutter test --coverage` | Pass; 207 tests passed |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 7093 |
| Lines found | 10737 |
| Line coverage | 66.06% |

## Scope Check

- API payloads: unchanged.
- Endpoint paths: unchanged.
- Refresh/replay behavior: unchanged and covered by existing tests.
- Mentor/AI consent preflight: unchanged by REFACTOR-006; later changed by REFACTOR-007.
- UI behavior: unchanged.

## Follow-Up

- REFACTOR-007 used the REFACTOR-005 consent characterization tests to introduce the fail-closed Mentor/AI consent gate.
- Backend contract smoke should verify deployed services accept `Authorization: Bearer <accessToken>` for the protected paths listed above.