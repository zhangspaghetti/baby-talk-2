---
phase: 41-mobile-v2-runnable-vertical-slice
plan: "05"
subsystem: mobile-content
tags: [flutter, dart, fixture, dto, mapper, repository, tdd]
requires:
  - phase: 41-mobile-v2-runnable-vertical-slice
    plan: "01"
    provides: registered fixture boundary, approved illustration, and immutable model conventions
provides:
  - Backend-shaped shoes_on Ritual Room fixture
  - Strict DTO-to-domain content mapping with approved illustration validation
  - Asynchronous asset-backed content API and domain repository
  - Requirement-traced payload ownership and substitution tests
affects: [41-06, 41-08, 41-09, ritual-room-presentation]
tech-stack:
  added: []
  patterns: [content API boundary, manual immutable DTOs, strict mapper validation, repository delegation]
key-files:
  created:
    - mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json
    - mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart
    - mobile_v2/lib/features/ritual_room/domain/repositories/ritual_room_repository.dart
    - mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart
    - mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart
    - mobile_v2/lib/features/ritual_room/data/datasources/ritual_content_api.dart
    - mobile_v2/lib/features/ritual_room/data/datasources/mock_ritual_content_api.dart
    - mobile_v2/lib/features/ritual_room/data/repositories/ritual_room_repository_impl.dart
    - mobile_v2/test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart
    - mobile_v2/test/features/ritual_room/data/datasources/mock_ritual_content_api_test.dart
    - mobile_v2/test/features/ritual_room/data/repositories/ritual_room_repository_test.dart
  modified:
    - mobile_v2/pubspec.yaml
key-decisions:
  - "Keep stable ritual content in a dedicated fixture -> API -> DTO -> mapper -> repository -> domain path."
  - "Validate the approved shoes_on illustration lifecycle and canonical asset path at the mapper boundary."
  - "Carry Context Seed, joinability, Governor, and non-production Garden status as immutable evidence only."
patterns-established:
  - "Stable content repositories delegate loading and mapping without importing interaction runtime types."
  - "Payload-substitution tests prove that user-visible ritual values are supplied by data, not constants."
requirements-completed: [R058, R059, R060, R063, R064, R065, R067]
duration: 10 min
completed: 2026-06-20
---

# Phase 41 Plan 05: Stable Ritual Content Boundary Summary

**Asset-backed `shoes_on` content now flows through a validated DTO/mapper/repository boundary into immutable domain data without gaining interaction or Garden authority.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-20T05:03:30Z
- **Completed:** 2026-06-20T05:13:13Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Added the complete D.4.5 stable Ritual Room payload, including approved illustration metadata, room identity, bootstrap utterance, action cue, audio metadata, neutral context choices, reassurance, pending copy, quiet exit, and governance evidence.
- Added strict manual transport DTOs, immutable domain models, approved-asset validation, asynchronous asset loading, and a repository that exposes domain content only.
- Proved content ownership through an alternate safe payload that changes room labels, helper text, utterance, cue, and choices without production constants.
- Kept ProductSnapshot, consistency receipts, replay state, child scoring, completion, production Garden transitions, and activation authority outside the stable content boundary.

## TDD Evidence

### RED

- Added mapper, mock API, and repository tests before production code.
- Captured Flutter compiler failure naming missing `RitualRoomMapper`, `RitualContentApi`, and `RitualRoomRepository` symbols.
- Committed the failing contract as `923b56b`.

### GREEN

- Implemented the fixture, DTO/domain contracts, mapper, API, and repository.
- Targeted content suite passed 9/9 tests.
- Committed the passing implementation as `195570d`.

### REFACTOR

- No separate refactor commit was needed; the minimal GREEN implementation remained cohesive and analyzer-clean.

## Task Commits

1. **Task 1 RED: Specify content schema, ownership, governance evidence, and substitution** — `923b56b` (test)
2. **Task 2 GREEN/REFACTOR: Implement the stable content adapter path** — `195570d` (feat)

## Files Created/Modified

- `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json` — Backend-shaped stable D.4.5 content and non-authoritative governance evidence.
- `mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart` — Immutable room content and defensive reaction-choice collection.
- `mobile_v2/lib/features/ritual_room/domain/repositories/ritual_room_repository.dart` — Domain-facing stable content contract.
- `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart` — Required-field transport parsing and serialization.
- `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart` — Canonical approved-asset validation and DTO-to-domain conversion.
- `mobile_v2/lib/features/ritual_room/data/datasources/ritual_content_api.dart` — Backend-shaped content API contract.
- `mobile_v2/lib/features/ritual_room/data/datasources/mock_ritual_content_api.dart` — Asynchronous registered-asset implementation with identity checks.
- `mobile_v2/lib/features/ritual_room/data/repositories/ritual_room_repository_impl.dart` — Thin API and mapper delegation.
- `mobile_v2/test/features/ritual_room/data/` — Requirement-traced mapper, asset API, repository, substitution, and negative-boundary tests.
- `mobile_v2/pubspec.yaml` — Registers the concrete nested `shoes_on` illustration directory.

## Decisions Made

- Stable room content and evolving ProductSnapshot state remain separate repository boundaries.
- Unknown ritual IDs fail instead of silently substituting `shoes_on` content.
- Approved status and canonical asset path are validated before content reaches presentation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered the concrete nested illustration directory**
- **Found during:** Task 2 GREEN verification
- **Issue:** Flutter asset directory declarations are not recursive; registering `assets/illustrations/rituals/` did not place `shoes_on_approved_v1.png` in the test bundle.
- **Fix:** Registered `assets/illustrations/rituals/shoes_on/` in `mobile_v2/pubspec.yaml`.
- **Files modified:** `mobile_v2/pubspec.yaml`
- **Verification:** The mock API asset test loads the PNG and confirms non-empty bytes; the full Flutter suite passes.
- **Commit:** `195570d`

---

**Total deviations:** 1 auto-fixed (1 blocking issue).
**Impact:** Corrected asset packaging only; product scope and architecture remain unchanged.

## Issues Encountered

- The normal Dart wrapper stalled on SDK cache initialization. Verification used the direct Dart SDK and Flutter tools snapshot with CI/analytics suppression.
- The semantic verifier is repository-root-sensitive; invoking it from `mobile_v2` scans the wrong path. Both verifier CLIs passed from the canonical repository root.

## Verification

- Expected RED proof — pass; missing content production symbols were captured.
- `dart format --output=none --set-exit-if-changed .` — pass, 38 files unchanged.
- `flutter analyze` — pass, no issues.
- `flutter test` — pass, 39/39 tests.
- Content mapper/API/repository suite — pass, 9/9 tests including fixture asset loading.
- Stable content negative scan — pass; no score, streak, completion, replay, consistency, or interaction-engine types.
- `dart run tool/verify_mobile_v2_semantic_firewall.dart` — pass, 28 runtime files scanned with zero violations.
- `dart run tool/verify_activation_governor_contract.dart` — pass, 5 contract cases with zero violations.
- TDD log check — RED `923b56b` precedes GREEN `195570d`.

## Known Stubs

None.

## User Setup Required

None.

## Next Phase Readiness

- The stable content bootstrap is ready for Ritual Room interaction adapters, Riverpod composition, and presentation projection.
- No blocker remains.

## Self-Check: PASSED

- All 12 created/modified plan files exist.
- Task commits `923b56b` and `195570d` exist in order.
- Required fixture values, approved illustration metadata, payload substitution, negative-boundary scans, full tests, analyzer, and both semantic verifiers pass.

---
*Phase: 41-mobile-v2-runnable-vertical-slice*
*Completed: 2026-06-20*
