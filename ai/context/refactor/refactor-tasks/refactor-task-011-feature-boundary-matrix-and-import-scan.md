# Refactor Task: REFACTOR-011 Feature Boundary Matrix and Report-Only Import Scan

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 / Phase 2  
Created: 2026-05-18  
Status: done

## Objective

Create a mobile feature boundary matrix and a report-only import scan that makes legacy cross-feature imports visible without changing production behavior or failing CI.

## Scope

- Add a feature boundary matrix under `ai/architecture`.
- Add a report-only scan for `mobile/lib/features/**/*.dart` import/export directives.
- Add tests proving the scan classifies approved legacy bridges and forbidden candidates without hard failure.
- Update R2 governance artifacts after validation.

## Forbidden Changes

- Do not modify production Flutter feature behavior.
- Do not move feature files or split repositories in this task.
- Do not enforce cross-feature import failures as hard CI gates.
- Do not edit generated Dart files.

## Acceptance Criteria

- [x] Feature boundary matrix documents intended feature roles, default forbidden rule, and temporary legacy exceptions.
- [x] Scan resolves package and relative imports from feature source files.
- [x] Scan excludes generated `*.g.dart` and `*.freezed.dart` files.
- [x] Scan prints total counts, pair counts, per-edge evidence, and a report-only success marker.
- [x] Scan tests pass through the root test and mobile wrapper test paths.
- [x] `flutter analyze`, `flutter test`, and `flutter test --coverage` remain green.

## Regression Test Requirements

- [x] Root scan contract test passes.
- [x] Mobile wrapper scan contract test passes.
- [x] Full mobile test suite remains green.

## Completion Evidence

- Added `ai/architecture/feature-boundary-matrix.md` with feature roles, default forbidden rule, approved report-only legacy edges, replacement directions, and direct scan command.
- Added `tool/verify_refactor_011_feature_boundaries.dart` as a Dart core-only report-only scanner for `mobile/lib/features/**/*.dart` imports/exports, excluding generated `.g.dart` and `.freezed.dart` files.
- Added root and mobile wrapper tests for scan contract classification, relative import resolution, rendering, and CLI argument handling.
- Current report-only baseline: 99 cross-feature import/export directives, 69 approved legacy bridges, 30 forbidden candidates.
- Focused validation: root scan contract test passed, mobile wrapper scan contract test passed, and direct report-only scan completed successfully.
- Full `flutter analyze`: pass, no issues found.
- Full `flutter test`: pass, 214 tests passed.
- Full `flutter test --coverage`: pass, 214 tests passed.
- Line coverage after REFACTOR-011: 66.32%.

## Authorizations

- AR-R3-010.