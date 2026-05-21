# REFACTOR-038 Real-Store Lifecycle Clearance Registry

---
id: REFACTOR-038
title: Real-store lifecycle clearance registry
status: done
priority: high
phase: 4
assignee: AI
created: 2026-05-20
estimated: 0.5 day
---

## Goal

Reduce the R4 sensitive local-data lifecycle blocker by registering the approved real-store delete/close primitives behind the existing governance orchestrator and proving the registry with temp-store tests.

## Target Locations

- `mobile/lib/app/local_sensitive_data_clearance_registry.dart`
- `mobile/lib/features/account/data/repositories/account_repository.dart`
- `mobile/lib/features/household/data/repositories/household_repository.dart`
- `mobile/lib/features/practice/data/repositories/practice_repository.dart`
- `mobile/test/app/local_sensitive_data_clearance_registry_test.dart`
- R4 task index, timeline, and readiness reports

## Approach

1. Add narrow lifecycle methods to repositories where the delete primitive was private or owned by a lower-level store.
2. Add an app-layer registry factory that maps all `LocalSensitiveDataTarget` values to real deletion primitives.
3. Keep the registry unwired from user flows, logout, account deletion, and consent withdrawal until explicit destructive-flow approval exists.
4. Add focused temp-store tests for registration coverage, governance rejection, and Staff+ destructive clearance.
5. Update R4 evidence truthfully: real-store registry exists, but production lifecycle readiness still needs approved product-flow wiring plus backup/encryption posture.

## Allowed Changes

- Add app-layer lifecycle registry code.
- Add repository wrapper methods that expose existing local delete primitives.
- Add focused tests using only temporary test stores.
- Update R4 verification and tracking reports.

## Forbidden Changes

- Do not wire destructive local-data clearance into logout, consent withdrawal, account deletion, device erase, app boot, or UI flows.
- Do not delete real user data outside test temp directories.
- Do not weaken Staff+ authorization requirements.
- Do not claim production lifecycle approval before backup/encryption and human approval are complete.

## Acceptance Criteria

- [x] Registry includes one clearance step for every sensitive lifecycle target.
- [x] Destructive account deletion clearance is rejected without Staff+ authorization and preserves seeded temp stores.
- [x] Staff+ destructive clearance deletes account, onboarding, household, practice, mentor, and installation ID temp stores.
- [x] Static analysis remains green.
- [x] Reports distinguish registry evidence from production destructive-flow approval.

## Verification Evidence

| Command | Exit | Result |
|---|---:|---|
| `flutter test test/app/local_sensitive_data_clearance_registry_test.dart` from `mobile/` | 0 | Pass; 3 tests |
| `flutter analyze` from `mobile/` | 0 | Pass; no issues found |
| `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart test/app/local_sensitive_data_clearance_registry_test.dart` from `mobile/` | 0 | Pass; 6 tests |

## Lifecycle Decision

REFACTOR-038 closes the missing real-store registry slice of the lifecycle gate. It does not approve destructive user-flow wiring. Production lifecycle readiness still requires explicit Staff+/human approval for product-flow integration, backup exclusion or encryption posture evidence, target replay, and final release approval.