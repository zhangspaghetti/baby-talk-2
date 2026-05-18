# Stage R1 Architecture Issues

Version: Flutter AI Software Factory v1.0.0  
Stage: R1 - Architecture Audit  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed, pending R2 decisions

Architecture score: 4 / 10.

## Summary

The app has a useful modular starting point, but it is not yet governed by the Factory architecture. The current system is best described as a logical legacy surface with partial feature slicing. The largest architecture risks are missing dependency inversion, cross-feature imports, dual app composition/state surfaces, ambiguous routing, and no `AsyncValue` standard.

## Architecture Findings

### ARCH-001: Dependency inversion is missing at repository boundaries

Evidence:

- Presentation imports concrete data repositories and local stores.
- No stable `domain/repositories` contract layer is present.
- No `domain/usecases` layer is present for cross-feature workflows.

Impact: Refactoring data or storage code directly affects UI and notifier tests.

R2 action: define minimal repository interfaces first, then adapt existing concrete repositories without behavior changes.

### ARCH-002: Feature isolation is broken

Evidence:

- Static scan found 245 cross-feature import candidates.
- `shell`, `mentor`, `share`, and `household` depend on internals from `practice` and `account`.

Impact: Feature modules cannot evolve independently, and R3 cannot safely migrate one feature at a time without a dependency map.

R2 action: create `ai/architecture/feature-boundary-matrix.md` and enforce it initially in report-only mode.

### ARCH-003: App composition has mixed Provider and Riverpod graphs

Evidence:

- `mobile/lib/app/app.dart` owns old Provider graph and nested Riverpod scope.
- `mobile/lib/app/providers/repository_providers.dart` owns another provider graph.
- Local screen providers still exist.

Impact: Dependency override, lifecycle, and state ownership are ambiguous.

R2 action: choose canonical composition target and write a migration map. Recommended target is Riverpod + GoRouter, with old Provider treated as compatibility legacy.

### ARCH-004: Async state standard is absent

Evidence: Static scan found 0 `AsyncValue` references and 41 ChangeNotifier/Provider references.

Impact: Loading/error/data state varies by notifier. This violates Factory architecture law 7.

R2 action: define the target state shape and pilot it in one low-risk notifier before high-risk flows.

### ARCH-005: Routing has multiple ownership surfaces

Evidence:

- `mobile/lib/app/router/app_router.dart`
- `mobile/lib/app/router/app_go_router.dart`
- router construction inside `mobile/lib/app/app.dart`

Impact: Redirect, route args, onboarding, and reentry behavior can diverge.

R2 action: write a route contract inventory before any router refactor.

### ARCH-006: Generated code isolation requires a project-level decision

Evidence: `*.freezed.dart` and `*.g.dart` files are co-located with source files under features.

Impact: Strict Factory compliance conflicts with normal Dart `part` co-location unless build output strategy is changed.

R2 action: confirm strict `lib/generated` migration or record a Dart tooling exception with analyzer/lint compensation.

## R2 Architecture Task Seeds

1. `ARCH-R2-001`: Create canonical app composition decision record.
2. `ARCH-R2-002`: Create route contract inventory and canonical router plan.
3. `ARCH-R2-003`: Create repository/usecase contract map for account, practice, mentor, household, share.
4. `ARCH-R2-004`: Create feature boundary matrix and forbidden import scan.
5. `ARCH-R2-005`: Create AsyncValue migration pilot plan.
6. `ARCH-R2-006`: Decide generated code policy.

## Required Human Decisions

See:

- `ai/context/pending-decisions/need-confirmation-r1-canonical-app-composition.md`
- `ai/context/pending-decisions/need-confirmation-r1-generated-code-policy.md`