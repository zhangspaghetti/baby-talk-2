# REFACTOR-015 Shared Component Extraction Pilot

Version: Flutter AI Software Factory v1.0.0
Stage: R3 / Phase 3
Task: REFACTOR-015
Created: 2026-05-18
Status: approved

## Objective

Extract one behavior-preserving shared presentation component from duplicated feature-local UI shells.

## Pilot Surface

- Add `AppSurfaceCard` under `mobile/lib/app/widgets`.
- Migrate only feature widgets that already use the same surface-card shell:
  - `HomeGrowthSummaryCard`
  - `ShareCalloutCard`
  - `DiscoverActivityCard`

## Guardrails

- Preserve existing padding, radius, color, border, shadow, width, keys, copy, semantics, callbacks, routes, and state behavior.
- Do not move feature-specific content, state resolution, or localization into the shared component.
- Do not normalize nearby cards with different geometry in this pilot.
- Do not change generated localization files.

## Completion Contract

The pilot is complete when a focused widget test proves the shared shell preserves the previous visual contract and the full mobile gates remain green.