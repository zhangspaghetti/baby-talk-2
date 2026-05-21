# Stage R0 Refactor Project Assessment

Version: Flutter AI Software Factory v1.0.0  
Stage: R0 - Project Onboarding and Initialization  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-16  
Updated: 2026-05-18  
Status: R0 complete, R1 audit complete, R2 pending red decisions

## Goal

Establish a safe, artifact-driven rescue process for the existing Flutter mobile app without changing runtime behavior.

## Startup Confirmation

Refactor rescue is started in Strict Mode. Stage R0 will create governance, inventory, baseline, and decision artifacts only. Source-code refactoring begins only after R1 audit and R2 planning are complete and approved.

## Current Project Facts

- Mobile package path: `mobile/`
- Flutter source path: `mobile/lib/`
- Current top-level source structure: `app/`, `core/`, `features/`, `l10n/`, `main.dart`
- Tracked Dart files under `mobile/lib`: 127
- State management: `flutter_riverpod` 2.6.1, `riverpod_annotation` 2.6.1, `hooks_riverpod` 2.6.1
- Routing: `go_router` 14.8.1
- Local persistence: `isar` 3.1.0+1
- Networking: `dio` 5.7.0 and `http` 1.2.2
- Code generation: `build_runner`, `freezed`, `json_serializable`, `isar_generator`, `riverpod_generator`
- i18n package support exists: `flutter_localizations`, `intl`, `mobile/lib/l10n/app_zh.arb`, generated localization files
- Theme/design-token work exists: `mobile/lib/app/theme/app_theme.dart`, `mobile/lib/app/theme/app_layout_constants.dart`
- Tests exist under `mobile/test` and `mobile/integration_test`, including smoke tests for a11y, i18n, app boot, session reset, and dark mode.

## Evidence Summary

### Existing Good Foundations To Preserve

- Feature folders already exist: `account`, `household`, `mentor`, `onboarding`, `practice`, `share`, `shell`, `sync`.
- Many features already follow a `data/domain/presentation` convention.
- Generated i18n files and `app_zh.arb` exist, so the app is not starting from zero on localization.
- Theme extension and layout constants exist, so design-system rescue can start by consolidating, not inventing from scratch.
- Regression test surface exists and should be expanded before behavior-preserving refactors.

### Initial High-Risk Hotspots

| Priority | Area | Evidence | Risk |
|---:|---|---|---|
| 1 | App composition monolith | `mobile/lib/app/app.dart` imports many feature repositories, notifiers, screens, router, theme, and app coordination code | High blast radius; app shell changes can affect routing, DI, auth, onboarding, and localization at once |
| 2 | Central DI concentration | `mobile/lib/app/providers/repository_providers.dart` wires storage, API services, repositories, and feature notifiers | Lifecycle and dependency changes can ripple through multiple features |
| 3 | Practice repository overload | `mobile/lib/features/practice/data/repositories/practice_repository.dart` contains many model/summary classes and repository behavior | Repository boundary and testability risk |
| 4 | Dual routing surface | `mobile/lib/app/router/app_go_router.dart` and `mobile/lib/app/router/app_router.dart` both exist | Migration ambiguity and behavior drift risk |
| 5 | State duality | Project knowledge identifies ViewModel + Notifier dual truth in multiple places | Async state consistency risk |
| 6 | Cross-feature imports | Project knowledge identifies direct feature-to-feature imports | Feature boundary erosion |
| 7 | UI hardcoded strings | UX audit found raw user-visible strings still passed into widgets | i18n incompleteness |
| 8 | Magic layout values | Existing tokens are partial; UI audit found repeated literal spacing/sizing in widgets | UX inconsistency and maintenance drift |
| 9 | Accessibility gaps | Existing smoke a11y test exists, but UI audit found incomplete/fragile semantics coverage | Screen-reader and touch-target risk |
| 10 | Generated/lint exclusions | `analysis_options.yaml` excludes `lib/**/*.g.dart`, but not all generated surfaces or future `legacy/` yet | Analyzer noise or missed governance checks |

## R0 Decisions Already Made

- Strict Mode is selected.
- R0 is documentation and governance only.
- No full-source move to `lib/legacy/` will be performed in R0 without human approval.
- Existing tests are treated as partial regression baselines, not full safety coverage.

## R0 Open Decisions

No blocking R0 decisions remain. R1 red decisions are tracked in `ai/context/daily-decision-summary.md`.

## R1 Completion Summary

Stage R1 read-only audit was completed on 2026-05-18. Reports were generated under `ai/context/refactor/audit-reports/`:

- `full-code-audit-report.md`
- `architecture-issues.md`
- `design-system-issues.md`
- `security-issues.md`
- `performance-issues.md`
- `technical-debt-assessment.md`
- `risks-and-mitigations.md`
- `test-regression-baseline.md`

R2 planning is not authorized for implementation until red decisions are confirmed and R2 task artifacts are approved.

## R0 Exit Criteria

- [x] Governance directory created.
- [x] R0 project assessment created.
- [x] Daily decision summary created.
- [x] Initial hotspots listed with paths.
- [x] No Flutter runtime code modified.
- [x] Human confirms deferred physical `lib/legacy/` migration policy.
- [x] Human confirms R1 audit scope and priority order.

## Verification Commands For Future Code Changes

Run from `mobile/` unless noted otherwise:

```bash
flutter pub get
flutter analyze
flutter test
flutter test --coverage
flutter test integration_test/e2e_smoke_test.dart
```

For repository root QA, run only when local dependencies and secrets are available:

```bash
./scripts/qa-up-helm.sh
```
