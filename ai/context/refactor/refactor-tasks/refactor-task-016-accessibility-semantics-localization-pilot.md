# Refactor Task: REFACTOR-016 Accessibility Semantics And Localization Pilot

Version: Flutter AI Software Factory v1.0.0
Stage: R3 / Phase 3
Created: 2026-05-19
Status: completed

## Objective

Run a behavior-preserving accessibility and localization pilot by moving selected Discover semantics labels and visible progress strings behind localization keys while keeping the rendered Chinese output unchanged.

## Scope

- Add R016 pilot documentation under `ai/architecture`.
- Add exact-value ARB keys for Discover activity and space activity semantics labels.
- Reuse existing Discover progress/next phrase and reaction localization keys in selected Discover widgets.
- Regenerate Flutter localization outputs from ARB.
- Extend Discover widget coverage to verify semantics labels and localized text contracts.

## Forbidden Changes

- Do not rewrite product copy.
- Do not change route paths, widget keys, callbacks, state behavior, or navigation behavior.
- Do not alter spacing, colors, card geometry, or component hierarchy outside text/semantics localization.
- Do not manually edit generated localization files.
- Do not broaden this task to all hardcoded strings in the app.

## Acceptance Criteria

- [x] R016 documentation records scope and guardrails.
- [x] Discover activity and space activity semantics labels resolve through localization.
- [x] Selected Discover visible strings preserve exact current Chinese output via localization.
- [x] Generated localization files are produced by `flutter gen-l10n`.
- [x] Focused Discover widget tests verify semantics/text contracts.
- [x] `flutter analyze`, focused tests, full tests, and coverage remain green.

## Regression Test Requirements

- [x] Discover activity view exposes the same activity semantics label through `AppLocalizations`.
- [x] Discover space view exposes the same space activity semantics label through `AppLocalizations`.
- [x] Full mobile test suite remains green.

## Implementation Notes

- `DiscoverActivityCard` now resolves its card semantics label through `discoverActivityCardSemantics`, visible progress through `discoverProgress`, next phrase through `discoverNextPhrase`, and reaction labels through existing reaction localization keys.
- `DiscoverSpaceSection` now resolves space progress through `discoverSpaceProgress`.
- `DiscoverSpaceGridItem` now resolves item semantics through `discoverSpaceActivitySemantics` and phrase progress through `discoverPhraseProgress`.
- New ARB keys preserve exact existing output values: `活动: {title}` and `空间活动: {title}`.
- Generated localization files were produced by `flutter gen-l10n` after ARB updates.

## Verification

| Command | Result |
|---|---|
| `flutter gen-l10n` | Passed; generated localization APIs updated from ARB |
| `flutter test test/features/shell/discover_screen_test.dart` | Passed; 6 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 220 tests |
| `flutter test --coverage` | Passed; 220 tests |
| LCOV summary | `LH=7172 LF=10780 Coverage=66.53%` |

## Residual Notes

- The existing nonfatal onboarding tap warning around `onboarding-name-continue` still appears during full test and coverage runs.
- Broader app-wide hardcoded string and accessibility cleanup remains out of scope for this pilot.

## Authorizations

- Human selected `进入 REFACTOR-016` after REFACTOR-015 completion on 2026-05-19.
