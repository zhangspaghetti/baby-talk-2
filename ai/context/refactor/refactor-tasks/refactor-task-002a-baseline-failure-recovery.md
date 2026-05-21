---
id: REFACTOR-002A
title: Baseline Failure Recovery
status: done
priority: high
phase: 1
assignee: AI
created: 2026-05-18
estimated: 0.25d
---

## Goal

Restore the mobile test baseline after REFACTOR-002 discovered one stale repo-root handoff assertion.

## Legacy Code Location

`test/tool/verify_m006_s14_release_closure_test.dart` and its mobile forwarding test at `mobile/test/tool/verify_m006_s14_release_closure_test.dart`.

## Original Functionality Description

The test verifies that the repo-root CI workflow preserves Docker relay, backend tests, Helm smoke, artifact upload, and fail aggregation ordering for the M006 S14 handoff surface.

## Refactoring Approach

1. Diagnose the failing expectation from the mobile forwarded test.
2. Confirm the current CI workflow includes an additional checkstyle step in the fail aggregation gate.
3. Update the stale test expectation to match the current CI step title and assert checkstyle remains ordered after backend tests.
4. Rerun targeted and full mobile verification.

## Target Location

`test/tool/verify_m006_s14_release_closure_test.dart`

## Allowed Changes

- Test-only correction for the stale CI handoff assertion.
- Governance artifact updates documenting the restored baseline.

## Forbidden Changes

- Production Flutter source changes.
- Behavior changes to the CI workflow.
- Quarantining or skipping the failing test.

## Acceptance Criteria

- [x] Root cause is documented.
- [x] Stale assertion is updated without weakening the handoff contract.
- [x] Targeted forwarded mobile test passes.
- [x] Full `flutter test` and `flutter test --coverage` pass.
- [x] `flutter analyze` remains green.

## Regression Test Requirements

- [x] `flutter test mobile/test/tool/verify_m006_s14_release_closure_test.dart`
- [x] `flutter test`
- [x] `flutter test --coverage`
- [x] `flutter analyze`

## Completion Evidence

- Targeted forwarded test: 9 passed, exit 0.
- `flutter test`: 200 passed, exit 0.
- `flutter test --coverage`: 200 passed, exit 0.
- `flutter analyze`: no issues found, exit 0.
- Coverage remains 63.99%.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Test becomes too loose and misses CI handoff drift | Low | Medium | Keep explicit fail-step title and add ordering assertion for checkstyle after backend tests |

## Review Checklist

- [x] Test-only change.
- [x] No production Flutter source change.
- [x] CI workflow behavior was not changed.
- [x] Baseline report updated with restored state.

## Known Decisions

- Human selected baseline failure handling before proceeding to REFACTOR-004/005.

## Authorizations

- AR-R3-002.

## Dependencies

- REFACTOR-002.