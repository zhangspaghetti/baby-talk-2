# Performance Verification Report

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Task: REFACTOR-017, updated through REFACTOR-041
Created: 2026-05-20
Status: completed, local full benchmark profile captured; production benchmark gate still blocked by target/profile replay

## Summary

R017 did not run dedicated performance benchmarks because no approved benchmark harness or baseline existed. REFACTOR-037 added a repeatable local integration benchmark harness and captured an initial Windows debug baseline for startup, repository projection, practice, home, growth, and mentor-panel open paths. REFACTOR-040 replayed the full local 0/100/1000/10000 event profile. REFACTOR-041 attempted release/profile replay and confirmed current Flutter tooling limitations in this Windows setup. The existing R1 performance audit remains a static score of 4/10 and is now supplemented by measured local evidence.

Performance production readiness is still blocked because the Phase 4 criterion requires target-platform or approved profile/release benchmark evidence showing no regression from an approved baseline. The current measured evidence is local Windows debug evidence, not release approval.

## Available Evidence

| Evidence | Status |
|---|---|
| R1 performance audit | Completed; performance score 4/10 |
| Required benchmark scenarios | Documented in `ai/refactor/audit-reports/performance-issues.md` |
| Analyze/test/coverage execution | Completed, but these are correctness checks, not performance measurements |
| Integration checks | Pass locally after R017A, but they are correctness checks and cannot replace benchmark proof |
| Dedicated benchmark harness | Present after REFACTOR-037; full 0/100/1000/10000 event local profile passes after REFACTOR-040 |
| Release/profile replay attempt | Attempted after REFACTOR-041; Flutter `test --release` and non-web Flutter Driver `--release` are unsupported, and profile drive produced no benchmark output before Windows batch termination |

## REFACTOR-037 Local Benchmark Evidence

| Command | Exit | Result |
|---|---:|---|
| `flutter test integration_test/r4_performance_benchmark_test.dart` from `mobile/` | 0 | Pass; default 0/100 event local benchmark profile completed |

| Measurement | Local Windows Debug Baseline |
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

## REFACTOR-040 Local Full Profile Evidence

| Command | Exit | Result |
|---|---:|---|
| `flutter test integration_test/r4_performance_benchmark_test.dart --dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000` from `mobile/` | 0 | Pass; local Windows debug full profile completed in 6:28 |

| Measurement | Local Windows Debug Full Profile |
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

## REFACTOR-041 Release/Profile Replay Attempts

| Command | Exit | Result |
|---|---:|---|
| `flutter test integration_test/r4_performance_benchmark_test.dart --release --dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000` | 64 | Unsupported by Flutter test; no release measurement captured |
| `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/r4_performance_benchmark_test.dart --release --dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000` | 1 | Unsupported for non-web Flutter Driver; no release measurement captured |
| `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/r4_performance_benchmark_test.dart --profile --dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000` | inconclusive | Built and installed `app-profile.apk`, then Windows batch termination occurred before benchmark output was captured |

These attempts are negative/inconclusive evidence only. They do not satisfy the production performance gate.

## Required Benchmark Scenarios Not Yet Proven

| Scenario | Status |
|---|---|
| Clean and warm cold start with 0/100/1k/10k events | Measured locally in Windows debug; target/profile replay pending |
| Logged-in startup offline/online with pending uploads | Not measured |
| Practice reaction tap-to-next and final reaction-to-home latency | Measured locally in default profile; target replay pending |
| Home continuity and garden refresh latency/rebuild count | Home recent reachability measured locally for 0/100 events; rebuild count not measured |
| Growth page first enter and refresh under data-size variants | First enter measured locally after practice flow; larger data-size refresh/rebuild evidence pending |
| Mentor panel open-to-ready, submit chat, append fact, TTS interaction | Panel open measured locally; submit/fact/TTS pending |
| Animation jank and repaint scope | Not measured |

## Performance Risks Still Open

- Cold start can still be coupled to boot state, local stores, feature gates, and continuity projection.
- Isar full-read and Dart-side projection paths still need benchmarked limits before optimization claims.
- Provider/Riverpod mixed ownership can still produce broad rebuilds until migrated areas have narrower selectors and measurement.
- Passing focused integration flows provide correctness confidence after R017A, but they do not measure latency, frame timing, rebuild scope, or data-size limits.

## Performance Exit Decision

Performance verification is not production-ready. REFACTOR-037 removed the missing-harness blocker, REFACTOR-040 captures the local full profile, and REFACTOR-041 documents failed/inconclusive release/profile replay attempts, but this does not approve release or legacy deletion. Remaining work must replay the profile on approved target hardware/CI or an approved profile/release harness, define comparison thresholds, and add logged-in startup, mentor submit/fact/TTS, frame jank, repaint, and rebuild-count evidence.