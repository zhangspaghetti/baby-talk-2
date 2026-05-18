# Mobile Feature Boundary Matrix

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 / REFACTOR-011  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: report-only

## Purpose

This matrix records the intended dependency direction between mobile feature modules before any hard enforcement. REFACTOR-011 keeps the scan report-only so legacy edges stay visible while future tasks introduce contracts and remove direct internals imports in smaller behavior-preserving steps.

## Boundary Law

- Feature code may import its own `data`, `domain`, and `presentation` layers.
- Cross-feature production imports are forbidden by default.
- `mobile/lib/app`, `mobile/lib/core`, generated localization, and root composition code may wire features together.
- `shell` is the current legacy composition surface and may temporarily import feature presentation/domain entry points.
- New cross-feature imports should target a documented contract seam, not another feature's concrete `data` or `presentation` internals.
- The current scan is report-only. It tracks candidates but must not fail CI until a later stage explicitly approves enforcement.

## Feature Roles

| Feature | Owns | Intended Public Contract |
|---|---|---|
| account | Login/session, consent, account lifecycle | Account repository/session contract and auth client contract |
| household | Caregiver household context and invite UI | Household summary/invite contract |
| mentor | Local suggestions and network mentor chat | Mentor chat contract gated by account session and consent |
| onboarding | Local onboarding snapshot and stage matching | Profile/onboarding snapshot contract |
| practice | Practice catalog, session, events, restore, continuity, garden growth | Practice entry, summary, lifecycle, and sync contracts |
| share | Share draft and share sheet integration | Shareable progress contract |
| shell | Current tab shell and discovery/garden composition | Temporary composition bridge only |
| sync | Current sync orchestration for local event uploads | Sync contract; practice event upload contract |

## Approved Report-Only Legacy Edges

| Source | Target | Current Reason | Replacement Direction |
|---|---|---|---|
| shell | account, household, mentor, onboarding, practice, share | Shell currently composes app tabs, cards, panels, and feature entry surfaces | Replace direct imports with feature entry contracts after app composition migration |
| mentor | account | Mentor API still reads account session/authenticated client types | Move authenticated client/session read behind `core` or account contract |
| account | practice | Account lifecycle still coordinates practice export/delete behavior | Add practice lifecycle/export contract before moving account internals |
| account | household | Account surface still renders household cards | Add account surface slot or household summary contract |
| account | onboarding | Account surface phase still reads onboarding snapshot | Add profile/onboarding summary contract |
| household | practice | Household cards still deep-link to practice route args | Add practice entry contract |
| share | practice | Share notifier still reads practice progress models | Add shareable practice summary contract |
| sync | practice | Sync repository currently uploads practice interaction events | Add practice sync contract |

## Forbidden Candidate Rule

Any feature-to-feature edge not listed above is a forbidden candidate in report-only mode. Later stages may either remove it, convert it to a contract seam, or explicitly add a temporary exception with a sunset condition.

## Report-Only Scan

Run from the repository root:

```bash
dart tool/verify_refactor_011_feature_boundaries.dart
```

The scan inspects `mobile/lib/features/**/*.dart`, excluding generated `*.g.dart` and `*.freezed.dart` files. It prints:

- total cross-feature import/export directives;
- count of approved legacy bridges;
- count of forbidden candidates;
- count by source-target pair;
- each edge with file, line, directive, target layer, and reason.

The scan exits successfully in REFACTOR-011 even when forbidden candidates exist.