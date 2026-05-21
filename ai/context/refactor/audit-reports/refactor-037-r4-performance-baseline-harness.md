# REFACTOR-037 R4 Performance Baseline Harness Report

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Task: REFACTOR-037  
Created: 2026-05-20  
Status: complete; local R4 performance baseline harness added

## Summary

REFACTOR-037 adds a repeatable integration benchmark harness for the R4 performance gate. It captures a local Windows debug baseline for startup, repository projection, home continuity surface reachability, practice interaction latency, growth first enter, and mentor-panel open latency.

No production code was changed. The benchmark is evidence for a local baseline only; it does not approve production performance readiness by itself.

## Changes

| Area | Change |
|---|---|
| Full-chain integration harness | Added benchmark-only event seeding and repository projection timing helpers |
| R4 performance benchmark | Added `r4_performance_benchmark_test.dart` with default 0/100 event profile and full-profile command metadata |
| R4 reports | Updated performance/readiness/engineering reports with measured local baseline and remaining gates |

## Verification

| Command | Exit | Result |
|---|---:|---|
| `flutter test integration_test/r4_performance_benchmark_test.dart` from `mobile/` | 0 | Pass; local 0/100 event benchmark profile completed |

## Measured Baseline

| Measurement | Value |
|---|---:|
| `seed_0_events_ms` | 1 ms |
| `repo_0_catalog_ms` | 203 ms |
| `repo_0_catalog_total_events` | 0 |
| `repo_0_continuity_ms` | 33 ms |
| `repo_0_home_summary_ms` | 44 ms |
| `cold_start_shell_0_events_ms` | 4099 ms |
| `home_recent_scroll_0_events_ms` | 993 ms |
| `practice_open_ms` | 909 ms |
| `practice_first_tap_to_next_ms` | 459 ms |
| `practice_final_tap_to_home_ms` | 2227 ms |
| `practice_flow_event_count` | 3 |
| `growth_first_enter_ms` | 1017 ms |
| `mentor_panel_open_ms` | 437 ms |
| `seed_100_events_ms` | 2556 ms |
| `repo_100_catalog_ms` | 21 ms |
| `repo_100_catalog_total_events` | 100 |
| `repo_100_continuity_ms` | 20 ms |
| `repo_100_home_summary_ms` | 14 ms |
| `cold_start_shell_100_events_ms` | 1450 ms |
| `home_recent_scroll_100_events_ms` | 383 ms |

## Remaining Performance Gaps

| Gap | Required Evidence |
|---|---|
| Full data-size profile | Run `--dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000` on approved target hardware or CI |
| Target-platform replay | Capture benchmark output on the release target environment, preferably release/profile mode |
| Regression policy | Define approved thresholds and compare future runs against the captured baseline |
| Logged-in startup | Add offline/online logged-in startup profile with pending uploads |
| Mentor deeper flow | Measure submit chat, append fact, and TTS interaction |
| Animation/rebuild evidence | Add frame jank, repaint scope, and rebuild-count measurements |

## Risk Decision

The R4 performance gate is no longer blocked by a missing harness, but production performance readiness remains open. The local debug baseline is suitable for trend comparison and future hardening, not for final release approval.