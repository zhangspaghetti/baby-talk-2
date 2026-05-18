# Phase 3 Plan - UI, Design System, i18n, And Accessibility

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 Planning  
Created: 2026-05-18  
Status: draft

## Goal

Remove UI/demo corrosion without changing product behavior. Phase 3 converts repeated literals and widgets into governed tokens and components, migrates hardcoded strings to localization, and improves accessibility semantics while preserving rendered output.

## Duration

Estimated 1-2 weeks.

## Workstreams

| Workstream | Output | Boundary |
|---|---|---|
| Token normalization | Spacing, radius, icon, touch-target, duration tokens | Preserve current visual values first |
| Shared components | App surface/card/banner/pill/empty-state pilots | Preserve callbacks, keys, layout, and copy |
| i18n cleanup | Existing strings moved to ARB keys | No copy rewrite without approval |
| Accessibility | Semantics labels and tests for critical interactions | Labels must align with localization strategy |
| Design scans | Hardcoded color/spacing/text reports | Convert report-only gates to hard gates gradually |

## Entry Criteria

- Phase 2 app/router/provider/auth seams are stable enough for widget tests.
- Yellow design decisions are resolved or explicitly scoped to preserve existing values.

## Exit Criteria

- New UI code uses tokens and localized strings.
- Selected shared components have widget and semantics tests.
- Existing copy and visual rhythm are unchanged unless separate decisions approve changes.

## Forbidden Changes

- Product copy rewrites.
- Palette redesign.
- Radius/spacing density redesign.
- Loading, empty, error, or navigation behavior changes.