# T6 Mobile Care Turn Acceptance / Release Readiness Review Plan

Date: 2026-07-02
Status: Draft for user review
Branch: `gsd/v0.1-milestone`
Base commit: `f8e524566856b33e9f1a6c371261180badb04e86`
Scope: acceptance / release-readiness review only. No code implementation, no commit.

## Current Milestone State Summary

T6 is not a product slice. It is the acceptance pass that decides whether the current `mobile/` mainline can be demonstrated as a complete care-turn vertical slice.

Target demo loop:

```text
今天 / 场景
  -> 现在说一句
  -> 听一下
  -> 我说了
  -> 宝宝反应
  -> 下一句照护支持
  -> 花园痕迹
```

Known completed milestones:

| Milestone | State | Commit / evidence |
| --- | --- | --- |
| T2 care_path facade | Completed and committed | `fa3bbcd4375fb8311e2e29754fd0c00529d8c96c` |
| T3 Today / Scene IA adapter | Completed and committed | `9fb5ddb966d9aee5a56d96ab38c0d197b852b29e` |
| T4 one-utterance loop | Completed and committed | `c440841cdce6c786b345b15dca91456db3a51b2f` |
| T5 Care Turn QA / Device Validation / UX Hardening | Completed and committed | `f8e524566856b33e9f1a6c371261180badb04e86` |

T5 touched only the mobile slice and its plan:

```text
docs/superpowers/plans/2026-07-01-t5-care-turn-qa-device-validation-ux-hardening-plan.md
mobile/lib/features/practice/presentation/screens/home_screen.dart
mobile/lib/features/practice/presentation/screens/practice_session_screen.dart
mobile/lib/features/practice/presentation/widgets/scene_reaction_chip_row.dart
mobile/lib/features/shell/presentation/screens/discover_screen.dart
mobile/lib/l10n/app_zh.arb
mobile/lib/l10n/app_localizations_zh.dart
mobile/test/features/practice/critical_ui_coverage_test.dart
mobile/test/tool/verify_care_path_copy_firewall_test.dart
mobile/test/tool/verify_t3_today_scene_copy_firewall_test.dart
```

Current explicit boundaries:

- Worktree is expected to be clean before T6 execution.
- `mobile/` is the review target.
- `mobile_v2/` is not回流主线 and must remain untouched.
- Backend must remain untouched.
- Reaction contract is already settled and must not be reopened.
- T6 may create an evidence report later if execution is approved, but this planning step creates only this plan document.

## T6 Scope Challenge

T6 should answer one question:

```text
Can the current mobile mainline be demoed as a care-turn vertical slice without hiding a broken core step?
```

Minimum complete T6:

1. Verify the Today entry reaches the real one-turn screen.
2. Verify the Scene entry reaches the real one-turn screen.
3. Verify the one-turn screen supports listen, said, five canonical baby reactions, next support, and Garden trace.
4. Verify route re-entry does not leak stale reaction or next-support state.
5. Verify supported viewport/text-scale cases keep controls visible, readable, and at least 48dp.
6. Verify copy firewalls still keep Today / Scene / one-turn visible copy out of lesson/progress/completion framing.
7. Run or record the full-known-baseline checks without treating already scoped-out issues as new blockers.
8. Run manual device validation or explicitly mark it as missing evidence.

T6 should not repair broad debt. If evidence finds a blocker, the review stops with a blocker report and asks for approval for a follow-up fix slice.

## What Already Exists

| Need | Existing evidence source | T6 decision |
| --- | --- | --- |
| care_path facade | `features/care_path` tests from T2 | Reuse as prior milestone evidence; do not retest every facade branch unless acceptance fails. |
| Today / Scene IA | `home_screen.dart`, `discover_screen.dart`, T3 copy firewall | Verify only demo-path behavior and labels. |
| One-turn care UI | `PracticeSessionScreen` after T4/T5 | Treat as the main acceptance target. |
| Route smoke | `critical_ui_coverage_test.dart` T5 route tests | Run targeted tests, not only direct widget pumps. |
| Viewport and touch target coverage | `critical_ui_coverage_test.dart` care-turn viewport matrix | Run targeted viewport tests. |
| Copy firewall | `verify_t3_today_scene_copy_firewall_test.dart`, `verify_care_path_copy_firewall_test.dart` | Run both. |
| Known old PhraseCard baseline | two full-file `critical_ui_coverage_test.dart` failures | Scope out unless they appear on the demo path. |
| Known analyzer debt | full `flutter analyze --no-pub` has 13 existing issues | Scope out unless a specific issue blocks demo. |
| NativeAssetsManifest race | prior parallel Flutter test caveat | Use serial commands; record if parallel-only. |

## User Loop Acceptance Checklist

All items below are demo blockers if they fail in the approved demo path.

### Entry From Today

- [ ] App opens to `今天` as the primary shell destination.
- [ ] Today current care node is visible and parent-facing.
- [ ] Primary CTA says `现在说一句` or equivalent care-turn copy, not practice/progress copy.
- [ ] Tapping Today CTA opens the real `/practice` route backed by `PracticeSessionScreen`.
- [ ] The opened route carries the expected `PracticeRouteArgs` from the current care moment.

### Entry From Scene

- [ ] Shell destination `场景` is visible and remains index 1.
- [ ] Scene browse/search/filter surface remains usable.
- [ ] A scene card CTA says `现在说一句`.
- [ ] Tapping Scene CTA opens the real one-turn screen.
- [ ] The opened route carries expected `spaceId` and `activityId`.

### One Care Turn

- [ ] Current utterance renders English, Chinese support text, and when-to-say copy.
- [ ] `听一下` is visible and tappable.
- [ ] `听一下` either plays audio or shows the existing graceful fallback; a silent no-op is a blocker.
- [ ] `我说了` is visible and tappable.
- [ ] Before `我说了`, reaction chips are not visible.
- [ ] After `我说了`, exactly the canonical reaction choices are available: `配合`, `犹豫`, `不想`, `没反应`, `其他`.
- [ ] Selecting a reaction records one local event, not duplicate events.
- [ ] After reaction save, `下一句照护支持` appears.
- [ ] After reaction save, Garden trace appears with `花园留痕` or equivalent trace copy.
- [ ] Back/exit returns without `PracticeCompletionView`, completion summary, step count, or progress framing.
- [ ] Re-entering the same route starts clean: no stale chips, no stale next support, no stale trace state before action.

### Language And Semantics

- [ ] Core flow does not expose `练习`, `课程`, `进度`, `完成`, `第 N 句`, `task`, `XP`, `streak`, `lesson`, `session`, `progress`, or `completion` as visible demo-path framing.
- [ ] Screen reader labels for listen, said, reaction chips, next support, and Garden trace are parent-facing.
- [ ] Wire values such as `cooperating`, `hesitant`, `resisting`, and `no_response` do not surface in semantics.

### Viewport And Touch

- [ ] 427x952dp at 1.0 text scale passes.
- [ ] 427x952dp at 1.3 text scale passes.
- [ ] 390x844dp at 1.3 text scale passes.
- [ ] `听一下`, `我说了`, and every reaction chip are at least 48dp in both dimensions.
- [ ] No horizontal overflow or clipped button/chip text appears during the demo path.

## Test Evidence Checklist

T6 evidence should be recorded as pass/fail with command, date/time, commit, and short notes. Do not summarize a failing command as "known" unless the exact failure matches the known scope-out register below.

### Required Passing Evidence

| Evidence | Required command class | Blocker if failed? |
| --- | --- | --- |
| one-turn screen listen -> said -> reaction -> next support -> Garden trace | targeted `critical_ui_coverage_test.dart` | Yes |
| viewport/touch target matrix | targeted `critical_ui_coverage_test.dart` | Yes |
| care-turn semantics only | targeted `critical_ui_coverage_test.dart` | Yes |
| Today CTA opens real one-turn route | targeted `critical_ui_coverage_test.dart` | Yes |
| Scene CTA opens real one-turn route | targeted `critical_ui_coverage_test.dart` | Yes |
| route re-entry/back stays one-turn clean | targeted `critical_ui_coverage_test.dart` | Yes |
| shell labels Today/Scene and Garden index | targeted `critical_ui_coverage_test.dart` | Yes |
| Today/Scene copy firewall | `verify_t3_today_scene_copy_firewall_test.dart` | Yes |
| care_path / one-turn copy firewall | `verify_care_path_copy_firewall_test.dart` | Yes |
| focused analyzer on T5-touched demo-path files | focused `flutter analyze --no-pub` | Yes |

### Awareness Evidence

| Evidence | Expected T6 handling |
| --- | --- |
| full `critical_ui_coverage_test.dart` | May fail only on the two registered PhraseCard stacking failures. Any additional failure is a blocker. |
| full `flutter analyze --no-pub` | May report exactly the 13 registered existing issues. Any issue that prevents build/install/demo, or any new demo-path issue, is a blocker. |
| parallel Flutter tests | Not a gate. NativeAssetsManifest race remains a tooling caveat unless it reproduces in serial focused commands. |

## Device / Manual Validation Checklist

Manual validation is required before calling the slice demo-ready. If no device is available, T6 should say `manual device evidence missing` and avoid a release-ready verdict.

### Device Metadata To Record

- [ ] Device or emulator model.
- [ ] OS version.
- [ ] `adb devices` output identifier.
- [ ] `adb shell wm size`.
- [ ] `adb shell wm density`.
- [ ] Text scale setting for each pass.
- [ ] App build mode: debug/profile/release.
- [ ] Commit: `f8e524566856b33e9f1a6c371261180badb04e86` or later explicitly approved commit.

### Manual Path A: Today Entry

- [ ] Launch app.
- [ ] Confirm `今天` tab is selected.
- [ ] Tap Today `现在说一句`.
- [ ] Confirm current utterance is visible.
- [ ] Tap `听一下`.
- [ ] Confirm audio or graceful fallback.
- [ ] Tap `我说了`.
- [ ] Confirm five reaction chips.
- [ ] Tap `配合`.
- [ ] Confirm next support appears.
- [ ] Confirm Garden trace appears.
- [ ] Back out and confirm no completion summary.

### Manual Path B: Scene Entry

- [ ] Open `场景`.
- [ ] Use one scene card CTA.
- [ ] Confirm the same one-turn sequence works.
- [ ] Exit before reaction once; re-enter and confirm no stale reaction chips.
- [ ] Complete one turn once; re-enter and confirm initial state is clean.

### Manual Path C: Accessibility Pressure

- [ ] Set text scale to about 1.3x.
- [ ] Repeat Today path.
- [ ] Repeat Scene path.
- [ ] Confirm buttons/chips are readable and not clipped.
- [ ] Confirm all actions are reachable by normal vertical scroll.
- [ ] Confirm no horizontal overflow banner appears.

### Manual Path D: Garden Trace Continuity

- [ ] After reaction, verify trace copy appears on one-turn screen.
- [ ] Navigate to `花园`.
- [ ] Confirm Garden can show a related trace/patch/flower state without crashing.
- [ ] If Garden trace is delayed or generic, record whether the one-turn screen still clearly tells the parent the moment was recorded.

## Known Scope-Out Issues Register

These issues are known at T6 planning time. They should be recorded, not fixed, unless the blocker test below is true.

| ID | Issue | Current handling | Becomes demo blocker only if |
| --- | --- | --- | --- |
| K1 | full `mobile/test/features/practice/critical_ui_coverage_test.dart` has two existing PhraseCard stacking failures: `Active PhraseCard stacks play affordance at high text scale` and `Active PhraseCard stacks play affordance in narrow width` | Scope out for T6. The T4/T5 one-turn screen is not supposed to use `PhraseCard`, and `verify_care_path_copy_firewall_test.dart` already guards against `PhraseCard(` in `PracticeSessionScreen`. | The demo path renders `PhraseCard`, the targeted care-turn viewport tests fail, or a PhraseCard failure is the only way to make demo controls readable. |
| K2 | full `flutter analyze --no-pub` has 13 existing issues | Scope out for T6. Run focused analyze on demo-path/T5-touched files as the T6 gate and capture full analyze as awareness evidence. | An analyzer issue prevents build/install/demo, appears in a T5/T6 demo-path file, or is newly introduced after `f8e52456`. |
| K3 | `NativeAssetsManifest.json` can race under parallel Flutter test execution | Use serial focused commands with `--concurrency=1`. Do not add sleeps or unrelated cleanup. | The same asset-manifest failure reproduces twice in the same serial focused command after a clean retry. |

## Release-Readiness Risk Matrix

| Risk | Probability | Impact | Gate / mitigation | Demo verdict if triggered |
| --- | --- | --- | --- | --- |
| Today CTA opens wrong scene or fallback | Medium | High | targeted Today route test + manual Path A | Block demo |
| Scene CTA only tests opener seam, not real route | Medium | High | targeted Scene real-route test + manual Path B | Block demo |
| `听一下` silently fails | Medium | Medium | widget test plus manual audio/fallback check | Block demo if silent; acceptable if graceful fallback |
| reaction save duplicates event on rapid tap | Low | High | one-turn widget test and notifier prior coverage | Block demo |
| next support does not appear after reaction | Medium | High | targeted one-turn test + manual Path A/B | Block demo |
| Garden trace absent after reaction | Medium | High | targeted one-turn test + manual Path D | Block demo |
| viewport clips core actions at 390dp / 1.3x | Medium | High | viewport matrix + manual Path C | Block demo |
| legacy progress/completion copy leaks into core flow | Medium | Medium | copy firewalls + manual scan | Block demo if visible in core loop |
| PhraseCard stacking baseline remains red | High | Low for T6 | keep registered as K1 | Not a blocker unless it enters demo path |
| full analyzer debt distracts review | High | Medium | focused analyze gate + K2 | Not a blocker unless demo-path/build-impacting |
| NativeAssetsManifest race makes parallel runs noisy | Medium | Medium | serial commands + retry policy | Not a blocker unless serial reproduction |
| `mobile_v2` confusion sends review to wrong tree | Low | High | scope guard checks and file-path review | Block review, not product |

## What Must Be Fixed Before A Demo

T6 must recommend a fix slice before demo if any of these are true:

1. Today or Scene cannot reach the real one-turn screen.
2. `听一下`, `我说了`, baby reaction, next support, or Garden trace is missing from the core loop.
3. Reaction chips are not the five approved labels or leak wire values to users.
4. A reaction save produces duplicate local events in the targeted flow.
5. Back/exit shows completion summary or old lesson/session progress.
6. Route re-entry shows stale reaction, stale next support, or stale trace state before action.
7. 427x952dp or 390x844dp at 1.3x clips core actions or violates 48dp touch targets.
8. Focused copy firewall fails on visible Today / Scene / one-turn copy.
9. Focused analyzer fails in T5-touched demo-path files.
10. Manual device validation cannot be performed and the user needs a live device demo, not only simulator/widget evidence.

Fix policy:

- If one of these appears during T6, stop and write the blocker in the review result.
- Do not fix it inside T6 without explicit approval.
- The follow-up fix slice must remain mobile-only unless the blocker clearly proves otherwise.

## What Can Wait Until Later

These should not block the T6 demo verdict:

- Full PhraseCard stacking baseline repair, as long as only K1 fails and the one-turn demo path does not render PhraseCard.
- Full `flutter analyze --no-pub` cleanup of the 13 known existing issues, unless one becomes a demo blocker under K2.
- Parallel Flutter test runner cleanup for NativeAssetsManifest, unless it reproduces serially.
- Today / Scene / Garden visual redesign.
- Garden/Growth broad information architecture or visual polish.
- Full internal rename from `practice` to `care_path`.
- `mobile_v2` backflow or migration.
- Backend reaction, sync, AI, or API work.
- New screenshots/goldens beyond manual evidence captures.
- Full integration-test automation of the entire user loop.
- Product features such as ASR/STT, dynamic phrase generation, sharing, analytics expansion, or new Garden mechanics.

## Explicitly Not In Scope

- No backend changes.
- No `mobile_v2` changes.
- No reaction contract changes.
- No new reaction type or reaction remapping.
- No new product capability.
- No Today visual redesign.
- No Scene visual redesign.
- No Garden visual redesign.
- No PhraseCard stacking baseline fix unless T6 explicitly proves it blocks the demo path.
- No full-analyze 13-issue cleanup unless T6 explicitly proves a specific issue blocks demo.
- No new API.
- No new storage or Isar collection.
- No ASR/STT.
- No dynamic practice generation.
- No routing framework migration.
- No broad localization rewrite.
- No broad screenshot/golden refresh.
- No commit from this planning step.

## Verification Commands

Run from PowerShell on Windows.

### Preflight

```powershell
cd C:\code\AI\baby-talk-2
git status --short
git rev-parse HEAD
git status --short -- backend mobile_v2
git diff --name-only -- backend mobile_v2
```

Expected:

- `git status --short` is clean before T6 execution, or only an approved T6 evidence report is dirty after execution.
- `git rev-parse HEAD` is `f8e524566856b33e9f1a6c371261180badb04e86` unless the user explicitly approved a later commit.
- backend and `mobile_v2` checks print no changed files.

### Targeted Care-Turn Acceptance Tests

Run these serially from `mobile/`.

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart `
    --plain-name "Practice session screen renders one-turn care path UI and records reaction"

  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart `
    --plain-name "Practice session screen fits"

  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart `
    --plain-name "Practice session screen exposes care-turn semantics only"

  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart `
    --plain-name "HomeScreen primary care CTA opens real one-turn route"

  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart `
    --plain-name "Discover scene CTA opens real one-turn route"

  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart `
    --plain-name "Practice route re-entry and back exit stay one-turn clean"

  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart `
    --plain-name "Shell labels use Today/Scene and Garden remains index 2"
} finally {
  Pop-Location
}
```

Expected: all commands pass. Any failure in this block is a T6 blocker.

### Scene Browse Smoke

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\shell\discover_screen_test.dart
} finally {
  Pop-Location
}
```

Expected: pass. This protects the Scene browse surface around the entry point.

### Copy Firewall

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\tool\verify_t3_today_scene_copy_firewall_test.dart

  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\tool\verify_care_path_copy_firewall_test.dart
} finally {
  Pop-Location
}
```

Expected: both pass.

### Focused Analyze Gate

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' analyze --no-pub `
    lib\features\practice\presentation\screens\home_screen.dart `
    lib\features\practice\presentation\screens\practice_session_screen.dart `
    lib\features\practice\presentation\widgets\scene_reaction_chip_row.dart `
    lib\features\shell\presentation\screens\discover_screen.dart `
    lib\l10n `
    test\features\practice\critical_ui_coverage_test.dart `
    test\features\shell\discover_screen_test.dart `
    test\tool\verify_t3_today_scene_copy_firewall_test.dart `
    test\tool\verify_care_path_copy_firewall_test.dart
} finally {
  Pop-Location
}
```

Expected: pass. Any issue in these paths is a T6 blocker.

### Full Baseline Awareness Checks

Run after required gates, not before.

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart

  & 'C:\software\flutter\bin\flutter.bat' analyze --no-pub
} finally {
  Pop-Location
}
```

Expected:

- Full `critical_ui_coverage_test.dart` may fail only on:
  - `Active PhraseCard stacks play affordance at high text scale`
  - `Active PhraseCard stacks play affordance in narrow width`
- Full `flutter analyze --no-pub` may report exactly the 13 known existing issues.
- Any additional failure or any build/demo-impacting issue escalates to blocker.

### Manual Device Commands

```powershell
cd C:\code\AI\baby-talk-2\mobile
adb devices
adb shell wm size
adb shell wm density
& 'C:\software\flutter\bin\flutter.bat' run -d <device-id>
```

Record the manual checklist results in the T6 evidence summary if execution is approved.

## T6 Review Tasks

- [ ] **T6.1 (P1)** - Preflight scope guard.
  - Verify HEAD, worktree, backend, and `mobile_v2` state.
  - Output: preflight evidence.

- [ ] **T6.2 (P1)** - Targeted automated acceptance.
  - Run the care-turn targeted commands and copy firewalls.
  - Output: pass/fail evidence for every core user-loop step.

- [ ] **T6.3 (P1)** - Focused analyzer gate.
  - Run focused analyze on T5-touched demo-path files.
  - Output: pass/fail evidence.

- [ ] **T6.4 (P1)** - Full baseline awareness.
  - Run the full known-baseline commands.
  - Output: exact comparison against K1/K2/K3.

- [ ] **T6.5 (P1)** - Device/manual validation.
  - Run the Today and Scene manual paths on a real device or emulator.
  - Output: device metadata and checklist result.

- [ ] **T6.6 (P1)** - Release-readiness verdict.
  - Classify as `demo-ready`, `demo-ready-with-known-scope-outs`, or `blocked`.
  - Output: concise evidence report. No code patch unless separately approved.

## Completion Summary Template

Use this exact shape when T6 is executed:

```markdown
# T6 Completion Summary

- Scope guard: pass/fail
- Targeted care-turn tests: pass/fail
- Copy firewall: pass/fail
- Focused analyze: pass/fail
- Full critical UI baseline: pass/fail; only K1 failures? yes/no
- Full analyze baseline: pass/fail; exactly 13 known issues? yes/no
- NativeAssetsManifest serial caveat: reproduced/not reproduced
- Device/manual validation: pass/fail/missing
- Demo verdict: demo-ready / demo-ready-with-known-scope-outs / blocked
- Blockers: list or none
- Follow-ups that can wait: list
```

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | clear, may be stale by commit | Care-path strategic supersession was approved before T2-T5; T6 does not add product scope. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | Skipped; user asked for a planning document only and did not authorize subagents or outside review. |
| Eng Review | `/plan-eng-review` | Architecture & tests | 1 | draft_clear | T6 is accepted as review-only. Core gate is targeted care-turn evidence plus manual device validation; known PhraseCard/analyze/tooling issues are scope-out unless they block demo. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | Not required because T6 forbids visual redesign. Manual validation may later recommend a design review if visual demo blockers appear. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Not required; serial test policy and baseline caveats are included in this plan. |

**UNRESOLVED:** 0

**VERDICT:** ENG PLAN DRAFT CLEAR FOR REVIEW - T6 may proceed after user approval as a mobile-only acceptance / release-readiness review. It may produce evidence and a verdict, but it must not implement code, modify backend, modify `mobile_v2`, change the reaction contract, add functionality, redesign Today/Scene/Garden, fix PhraseCard stacking baseline, or clean up the 13 full-analyze issues unless a specific item is proven to block the demo path and the user approves a follow-up fix slice.
