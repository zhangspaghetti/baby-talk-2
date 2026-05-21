# Refactor Task: REFACTOR-013 Local Sensitive Data Lifecycle Plan and Tests

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 / Phase 2  
Created: 2026-05-18  
Status: done

## Objective

Document the local sensitive data lifecycle baseline and add report-only tests that track current deletion primitives and gaps before any destructive storage migration or hard CI enforcement.

## Scope

- Add a local sensitive data lifecycle matrix under `ai/architecture`.
- Classify account, onboarding, household, practice, mentor, and installation-id local data surfaces.
- Add a report-only scanner for current source-level deletion primitives.
- Add tests proving the scanner recognizes covered primitives and current gaps.
- Update R2 governance artifacts after validation.

## Forbidden Changes

- Do not delete local user data in this task.
- Do not migrate JSON or Isar stores to new storage.
- Do not change account logout, consent withdrawal, or account deletion runtime behavior.
- Do not make lifecycle gaps hard CI failures.
- Do not edit generated Dart files.

## Acceptance Criteria

- [x] Lifecycle matrix documents sensitive surfaces, triggers, backup/encryption target, and current gaps.
- [x] Scanner validates all expected sensitive surfaces are documented.
- [x] Scanner detects current deletion primitives and the missing installation ID delete/reset primitive.
- [x] Scanner prints report-only counts, per-surface evidence, and a success marker.
- [x] Scanner tests pass through the root test and mobile wrapper test paths.
- [x] `flutter analyze`, `flutter test`, and `flutter test --coverage` remain green.

## Regression Test Requirements

- [x] Root scanner contract test passes.
- [x] Mobile wrapper scanner contract test passes.
- [x] Full mobile test suite remains green.

## Authorizations

- Human selected `进入 REFACTOR-013` after REFACTOR-012 completion.

## Completion Evidence

- `dart tool/verify_refactor_013_sensitive_lifecycle.dart`: report-only scan completed with 6 sensitive surfaces, 5 covered delete primitives, 1 missing installation ID delete/reset primitive, 0 missing sources, and 0 missing documentation rows.
- Focused scanner tests: 3 passed.
- `flutter analyze`: pass.
- `flutter test`: 218 passed.
- `flutter test --coverage`: 218 passed.
- `LCOV_SUMMARY LH=7136 LF=10760 Coverage=66.32%`.

## Notes

- The first chained full gate left stale `flutter_tester.exe` processes after the coverage phase stalled; those stale test runners were stopped, and the clean standalone coverage run passed.
- The existing onboarding tap warning around `onboarding-name-continue` still appears during full tests and remains nonfatal.
- Runtime storage deletion behavior was not changed in this task.