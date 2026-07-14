---
phase: 41-mobile-v2-runnable-vertical-slice
plan: "01"
subsystem: mobile-domain
tags: [flutter, dart, crypto, immutable-models, interaction-engine]
requires:
  - phase: 39-vnext-family-english-micro-ritual
    provides: mobile_v2 semantic boundary and product contract
  - phase: 40-activation-governor-garden-memory
    provides: activation and Garden Memory semantic guards
provides:
  - Audited crypto dependency and registered Phase 41 asset roots
  - Executable Flutter and semantic-verifier command map
  - Five-channel ephemeral InputEvent contract
  - Immutable schema-1 ProductSnapshot and exhaustive AdvanceResult contracts
affects: [41-02, 41-03, 41-04, 41-05, 41-06, 41-07, 41-08, interaction-engine]
tech-stack:
  added: [crypto 3.0.7]
  patterns: [sealed typed payloads, immutable collection boundaries, pure-Dart domain models]
key-files:
  created:
    - .planning/phases/41-mobile-v2-runnable-vertical-slice/41-COMMAND-HEALTH.md
    - mobile_v2/lib/features/ritual_room/domain/models/input_event.dart
    - mobile_v2/lib/features/ritual_room/domain/models/product_snapshot.dart
    - mobile_v2/lib/features/ritual_room/domain/models/advance_result.dart
    - mobile_v2/test/features/ritual_room/domain/models/interaction_contract_test.dart
  modified:
    - mobile_v2/pubspec.yaml
    - mobile_v2/pubspec.lock
key-decisions:
  - "Keep Riverpod completely absent until Plan 41-08; Plan 41-01 adds only crypto:^3.0.7."
  - "Represent raw inputs as one immutable envelope over five sealed payload variants, with UTC canonical content."
  - "Keep ProductSnapshot limited to current product truth; consistency receipts, replay evidence, raw observations, and UI state remain outside it."
patterns-established:
  - "Pure-Dart domain models import only dart: libraries and sibling model files."
  - "All exposed model collections are defensive unmodifiable views."
requirements-completed: [R058, R059, R060, R067]
duration: 26 min
completed: 2026-06-20
---

# Phase 41 Plan 01: Core Interaction Contracts Summary

**Audited crypto and asset gates plus tested pure-Dart contracts for five-channel input, schema-1 product truth, and exhaustive advance outcomes**

## Performance

- **Duration:** 26 min
- **Started:** 2026-06-20T00:01:07Z
- **Completed:** 2026-06-20T00:27:35Z
- **Tasks:** 3
- **Files modified:** 13

## Accomplishments

- Locked the approved D.4.5 prototype and `shoes_on` illustration as execution gates, registered both asset roots, and resolved `crypto` 3.0.7 without introducing Riverpod or code generation.
- Added five sealed raw input variants with stable UTC canonical content and no framework dependency.
- Added immutable normalized context, compressed memory, strategy, utterance, schema-1 revision-0 product snapshot, and all locked advance success/rejection outcomes.
- Proved RED from absent production symbols, then GREEN with 7 focused tests, analyzer success, and both semantic firewalls passing.

## Task Commits

Each task was committed atomically:

1. **Task 1: Enforce D.4.5, static-asset, crypto, and command gates** - `4e27103` (chore)
2. **Task 2 RED: Specify immutable engine contracts** - `c09fc9a` (test)
3. **Task 3 GREEN: Implement pure-Dart immutable models** - `be0a0b4` (feat)

## Files Created/Modified

- `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-COMMAND-HEALTH.md` - Runnable package, verifier, dependency, and SDK fallback commands.
- `mobile_v2/.gitignore` - Keeps generated Flutter/Dart package state out of version control.
- `mobile_v2/pubspec.yaml` / `mobile_v2/pubspec.lock` - Adds only audited `crypto:^3.0.7` and registers the fixture and illustration roots.
- `mobile_v2/assets/fixtures/ritual_rooms/.gitkeep` - Preserves the canonical fixture directory before fixture content arrives.
- `mobile_v2/lib/features/ritual_room/domain/models/input_event.dart` - Five typed ephemeral event channels and canonical content.
- `mobile_v2/lib/features/ritual_room/domain/models/normalized_input.dart` - Irreversible non-verbatim semantic input.
- `mobile_v2/lib/features/ritual_room/domain/models/context_memory.dart` - Compressed interaction-local memory.
- `mobile_v2/lib/features/ritual_room/domain/models/strategy_decision.dart` - Language policy that does not describe or score a child.
- `mobile_v2/lib/features/ritual_room/domain/models/utterance.dart` - One primary immediately speakable caregiver line.
- `mobile_v2/lib/features/ritual_room/domain/models/product_snapshot.dart` - Immutable schema-1 current product truth.
- `mobile_v2/lib/features/ritual_room/domain/models/advance_result.dart` - Applied, duplicate, and exhaustive rejected outcomes.
- `mobile_v2/test/features/ritual_room/domain/models/interaction_contract_test.dart` - Contract, immutability, privacy, UTC, schema/revision, and result coverage.

## Decisions Made

- Riverpod remains absent until Plan 41-08, preserving the planned pure-Dart-first dependency order.
- Canonical event content is generated from the complete immutable envelope after timestamp normalization to UTC.
- ProductSnapshot metadata contains only observation data (`lastEventId`, `updatedAt`); idempotency and replay state are separate future runtime contracts.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Ignored generated package state**
- **Found during:** Task 1
- **Issue:** `flutter pub get` created an untracked `mobile_v2/.dart_tool/` directory, which would leave generated runtime output in the working tree.
- **Fix:** Added a package-local `.gitignore` for `.dart_tool`, Flutter plugin metadata, and build output.
- **Files modified:** `mobile_v2/.gitignore`
- **Verification:** `git status --short` no longer reports generated package state.
- **Committed in:** `4e27103`

---

**Total deviations:** 1 auto-fixed (1 blocking issue).
**Impact on plan:** Repository hygiene only; no product or architecture scope changed.

## Issues Encountered

- Flutter initially could not update its SDK cache from the restricted sandbox. The same planned commands passed after granting the Flutter executable access to its normal SDK and user-profile cache locations.

## Verification

- `dart format --output=none --set-exit-if-changed .` - pass, 9 files unchanged.
- `flutter analyze` - pass, no issues.
- `flutter test` - pass, 7/7 tests.
- `dart run tool/verify_mobile_v2_semantic_firewall.dart` - pass, 0 violations.
- `dart run tool/verify_activation_governor_contract.dart` - pass, 0 violations.
- Asset, dependency, forbidden-package, framework-import, and ProductSnapshot privacy assertions - pass.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Pure-Dart model contracts are ready for Plan 41-02 deterministic pipeline modules.
- No blockers remain.

## Self-Check: PASSED

- All 13 created/modified plan files exist.
- Task commits `4e27103`, `c09fc9a`, and `be0a0b4` exist.
- TDD RED and GREEN commits are present in order.
- Final plan verification and all task acceptance assertions pass.

---
*Phase: 41-mobile-v2-runnable-vertical-slice*
*Completed: 2026-06-20*
