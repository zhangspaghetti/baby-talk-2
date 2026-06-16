---
phase: 40-activation-governor-garden-memory
plan: "02"
subsystem: testing
tags: [vnext, activation-governor, garden-memory, contract-verifier, dart, tdd]

requires:
  - phase: 40-activation-governor-garden-memory
    provides: 40-01 independent Activation Governor verifier foundation and typed contract cases
provides:
  - Surface-level Activation Governor scanner coverage for Home, Onboarding, Garden, Runtime, and reminder copy
  - Explore-positive fixture proof for ideas, examples, routes, future expansion, and expert explanation
  - Weak-signal limits that allow prompt/review opportunities but reject truth-state promotion
  - Parent-confirmed Garden Memory validation requiring warm low-pressure non-scoring language
  - Mobile wrapper parity for the Activation Governor verifier suite
affects: [phase-40, phase-41, mobile_v2, activation-governor, garden-memory]

tech-stack:
  added: []
  patterns: [pure Dart scanner rule tables, table-driven contract fixtures, mobile wrapper forwarder]

key-files:
  created:
    - test/features/vnext/activation_governor_contract_surface_test.dart
    - mobile/test/tool/verify_activation_governor_contract_test.dart
  modified:
    - tool/verify_activation_governor_contract.dart
    - test/tool/verify_activation_governor_contract_test.dart

key-decisions:
  - "Plan 40-02 keeps scan scope in the existing pure Dart verifier instead of adding runtime UI, schema, API, Runtime Agent, Strategy Pack, Primitive, or metrics constructs."
  - "Chinese and English activation/pressure copy are auxiliary scanner guards; structured ActivationGovernorContractCase fields remain the authority backbone."
  - "Wrapper parity is a non-TDD closure task and forwards to the root test suite as the single source of truth."

patterns-established:
  - "Activation intent is tested across Home, Onboarding, Garden, Runtime, and reminder/push-like surface fixtures."
  - "Weak-signal-only cases may pass only as prompt/review actions and fail for active, familiar, resting, belongs_to_family, and truth-like suggested_familiar states."
  - "Parent-confirmed Garden transitions pass only with low-pressure confirmation copy and fail with checklist, streak, growth, unlock, reward, score, progress, or punishment language."

requirements-completed: [R063, R064, R065]

duration: 11 min
completed: 2026-06-16
---

# Phase 40 Plan 02: Surface Activation and Garden Confirmation Summary

**Activation Governor scanner coverage now separates open Explore from action-now activation copy and protects Garden Memory from weak-signal or pressure-based transfer claims.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-06-16T04:45:00Z
- **Completed:** 2026-06-16T04:56:14Z
- **Tasks:** 3 completed
- **Files modified:** 4

## Accomplishments

- Added table-driven root tests for positive Explore copy, surface activation CTAs, weak-signal limits, and low-pressure parent-confirmed Garden transitions.
- Added focused `mobile_v2/lib` temporary surface fixtures proving Home, Onboarding, Garden, Runtime, and reminder/push-like activation copy is rejected without Governor approval.
- Extended the verifier with Chinese and English activation-intent patterns, Chinese Garden pressure terms, low-pressure parent-confirmation checks, and truth-like weak-signal action rejection.
- Added the mobile wrapper forwarder after the scanner feature was green, keeping the root verifier suite as the single test source of truth.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: add surface, activation-copy, and Garden Memory fixture failures** - `ffa95cb` (test)
2. **Task 2 GREEN: implement activation-language, suspicious-name, and Garden confirmation rules** - `7c002a2` (feat)
3. **Task 3 closure: complete wrapper parity and final focused suite** - `9706377` (test)

**Plan metadata:** pending docs close-out commit.

_Note: This TDD plan produced a RED test commit followed by a GREEN feature commit; wrapper parity was intentionally committed as a non-TDD closure task._

## Files Created/Modified

- `tool/verify_activation_governor_contract.dart` - Added activation-intent, Garden pressure, low-pressure confirmation, and weak-signal truth-like action rules.
- `test/tool/verify_activation_governor_contract_test.dart` - Added table-driven public scanner cases for Explore openness, activation CTAs, weak-signal limits, and parent confirmation.
- `test/features/vnext/activation_governor_contract_surface_test.dart` - Added temporary `mobile_v2/lib` surface fixtures for Home, Onboarding, Garden, Runtime, reminder copy, suspicious names, and Garden pressure copy.
- `mobile/test/tool/verify_activation_governor_contract_test.dart` - Added thin mobile wrapper forwarding to the root verifier test suite.

## Decisions Made

- Kept Plan 40-02 implementation in the verifier/test layer only; no UI controls, navigation, database schema, API/event names, Runtime Agent payloads, Strategy Pack schema, Primitive sequencing, activation algorithm, or metrics instrumentation were added.
- Treated Chinese parent-facing copy as first-class scanner input because the product and UI contracts are Chinese-first for parent confirmation and activation pressure.
- Preserved root tests as the single source of truth for mobile wrapper parity.

## TDD Gate Compliance

- **RED:** `ffa95cb` added failing tests before implementation. RED verification used the direct Flutter-tools fallback and failed with the expected missing scanner behavior: activation-intent case IDs were absent, weak-signal truth-like cases were not all rejected, and Chinese activation/pressure surface fixtures were not blocked.
- **GREEN:** `7c002a2` implemented the scanner rules. Focused verification passed 23/23 tests and the Activation Governor CLI reported `activation_governor_contract_status=pass`.
- **REFACTOR:** No separate refactor commit was needed; the implementation remained small and table-driven.

## Verification

- `./flutter.cmd test test\tool\verify_activation_governor_contract_test.dart test\features\vnext\activation_governor_contract_surface_test.dart` - timed out after 180 seconds with no test output during Task 1; documented direct fallback was used.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe --packages=C:\software\flutter\packages\flutter_tools\.dart_tool\package_config.json C:\software\flutter\bin\cache\flutter_tools.snapshot test test\tool\verify_activation_governor_contract_test.dart test\features\vnext\activation_governor_contract_surface_test.dart` - RED run exited nonzero after 15 tests with 8 expected failures before implementation; GREEN run passed 23/23 tests.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe --packages=C:\software\flutter\packages\flutter_tools\.dart_tool\package_config.json C:\software\flutter\bin\cache\flutter_tools.snapshot test test\tool\verify_activation_governor_contract_test.dart test\features\vnext\activation_governor_contract_surface_test.dart mobile\test\tool\verify_activation_governor_contract_test.dart test\tool\verify_mobile_v2_semantic_firewall_test.dart` - passed after all task commits, 46/46 tests.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_activation_governor_contract.dart` - passed with `activation_governor_contract_status=pass`, `scanned_runtime_files=1`, `evaluated_contract_cases=5`, and no violations.
- `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_mobile_v2_semantic_firewall.dart` - passed with `mobile_v2_semantic_firewall_status=pass`, `scanned_runtime_files=1`, `scanned_reference_files=2`, and no violations.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope expansion; all work stayed inside the allowed verifier/test/wrapper files.

## Issues Encountered

- The repo `flutter.cmd` wrapper timed out with no output, matching the Phase 40 research warning. The documented direct Flutter-tools fallback was used for RED, GREEN, and final verification.
- The direct Flutter-tools fallback required sandbox escalation because Flutter writes `C:\software\flutter\bin\cache\lockfile` outside the workspace.

## Known Stubs

None. Stub scan found only ordinary `!= null` control-flow checks; no TODO/FIXME markers, placeholder text, empty UI/data stubs, or mock data sources were introduced.

## Threat Flags

None. The plan intentionally expands the verifier's text/case scanning surface for `mobile_v2/lib` temporary fixtures and does not introduce new runtime network endpoints, auth paths, file access beyond the existing verifier scan root, schemas, APIs, or trust-boundary persistence.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 40-03 can now create Phase 40 proof/validation artifacts and SPEC links using executable evidence for D-07/D-08 and D-18 through D-30: open Explore pass cases, activation-intent failures across required surfaces, weak-signal limits, parent-confirmed Garden transitions, pressure-language rejection, and mobile wrapper parity.

## Self-Check: PASSED

- `.planning/phases/40-activation-governor-garden-memory/40-02-SUMMARY.md` exists.
- Key files exist: `tool/verify_activation_governor_contract.dart`, `test/tool/verify_activation_governor_contract_test.dart`, `test/features/vnext/activation_governor_contract_surface_test.dart`, and `mobile/test/tool/verify_activation_governor_contract_test.dart`.
- Commits found: `ffa95cb`, `7c002a2`, `9706377`.
- TDD gate compliance verified: `test(40-02)` RED commit precedes `feat(40-02)` GREEN commit.
- Final focused suite and both CLI verifier gates passed after task commits.

---
*Phase: 40-activation-governor-garden-memory*
*Completed: 2026-06-16*
