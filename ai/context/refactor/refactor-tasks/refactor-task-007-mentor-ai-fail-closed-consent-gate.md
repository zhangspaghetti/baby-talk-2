---
id: REFACTOR-007
title: Mentor AI Fail Closed Consent Gate
status: done
priority: high
phase: 2
assignee: AI
created: 2026-05-18
estimated: 1d
---

## Goal

Make Mentor/AI network requests fail closed unless the parent account is logged in, has accepted consent, and has a JWT-capable session. Local Mentor suggestions must remain available for all account states.

## Legacy Code Location

`mobile/lib/features/mentor/presentation/mentor_notifier.dart` and Mentor tests under `mobile/test/features/mentor/`.

## Original Functionality Description

REFACTOR-005 characterized the legacy behavior: Mentor chat preflight blocked account-loading and offline states, but allowed anonymous or unsafe consent states to reach `MentorApiService.sendChat`. `submitChat` selected a session through `AccountNotifier.isSignedIn`, which could still pass a revoked-with-session account into the authenticated request path.

## Refactoring Approach

1. Extend Mentor chat availability codes to distinguish login-required and consent-required blocked states.
2. Derive chat availability from `AccountConsentState`, offline status, and `AccountSession.hasJwtTokens`.
3. Select the outgoing Mentor chat session only from the validated `acceptedPendingSync + JWT tokens` path.
4. Record fail-closed preflight denials as `MentorFactType.chatFailed` without calling the Mentor API.
5. Update characterization tests to target the approved REFACTOR-007 behavior.

## Target Location

`mobile/lib/features/mentor/presentation/mentor_notifier.dart`, `mobile/test/features/mentor/mentor_notifier_test.dart`, and `mobile/test/features/mentor/mentor_shell_panel_test.dart`.

## Allowed Changes

- Mentor chat availability/preflight behavior.
- Mentor chat session selection before network submission.
- Tests and fakes proving fail-closed behavior and authenticated success behavior.
- Documentation artifacts describing the completed behavior.

## Forbidden Changes

- API payload changes.
- Endpoint path changes.
- Bearer header construction changes from REFACTOR-006.
- Auth refresh/replay behavior changes.
- Route behavior changes.
- Removing or blocking local Mentor suggestions for local-only, signed-out, revoked, deleted, offline, or missing-token states.

## Acceptance Criteria

- [x] `localOnly` and `signedOut` account states cannot submit Mentor chat and do not call Mentor API.
- [x] `revoked` and `deleted` account states cannot submit Mentor chat and do not call Mentor API even if a session exists.
- [x] `acceptedPendingSync` without a JWT-capable session cannot submit Mentor chat and does not call Mentor API.
- [x] `acceptedPendingSync` with JWT tokens can submit Mentor chat and passes the session to the API.
- [x] Offline preflight remains blocked and does not call Mentor API.
- [x] Local suggestions remain available in blocked states.
- [x] Fail-closed preflight denials append `chatFailed` facts.
- [x] Full mobile analyze/test/coverage baseline remains green.

## Regression Test Requirements

- [x] Unit test for unsafe consent states failing closed without Mentor API calls.
- [x] Unit test for accepted JWT session preserving online chat success.
- [x] Unit tests for authenticated error, timeout, and multi-turn behavior under the new gate.
- [x] Widget test for chat submission using an accepted JWT session.
- [x] Existing offline preflight test remains green.

## Completion Evidence

- Updated `MentorNotifier` availability derivation and chat session selection.
- Superseded the REFACTOR-005 unsafe consent characterization with REFACTOR-007 target behavior.
- Updated Mentor widget chat success coverage to use an accepted JWT session.
- Targeted Mentor tests: pass, 20 tests passed.
- Full `flutter analyze`: pass, no issues found.
- Full `flutter test`: pass, 207 tests passed.
- Full `flutter test --coverage`: pass, 207 tests passed.
- Line coverage after REFACTOR-007: 66.10%.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Legitimate accepted users are blocked by missing token migration edge cases | Medium | Medium | Gate uses `AccountSession.hasJwtTokens`, matching existing authenticated-client fail-closed behavior; visible retry/login state remains exposed |
| Local-only users lose Mentor value | Low | High | Local suggestions and panel opening remain available; only network chat submission is blocked |
| Bearer header behavior regresses | Low | High | No Mentor API service/header changes in this task; REFACTOR-006 tests remain green |
| Preflight facts become noisy | Low | Low | Facts are appended only on explicit submit attempts, not on panel opening |

## Review Checklist

- [x] The API is not called for unauthenticated, unconsented, deleted, revoked, missing-session, missing-token, or offline states.
- [x] Accepted JWT sessions still call Mentor API exactly through the existing service path.
- [x] Existing request payloads, endpoint paths, refresh, and Bearer header construction remain unchanged.
- [x] Local suggestions remain available before and after blocked chat preflight.
- [x] Full verification gates are green after implementation.

## Known Decisions

- Mentor/AI network calls require parent login and accepted consent.
- Bearer JWT is the canonical mobile auth source.
- Local Mentor suggestions are allowed in local-only/offline states; online AI chat is not.

## Authorizations

- AR-R3-006.

## Dependencies

- REFACTOR-005.
- REFACTOR-006.