# REFACTOR-037 R4 Performance Baseline Harness

---
id: REFACTOR-037
title: R4 performance baseline harness
status: done
priority: high
phase: 4
assignee: AI
created: 2026-05-20
estimated: 0.5 day
---

## Goal

Reduce the R4 performance blocker by adding a repeatable local benchmark harness and capturing an initial baseline for the core startup, practice, home, growth, mentor-panel, and repository projection paths.

## Target Locations

- `mobile/integration_test/r4_performance_benchmark_test.dart`
- `mobile/integration_test/support/full_chain_test_harness.dart`
- `ai/context/refactor/verification-reports/performance-verification-report.md`
- R4 task index, timeline, and readiness reports

## Approach

1. Extend the existing full-chain integration harness with benchmark-only seeding and repository projection measurement helpers.
2. Add an R4 integration benchmark test that records local Windows debug baseline timings for 0 and 100 practice events by default.
3. Include a full-profile command that can expand the event sizes to 0, 100, 1000, and 10000 events when target hardware time is available.
4. Run the benchmark harness and record the printed measurement summary.
5. Update R4 performance and readiness reports truthfully: local baseline exists, but production performance readiness still needs full profile, target replay, and comparison policy.

## Allowed Changes

- Add or extend integration-test harness code.
- Add benchmark-only test code under `mobile/integration_test/`.
- Update R4 verification reports and task tracking docs.

## Forbidden Changes

- Do not change production runtime behavior, routes, API payloads, persisted schema, or user-visible requirements.
- Do not convert the benchmark into a hard CI gate without separate approval.
- Do not claim release performance approval from a local debug baseline alone.
- Do not wire destructive local-data lifecycle flows.

## Acceptance Criteria

- [x] R4 benchmark harness exists and is repeatable.
- [x] Local benchmark profile runs successfully.
- [x] Benchmark output includes startup, repository projection, practice, home, growth, and mentor-panel measurements.
- [x] Reports distinguish local baseline evidence from target-platform production readiness.

## Verification Evidence

| Command | Exit | Result |
|---|---:|---|
| `flutter test integration_test/r4_performance_benchmark_test.dart` from `mobile/` | 0 | Pass; default 0/100 event local benchmark profile completed |

## Baseline Snapshot

| Measurement | Local Windows Debug Baseline |
|---|---:|
| `cold_start_shell_0_events_ms` | 4099 ms |
| `cold_start_shell_100_events_ms` | 1450 ms |
| `repo_0_catalog_ms` | 203 ms |
| `repo_100_catalog_ms` | 21 ms |
| `repo_0_continuity_ms` | 33 ms |
| `repo_100_continuity_ms` | 20 ms |
| `repo_0_home_summary_ms` | 44 ms |
| `repo_100_home_summary_ms` | 14 ms |
| `practice_open_ms` | 909 ms |
| `practice_first_tap_to_next_ms` | 459 ms |
| `practice_final_tap_to_home_ms` | 2227 ms |
| `home_recent_scroll_0_events_ms` | 993 ms |
| `home_recent_scroll_100_events_ms` | 383 ms |
| `growth_first_enter_ms` | 1017 ms |
| `mentor_panel_open_ms` | 437 ms |

## Performance Decision

The R4 performance work now has a runnable local benchmark harness and initial baseline evidence. Production performance readiness is still not approved because full 0/100/1000/10000 profile replay, target-platform or CI execution, release-mode comparison thresholds, logged-in startup, mentor submit/fact/TTS, animation jank, and rebuild-count evidence remain open.