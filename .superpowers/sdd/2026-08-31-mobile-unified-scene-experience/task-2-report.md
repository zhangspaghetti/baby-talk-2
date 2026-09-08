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
