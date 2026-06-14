# Task 0 Keep/Drop Decisions (2026-05-30)

## Snapshot Commands Run
- `git status --short`
- `git diff --stat`
- `git ls-files --others --exclude-standard .`
- `cd mobile && flutter test test/widget_test.dart`
- `git diff --cached --name-only`
- `$v1='docs/superpowers/reports/2026-05-30-backend-baseline-output.txt'; $v2='docs/superpowers/reports/2026-05-30-backend-baseline-output-v2.txt'; "v1=$((Get-Content $v1).Count)"; "v2=$((Get-Content $v2).Count)"`

## Index Safety Check
- `git diff --cached --name-only` returned no output.
- All git commands used in this check were read-only/non-destructive inspection commands.
- Explicitly not used: `git reset --hard`, `git checkout --`.
- Conclusion: no files were staged during Task 0 execution.

## Keep/Drop Decision Table

| Path | Decision | Evidence | Rationale |
|---|---|---|---|
| `.metadata` | DROP_OR_IGNORE | Untracked in inventory snapshot. | Flutter tool metadata; normally local/ephemeral and not needed for repo history. |
| `baby_talk_worktree_root.iml` | DROP_OR_IGNORE | Untracked in inventory snapshot. | IDE IntelliJ module file; local machine artifact. |
| `android/baby_talk_worktree_root_android.iml` | DROP_OR_IGNORE | Untracked in inventory snapshot. | IDE Android module file; local machine artifact. |
| `docs/superpowers/plans/2026-05-30-garden-growth-backend-persistence.md` | DROP_FOR_THIS_COMMIT_SCOPE | `git log --oneline -- <file>` produced no history; file content is a forward implementation plan with unchecked tasks. | Does not show as already-landed work artifact; treat as planning draft unless explicitly requested. |
| `docs/superpowers/reports/2026-05-30-backend-baseline-output-v2.txt` | DROP_FOR_THIS_COMMIT_SCOPE | Tracked v1 exists: `docs/superpowers/reports/2026-05-30-backend-baseline-output.txt`; raw count command output: `v1=3919`, `v2=1624` (from `Get-Content ... .Count`). | Insufficient evidence that v2 supersedes v1; keep out until supersession criteria are explicit. |
| `analysis_options.yaml` | DROP_FOR_THIS_COMMIT_SCOPE | Untracked; no git history (`git ls-files` and `git log` empty). | Root Flutter runner adoption not established by committed history. |
| `android/**` | DROP_FOR_THIS_COMMIT_SCOPE | Root status shows `?? android/`; representative samples exist but are untracked: `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `android/settings.gradle.kts` (`exists=True`, `tracked=False`). | Extrapolation rule: when git short status reports only parent dir as untracked (`?? android/`) and representative files across manifest/build/settings are all untracked, treat the entire subtree as one untracked scaffold until explicit tracking/move commits appear. |
| `lib/main.dart` | DROP_FOR_THIS_COMMIT_SCOPE | Untracked; no git history. | Same root-runner pattern as above; not confirmed as intentional adoption. |

## Baseline Blocker Signature
Command: `cd mobile && flutter test test/widget_test.dart`

Result: FAIL (exit code 1)

First failure signature:
- `lib/app/providers/repository_providers.dart:452:50: Error: The getter 'wireValue' isn't defined for the type 'BabyReactionType'.`
- Failing access: `reactionType: e.reactionType.wireValue`
