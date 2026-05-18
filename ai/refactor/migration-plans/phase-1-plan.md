# Phase 1 Plan - Foundation And Gates

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 Planning  
Created: 2026-05-18  
Status: draft

## Goal

Make the current system observable and governable before changing behavior. Phase 1 focuses on decision sync, baselines, report-only scans, generated-code canary planning, and characterization tests around app boot, routing, providers, auth, and consent.

## Duration

Estimated 1 week.

## Workstreams

| Workstream | Output | Notes |
|---|---|---|
| Decision sync | Updated HDR/AR/daily decision artifacts | Red decisions confirmed; yellow design/lint questions remain scoped |
| Verification baseline | Analyze/test/coverage record | Baseline first; do not fail old debt immediately |
| Report-only gates | Import, generated, file-size, UI literal, hardcoded text scans | Report old violations; fail new violations later |
| Generated-code canary | Build config design and one-model PoC plan | Strict `lib/generated/` target is confirmed but high risk |
| Characterization tests | Boot/router/provider/auth/mentor consent tests | Required before Phase 2 source migration |

## Entry Criteria

- R0 and R1 reports exist.
- Red R1 decisions are confirmed.
- No runtime Flutter source changes are bundled with planning changes.

## Exit Criteria

- `flutter analyze`, `flutter test`, and `flutter test --coverage` baselines are captured or explicitly blocked with environment notes.
- Report-only scan outputs are documented.
- Generated-code strict migration has a canary and rollback plan.
- App boot/router/provider/auth/consent characterization tests are ready or queued with clear allowed files.
- CI remains green for all changed code.

## Forbidden Changes

- No production behavior changes.
- No route, payload, persistence, copy, or visual value changes.
- No full-source move to `lib/legacy/`.
- No generated-code mass migration until the canary passes.