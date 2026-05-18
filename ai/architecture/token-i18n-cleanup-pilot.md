# Token and I18n Cleanup Pilot

Version: Flutter AI Software Factory v1.0.0
Stage: R3 / Phase 3
Task: REFACTOR-014
Created: 2026-05-18
Status: completed

## Decision

REFACTOR-014 is a behavior-preserving design-token cleanup pilot. It may move existing numeric values into named tokens and update local call sites to use those tokens, but it must not change visual values, product copy, interaction behavior, navigation, or accessibility semantics.

The i18n cleanup path remains planned but untouched in this task because exact-copy ARB replacement must be selected case by case. No hardcoded user-visible text is rewritten in this pilot.

## Pilot Surface

| Surface | Cleanup | Output Contract |
|---|---|---|
| `AppLayoutConstants` | Add spacing, radius, touch target, icon, progress, input, banner, and empty-state tokens | Existing numeric values preserved |
| `AppTheme.build()` and `AppTheme.buildDark()` | Replace repeated radius, padding, and size literals with `AppLayoutConstants` | Light/dark theme metrics remain unchanged |
| `AppStepProgress` | Replace progress duration, margin, height, and radius literals with tokens | Progress bar animation and geometry unchanged |
| `AppBanner` | Replace padding, spacing, and icon sizes with tokens | Banner layout, text, semantics, and actions unchanged |
| `AppEmptyState` | Replace padding, icon size, container size, and vertical gaps with tokens | Empty-state layout and copy unchanged |

## Guardrails

- Preserve all current token values exactly.
- Do not normalize 16 vs 24 radius decisions beyond naming existing values.
- Do not collapse spacing values into a new scale if it changes layout density.
- Do not add, remove, or rewrite ARB keys in this task.
- Do not alter generated localization files.
- Do not change widget keys, semantics labels, callbacks, or navigation.

## Exit Signal

The pilot is complete: theme smoke tests assert the new tokens preserve existing metric values, and the full mobile gates are green.