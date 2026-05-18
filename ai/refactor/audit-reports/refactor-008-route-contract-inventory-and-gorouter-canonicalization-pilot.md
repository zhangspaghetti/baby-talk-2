# REFACTOR-008 Route Contract Inventory And GoRouter Canonicalization Pilot

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Task: REFACTOR-008  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-008 centralizes the mobile app's canonical route path values in `AppRouteNames` and rewires low-risk call sites to consume that contract. The task preserves the existing route values and keeps both the inline production GoRouter and legacy named route factory intact.

This is a pilot for route contract canonicalization, not a full router migration.

## Changed Production Files

| File | Change |
|---|---|
| `mobile/lib/app/router/app_route_contract.dart` | Added canonical route path constants and the path inventory set |
| `mobile/lib/app/router/app_router.dart` | Re-exported the route contract and replaced local route constants |
| `mobile/lib/app/router/app_go_router.dart` | Replaced duplicated route path literals with canonical constants |
| `mobile/lib/app/app.dart` | Replaced inline GoRouter route path literals with canonical constants |
| `mobile/lib/app/app_reentry_orchestrator.dart` | Replaced shell and practice navigation literals with canonical constants |
| `mobile/lib/features/practice/presentation/practice_route_args.dart` | Replaced practice push literal with the canonical route constant |

## Added Tests

| File | Coverage |
|---|---|
| `mobile/test/app/app_route_contract_test.dart` | Asserts exact canonical route path values, inventory size, legacy route factory practice routing, and unknown-route fallback behavior |

## Route Contract Matrix

| Route Constant | Path | Notes |
|---|---|---|
| `AppRouteNames.shell` | `/` | Shell/home route entry |
| `AppRouteNames.home` | `/` | Alias for shell/home semantics |
| `AppRouteNames.onboarding` | `/onboarding` | Onboarding route |
| `AppRouteNames.practice` | `/practice` | Practice session route |
| `AppRouteNames.account` | `/account` | Account entry route |

## Verification

| Command | Result |
|---|---|
| Targeted route contract, app composition, and re-entry tests | Pass; 14 tests passed |
| `flutter analyze` | Pass; no issues found |
| `flutter test` | Pass; 209 tests passed |
| `flutter test --coverage` | Pass; 209 tests passed |

## Coverage

| Metric | Value |
|---|---:|
| Lines hit | 7119 |
| Lines found | 10759 |
| Line coverage | 66.17% |

## Scope Check

- Route path values: unchanged.
- Route argument payloads: unchanged.
- Initial route behavior: unchanged.
- Share and invite destination behavior: unchanged.
- Legacy named route factory: retained.
- Alternate Riverpod GoRouter provider: retained.

## Residual Notes

- Full test runs still emit the pre-existing nonfatal onboarding tap warning for `onboarding-name-continue` outside the default 800x600 viewport; tests pass.
- Isar inspector URLs in test output remain benign test runtime output.

## Follow-Up

- REFACTOR-009 remains blocked until separately approved for repository/usecase contract mapping and account adapter seam work.
- A later router migration can remove compatibility surfaces only after additional characterization and explicit approval.