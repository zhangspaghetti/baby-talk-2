---
phase: 41-mobile-v2-runnable-vertical-slice
plan: "02"
subsystem: mobile-domain
tags: [flutter, dart, tdd, interaction-engine, deterministic-policy]
requires:
  - phase: 41-mobile-v2-runnable-vertical-slice
    plan: "01"
    provides: immutable interaction input, context, strategy, utterance, and snapshot contracts
provides:
  - Five-channel irreversible semantic normalization
  - Decay-based bounded interaction-local memory evolution
  - Stateless low-pressure strategy selection
  - One-line caregiver utterance realization from preselected policy
affects: [41-03, 41-04, 41-05, interaction-engine-runtime]
tech-stack:
  added: []
  patterns: [pure async interfaces, deterministic rule implementations, bounded decay memory, policy-language separation]
key-files:
  created:
    - mobile_v2/lib/features/ritual_room/domain/engine/normalize_engine.dart
    - mobile_v2/lib/features/ritual_room/domain/engine/state_accumulator.dart
    - mobile_v2/lib/features/ritual_room/domain/engine/strategy_engine.dart
    - mobile_v2/lib/features/ritual_room/domain/engine/utterance_engine.dart
    - mobile_v2/test/features/ritual_room/domain/engine/normalize_engine_test.dart
    - mobile_v2/test/features/ritual_room/domain/engine/state_accumulator_test.dart
    - mobile_v2/test/features/ritual_room/domain/engine/strategy_engine_test.dart
    - mobile_v2/test/features/ritual_room/domain/engine/utterance_engine_test.dart
  modified: []
key-decisions:
  - "Treat future signals and caregiver strategy preferences as normalized evidence; only StrategyEngine selects policy."
  - "Bound compressed interaction history to eight irreversible summaries and decay all prior signal weights before applying new evidence."
  - "Keep utterance realization downstream of an immutable StrategyDecision and return exactly one primary caregiver line."
patterns-established:
  - "Each deterministic module has a replaceable interface and a stateless Phase 41 implementation."
  - "Domain engine files depend only on sibling pure-Dart models and own no lifecycle, storage, revision, replay, UI, or provider authority."
requirements-completed: [R058, R059, R060, R067]
duration: 16 min
completed: 2026-06-20
---

# Phase 41 Plan 02: Deterministic Engine Modules Summary

**Four independently replaceable pure-Dart modules normalize five input channels, evolve decaying interaction-local context, select low-pressure policy, and realize one speakable caregiver line**

## Performance

- **Duration:** 16 min continuation
- **Completed:** 2026-06-20T04:37:22Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added normalization across reaction, voice observation, free text, future signal, and strategy preference without retaining verbatim raw input.
- Added bounded decay accumulation whose joinability trend can improve, regress, oscillate, or remain uncertain within one interaction.
- Kept policy selection separate from language generation: StrategyEngine returns policy only, while UtteranceEngine accepts that immutable decision and emits one primary caregiver line.
- Proved the contracts through a committed RED gate followed by a GREEN implementation with 13 focused tests and 20 package tests passing.

## TDD Cycle

### RED

- **Commit:** `a92056f`
- Added four mirrored test suites covering five modalities, observed-versus-interpreted separation, non-monotonic decay, bounded compressed history, policy/language separation, stable ritual anchoring, and forbidden evaluation semantics.
- The production engine files did not exist in the RED commit's parent, so the tests referenced missing required module symbols.

### GREEN

- **Commit:** `50ab072`
- Implemented `RuleBasedNormalizeEngine`, `DecayStateAccumulator`, `RuleBasedStrategyEngine`, and `RuleBasedUtteranceEngine`.
- All focused tests passed without changing the committed RED contracts.

### REFACTOR

- No separate refactor commit was needed; formatting reported zero changes and the minimal GREEN implementation passed analysis and boundary scans.

## Task Commits

1. **Task 1 RED: Specify four pure module behaviors** - `a92056f` (test)
2. **Task 2 GREEN/REFACTOR: Implement deterministic stateless modules** - `50ab072` (feat)

## Files Created

- `mobile_v2/lib/features/ritual_room/domain/engine/normalize_engine.dart` - Converts all five raw input variants into irreversible semantic evidence.
- `mobile_v2/lib/features/ritual_room/domain/engine/state_accumulator.dart` - Applies decay, clamping, trend derivation, and an eight-entry compressed history bound.
- `mobile_v2/lib/features/ritual_room/domain/engine/strategy_engine.dart` - Selects low-pressure multi-axis policy without generating caregiver language.
- `mobile_v2/lib/features/ritual_room/domain/engine/utterance_engine.dart` - Realizes a supplied policy as exactly one primary caregiver line.
- `mobile_v2/test/features/ritual_room/domain/engine/normalize_engine_test.dart` - Covers equivalent observations and all five input channels.
- `mobile_v2/test/features/ritual_room/domain/engine/state_accumulator_test.dart` - Covers reversal, decay/clamping, and bounded non-diagnostic summaries.
- `mobile_v2/test/features/ritual_room/domain/engine/strategy_engine_test.dart` - Covers low-pressure selection and preference-as-evidence semantics.
- `mobile_v2/test/features/ritual_room/domain/engine/utterance_engine_test.dart` - Covers one-line realization, decision immutability, and stable ritual framing.

## Decisions Made

- Strategy preferences remain evidence rather than direct commands, preventing callers from bypassing StrategyEngine.
- Context memory remains interaction-local and compressed; no child trait, score, diagnosis, correctness, or compliance state is created.
- The Phase 41 utterance implementation uses the stable ritual anchor and selected modifiers but has no authority to revise the strategy.

## Deviations from Plan

None - plan implementation executed exactly as written.

## Issues Encountered

- The first focused Flutter test attempt timed out because the restricted sandbox could not access Flutter SDK cache and lock files. The direct SDK command passed after approved escalation.
- The semantic verifiers resolve the repository root from the current directory, so they were run from the repository root rather than from `mobile_v2`.

## Verification

- Focused four-file suite via direct Flutter SDK - pass, 13/13 tests.
- `dart analyze lib/features/ritual_room/domain/engine` - pass, no issues.
- `dart format --output=none --set-exit-if-changed .` - pass, 17 files unchanged.
- `flutter analyze --no-pub` - pass, no issues.
- `flutter test --no-pub` - pass, 20/20 tests.
- `dart run tool/verify_mobile_v2_semantic_firewall.dart` - pass, 0 violations.
- `dart run tool/verify_activation_governor_contract.dart` - pass, 0 violations.
- Forbidden vocabulary, Flutter/Riverpod, runtime-store, replay, lifecycle, and stub scans - pass.
- TDD order check - `a92056f` is an ancestor of `50ab072`, and all four production files were absent before RED.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 41-03 can compose these four deterministic modules behind the interaction authority and consistency/replay runtime.
- No blocker remains.

## Self-Check: PASSED

- All eight created plan files exist.
- RED commit `a92056f` and GREEN commit `50ab072` exist in order.
- Focused, package-level, semantic, boundary, and analyzer gates pass.

---
*Phase: 41-mobile-v2-runnable-vertical-slice*
*Completed: 2026-06-20*
