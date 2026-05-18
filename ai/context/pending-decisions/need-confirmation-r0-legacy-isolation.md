# Need Confirmation: R0 Legacy Isolation Policy

ID: HDR-R0-001  
Level: Red  
Stage: R0  
Created: 2026-05-16  
Status: confirmed

## Current Task

Start Flutter AI Software Factory v1.0.0 legacy rescue from Stage R0.

## Problem Description

The official Stage R0 checklist says all original code should be moved into `lib/legacy/`. This repository already has a running app with `app/core/features/l10n`, 127 tracked Dart source files, existing tests, i18n, theme scaffolding, and many cross-file imports. Moving everything at once would create large import churn and may violate the no-behavior-change and CI-green constraints.

## Decision Level

Red: architecture and refactor-scope decision.

## Existing Information

- `modules/09-workflow-refactor.md` Stage R0 requires `lib/legacy/` isolation.
- `modules/01-principles.md` requires incremental refactor, CI green, and no behavior change.
- Oracle consultation recommends Stage R0 as governance plus evidence only, with physical legacy movement deferred.

## Options

1. Move all current code to `lib/legacy/` immediately.
2. Defer physical movement and classify current app as the logical legacy surface during R0.

## Recommendation

Use option 2. It preserves runtime behavior and CI safety while still satisfying the governance intent of legacy isolation.

## Risk Assessment

| Option | Risk |
|---|---|
| Immediate move | High risk of import churn, broken routes, broken generated paths, and CI failure |
| Deferred move | Requires documenting a deliberate deviation from literal workflow text |

## Required Confirmation

Confirmed: option 2 is approved for this repository.
