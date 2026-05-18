# Need Confirmation: R1 Audit Scope And Priority

ID: HDR-R0-002  
Level: Red  
Stage: R0  
Created: 2026-05-16  
Status: confirmed

## Current Task

Prepare the next stage after R0.

## Problem Description

The user requested all refactor stages in order, but implementation cannot safely start until R1 full audit and R2 planning are complete. The audit scope and priority order affect later work sequencing.

## Decision Level

Red: refactor scope and priority decision.

## Existing Information

- Initial hotspots include app shell, central DI, practice repository, routing duality, state duality, feature boundaries, hardcoded UI, design tokens, i18n, and accessibility.
- Existing tests are helpful but not complete regression coverage.

## Options

1. Audit all `mobile/` code and tests before any implementation.
2. Audit only the highest-risk files and start implementation sooner.

## Recommendation

Use option 1. The app has multiple interconnected debt categories; read-only full audit is safer than partial implementation.

## Risk Assessment

| Option | Risk |
|---|---|
| Full audit first | Slower start, but lower chance of breaking behavior |
| Partial audit | Faster start, but higher chance of missing hidden coupling |

## Required Confirmation

Confirmed: R1 should audit the whole mobile app before implementation, and R2 should prioritize architecture safety first.
