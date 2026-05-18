---
id: REFACTOR-005
title: Auth And Consent Characterization
status: done
priority: high
phase: 1
assignee: AI
created: 2026-05-18
estimated: 1-2d
---

## Goal

Capture current auth and mentor/AI consent behavior before introducing the single Bearer JWT client and fail-closed consent gate.

## Legacy Code Location

`mobile/lib/core/network/`, `mobile/lib/features/account/`, `mobile/lib/features/mentor/`, and protected API service paths.

## Original Functionality Description

Account, household, mentor, practice, and share flows currently use mixed token-adjacent service paths. Mentor chat can send prompt/context through the mentor API path. Current behavior must be recorded before it is corrected.

## Refactoring Approach

1. Inventory protected API paths and current token handling.
2. Add tests that describe current behavior.
3. Add failing/expected tests for the approved target behavior where appropriate, but do not change production source in this task unless explicitly approved.
4. Use these tests to unlock REFACTOR-006 and REFACTOR-007.

## Target Location

`mobile/test/features/account/`, `mobile/test/features/mentor/`, and `mobile/test/core/network/`

## Allowed Changes

- New tests and fakes.
- Documentation of current auth/consent behavior.

## Forbidden Changes

- Production auth behavior changes in this characterization task.
- Network API payload changes.
- Consent UX changes.

## Acceptance Criteria

- [x] Protected API paths are inventoried.
- [x] Tests exist for auth header behavior or document current gaps.
- [x] Tests exist proving mentor calls can be observed and later made fail-closed.
- [x] Follow-up implementation tasks are blocked until tests exist.

## Regression Test Requirements

- [x] Authenticated client/header tests.
- [x] Mentor network call guard tests.
- [x] Unauthenticated/unconsented behavior tests.

## Completion Evidence

- Added `mobile/test/features/mentor/mentor_api_service_auth_characterization_test.dart`.
- Extended `mobile/test/features/mentor/mentor_notifier_test.dart` with REFACTOR-005 baseline tests.
- Existing `mobile/test/features/account/jwt_session_refresh_test.dart` already covers `AuthenticatedApiClient` single-flight refresh, refresh timeout fail-closed behavior, replay 401 handling, and missing-token fail-closed behavior.
- Targeted REFACTOR-005 test run: pass, 14 tests passed.
- Targeted coverage run: pass, 14 tests passed.
- Full `flutter analyze`: pass, no issues found.
- Full `flutter test`: pass, 204 tests passed.
- Full `flutter test --coverage`: pass, 204 tests passed.
- Line coverage after REFACTOR-005: 64.75%.

## Protected API Inventory

| Surface | Current Auth Handling | Characterization |
|---|---|---|
| `AuthenticatedApiClient` | Requires JWT access/refresh tokens before protected sends, performs single-flight refresh after first 401, and fails closed for legacy sessions without tokens | Covered by existing `mobile/test/features/account/jwt_session_refresh_test.dart` |
| `HouseholdApiService` | Uses `AuthenticatedApiClient` for protected household API requests and maps authenticated-client failures into visible 401-like household errors | Covered by existing household repository/service tests |
| `MentorApiService` anonymous chat | Posts directly to `/api/v1/mentor/chat` when no session is supplied | Covered by existing mentor notifier and shell panel tests |
| `MentorApiService` signed-in chat | Routes through `AuthenticatedApiClient` when a session is supplied, but current request construction does not attach an `Authorization` header | Captured by new `mentor_api_service_auth_characterization_test.dart` |
| `MentorNotifier` chat preflight | Blocks only account-loading and offline availability; consent state is not currently a fail-closed gate | Captured by new `mentor_notifier_test.dart` REFACTOR-005 baseline tests |

## Observed Behavior

- Current mentor chat availability is `ready` for `localOnly`, `signedOut`, `revoked`, and `deleted` snapshots when the account phase is not offline.
- `localOnly` and `signedOut` snapshots can submit anonymous Mentor chat requests.
- A `revoked` snapshot with a retained session is treated as signed in by `AccountNotifier.isSignedIn` and the session is forwarded to Mentor chat.
- A `deleted` snapshot with a retained session can still submit the chat request, but the session is not forwarded.
- Offline preflight prevents Mentor API calls and records a `chatFailed` fact with `offline` phase.
- `MentorApiService` currently accepts an authenticated access token from `AuthenticatedApiClient` but does not place it in the outbound request headers.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Tests reveal current unsafe behavior | Medium | High | Record as baseline and fix only in approved follow-up task |

## Review Checklist

- [x] Tests do not silently change production behavior.
- [x] Security target is clear for Phase 2.

## Known Decisions

- Bearer JWT through one authenticated client.
- Mentor/AI network calls require login and consent.

## Authorizations

- AR-R3-004.
- AI may add tests and fakes only.

## Dependencies

- REFACTOR-002.