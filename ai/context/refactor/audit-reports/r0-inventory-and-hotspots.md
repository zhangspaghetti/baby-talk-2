# R0 Inventory And Hotspots

Version: Flutter AI Software Factory v1.0.0  
Stage: R0  
Created: 2026-05-16  
Status: draft

## Inventory

| Dimension | Current State |
|---|---|
| Source root | `mobile/lib` |
| Top-level source folders | `app`, `core`, `features`, `l10n` |
| Feature folders | `account`, `household`, `mentor`, `onboarding`, `practice`, `share`, `shell`, `sync` |
| Tracked Dart files under source | 127 |
| State stack | Riverpod 2.6.1 with hooks and annotations |
| Router | go_router 14.8.1 plus older app router surface |
| Local storage | Isar 3.1.0+1 |
| Network | Dio 5.7.0, http 1.2.2 |
| i18n | `app_zh.arb`, generated `app_localizations.dart`, generated zh implementation |
| Design system | `BabyTalkColors`, `AppTheme`, `AppLayoutConstants` |
| Tests | Unit/widget/integration tests exist, including smoke tests for app boot, i18n, a11y, dark mode |

## Hotspot Register

| ID | File / Area | Problem Pattern | R1 Audit Requirement |
|---|---|---|---|
| HOT-R0-001 | `mobile/lib/app/app.dart` | App-level monolith and mixed composition concerns | Map responsibilities, extract safe seams, identify regression tests before any split |
| HOT-R0-002 | `mobile/lib/app/providers/repository_providers.dart` | Central DI and repository/notifier wiring | Build dependency graph and lifecycle map |
| HOT-R0-003 | `mobile/lib/features/practice/data/repositories/practice_repository.dart` | Large repository surface with multiple summaries and behavior paths | Characterization tests before repository slicing |
| HOT-R0-004 | `mobile/lib/app/router/app_go_router.dart` and `mobile/lib/app/router/app_router.dart` | Dual routing surfaces | Decide canonical router after route behavior inventory |
| HOT-R0-005 | `mobile/lib/features/*/presentation/*view_model.dart` and `*notifier.dart` | Dual truth source risk | Inventory every ViewModel/Notifier pair and define migration rule |
| HOT-R0-006 | `mobile/lib/features/**` | Potential direct cross-feature imports | Generate import graph and define allowed contract layer |
| HOT-R0-007 | `mobile/lib/app/widgets/*` and feature presentation widgets | Literal spacing, size, radius, and copy | Token adoption map before UI cleanup |
| HOT-R0-008 | `mobile/lib/l10n/*` plus UI screens/widgets | Existing i18n surface but incomplete string migration | Hardcoded user-visible string census |
| HOT-R0-009 | User interaction widgets and screens | Semantics coverage inconsistent | Screen-reader and touch-target audit |
| HOT-R0-010 | `mobile/analysis_options.yaml` | Minimal analyzer policy, no legacy-specific governance yet | Define phase-1 lint gates without breaking current CI |

## Preservation Rules

- Preserve current feature names and user flows until R2 approved tasks say otherwise.
- Preserve current repository public behavior and data formats.
- Preserve route paths and navigation behavior.
- Preserve generated localization behavior.
- Preserve existing tests and add characterization tests before any extraction.
