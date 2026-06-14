# S08 Evidence Draft

| Slice | Command | Exit Code | Result | Verdict |
|-------|---------|-----------|--------|---------|
| S02/S05 | `cd mobile && flutter analyze` | 0 | 0 issues | PASS |
| S02/S05 | `cd mobile && flutter test test/smoke/` | 0 | 58/58 passed | PASS |
| S02/S05 | `cd mobile && flutter test -j 1 test/features/practice/garden_growth_home_test.dart` | 0 | 8/8 passed | PASS |
| S04/S05 | `cd mobile && flutter test -j 1 test/features/practice/garden_growth_shell_test.dart` | 0 | 5/5 passed | PASS |
| S03/S05 | `cd mobile && flutter test -j 1 test/features/shell/discover_screen_test.dart` | 0 | 6/6 passed | PASS |
| S06/S07 | `npm --prefix admin-web run typecheck` | 0 | `tsc --noEmit` clean | PASS |
| S07 | `npm --prefix admin-web run test:e2e -- tests/knowledge-ops.spec.ts` | N/A | Environment-blocked: no `docker-compose.yml` in the worktree; `admin-web/playwright.global-setup.ts` falls into compose-free mode and times out waiting for `http://127.0.0.1:8080/actuator/health`. This is an environment limitation, not a code defect. | DEFERRED |

## R001 / R034 / R008 Contract Evidence
- R001: `home-start-practice` key present in `HomeTodaySceneCard` — `garden_growth_home_test.dart` 8/8 passed.
- R034: `HomeTodaySceneCard` remains the first real `ListView` child and `GardenContinueCard` stays in Zone A — `garden_growth_home_test.dart` 8/8 passed and `garden_growth_shell_test.dart` 5/5 passed.
- R008: `hasRecoverableIssue` chip remains visible after density cleanup — `discover_screen_test.dart` 6/6 passed.
