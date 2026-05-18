# Need Confirmation: R1 Generated Code Policy

ID: HDR-R1-005  
Level: Red  
Stage: R1  
Created: 2026-05-18  
Status: confirmed

## Current Task

Prepare R2 engineering governance and lint policy.

## Problem Description

Factory v1.0.0 says generated code must live under `lib/generated/`. This Flutter project currently uses Dart `part`-based generated files co-located with source files, including Freezed and Isar outputs. Strict movement may require build configuration changes and can break generation if done carelessly.

## Decision Level

Red: engineering architecture and build-system decision.

## Existing Information

- R1 audit found generated files under feature directories.
- `analysis_options.yaml` excludes `*.g.dart` but not all generated surfaces.
- Factory standard prefers `lib/generated/` isolation.

## Options

1. Strictly migrate generated outputs into `lib/generated/` through build configuration and import/part updates.
2. Record a project-specific Dart tooling exception for `part`-based generated files, and compensate with analyzer exclusions and report-only governance scans.

## Recommendation

Choose option 2 for the initial rescue. It avoids build_runner churn during R2 and still lets us enforce governance around generated code. Revisit strict migration only after CI and tests are stable.

## Risk Assessment

| Option | Risk |
|---|---|
| Strict generated migration | High import/part churn; possible build_runner breakage |
| Documented exception | Deviates from literal Factory standard; requires explicit artifact and scan compensation |

## Required Confirmation

Confirmed on 2026-05-18: strict generated-code isolation is required. R2/R3 must migrate generated outputs to `lib/generated/`; the previously recommended Dart `part` exception is not approved.