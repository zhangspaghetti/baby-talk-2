# REFACTOR-018 Legacy Deletion Candidate Audit

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Created: 2026-05-19
Status: completed, deletion not approved

## Summary

REFACTOR-018 audited legacy deletion candidates after the R017 verification report suite. No mobile production code, mobile tests, generated files, route behavior, API payloads, persisted data, copy, or visual values were changed.

No current legacy surface is safe to delete immediately. The project is not production-ready, core integration flows are blocked, coverage is below target, sensitive lifecycle enforcement is incomplete, performance benchmarks are missing, and the final human gate has not approved deletion.

## Scanner Evidence

| Scanner | Result |
|---|---|
| `dart tool/verify_refactor_011_feature_boundaries.dart` | Passed in report-only mode; `total_cross_feature_imports=99`, `legacy_bridge=69`, `forbidden_candidate=30` |
| `dart tool/verify_refactor_013_sensitive_lifecycle.dart` | Passed in report-only mode; `total_sensitive_surfaces=6`, `covered_delete_primitive=5`, `missing_delete_primitive=1` |

## Immediate Deletion Decision

| Decision | Result |
|---|---|
| Safe to delete now | No |
| Safe to move/archive now | No |
| Safe to hard-fail legacy scans now | No |
| Safe to prepare candidate list | Yes, report-only |

## Candidate Matrix

| Candidate Surface | Current Evidence | Classification | Required Proof Before Deletion |
|---|---|---|---|
| Deprecated named route factory in `mobile/lib/app/router/app_router.dart` | Marked `@Deprecated`; R008 kept legacy named route fallback intact | Candidate after router migration | All navigation, reentry, and practice route flows use the canonical GoRouter path; route contract tests and integration checks pass; no named-route callers remain |
| Inline production router construction in `mobile/lib/app/app.dart` versus `app_go_router.dart` provider | R008 centralized route constants but did not migrate app composition to the provider | Candidate after app composition migration | Single canonical GoRouter owner is selected and tested; boot/onboarding/shell/reentry behavior remains unchanged; integration blockers cleared |
| Old Provider `MultiProvider` compatibility graph in `mobile/lib/app/app.dart` | R004 recorded Provider/Riverpod bridge behavior; Riverpod is canonical target | Candidate after DI migration | All repositories/notifiers are owned by the Riverpod graph or approved contracts; app composition tests prove lifecycle/override parity; Provider consumers removed |
| Duplicate Riverpod repository graph in `mobile/lib/app/providers/repository_providers.dart` | Mirrors app bootstrap dependencies and still uses concrete repository types | Retain, possible consolidation later | Decide whether this becomes the canonical graph; migrate concrete dependencies behind contracts; prove app boot and tests use one graph |
| Shell cross-feature composition imports under `mobile/lib/features/shell/**` | R011 records shell as an approved temporary composition bridge with 41 shell-origin edges | Retain as bridge, not deletion | Feature entry contracts exist for account, household, mentor, onboarding, practice, and share; shell imports only public contracts; UI behavior tests pass |
| Cross-feature forbidden candidates outside shell | R018 scanner still reports 30 forbidden candidates | Boundary migration candidates, not deletion | Add contract seams or approved sunset exceptions; reduce forbidden count to zero or approved target before hard gate |
| Co-located generated files under `mobile/lib/features/**/*.freezed.dart` and `*.g.dart` | R003 remains blocked; current count is 11 Freezed and 2 Isar generated files under feature dirs | Migration-only, not deletion | Complete generated strict migration canary; prove build_runner/Isar/Freezed compatibility; regenerate under approved target; then delete old generated outputs in the same controlled migration |
| Concrete repository dependencies for household, mentor, practice, share | Only account has the first explicit repository contract seam from R009 | Retain until contract seams exist | Add contracts and tests per feature; remove UI/data direct coupling; prove no behavior or persistence changes |
| Legacy getter compatibility in async state pilots | R012 preserved existing share notifier getters while adding AsyncValue state | Retain until callers migrate | Migrate all callers to unified async state; focused tests prove old getters unused; remove compatibility in a separate behavior-preserving task |
| Local sensitive lifecycle gap for `mobile/lib/core/device/installation_id_service.dart` | R013/R018 scanner reports missing delete primitive | Not deletion candidate; lifecycle blocker | Add delete/reset primitive, lifecycle service, and tests before hard lifecycle enforcement or account deletion proof |
| Large legacy UI/repository files | R1 debt report identifies large files and monolith risk | Refactor candidates, not deletion | Add characterization coverage and split by behavior-preserving seams; no deletion without replaced behavior and passing tests |

## Blockers Inherited From R017

| Blocker | Impact On Deletion |
|---|---|
| Integration checks `s01`, `s02`, `s03`, and `s06` fail with timeouts | Cannot prove replacement behavior or route/app lifecycle parity |
| LCOV is 66.53% versus 80% target | Deletion risk is not covered by target-level tests |
| Critical UI widget coverage slice missing | Cannot prove high-risk UI surfaces after removing compatibility layers |
| `installation_id` delete/reset primitive missing | Sensitive lifecycle hard gate cannot be enabled |
| Performance benchmarks missing | Cannot prove deletion/migration does not regress startup, practice, growth, or mentor paths |
| Final human gate missing | Any deletion is explicitly blocked by Phase 4 plan |

## Recommended Deletion Readiness Sequence

1. Fix or formally except the integration blockers from R017.
2. Resolve R003 generated-code canary before touching generated output locations.
3. Add missing feature contracts for cross-feature edges, starting with the 30 forbidden candidates.
4. Complete the sensitive lifecycle gap for installation ID deletion/reset.
5. Establish performance benchmarks for startup, practice, growth, and mentor paths.
6. Choose and verify a single app composition/router owner.
7. Request explicit human approval for one narrowly scoped deletion task at a time.

## Non-Goals Confirmed

- No legacy file was deleted, moved, renamed, or archived.
- No generated file was edited or regenerated.
- No mobile source or test file was modified.
- No report-only scanner was hardened.
- No production readiness or deletion approval was claimed.

## Standard Git Commit Message

```text
refactor(mobile): audit legacy deletion candidates
```