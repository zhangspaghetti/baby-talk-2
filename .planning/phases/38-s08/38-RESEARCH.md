# S08 Research: Proof refresh and archival follow-through

**Calibration: Light** — All patterns are established, all code changes are already in place from S02-S07, and all verification commands are known. This slice is a run-commands-and-record-evidence operation, not a design or architecture task.

## Summary

S08 has one job: run the verification commands for every code slice that changed (S02-S07), record pass/fail evidence, note any environment-limited deferrals, and append the results to `docs/reviews/m009-autoplan-2026-04-26.md`. No code changes are expected. If a verification fails, the task is to investigate and fix, not to accept failure.

## Requirements Owned

- **R001** (supporting, via S02/S05): `home-start-practice` Key in HomeTodaySceneCard must be present in the DOM — garden_growth_home_test.dart asserts this.
- **R034** (supporting, via S02/S04/S05): HomeTodaySceneCard as first real ListView child; GardenContinueCard in Zone A — both test suites assert this.
- **R008** (supporting, via S03/S05): `hasRecoverableIssue` chip preserved in DiscoverActivityCard — discover_screen_test.dart asserts this.

## Implementation Landscape

### What changed (S02-S07)

All code changes are in place in the worktree:

| Slice | Changed files | Key structural assertion |
|-------|--------------|--------------------------|
| S02 | `mobile/lib/features/practice/presentation/screens/home_screen.dart` | HomeTodaySceneCard at ListView.children[1], warmShadowMd Container decoration |
| S03 | `mobile/lib/features/shell/presentation/screens/discover_screen.dart` | hero note removed, chip row removed, footer container stripped; R008 chip preserved |
| S04 | `mobile/lib/features/shell/presentation/screens/garden_screen.dart` | GardenContinueCard at line 75, HouseholdSharedContextCard at line 100 (Zone A < Zone C) |
| S05 | 12 extracted widget files across `shell/presentation/widgets/` and `practice/presentation/widgets/`; 3 screen orchestrators slimmed | `home-start-practice` Key in `home_today_scene_card.dart` line 95; `garden-continue-card` Key in `garden_continue_card.dart` line 42 |
| S06 | `admin-web/src/layout/AdminLayout.tsx` | `destroyInactivePanel={false}` + `defaultActiveKey={[]}` present; all testids (`session-user`, `workspace-current`, `session-role`) remain in DOM |
| S07 | `admin-web/src/pages/KnowledgeOpsPage.tsx` (249 lines), `IngestionSurface.tsx`, `PalaceRagSurface.tsx`, `KgSurface.tsx`, `knowledgeOpsUtils.ts` | 0 useState in KnowledgeOpsPage.tsx; 1 useSearchParams in KnowledgeOpsPage.tsx; none in surfaces |

All structural assertions confirmed by direct grep (line numbers, counts, key presence).

### Target file for evidence write-back

`docs/reviews/m009-autoplan-2026-04-26.md` — currently 719 lines, ending at `### Evidence Sources Used`. No validation evidence section exists yet. S08 appends `## S08 Validation Evidence` at the end of the file.

### Verification commands

#### Mobile (Git Bash, from worktree root)

```bash
cd mobile && flutter analyze
cd mobile && flutter test test/smoke/
cd mobile && flutter test -j 1 test/features/practice/garden_growth_home_test.dart
cd mobile && flutter test -j 1 test/features/practice/garden_growth_shell_test.dart
cd mobile && flutter test -j 1 test/features/shell/discover_screen_test.dart
```

Expected pass counts (from S02-S05 summaries):

- `flutter analyze` — 0 issues
- `flutter test test/smoke/` — 58/58
- `garden_growth_home_test.dart` — 8/8 (includes S02 warmShadowMd test; S05 R001/R034 contract)
- `garden_growth_shell_test.dart` — 5/5 (S04 zone ordering; S05 continuity contract)
- `discover_screen_test.dart` — 6/6 (S03 density regression; S05 R008 chip)

#### Admin (from worktree root)

```bash
npm --prefix admin-web run typecheck
```

Expected: exit 0 (tsc --noEmit clean).

**Note on path**: Must run `npm --prefix admin-web run typecheck` from the worktree root, NOT `cd admin-web && npm run typecheck`. The latter requires a lockfile at the subdirectory root and is unreliable on this Windows setup.

#### E2E (deferred — environment blocked)

`npm --prefix admin-web run test:e2e -- tests/knowledge-ops.spec.ts` is deferred. The worktree has no `docker-compose.yml`, so `playwright.global-setup.ts` enters compose-free mode and times out waiting for `127.0.0.1:8080`. This is an environment limitation, not a code defect. It must be noted in the validation evidence section, not silently omitted.

## Recommendation

S08 decomposes into two tasks:

**T01 — Run all verifiable checks and collect evidence**
Run each command above, capture exit codes and test counts. If any command fails, investigate and fix before recording (this is proof refresh, not proof fabrication). Record the literal exit code and test count for each command.

**T02 — Append validation evidence section to autoplan**
Append `## S08 Validation Evidence` to `docs/reviews/m009-autoplan-2026-04-26.md`. The section must include:

- Per-slice table with: command, exit code, test count/pass, verdict
- Explicit note for E2E deferred (environment-blocked, not code failure)
- S08 Checklist sign-off (all three acceptance items from the autoplan file)

## Constraints

1. **Karpathy surgical-change rule**: Only append to the autoplan — do not rewrite existing sections. The `## S08 Validation Evidence` section goes after `### Evidence Sources Used`.
2. **No code changes expected**: If all prior slice work is correct, every command should pass. Investigation and a minimal fix are allowed if one command fails; reopening completed slices is not.
3. **Windows/Git Bash**: `cd mobile && flutter ...` works from worktree root in Git Bash. `npm --prefix ...` works from worktree root in cmd.exe or Git Bash. Avoid bash negation (`! grep`) and `set -e` patterns.
4. **Evidence format**: Record literal outputs — exact line counts, exact pass counts, exact exit codes. Do not summarize ambiguously.

## Skills Discovered

No new skills needed — this is a known-pattern validation slice using Flutter and TypeScript tooling already established in prior slices.
