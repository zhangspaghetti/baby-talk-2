# Stage R1 Full Code Audit Report

Version: Flutter AI Software Factory v1.0.0  
Stage: R1 - Full Audit  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed, pending R2 decisions

## Scope

Read-only audit of:

- `mobile/lib`
- `mobile/test`
- `mobile/integration_test`
- Existing R0 artifacts under `ai/context/refactor` and `ai/context`

No Flutter runtime source code was modified during this audit.

## Executive Summary

The mobile app is not a disposable demo, but it is a heavily corroded legacy surface that needs governance before implementation work. It already has feature folders, Riverpod dependencies, tests, generated i18n, theme files, and reusable widgets. The central problem is that these foundations are not enforced by architecture, lint, tests, or clear ownership boundaries.

Overall R1 quality score: 4.8 / 10.

| Dimension | Score | Summary |
|---|---:|---|
| Architecture | 4.0 | Feature boundaries, repository abstraction, app composition, router, and async state are not yet governable |
| Code quality | 5.5 | Good test assets and error handling patterns exist, but large files and mixed state/data access dominate |
| Design system | 6.0 | Color/theme foundation exists; spacing, radius, components, i18n, and a11y are incomplete |
| Security/privacy | 4.0 | No real hardcoded secrets found, but consent, auth header, local sensitive data, and URL policy need R2 decisions |
| Performance | 4.0 | Startup work, provider rebuild scope, Isar scans, and missing benchmarks are high-risk |
| Test/regression | 6.5 | Existing tests are useful; coverage and characterization around hotspots are insufficient |

## Static Baseline

Collected with PowerShell-native read-only scanning on 2026-05-18.

| Metric | Count |
|---|---:|
| All Dart files under `mobile/lib` | 128 |
| Handwritten Dart files under `mobile/lib` | 115 |
| Dart test files under `mobile/test` and `mobile/integration_test` | 40 |
| `AsyncValue` references | 0 |
| `ChangeNotifier` / old Provider references | 41 |
| Riverpod references | 67 |
| Direct data/infra import candidates | 108 |
| Cross-feature import candidates | 245 |
| UI literal number candidates | 627 |
| `Text(` widget candidates | 375 |
| Sensitive keyword references | 452 |

## Largest Handwritten Source Files

Generated localization files are excluded from this risk list.

| File | Lines | Risk |
|---|---:|---|
| `mobile/lib/features/practice/data/repositories/practice_repository.dart` | 1169 | Repository god object; event, summary, sync, and projection behavior mixed |
| `mobile/lib/features/mentor/presentation/mentor_notifier.dart` | 931 | Large state machine with chat, facts, suggestions, and network paths |
| `mobile/lib/features/household/presentation/widgets/household_shared_context_card.dart` | 926 | Widget monolith and presentation/data coupling |
| `mobile/lib/features/account/data/repositories/account_repository.dart` | 905 | Auth/session/storage/network behavior concentrated |
| `mobile/lib/app/app.dart` | 791 | App composition, DI, router, boot state, localization, and shell gate mixed |
| `mobile/lib/app/theme/app_theme.dart` | 742 | Theme foundation exists but may need token slicing |
| `mobile/lib/features/account/presentation/screens/account_entry_screen.dart` | 729 | Account UI flow and state rendering concentrated |
| `mobile/lib/features/mentor/data/repositories/mentor_repository.dart` | 717 | Mentor data orchestration and local/remote concerns mixed |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart` | 694 | Onboarding UI complexity and hardcoded copy risk |
| `mobile/lib/features/practice/presentation/screens/home_screen.dart` | 630 | Large home composition and broad provider watch surface |

## Critical Findings

### R1-CODE-001: Repository and usecase boundaries are not established

Evidence:

- `domain/repositories` and `domain/usecases` are effectively absent as stable abstraction layers.
- Presentation code imports concrete data repositories and local stores, including `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`, `mobile/lib/features/household/presentation/widgets/household_shared_context_card.dart`, and `mobile/lib/features/practice/presentation/screens/home_screen.dart`.

Risk: UI depends on storage/API implementation shape. Repository changes will ripple into screens and notifiers, making behavior-preserving refactor risky.

R2 requirement: define minimal domain repository interfaces and usecase seams before moving implementation code.

### R1-CODE-002: Feature boundaries are systemically violated

Evidence:

- Cross-feature import candidates: 245.
- Known high-risk flows include `shell -> practice`, `mentor -> account`, `share -> practice`, and `household -> account/practice`.

Risk: Feature modules cannot be independently tested or migrated. A change in one feature can silently affect another feature's UI or state.

R2 requirement: publish an allowed feature dependency matrix and introduce contract models/usecases for cross-feature communication.

### R1-CODE-003: App composition and state management have multiple truth surfaces

Evidence:

- `mobile/lib/app/app.dart` uses old Provider `MultiProvider` and nested Riverpod `ProviderScope`.
- `mobile/lib/app/providers/repository_providers.dart` defines Riverpod providers for the same system-level graph.
- Some screens still create local `ChangeNotifierProvider` instances.
- `AsyncValue` references: 0.

Risk: Lifecycle ownership, dispose timing, loading/error state, and repository overrides are hard to reason about.

R2 requirement: select canonical app composition and migration target. Recommended target: Riverpod + GoRouter, with old Provider retained only as a temporary compatibility layer.

### R1-CODE-004: Router ownership is ambiguous

Evidence:

- `mobile/lib/app/router/app_router.dart` exists as a deprecated older router surface.
- `mobile/lib/app/router/app_go_router.dart` exists as a GoRouter provider surface.
- `mobile/lib/app/app.dart` also constructs routing behavior.

Risk: Route paths, redirect behavior, extra arguments, onboarding, and reentry can drift across surfaces.

R2 requirement: inventory all route contracts and choose one canonical router before implementation.

### R1-CODE-005: Generated code policy conflicts with Factory standard

Evidence:

- Freezed and Isar generated files are co-located under feature directories.
- `mobile/analysis_options.yaml` excludes `*.g.dart` but not `*.freezed.dart`.
- Factory v1.0.0 says generated code must live under `lib/generated/`.

Risk: Strict migration may break Dart `part` generation patterns; ignoring it may keep lint and audit results noisy.

R2 requirement: human decision required for strict generated-output migration versus documented Dart tooling exception.

## High Findings

### R1-CODE-006: Large files exceed Factory thresholds

Multiple files exceed the configured `max_source_lines_of_code: 200` and page threshold. The worst hotspots are listed above.

R3 rule: no hotspot should be split until characterization tests exist for its current behavior.

### R1-CODE-007: Hardcoded UI strings and design literals remain widespread

Evidence:

- UI literal number candidates: 627.
- `Text(` widget candidates: 375.
- Existing ARB keys are not consistently reused.

Risk: i18n, visual rhythm, and accessibility labels will keep drifting unless converted into machine-checkable rules.

R2 requirement: token and i18n cleanup must be defined as behavior-preserving. Product copy rewrites are separate red/yellow decisions.

### R1-CODE-008: Security/privacy gates are not yet product-safe

Evidence is detailed in `security-issues.md`.

R2 requirement: resolve mentor chat consent, JWT vs Cookie auth source, sensitive local data storage, and installation ID policy before touching core flows.

## R2 Priority Recommendations

1. Establish architecture fitness gates in report-only mode: import boundaries, generated exclusions, file size thresholds, and hardcoded UI scans.
2. Confirm canonical app composition: Riverpod + GoRouter target, old Provider compatibility strategy, router ownership.
3. Define repository/usecase seams for `account`, `practice`, and `mentor` before implementation.
4. Add characterization tests for `app.dart`, repository providers, practice repository, account repository, and mentor chat.
5. Resolve red security/privacy decisions before any R3 core-flow refactor.

## Stage R1 Exit Status

R1 audit is complete. R2 planning may start after the red decisions in `ai/context/daily-decision-summary.md` are confirmed.