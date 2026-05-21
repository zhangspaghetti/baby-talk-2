# REFACTOR-011 Feature Boundary Matrix and Report-Only Import Scan

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Task: REFACTOR-011  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-011 establishes the mobile feature boundary matrix and adds a report-only Dart scan for cross-feature imports and exports under `mobile/lib/features`. The task makes legacy edges visible without changing production behavior and without converting boundary violations into hard CI failures.

No production Flutter feature source was modified.

## Added Files

| File | Purpose |
|---|---|
| `ai/architecture/feature-boundary-matrix.md` | Documents feature roles, default forbidden rule, approved report-only legacy edges, and replacement directions |
| `tool/verify_refactor_011_feature_boundaries.dart` | Scans mobile feature imports/exports and prints report-only edge evidence |
| `test/tool/verify_refactor_011_feature_boundaries_test.dart` | Tests scanner classification, package/relative import resolution, rendering, and CLI argument handling |
| `mobile/test/tool/verify_refactor_011_feature_boundaries_test.dart` | Mobile wrapper so the root scanner contract is covered by mobile test runs |

## Current Scan Baseline

| Metric | Count |
|---|---:|
| Total cross-feature directives | 99 |
| Approved legacy bridges | 69 |
| Forbidden candidates | 30 |

## Pair Counts

| Pair | Count |
|---|---:|
| account -> household | 2 |
| account -> onboarding | 2 |
| account -> practice | 2 |
| household -> account | 6 |
| household -> practice | 3 |
| mentor -> account | 9 |
| mentor -> household | 2 |
| mentor -> onboarding | 6 |
| mentor -> practice | 4 |
| onboarding -> practice | 1 |
| practice -> account | 3 |
| practice -> household | 1 |
| practice -> mentor | 2 |
| practice -> onboarding | 4 |
| practice -> share | 1 |
| share -> practice | 7 |
| shell -> account | 1 |
| shell -> household | 7 |
| shell -> mentor | 1 |
| shell -> onboarding | 2 |
| shell -> practice | 27 |
| shell -> share | 4 |
| sync -> practice | 2 |

## Verification

| Command | Result |
|---|---|
| `flutter test test/tool/verify_refactor_011_feature_boundaries_test.dart` | Pass; 3 tests passed |
| `flutter test test/tool/verify_refactor_011_feature_boundaries_test.dart` from `mobile/` | Pass; 3 tests passed |
| `dart tool/verify_refactor_011_feature_boundaries.dart` | Pass; report-only scan completed |
| `flutter analyze` from `mobile/` | Pass; no issues found |
| `flutter test` from `mobile/` | Pass; 214 tests passed |
| `flutter test --coverage` from `mobile/` | Pass; 214 tests passed |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 7135 |
| Lines found | 10759 |
| Line coverage | 66.32% |

## Scope Check

- Production feature behavior: unchanged.
- Feature files moved or split: none.
- Generated Dart files: unchanged.
- Hard CI enforcement: not introduced.
- Scan mode: report-only.

## Residual Notes

- The root `dart run tool/...` path triggers the repo-root dependency solver and currently hits a known `win32` dependency conflict between `share_plus` and `flutter_secure_storage`. The scanner uses only Dart core libraries, so the documented invocation is `dart tool/verify_refactor_011_feature_boundaries.dart`.
- Full test runs still emit benign Isar inspector URLs and the pre-existing nonfatal onboarding tap warning for `onboarding-name-continue`; tests pass.

## Follow-Up

- REFACTOR-012 remains blocked until separately approved for the AsyncValue low-risk pilot.
- Future boundary work should reduce the 30 forbidden candidates through contract seams before any report-only scan is converted into a hard CI gate.