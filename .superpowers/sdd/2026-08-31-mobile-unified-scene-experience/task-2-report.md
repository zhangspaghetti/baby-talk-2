# Task 2 Report

- RED: focused catalog tests first failed because Task2 model/API/store/repository seams were absent.
- GREEN: API, store, catalog repository, and PracticeRepository catalog tests pass (39/39).
- Files: strict preset model/API, atomic catalog store, remote-first repository, seed adapter, PracticeRepository merge, DI, focused tests.
- API: exact eight public keys, 2xx JSON-array parsing, duplicate/route/type/fractional validation, public headers, no Bearer or generation brief.
- Store: versioned exact-key root; stable-order JSON; temporary sibling, flush, replace; malformed cache quarantine bounded to 3.
- Empty ruling: valid remote `[]` is authoritative, cached as empty, and remains empty offline; missing cache differs from valid empty.
- Practice merge: published metadata and API order preserved; matching seed phrases/audio remain generic fallback; remote-only scenes have empty fallback phrases.
- Verification: `flutter analyze` clean; fresh `flutter test --no-pub --reporter compact` 953/953.
- Scope audit: only Task2 files plus required DI/report; custom/household WIP and Windows generated files untouched/unstaged.

## Fix Round 1

- RED: reviewer regressions reproduced for Windows replacement loss, onboarding remote catalog access, uncapped/late remote loads, concurrent loads, invalid UTF-8, and release-disabled model invariants.
- GREEN: backup restore replacement, bundled-only onboarding seam, 3-second cancelable remote budget, single-flight/memory cache/explicit refresh, strict byte decoding, and runtime ID/space/sort validation added.
- Verification: catalog/API/store/repository focused plus care-path and PracticeRepository regressions pass; fresh full Flutter suite 953/953; `flutter analyze` clean.
- Onboarding continuation now bypasses catalog/cache entirely, including reaction continuation and garden projection reads.
- Store replacement tests inject final rename failure and verify old snapshot remains readable; invalid UTF-8 is quarantined as malformed while resolver I/O remains `ioFailure`.
