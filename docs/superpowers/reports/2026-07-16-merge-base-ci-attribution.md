# Merge-base CI attribution evidence

Date: 2026-07-16

## Historical-context notice

This report originally measured `origin/main` against evaluated HEAD `95b39d9598cf3f6cedfa188d0cc02678c1975d2d`. Those measurements, logs, counts, and conclusions are retained below as historical evidence only. They do not describe the current `Develop`-targeted branch state and have not been relabeled as current results.

## Current `origin/Develop` attribution snapshot

Recomputed on 2026-07-16 from the Task 1 input commit, without reusing the historical `origin/main` merge-base result:

- Actual target branch: `Develop`
- Task 1 input HEAD: `bbcaf84edc961c4aadee899b2c3b3e5cbe75ab3f`
- Observed `origin/Develop`: `4f0b33462a0c7ca4b7f6f3ba0203ae776a9239cb`
- Current merge base: `ad05936ea58283fced9db67a21f9cde2c63ea1c1`
- Divergence from `origin/Develop`: 1 target-only commit, 21 branch-only commits
- Current branch attribution range: `ad05936ea58283fced9db67a21f9cde2c63ea1c1..bbcaf84edc961c4aadee899b2c3b3e5cbe75ab3f`
- Attributed tree delta: 136 files changed, 5,600 insertions, 1,124 deletions

Therefore current attribution uses `origin/Develop` and merge base `ad05936e`. The historical Helm/mobile measurements against `10280f21` remain valid only for their original `origin/main` snapshot; this report makes no claim that those exact counts were rerun against current `origin/Develop`.

## Historical scope (original measurement)

- Target branch: `gsd/v0.1-milestone`
- Merge target: `origin/main`
- Git merge base: `10280f210db5310338dd9dba0ae8b325c5471315`
- Evaluated HEAD: `95b39d9598cf3f6cedfa188d0cc02678c1975d2d`
- B2.1 baseline: `d8960d1c9a68c2dd666cf697b047c0faa367a789`
- Custom-scene base: `ad05936ea58283fced9db67a21f9cde2c63ea1c1`

`ad05936e` is an ancestor inside the branch. It is not the branch merge base.

## Method

Two detached worktrees were used:

- merge base: `C:/code/AI/.worktrees/baby-talk-2-attribution-base`
- HEAD: `C:/code/AI/.worktrees/baby-talk-2-attribution-head`

Each comparison used the same machine, toolchain, environment, command, and script content. The scripts are byte-identical between merge base and HEAD:

- `ci/k8s-smoke.sh`: SHA-256 `275955E446E58FC17A2AF950F9205652247DF075F4721E65D7FC73717C81DBD8`
- `ci/mobile-analyze.sh`: SHA-256 `D6B2A5FDCC0ABBBC4EDDAFC62FBB2EB45DAC4F1C0590DF1E0CBDA3EEAFCCC3F9`

Commands:

```bash
bash ci/k8s-smoke.sh
bash ci/mobile-analyze.sh
```

Toolchain:

- Bash `5.2.37`
- Helm `v4.1.4`
- kubectl `v1.34.1`
- Python `3.14.4`
- Flutter `3.41.6` stable, revision `db50e20168`
- Dart `3.11.4`

## Helm smoke attribution

| Revision | Exit | PASS | FAIL | SKIP |
| --- | ---: | ---: | ---: | ---: |
| merge base `10280f21` | 0 | 66 | 0 | 2 |
| HEAD `95b39d95` | 1 | 60 | 6 | 2 |

The two stable skips are kubectl dry-runs without a reachable cluster. HEAD added six failures:

1. `Runbook not found at docs/runbooks/k8s-deploy.md`
2. `schema compatibility matrix not found at docs/schema-compatibility-matrix.md`
3. `runbook missing babytalk-infra reference`
4. `runbook missing babytalk-app reference`
5. `own-jdbctemplate-count — expected [0], got [14]`
6. `docs/runbooks/k8s-deploy.md missing Spring Cloud Gateway reference`

Five documentation failures came from moving two still-authoritative documents under `docs/archived/`. The runtime audit failure came from four services introduced after the merge base.

Raw logs:

- `helm-base.log`: SHA-256 `5461D7C6DC1BA69725902506485262A42136A6964ED9B80F9ED83A8FC31EF80D`
- `helm-head.log`: SHA-256 `E9E7BE631330CC1590568794D74DC27C81A39E803ED99DB30188DA4BDADBD107`

## Mobile analyze attribution

| Revision | Exit | Analyze | Tests |
| --- | ---: | --- | --- |
| merge base `10280f21` | 0 | 0 issues | 223 passed |
| HEAD `95b39d95` | 1 | 14 issues | not run because analyze failed fast |

HEAD added all 14 diagnostics: 0 errors, 2 warnings, and 12 infos.

1. `integration_test/s01_guest_practice_flow_test.dart:351:6` — `unused_element`
2. `lib/features/garden/domain/services/garden_fertilizer_service.dart:1:1` — `dangling_library_doc_comments`
3. `lib/features/practice/domain/services/practice_recommendation_service.dart:4:1` — `dangling_library_doc_comments`
4. `lib/features/practice/presentation/widgets/home_botanical_header.dart:198:13` — `overridden_fields`
5. `lib/features/practice/presentation/widgets/home_botanical_header.dart:198:13` — `annotate_overrides`
6. `lib/features/settings/presentation/screens/caregiver_preferences_screen.dart:160:15` — deprecated `groupValue`
7. `lib/features/settings/presentation/screens/caregiver_preferences_screen.dart:161:15` — deprecated `onChanged`
8. `pubspec.yaml:80:7` — missing `assets/images/garden/`
9. `test/app/widgets/app_scene_pill_test.dart:118:22` — deprecated `hasFlag`
10. `test/app/widgets/app_scene_pill_test.dart:119:22` — deprecated `hasFlag`
11. `test/app/widgets/app_segment_tab_test.dart:100:22` — deprecated `hasFlag`
12. `test/app/widgets/app_segment_tab_test.dart:101:22` — deprecated `hasFlag`
13. `test/features/practice/widgets/scene_reaction_chip_row_test.dart:80:17` — deprecated `hasFlag`
14. `test/unit/domain/services/growth_stats_service_test.dart:8:25` — `no_leading_underscores_for_local_identifiers`

Raw logs:

- `mobile-base.log`: SHA-256 `CB8F8A4CB1F711E971FB87BE361A9335EE869F0C13B94E7F5D497E38E24F1900`
- `mobile-head.log`: SHA-256 `B5DC577683B98B500B717D50BEBF40932D9A143D72E77DC142EABDBA2AFE3144`

## JdbcTemplate attribution

The Helm audit counts matching source lines, not files. Its reported `14` means 14 lines in four production files.

| File | Audit positions | Actual JDBC call positions | Introduced by |
| --- | --- | --- | --- |
| `GardenFertilizerService.java` | 12 import, 19 field, 21 constructor | 48, 58, 97, 120, 154, 168, 179, 196 | `8c448055` |
| `GardenSnapshotService.java` | 12 import, 21 field, 26 public constructor, 31 package constructor | 46, 73, 103, 162, 188, 231 | `e7fe00d2` |
| `GrowthInsightsService.java` | 15 import, 23 field, 28 public constructor, 33 package constructor | 76, 109, 165, 186, 222, 242 | `6b942b00`, `146e2113` |
| `GrowthSummaryService.java` | 14 import, 21 field, 25 constructor | 37 | `c5fd3ad8` |

Exact audit counts:

| Revision | Matching lines | Files |
| --- | ---: | ---: |
| merge base `10280f21` | 0 | 0 |
| B2.1 baseline `d8960d1c` | 14 | 4 |
| custom-scene base `ad05936e` | 14 | 4 |
| evaluated HEAD `95b39d95` | 14 | 4 |

The 14 `path:line:text` records are identical at `d8960d1c`, `ad05936e`, and evaluated HEAD. Therefore B2.1/custom-scene and Spring AI 2 platform work did not add a JdbcTemplate hit. However, the current branch did add all 14 after its actual merge base.

## Attribution decision

The hypothesis `BLOCKED BY VERIFIED PRE-EXISTING ISSUES` is rejected for the evaluated HEAD:

- merge base passed both commands;
- HEAD added all six Helm failures;
- HEAD added all 14 mobile analyze diagnostics;
- the JdbcTemplate issue predates B2.1/platform work but does not predate the overall branch merge base.

No waiver, skip, ignore, rule relaxation, or path exclusion is valid. User condition 4 requires fixing these branch-introduced failures before merge-readiness can be reassessed.

## Required remediation

Because the merge-base comparison rejected the pre-existing-issue hypothesis, the branch-added failures were repaired instead of waived:

- `682c73d9` migrates the four branch-added growth/garden services from owned `JdbcTemplate` calls to MyBatis mappers and XML while preserving their service contracts. The production audit is now zero. Real PostgreSQL coverage proves aggregate boundaries, deterministic ordering, `LIMIT 5`, pending `LIMIT 20`, milestone timestamps, transaction/idempotency behavior, and unique-conflict error mapping.
- `2ef09be0` fixes the 14 analyzer diagnostics and the 13 test failures exposed after analysis became green. The latter comprised one canonical-route contract, five Mentor shell tests, one practice-scene label contract, two PhraseCard contracts, one app-boot contract, and three M006 closure contracts. No test was removed, skipped, disabled, or weakened.
- `e4f9f0e2` restores the active Kubernetes runbook and schema compatibility matrix required by the Helm gate. It also marks the legacy M006 S14 child chain as non-runnable historical material and identifies `bash ci/k8s-smoke.sh` as the current executable release-smoke front door.

The Mentor fixture keeps the real `PracticeRepository` and Isar database. Only its installation ID is in-memory because that UI test does not test file persistence. Teardown unmounts the widget tree, drains bounded async work, closes the repository, retries Windows directory deletion for at most five seconds, and rethrows the final failure. Independent review confirmed that cleanup and all five business assertions remain observable.

## Post-remediation verification

All commands below ran against the remediated branch content on 2026-07-16.

| Gate | Result |
| --- | --- |
| `python -m unittest test.tool.verify_spring_ai_2_backend_platform_test` | 19 passed |
| `python tool/verify_spring_ai_2_backend_platform.py` | exit 0 |
| CI-equivalent Spring AI dependency tree plus live verifier | every resolved `org.springframework.ai` artifact is `2.0.0`; exit 0 |
| `bash ci/backend-test.sh` | all six Maven reactor modules succeeded; exit 0 |
| `./backend/mvnw -f backend/pom.xml -B checkstyle:check` | zero violations in all six modules; exit 0 |
| `bash ci/k8s-smoke.sh` | 66 pass, 0 fail, 2 environment skips; exit 0 |
| `bash ci/mobile-analyze.sh` | 0 analyzer issues, 629 tests passed; exit 0 |
| `bash ci/mobile-r4-release-gates.sh` | 25 tests passed; policy-controlled full performance profile not requested; exit 0 |
| `git diff --check` | exit 0 |

Focused evidence also passed: the real-PostgreSQL mapper integration suite 2/2, M006 S14 fixture suite 9/9, Mentor shell suite 5/5, app boot suite 8/8, and the route/label/PhraseCard regressions. Separate reviewers approved the JDBC/MyBatis migration, the M006 truth update, and the mobile cleanup after their findings were corrected.

## Historical final status classification (evaluated HEAD `95b39d95`)

- **Backend platform/custom-scene prerequisite:** `APPROVED`.
- **Current branch complete repository CI:** local equivalents are `GREEN` after repairing branch-introduced failures. `BLOCKED BY VERIFIED PRE-EXISTING ISSUES` is not supported by the merge-base evidence.
- **Merge readiness:** ready for remote CI and branch-protection evaluation. These failures need neither a pre-existing-issue waiver nor a backend-only split; the remote required checks remain authoritative.
