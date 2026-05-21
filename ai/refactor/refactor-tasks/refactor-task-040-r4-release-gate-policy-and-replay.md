# REFACTOR-040 R4 Release Gate Policy And Replay

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Created: 2026-05-20  
Status: complete; local release-gate policy and full performance profile captured

## Goal

Reduce the next R4 production-readiness blockers without wiring destructive product flows: capture the existing full R4 performance profile, make release-gate policy executable, and wire the new mobile R4 gates into CI.

## Scope

In scope:

- Run the existing R4 full performance profile with `R4_PERF_EVENT_COUNTS=0,100,1000,10000`.
- Add a Flutter release-gate policy test for current feature-boundary budget, sensitive lifecycle primitive coverage, unapproved destructive product-flow wiring, and account upgrade URL policy.
- Tighten account upgrade external links to HTTPS-only allowed hosts.
- Add a CI script for explicit R4 mobile release gates and wire it into the GitHub CI workflow.
- Record the destructive product-flow approval question as a red HDR artifact.

Out of scope:

- Wiring logout, consent withdrawal, account deletion, onboarding reset, or device erasure to real destructive local data clearance.
- Claiming production readiness.
- Claiming iOS backup runtime proof or release-mode target performance proof.
- Requiring all historical feature-boundary debt to be zero before the next task.

## Regression Requirements

- [x] Account upgrade URL validation rejects `http` and unknown hosts.
- [x] Feature-boundary imports cannot regress beyond the current 99 total / 69 legacy / 30 forbidden budget.
- [x] Sensitive lifecycle scanner remains at zero missing source, documentation, and delete primitive gaps.
- [x] Feature product-flow code contains no unapproved destructive local-data clearance wiring.
- [x] R4 release-gate script passes locally without requiring target performance hardware.
- [x] Full local performance profile passes with 0/100/1000/10000 events.

## Verification Log

| Command | Result |
|---|---|
| `flutter test integration_test/r4_performance_benchmark_test.dart --dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000` from `mobile/` | Passed; 1 test; local Windows debug full profile completed in 6:28 |
| `runTests` for `r4_release_gate_policy_test.dart`, `account_repository_test.dart`, and `account_entry_screen_test.dart` | Passed; 28 tests |
| `bash ci/mobile-r4-release-gates.sh` from repo root | Passed; feature-boundary scan 99/69/30, lifecycle scan 6/6 covered, focused gate tests passed, full profile skipped by default |
| `flutter analyze` from `mobile/` | Passed; no issues found |

## R4 Gate Policy

| Gate | Current Policy |
|---|---|
| Feature boundary | Hard no-regression budget: total <= 99, legacy bridge <= 69, forbidden candidate <= 30 |
| Sensitive lifecycle | Hard zero-gap gate for documented source files, source markers, and delete primitives |
| Destructive product-flow wiring | Hard block on feature-level destructive clearance markers until HDR approval updates the gate |
| Account upgrade URL | HTTPS-only, compile-time allowlisted hosts via `BABY_TALK_ALLOWED_UPGRADE_HOSTS` |
| Full performance profile | Local full profile can be replayed; CI script runs it only when `BABY_TALK_RUN_R4_FULL_PERF=1` |

## Remaining Gaps

- Live CI run evidence after this workflow change is still pending.
- Approved target-platform or release-mode performance replay is still pending.
- iOS backup runtime proof is still pending.
- Destructive lifecycle product-flow wiring remains blocked pending HDR-R4-003.
- Final production readiness and legacy deletion remain blocked pending human approval.

## Standard Git Commit Message

```text
test(mobile): add R4 release gate policy
```