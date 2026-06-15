---
phase: 39-vnext-family-english-micro-ritual
plan: "02"
subsystem: testing
tags: [vnext, mobile_v2, semantic-firewall, dart, flutter-test]

requires:
  - phase: 39-vnext-family-english-micro-ritual
    provides: Phase 39 product contract, old-semantic supersession rules, and R058/R059/R060 boundaries
provides:
  - Pure Dart semantic-firewall scanner for mobile_v2 runtime/product paths
  - Root verifier tests covering forbidden imports, banned terms, allowlisted reference material, missing boundary, and surface contracts
  - Mobile package wrapper that delegates to the root verifier tests
  - CLI help and failure/success behavior for the Phase 39 gate
affects: [phase-39, phase-40, phase-41, mobile_v2, semantic-firewall]

tech-stack:
  added: []
  patterns: [pure Dart repository scanner, fail-closed semantic boundary gate, mobile test forwarder]

key-files:
  created:
    - tool/verify_mobile_v2_semantic_firewall.dart
    - mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart
  modified:
    - test/tool/verify_mobile_v2_semantic_firewall_test.dart
    - test/features/vnext/mobile_v2_surface_contract_test.dart

key-decisions:
  - "The semantic firewall fails closed when mobile_v2/lib is missing, so later phases cannot pass without an enforceable vNext runtime boundary."
  - "Old semantic terms are allowed only in explicit reference/quarantine/docs/test-fixture paths outside mobile_v2/lib."
  - "The root verifier stays pure Dart and package-free; Flutter is used only for existing test execution."

patterns-established:
  - "Scanner API exports structured report and violation objects so tests can assert behavior without parsing CLI output."
  - "Surface contract fixtures prove Onboarding, Home, Practice, and Garden old semantics are rejected through the same scanner."

requirements-completed: [R058, R059, R060]

duration: 5h 19m
completed: 2026-06-15
---

# Phase 39 Plan 02: Semantic Firewall Summary

**Pure Dart mobile_v2 semantic firewall with root and mobile-wrapper tests that reject old phrase/activity/completion/streak/Garden product truth.**

## Performance

- **Duration:** 5h 19m, including stalled executor recovery
- **Started:** 2026-06-15T12:57:39+08:00
- **Completed:** 2026-06-15T18:16:18+08:00
- **Tasks:** 2 completed
- **Files modified:** 4

## Accomplishments

- Added `tool/verify_mobile_v2_semantic_firewall.dart`, a pure Dart scanner and CLI that recursively scans `mobile_v2/lib`, rejects forbidden old `mobile/` practice/onboarding/garden imports, rejects banned old runtime terms, and reports allowlisted reference material.
- Added root tests for clean pass, forbidden package imports, forbidden relative imports, banned runtime terms, allowlisted reference paths, missing `mobile_v2/lib`, and CLI option parsing.
- Added targeted vNext surface contract tests proving Onboarding, Home, Practice, and Garden old starter-phrase, next-incomplete-task, phrase-completion, child-response-required, streak, and GardenGrowth semantics fail under `mobile_v2/lib`.
- Added `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` as a mobile-side wrapper that delegates to the root verifier tests.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add failing semantic-firewall tests** - `64f7b43` (test)
2. **Task 1/2 GREEN: Implement semantic-firewall scanner, CLI, and wrapper** - `2151506` (feat)

**Plan metadata:** committed in the plan close-out docs commit.

## Files Created/Modified

- `tool/verify_mobile_v2_semantic_firewall.dart` - Pure Dart scanner, structured report/violation API, renderer, and CLI behavior.
- `test/tool/verify_mobile_v2_semantic_firewall_test.dart` - Root verifier tests for import guard, banned-term scan, allowlist handling, missing-boundary behavior, and CLI parsing.
- `test/features/vnext/mobile_v2_surface_contract_test.dart` - Surface contract tests for old Onboarding, Home, Practice, and Garden semantic rejection.
- `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` - Mobile package test forwarder calling the root verifier tests.

## Decisions Made

- Kept the verifier independent of new dependencies and shell-only grep logic, matching the existing pure Dart verifier style.
- Treated missing `mobile_v2/lib` as a blocking violation, preserving the Phase 39 fail-closed contract until Plan 39-03 creates the boundary anchor.
- Used set-based allowlist assertions in tests so multiple old terms in the same reference file prove quarantine behavior without requiring one reference per term.

## Deviations from Plan

None - plan scope executed as written. The executor stall was an orchestration issue, not a product-scope deviation.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope creep; all plan artifacts stayed within the declared file list.

## Issues Encountered

- The first `gsd-executor` stalled after creating the RED test commit and partial implementation files. Orchestration closed the stalled executor, completed the remaining implementation inline, and preserved the existing RED commit.
- Flutter and Dart commands needed sandbox escalation because the toolchain writes SDK cache locks under `C:\software\flutter\bin\cache` and Dart telemetry state under the user profile.

## Verification

- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe --packages=C:\software\flutter\packages\flutter_tools\.dart_tool\package_config.json C:\software\flutter\bin\cache\flutter_tools.snapshot test test\tool\verify_mobile_v2_semantic_firewall_test.dart test\features\vnext\mobile_v2_surface_contract_test.dart` - passed, 12 tests.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe run tool\verify_mobile_v2_semantic_firewall.dart --help` - passed, printed expected usage.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe --packages=C:\software\flutter\packages\flutter_tools\.dart_tool\package_config.json C:\software\flutter\bin\cache\flutter_tools.snapshot test mobile\test\tool\verify_mobile_v2_semantic_firewall_test.dart` - passed, 7 tests.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 39-03 can create the minimum non-UI `mobile_v2` boundary and then run the no-arg verifier against the real repo. The semantic firewall is ready to block old product truth once `mobile_v2/lib` exists.

---
*Phase: 39-vnext-family-english-micro-ritual*
*Completed: 2026-06-15*
