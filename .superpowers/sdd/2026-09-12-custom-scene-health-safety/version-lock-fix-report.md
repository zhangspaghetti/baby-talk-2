# Version-lock scanner fix

## Result

`verify_practice_ai_version_lock.py` now discovers the fixed `health-safety-v1` policy outside `config/practice-ai`, validates its typed classifier prompt reference, and emits a sorted 22-resource lock. Existing `origin/Develop` versions keep their paths and hashes; only classifier and health-policy versions are additive.

## Tests and gates

- RED: `python3 -m unittest test.tool.verify_practice_ai_version_lock_test` failed before scanner changes because health policy and classifier resources were absent from discovery.
- GREEN: `python3 -m unittest test.tool.verify_practice_ai_version_lock_test` — 5 tests passed.
- Lock generation: `python3 tool/verify_practice_ai_version_lock.py --write` — 22 resources.
- Base comparison: `python3 tool/verify_practice_ai_version_lock.py --verify --base-lock <origin/Develop lock>` — verified 22 resources.
- Platform gate: `python3 tool/verify_spring_ai_2_backend_platform.py` — verified.
- Backend lock consumers: `cd backend && bash mvnw -pl app-api -Dtest=VersionedResourceRegistryTest,CustomSceneSafetyPropertiesTest test` — 26 tests passed.
- `git diff --check` — passed.

## Changed files

- `tool/verify_practice_ai_version_lock.py`
- `test/tool/verify_practice_ai_version_lock_test.py`
- `backend/app-api/src/main/resources/config/practice-ai/version-lock.yml`

Commit: `fix(ci): scan health safety policy lock`
