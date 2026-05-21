---
id: REFACTOR-006
title: Single Bearer JWT Authenticated Client Interceptor
status: done
priority: high
phase: 2
assignee: AI
created: 2026-05-18
estimated: 1-2d
---

## Goal

Make protected mobile API requests consistently send `Authorization: Bearer <accessToken>` through the existing authenticated request path, without changing API payloads, refresh behavior, route behavior, or consent UX.

## Legacy Code Location

`mobile/lib/features/account/data/services/`, `mobile/lib/features/household/data/services/`, `mobile/lib/features/mentor/data/services/`, and `mobile/lib/core/network/`.

## Original Functionality Description

Protected account, household, and mentor calls already carried an `accessToken` parameter through their request builders or through `AuthenticatedApiClient.execute`. REFACTOR-005 showed those request builders did not write an outbound `Authorization` header. Existing refresh and fail-closed behavior must remain unchanged.

## Refactoring Approach

1. Add one shared Bearer header helper.
2. Wire existing `accessToken` request-builder parameters into `Authorization: Bearer <token>` headers.
3. Keep request payloads, endpoint paths, and refresh/replay semantics unchanged.
4. Add tests proving protected account, household, and mentor requests write Bearer headers.

## Target Location

`mobile/lib/core/network/`, `mobile/lib/features/account/data/services/`, `mobile/lib/features/household/data/services/`, `mobile/lib/features/mentor/data/services/`, `mobile/test/core/network/`, and `mobile/test/features/mentor/`.

## Allowed Changes

- Shared auth header helper.
- Protected API request header construction.
- Tests and fakes proving Bearer header injection.
- Documentation artifacts describing the completed behavior.

## Forbidden Changes

- API payload changes.
- Endpoint path changes.
- Refresh/replay behavior changes.
- Mentor/AI consent-gate behavior changes.
- Account, household, or mentor UI behavior changes.

## Acceptance Criteria

- [x] Protected Account API service calls write `Authorization: Bearer <accessToken>`.
- [x] Protected Household API service calls write `Authorization: Bearer <accessToken>` through `AuthenticatedApiClient`.
- [x] Protected Mentor API service calls write `Authorization: Bearer <accessToken>` through `AuthenticatedApiClient`.
- [x] Legacy missing-token fail-closed behavior remains covered.
- [x] Full mobile analyze/test/coverage baseline remains green.

## Regression Test Requirements

- [x] Account protected API header tests.
- [x] Household protected API header tests.
- [x] Mentor protected API header tests.
- [x] Existing authenticated-client refresh/fail-closed tests remain green.

## Completion Evidence

- Added `mobile/lib/core/network/auth_headers.dart`.
- Updated `AccountApiService`, `HouseholdApiService`, and `MentorApiService` request builders to include Bearer headers when an access token is present.
- Added `mobile/test/core/network/bearer_authorization_header_test.dart`.
- Updated `mobile/test/features/mentor/mentor_api_service_auth_characterization_test.dart` to assert REFACTOR-006 target behavior.
- Targeted auth/header tests: pass, 8 tests passed.
- Additional account/household/mentor targeted tests: pass.
- Full `flutter analyze`: pass, no issues found.
- Full `flutter test`: pass, 207 tests passed.
- Full `flutter test --coverage`: pass, 207 tests passed.
- Line coverage after REFACTOR-006: 66.06%.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Backend still expects legacy cookie-like token semantics | Medium | High | Only change header format to confirmed Bearer JWT target; keep payloads and refresh flow unchanged |
| Header helper diverges across services | Low | Medium | Centralize header name/value construction in `mobile/lib/core/network/auth_headers.dart` |
| Consent gate behavior accidentally changes | Low | High | Do not modify `MentorNotifier` preflight in this task; leave REFACTOR-007 blocked |

## Review Checklist

- [x] Tests prove Bearer header injection for protected service families.
- [x] Request payloads are unchanged.
- [x] Refresh and missing-token fail-closed tests remain green.
- [x] Mentor/AI consent behavior is not changed in this task.

## Known Decisions

- Bearer JWT is the canonical mobile auth source.
- Protected API calls must use one authenticated request path.
- Mentor/AI fail-closed consent gate is a separate task.

## Authorizations

- AR-R3-005.

## Dependencies

- REFACTOR-005.