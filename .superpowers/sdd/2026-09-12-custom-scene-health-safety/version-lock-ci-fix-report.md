# Practice AI version-lock CI fix report

## Changes

- Added the exact `backend/app-api/src/main/resources/config/practice-health-safety-v1.yml` path to both push and pull-request filters in `.github/workflows/practice-ai-version-lock.yml`.
- Replaced the version-lock test's `origin/Develop` lookup with the committed `test/tool/fixtures/practice_ai_version_lock_base.yml` fixture.
- Made additive-version coverage derive the added-version set from the fixture and current scan, so it does not depend on a branch relationship or a fixed number of additions.
- Added regression coverage for existing-version resource-path changes and for deterministic `(version, resource-path)` ordering in generated locks.
- Kept the base-lock fixture and all tests independent of remotes, fetch depth, and mutable refs.

## TDD evidence

- RED: the new test suite failed because the fixed fixture was absent and the workflow lacked both health-policy path entries.
- GREEN: after adding the fixture and workflow filters, all version-lock tests passed.

## Verification

- `python -m unittest test/tool/verify_practice_ai_version_lock_test.py` — 7 passed.
- `python tool/verify_practice_ai_version_lock.py --verify --base-lock test/tool/fixtures/practice_ai_version_lock_base.yml` — passed; 22 resources verified.
- `python test/tool/verify_spring_ai_2_backend_platform_test.py` — 22 passed.
- `python tool/verify_spring_ai_2_backend_platform.py` — passed.
- `git diff --check` — passed.
