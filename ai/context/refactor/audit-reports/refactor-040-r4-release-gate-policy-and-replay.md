# REFACTOR-040 R4 Release Gate Policy And Replay Report

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Task: REFACTOR-040  
Created: 2026-05-20  
Status: complete; local full profile and release-gate policy captured

## Summary

REFACTOR-040 advances the next non-destructive R4 gates. The existing R4 performance harness now has a local full-profile run across 0, 100, 1000, and 10000 events. Mobile release-gate policy is executable through Flutter tests and a CI script. Account upgrade external links are now HTTPS-only and host-allowlisted.

This task does not approve production readiness. Target-platform or release-mode replay, iOS backup runtime proof, destructive product-flow approval, and final release confirmation remain open.

## Changes

| Area | Change |
|---|---|
| Account external links | Tightened `validateAccountUpgradeUrl` to HTTPS-only allowed hosts with `BABY_TALK_ALLOWED_UPGRADE_HOSTS` override |
| R4 hard-gate policy | Added `mobile/test/tool/r4_release_gate_policy_test.dart` |
| CI replay | Added `ci/mobile-r4-release-gates.sh` and wired it into `.github/workflows/ci.yml` |
| Performance evidence | Ran the full local 0/100/1000/10000 event R4 benchmark profile |
| Governance | Added HDR-R4-003 as the destructive product-flow approval decision artifact |

## Verification

| Command | Exit | Result |
|---|---:|---|
| `flutter test integration_test/r4_performance_benchmark_test.dart --dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000` from `mobile/` | 0 | Pass; local Windows debug full profile completed |
| `runTests` for `r4_release_gate_policy_test.dart`, `account_repository_test.dart`, and `account_entry_screen_test.dart` | 0 | Pass; 28 tests |
| `bash ci/mobile-r4-release-gates.sh` from repo root | 0 | Pass; R4 policy gates pass, optional full profile skipped by default |
| `flutter analyze` from `mobile/` | 0 | Pass; no issues found |

## Full Local Performance Profile

| Measurement | Value |
|---|---:|
| `seed_0_events_ms` | 7 ms |
| `repo_0_catalog_ms` | 133 ms |
| `repo_0_catalog_total_events` | 0 |
| `repo_0_continuity_ms` | 32 ms |
| `repo_0_home_summary_ms` | 51 ms |
| `cold_start_shell_0_events_ms` | 4555 ms |
| `home_recent_scroll_0_events_ms` | 957 ms |
| `practice_open_ms` | 849 ms |
| `practice_first_tap_to_next_ms` | 454 ms |
| `practice_final_tap_to_home_ms` | 2091 ms |
| `practice_flow_event_count` | 3 |
| `growth_first_enter_ms` | 970 ms |
| `mentor_panel_open_ms` | 583 ms |
| `seed_100_events_ms` | 2781 ms |
| `repo_100_catalog_ms` | 28 ms |
| `repo_100_catalog_total_events` | 100 |
| `repo_100_continuity_ms` | 28 ms |
| `repo_100_home_summary_ms` | 21 ms |
| `cold_start_shell_100_events_ms` | 1146 ms |
| `home_recent_scroll_100_events_ms` | 570 ms |
| `seed_1000_events_ms` | 27056 ms |
| `repo_1000_catalog_ms` | 40 ms |
| `repo_1000_catalog_total_events` | 1000 |
| `repo_1000_continuity_ms` | 37 ms |
| `repo_1000_home_summary_ms` | 38 ms |
| `cold_start_shell_1000_events_ms` | 1506 ms |
| `home_recent_scroll_1000_events_ms` | 572 ms |
| `seed_10000_events_ms` | 262836 ms |
| `repo_10000_catalog_ms` | 71 ms |
| `repo_10000_catalog_total_events` | 10000 |
| `repo_10000_continuity_ms` | 65 ms |
| `repo_10000_home_summary_ms` | 59 ms |
| `cold_start_shell_10000_events_ms` | 1735 ms |
| `home_recent_scroll_10000_events_ms` | 401 ms |

## Gate Result

| Gate | Result |
|---|---|
| Feature-boundary no-regression budget | Pass; current scan remains 99 total, 69 legacy bridge, 30 forbidden candidate |
| Sensitive lifecycle primitive/doc/source coverage | Pass; 6 sensitive surfaces, 6 covered delete primitives, zero missing source/doc/primitive gaps |
| Destructive product-flow wiring block | Pass; no feature product-flow markers for destructive clearance wiring found |
| URL allowlist | Pass; HTTPS allowed hosts accepted, `http` and unknown hosts rejected |

## Risk Decision

The R4 policy and local full-profile evidence are stronger after this task. Production readiness remains blocked because the full profile is local Windows debug evidence, not approved target release evidence; destructive product-flow wiring still needs HDR-R4-003; iOS backup runtime proof and final human release confirmation remain open.