# Stage R1 Performance Issues

Version: Flutter AI Software Factory v1.0.0  
Stage: R1 - Performance Audit  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed, benchmarks required before R3 high-risk refactors

Performance score: 4 / 10.

## Summary

This score is a static R1 audit score, not a measured P95 benchmark. The current risk profile is dominated by cold-start work, provider rebuild scope, Isar full scans, reaction write/read amplification, widget monoliths, and lack of performance tests.

## Findings

### PERF-001: Production startup path needs a valid baseline before optimization

Evidence: The audit flagged startup repository factory behavior and boot dependency construction as areas that must be verified before measuring cold start.

Risk: Performance data is invalid if production startup cannot be exercised through the same dependency graph as tests.

R2 action: add startup characterization before refactoring boot code.

### PERF-002: Cold start does too much work before first useful UI

Evidence:

- Boot state loading occurs before `runApp` finishes startup composition.
- Seed content and audio asset validation paths can grow linearly with content size.

Risk: First frame and shell-ready latency will degrade as content grows.

R3 candidate: load only a minimal manifest at startup; move full asset validation to tests or background warmup.

### PERF-003: Feature gates and continuity snapshots can delay shell readiness

Evidence: Launch state resolution can include local state, feature gates, continuity, and activity snapshots.

Risk: App launch time becomes tied to local event history and Isar scan latency.

R3 candidate: enter shell with cached/empty state and refresh continuity in background.

### PERF-004: Rebuild storm risk is high

Evidence:

- App root mixes Provider and Riverpod.
- Home/growth pages watch broad notifier state.
- Static scan found 67 Riverpod references and 41 ChangeNotifier/Provider references.

Risk: Small state changes can rebuild entire pages and large card trees.

R3 candidate: use `select`/small Consumer widgets after state ownership is decided.

### PERF-005: Isar access patterns include full reads and Dart-side sorting/aggregation

Evidence: Practice and mentor local data paths perform list-all/sort/project operations.

Risk: Historical event growth leads to O(n) startup, home refresh, growth refresh, and mentor open latency.

R3 candidate: indexed queries, limit/sort at persistence layer, cached projections, and event-count benchmarks.

### PERF-006: Reaction write path causes read amplification

Evidence: Practice session reaction flow writes an event and then reloads derived state.

Risk: Tap-to-next latency and completion-to-home latency can spike on slower devices.

R3 candidate: update in-memory session state immediately and refresh derived state in background.

### PERF-007: No performance benchmark gate exists

Evidence: Audit found no dedicated performance/timeline/frame benchmark tests.

Risk: R3 changes cannot prove performance preservation or improvement.

R2 action: create benchmark plan before performance-sensitive refactors.

## Required Benchmark Scenarios

1. Cold start: clean install and warm start, 0/100/1k/10k interaction events.
2. Logged-in startup: session present, offline/online, pending uploads.
3. Practice reaction: tap-to-next and final reaction-to-home recent result.
4. Home refresh: continuity plus garden refresh latency and rebuild count.
5. Growth page: first enter and refresh under different diary/milestone sizes.
6. Mentor panel: open-to-ready, submit chat, append fact, TTS interaction.
7. Shimmer/celebration animation: frame jank and repaint scope.

## R3 Low-Risk Performance Candidates

- Move asset validation out of cold start.
- Defer continuity refresh behind shell render.
- Split large pages into smaller consumer cards.
- Add Isar query limits and sort indexes.
- Add reaction optimistic/in-memory update path.
- Add `RepaintBoundary` around animation-heavy surfaces.

Do not implement these until corresponding behavior/performance baselines exist.