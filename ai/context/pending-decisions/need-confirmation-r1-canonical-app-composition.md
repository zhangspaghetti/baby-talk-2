# Need Confirmation: R1 Canonical App Composition

ID: HDR-R1-001  
Level: Red  
Stage: R1  
Created: 2026-05-18  
Status: confirmed

## Current Task

Prepare Stage R2 refactor planning after the R1 audit.

## Problem Description

The app currently has mixed app composition surfaces: old Provider, Riverpod, local screen providers, older router surface, GoRouter provider surface, and router construction inside `app.dart`. R3 cannot safely refactor app boot, routing, or state until the canonical target is confirmed.

## Decision Level

Red: architecture and core refactor strategy decision.

## Existing Information

- R1 architecture audit found Provider + Riverpod dual graphs.
- R1 audit found 0 `AsyncValue` references.
- R1 audit found multiple router ownership surfaces.
- Factory v1.0.0 target architecture favors Riverpod and GoRouter.

## Options

1. Confirm Riverpod + GoRouter as the canonical target; keep old Provider/router only as temporary compatibility layers during incremental migration.
2. Preserve mixed Provider/Riverpod/router surfaces and refactor features independently.

## Recommendation

Choose option 1. It gives R2 a single target shape while preserving the incremental rule by not removing compatibility layers until tests exist.

## Risk Assessment

| Option | Risk |
|---|---|
| Riverpod + GoRouter target | Requires careful compatibility bridge and route/provider characterization tests |
| Preserve mixed surfaces | Keeps lifecycle and route ambiguity; R3 tasks remain high-risk |

## Required Confirmation

Confirmed on 2026-05-18: Riverpod + GoRouter is the canonical app composition target for R2/R3. Old Provider/router surfaces may remain only as temporary compatibility layers during incremental migration.