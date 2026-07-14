---
phase: 40-activation-governor-garden-memory
plan: "01"
subsystem: testing
tags: [vnext, activation-governor, garden-memory, contract-verifier, dart]

requires:
  - phase: 39-vnext-family-english-micro-ritual
    provides: mobile_v2 semantic boundary, vNext supersession rules, and Phase 39 semantic firewall pattern
provides:
  - Independent pure Dart Activation Governor / Garden Memory contract verifier
  - Typed ActivationGovernorContractCase fixture API for R063/R064/R065 authority seams
  - CLI report and success marker for scanning mobile_v2/lib without repo-wide scope
  - Root tests covering fail-closed boundary behavior, Explore openness, authority bypasses, parent intent, and scope guards
affects: [phase-40, phase-41, mobile_v2, activation-governor, garden-memory]

tech-stack:
  added: []
  patterns: [pure Dart contract verifier, typed table-driven contract cases, fail-closed mobile_v2/lib scan, no JSON/YAML fixtures]

key-files:
  created:
    - tool/verify_activation_governor_contract.dart
    - test/tool/verify_activation_governor_contract_test.dart
  modified: []

key-decisions:
  - "The Activation Governor contract verifier is independent from the Phase 39 semantic firewall while reusing its pure Dart scan/report/CLI pattern."
  - "Default CLI proof cases include expected negative seams, but the no-arg CLI passes only when those seams are correctly rejected."
  - "The verifier scans mobile_v2/lib only; repo-wide activation/Garden scanning remains deferred to avoid old docs, reference code, and deprecated mobile semantics."
  - "Root verifier tests use package:test so the pure Dart contract can run through both Flutter test and a sandbox-safe direct Dart test runner."

patterns-established:
  - "ActivationGovernorContractCase captures producer, consumer, decisionSource, Garden action, Governor decision, parent intent, weak-signal, and expected result fields."
  - "Expected negative default cases count as proof only when rejected; explicit caller-supplied negative cases surface as blocking violations."
  - "Source scanning is limited to mobile_v2/lib and rejects activation-intent copy without Governor decisions plus Garden checklist/progress pressure terms."

requirements-completed: [R063, R064, R065]

duration: 20 min
completed: 2026-06-16
---

# Phase 40 Plan 01: Activation Governor Contract Verifier Summary

**Pure Dart contract verifier that makes Activation Governor authority, Explore openness, and parent-confirmed Garden Memory seams machine-checkable before runtime implementation exists.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-06-16T04:16:55Z
- **Completed:** 2026-06-16T04:36:24Z
- **Tasks:** 3 completed
- **Files modified:** 2

## Accomplishments

- Added `tool/verify_activation_governor_contract.dart`, an independent Phase 40 verifier with typed cases, structured violations, deterministic report rendering, CLI help, and a success marker.
- Added `test/tool/verify_activation_governor_contract_test.dart`, covering missing-boundary fail-closed behavior, empty contract cases, Explore-only positives, Pack/Graph direct activation, Runtime self-governance, Garden-owned policy, and `candidate -> active` requirements.
- Added scope guards proving the verifier does not scan repo-wide deprecated/reference material and does not introduce JSON/YAML fixture paths.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Encode independent verifier and authority-seam expectations** - `4766e42` (test)
2. **Task 2 GREEN: Implement structured verifier, report, and CLI** - `04a86dd` (feat)
3. **Task 3 REFACTOR: Stabilize public verifier contract and scope guards** - `cf8cd3d` (refactor)

**Plan metadata:** pending docs close-out commit.

## Files Created/Modified

- `tool/verify_activation_governor_contract.dart` - Pure Dart scanner, typed contract case/report/violation API, report renderer, default proof cases, and CLI behavior.
- `test/tool/verify_activation_governor_contract_test.dart` - Root verifier tests for fail-closed boundaries, authority seams, parent intent/Governor gating, CLI parsing, scan scope, and typed fixture constraints.

## Decisions Made

- Kept Phase 40 proof independent from `tool/verify_mobile_v2_semantic_firewall.dart`, while reusing the same repository-owned pure Dart verifier style.
- Treated default negative proof cases as expected rejections for the no-arg CLI, while explicit negative caller-supplied cases remain blocking violations for table-driven tests.
- Used `package:test` in the root verifier test because the verifier is pure Dart and this allows a sandbox-safe test runner path when Flutter tooling cannot write SDK/user-profile lock or telemetry files.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used package:test for pure Dart root verifier tests**
- **Found during:** Task 1 RED verification
- **Issue:** The sandbox-safe direct test runner cannot load `package:flutter_test` because it requires Flutter engine `dart:ui`, while the Flutter tool path initially stalled or needed SDK cache lockfile access outside the workspace.
- **Fix:** Switched the root verifier test import to `package:test/test.dart`. The tests remain pure Dart and also pass under the documented Flutter-tools fallback once escalation is available.
- **Files modified:** `test/tool/verify_activation_governor_contract_test.dart`
- **Verification:** Direct test runner passed 10/10; escalated Flutter-tools fallback passed 10/10.
- **Committed in:** `4766e42`

---

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact on plan:** No product scope expansion. The verifier remains pure Dart, package-free, and compatible with the documented Flutter test fallback.

## Issues Encountered

- `./flutter.cmd test test\tool\verify_activation_governor_contract_test.dart` timed out after 120 seconds with no test output. This matches the Phase 40 research warning about wrapper stalls.
- The direct Flutter-tools fallback initially failed without escalation because Flutter needed `C:\software\flutter\bin\cache\lockfile`. The same fallback passed after escalation.
- `dart run test ...` was not used for final proof because Dartdev tried to update telemetry under `C:\Users\zhang\AppData\Roaming\.dart-tool`; the direct test package entrypoint avoided that side effect.

## Verification

- `./flutter.cmd test test\tool\verify_activation_governor_contract_test.dart` - timed out after 120 seconds with no output.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe --packages=C:\software\flutter\packages\flutter_tools\.dart_tool\package_config.json C:\software\flutter\bin\cache\flutter_tools.snapshot test test\tool\verify_activation_governor_contract_test.dart` - passed after escalation, 10/10 tests.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe --packages=.dart_tool\package_config.json C:\Users\zhang\AppData\Local\Pub\Cache\hosted\pub.flutter-io.cn\test-1.30.0\bin\test.dart test\tool\verify_activation_governor_contract_test.dart` - passed, 10/10 tests.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_activation_governor_contract.dart --help` - passed, printed expected usage.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_activation_governor_contract.dart` - passed with `activation_governor_contract_status=pass`, `scanned_runtime_files=1`, `evaluated_contract_cases=5`, `expected_rejected_contract_cases=3`, and success marker.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_activation_governor_contract.dart --repo-wide` - exited nonzero with `Unknown argument: --repo-wide` before scanning.

## Known Stubs

None. Stub scan found only ordinary `null` control-flow checks in the verifier renderer/options path; no placeholder data, TODO/FIXME markers, or empty UI/data stubs were introduced.

## Threat Flags

None. The only new file-access surface is the planned verifier scan of `mobile_v2/lib`, which is covered by the plan threat model boundary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 40-02 can extend this verifier with broader surface activation intent, weak-signal limits, parent-confirmed Garden Memory copy, and wrapper parity while preserving the independent typed-case contract established here.

## Self-Check: PASSED

- `tool/verify_activation_governor_contract.dart` exists.
- `test/tool/verify_activation_governor_contract_test.dart` exists.
- Commits found: `4766e42`, `04a86dd`, `cf8cd3d`.
- No tracked file deletions were introduced by task commits.
- TDD gate compliance verified: `test(40-01)`, `feat(40-01)`, and `refactor(40-01)` commits exist in order.

---
*Phase: 40-activation-governor-garden-memory*
*Completed: 2026-06-16*
