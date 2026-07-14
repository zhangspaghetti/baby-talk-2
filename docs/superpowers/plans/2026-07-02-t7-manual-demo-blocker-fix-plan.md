# T7 Manual Demo Blocker Fix Plan

Date: 2026-07-02
Status: Draft for user review
Branch: `gsd/v0.1-milestone`
Planning base commit: `ac101962`
T6 code evidence commit recorded in report: `f8e52456`
Scope: plan only. No implementation, no commit.

## T7 Scope Challenge

T7 should fix exactly one P0 from T6:

```text
1.3x accessibility pressure hit BOTTOM OVERFLOWED BY 7.0 PIXELS during onboarding practice.
```

This is not a care-turn contract problem. T6 automated care-turn evidence passed, and the current care-turn viewport matrix already covers `PracticeSessionScreen` at `427x952dp @ 1.3` and `390x844dp @ 1.3`.

It is still a release-readiness blocker because a fresh-install manual demo reaches onboarding before Today / Scene can be revalidated. The smallest complete T7 is therefore:

1. Reproduce and localize the overflow inside `mobile/` onboarding practice.
2. Apply the smallest layout accommodation needed for 1.3x text.
3. Add one focused regression test for the exact viewport/text-scale path.
4. Rerun only the T6 manual blocker subset.
5. Record whether T6 rerun is unblocked.

Scope should not expand into onboarding redesign, Garden continuity, audio proof, PhraseCard baseline, full analyze cleanup, backend, or `mobile_v2`.

## T6 Blocker Reproduction Plan

Use the exact manual pressure profile from T6 before changing code.

Observed T6 device profile:

```text
Device: emulator-5554
OS: Android 15 / API 35
Model: sdk_gphone64_x86_64
wm size: 1170x2532 override on 1280x2856
wm density: 480
Effective dp viewport: 390x844
Text scale sequence: 1.0 -> 1.3 -> 1.0
```

Reproducer:

1. Confirm preflight:

```powershell
cd C:\code\AI\baby-talk-2
git status --short
git rev-parse --short HEAD
git status --short -- backend mobile_v2
git diff --name-only -- backend mobile_v2
```

2. Set device pressure:

```powershell
adb devices
adb shell wm size
adb shell wm density
adb shell settings put system font_scale 1.3
adb shell settings get system font_scale
```

3. Start from onboarding:

```powershell
adb shell pm clear com.babytalk.mobile
cd C:\code\AI\baby-talk-2\mobile
& 'C:\software\flutter\bin\flutter.bat' run -d emulator-5554
```

4. Manual path:

```text
fresh install
  -> onboarding scene screen
  -> tap a scene card, preferably bath because it is the default T6 path
  -> onboarding practice initial phrase state
  -> confirm no overflow before action
  -> tap "我 说 了"
  -> reaction picker state
  -> confirm whether BOTTOM OVERFLOWED BY 7.0 PIXELS appears
  -> if needed, tap each reaction option once in separate runs
```

Primary suspected trigger is the reaction picker state, not the initial phrase state. The fixed card height and scaled two-line label line up with a 5-8px overflow.

## Suspected Code Paths / Screens To Inspect

Primary path:

```text
BabyTalkApp
  -> GoRoute /onboarding
  -> OnboardingSceneScreen
  -> context.push('/onboarding/practice')
  -> OnboardingPracticeScreen
  -> _BottomActionBar
  -> _ReactionArea
  -> _ReactionCard
```

Files and line anchors:

| File | Why inspect |
| --- | --- |
| `mobile/lib/app/app.dart:401` | `/onboarding/practice` resolves to `OnboardingPracticeScreen`; `/practice` at `app.dart:416` resolves to the separate care-turn `PracticeSessionScreen`. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart` | Fresh-install route into onboarding practice; confirms this is onboarding, not Today/Scene. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart:45` | Uses `OnboardingWarmScaffold` with fixed `bottomNavigationBar`. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart:54` | Main practice content is a `ListView`, so body content can scroll. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart:62` and `:67` | Reaction state uses two 48dp spacers before/after mentor bubble. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart:83` | Reaction picker enters `_ReactionArea`. |
| `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart:316` | `_ReactionCard` has fixed `height: 92`, likely too short at 1.3x for the longest label. |
| `mobile/lib/features/onboarding/domain/models/baby_reaction.dart:19` | Longest label is `没反应也没关系`, likely wraps to two lines. |
| `mobile/lib/features/onboarding/presentation/widgets/onboarding_design_widgets.dart:218` | `OnboardingOutlinedButton` has fixed 56dp height in the bottom action bar. |
| `mobile/test/features/practice/critical_ui_coverage_test.dart:219` | Existing viewport test pattern to reuse for the new onboarding regression. |
| `mobile/test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart` | Existing onboarding test style and provider override pattern. |

Boundary judgment:

- This sits at the onboarding-practice / legacy onboarding route boundary.
- It is not the T4/T5 care-turn route unless reproduction proves the overflow also appears after entering `/practice`.
- It is not K1 PhraseCard unless the overflow stack trace points at `PhraseCard`; current onboarding practice uses `_PhraseDisplay`, not `PhraseCard`.

## Minimal Fix Strategy Options

Recommendation: choose option A unless reproduction proves the bottom CTA, not reaction cards, is the source.

| Option | Change | Completeness | Risk |
| --- | --- | --- | --- |
| A | Replace `_ReactionCard` fixed `height: 92` with a min-height or slightly taller constrained layout that can grow with text scale. Keep the 3-card row and current visual structure. | 9/10 | Smallest likely fix for the exact 7px overflow; preserves existing route and copy. |
| B | Convert `_ReactionArea` from a single `Row` to a `Wrap` or vertical list at narrow/high text scale. | 10/10 | More resilient, but a bigger visual behavior change than the evidence currently justifies. |
| C | Reduce reaction label text size, icon size, or force tighter line height at 1.3x. | 4/10 | Avoids overflow by resisting accessibility scaling; use only as a last resort for a single decorative sub-label. |
| D | Move `_BottomActionBar` into the scroll body or add larger bottom scroll padding. | 6/10 | Useful if CTA reachability is the actual blocker, but it does not explain a fixed-card 7px bottom overflow. |
| E | Broad onboarding layout redesign. | 2/10 | Explicitly out of scope for T7. |

Expected implementation shape for option A:

```text
_ReactionCard
  fixed 92 height
    -> ConstrainedBox(minHeight: 92 or 100/104)
    -> child can grow under text scale
    -> row height follows tallest card
    -> ListView absorbs extra vertical space by scrolling
```

If reproduction shows overflow in the bottom action bar instead, use the same principle there:

```text
OnboardingOutlinedButton
  fixed 56 height
    -> minHeight 56 with vertical padding or text-safe alignment
```

Do not solve this with global text scale overrides.

## Test Plan

Add one focused regression test file:

```text
mobile/test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart
```

Test cases:

1. `OnboardingPracticeScreen fits 390x844dp @ 1.3 before and after said action`
   - Set `tester.view.devicePixelRatio = 1.0`.
   - Set `tester.view.physicalSize = Size(390, 844)`.
   - Set `tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3`.
   - Override `onboardingSessionProvider` with `OnboardingSessionNotifier(phraseService: ScenePhraseService())`.
   - Call `notifier.selectScene(PracticeScene.bath)` before pump.
   - Pump `MaterialApp` with `AppTheme.build()` and `OnboardingPracticeScreen`.
   - Assert `tester.takeException()` is null.
   - Assert `我 说 了` is visible or scrollable to.
   - Tap `我 说 了`.
   - Pump.
   - Assert `tester.takeException()` is null.
   - Assert `开心回应`, `玩水了`, and `没反应也没关系` are visible or scrollable to.

2. Optional if the first test exposes edge fragility: repeat at `427x952dp @ 1.3`.

The test should not depend on backend, Isar, audio, `/practice`, Garden, or `mobile_v2`.

Coverage diagram:

```text
CODE PATHS                                      USER FLOWS
[+] OnboardingPracticeScreen                    [+] Fresh install onboarding practice
  ├── [GAP] initial phrase state @ 390x844/1.3     ├── scene selected -> phrase visible
  ├── [GAP] bottom CTA visible/reachable           ├── tap "我 说 了"
  ├── [GAP] reaction picker @ 390x844/1.3          └── reaction labels visible, no overflow
  └── [N/A] complete navigation                    [+] T6 care-turn route
                                                  └── already covered by critical_ui_coverage_test

COVERAGE TARGET: 3/3 onboarding blocker paths covered after T7.
QUALITY TARGET: behavior regression, not screenshot-only.
```

Failure modes to test:

| Failure mode | Test assertion |
| --- | --- |
| Fixed reaction card overflows under 1.3x text | `tester.takeException()` remains null after tapping `我 说 了`. |
| CTA is hidden behind fixed bottom bar | `ensureVisible` or direct finder assertion proves `我 说 了` can be reached. |
| Longest reaction label is clipped | `没反应也没关系` is visible or scrollable to after action. |
| Fix accidentally touches care-turn route | Existing T6 targeted `PracticeSessionScreen` viewport test still passes. |

## Manual Validation Rerun Plan

T7 manual rerun is intentionally smaller than full T6.

Phase 1 - blocker proof:

```text
font scale 1.3
fresh install
onboarding scene -> onboarding practice
initial phrase state: no overflow
tap "我 说 了"
reaction state: no overflow
longest reaction label readable or reachable
bottom CTA visible or reachable
```

Phase 2 - T6 manual blocker subset:

```text
font scale stays 1.3
complete or reuse completed onboarding snapshot
Today path:
  今天 -> 现在说一句 -> one-turn screen
Scene path:
  场景 -> scene card 现在说一句 -> one-turn screen
One-turn path:
  听一下 -> 我说了 -> 配合 -> 下一句照护支持 -> 花园留痕
```

Expected T7 verdict language:

- If onboarding overflow is gone and Today / Scene / one-turn subset passes: `T6 rerun unblocked for P0; P1 Garden/audio evidence gaps remain`.
- If onboarding overflow is gone but Today / Scene / one-turn shows a new P0: `T6 still blocked by new manual P0`, with a separate follow-up plan.
- If overflow persists: `T7 fix failed`, continue localizing within onboarding practice only.

Garden continuity and audio output may be observed during Phase 2, but T7 should not fix or close them unless the user explicitly asks. They remain P1 evidence gaps from T6.

## File-Level Implementation Plan

Implementation should be sequential. No parallelization opportunity: all likely edits touch the onboarding UI and its focused test.

| Step | File | Action |
| --- | --- | --- |
| 1 | `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart` | Localize overflow source. Prefer changing `_ReactionCard` from fixed height to text-scale-tolerant min height. Only touch `_BottomActionBar` if reproduction proves it is the source. |
| 2 | `mobile/lib/features/onboarding/presentation/widgets/onboarding_design_widgets.dart` | Optional only if bottom CTA fixed height is the proven source. Convert fixed button height to min-height/padding without changing public copy or colors. |
| 3 | `mobile/test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart` | Add new 1.3x viewport regression for initial and reaction states. Reuse local helpers similar to `critical_ui_coverage_test.dart`. |
| 4 | `docs/superpowers/reports/2026-07-02-t7-manual-demo-blocker-fix-evidence.md` | After implementation and validation, record automated + manual evidence and whether T6 rerun is unblocked. Do not create this evidence report during this planning step. |

Implementation guardrails:

- No backend files.
- No `mobile_v2` files.
- No reaction contract files.
- No new `CareReactionType`.
- No Garden/Growth visual files.
- No broad onboarding redesign.
- No PhraseCard baseline work unless stack trace proves it is on the demo path.

## Explicitly Not In Scope

- Backend changes.
- `mobile_v2` changes.
- Reaction contract changes.
- New `CareReactionType`.
- Garden/Growth visual refactor.
- Garden continuity P1 fix.
- Audio aurally-confirmed P1 fix.
- PhraseCard stacking baseline fix, unless reproduction proves the P0 overflow is from demo-path `PhraseCard`.
- Full analyze 13-issue cleanup.
- Onboarding redesign.
- Today visual redesign.
- Scene visual redesign.
- Garden visual redesign.
- Routing framework migration.
- New onboarding product capability.
- New screenshots/goldens unless needed as manual evidence.
- Commit from this planning step.

## Verification Commands

Run from PowerShell.

Preflight:

```powershell
cd C:\code\AI\baby-talk-2
git status --short
git rev-parse --short HEAD
git status --short -- backend mobile_v2
git diff --name-only -- backend mobile_v2
```

Focused onboarding regression after implementation:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\onboarding\presentation\screens\onboarding_practice_screen_test.dart
} finally {
  Pop-Location
}
```

Focused analyze after implementation:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' analyze --no-pub `
    lib\features\onboarding\presentation\screens\onboarding_practice_screen.dart `
    lib\features\onboarding\presentation\widgets\onboarding_design_widgets.dart `
    test\features\onboarding\presentation\screens\onboarding_practice_screen_test.dart
} finally {
  Pop-Location
}
```

Existing T6 care-turn viewport guard:

```powershell
$env:CI='true'
$env:DART_SUPPRESS_ANALYTICS='true'
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
    test\features\practice\critical_ui_coverage_test.dart `
    --plain-name "Practice session screen fits"
} finally {
  Pop-Location
}
```

T6 manual blocker subset commands:

```powershell
adb devices
adb shell wm size
adb shell wm density
adb shell settings put system font_scale 1.3
adb shell settings get system font_scale
adb shell pm clear com.babytalk.mobile
Push-Location C:\code\AI\baby-talk-2\mobile
try {
  & 'C:\software\flutter\bin\flutter.bat' run -d emulator-5554
} finally {
  Pop-Location
}
```

Restore device text scale when done:

```powershell
adb shell settings put system font_scale 1.0
adb shell settings get system font_scale
```

Expected verification result:

- New onboarding regression passes.
- Focused analyze passes.
- Existing care-turn viewport guard still passes.
- Manual onboarding practice at 1.3 has no visible overflow.
- Manual Today / Scene / one-turn subset can complete at 1.3.
- `backend/` and `mobile_v2/` remain clean.

## What Already Exists

| Need | Existing source | T7 decision |
| --- | --- | --- |
| Care-turn viewport coverage | `mobile/test/features/practice/critical_ui_coverage_test.dart` | Reuse as guard; do not duplicate care-turn tests in onboarding suite. |
| Onboarding provider test pattern | `mobile/test/features/onboarding/presentation/screens/onboarding_name_screen_test.dart` | Reuse `onboardingSessionProvider` override style. |
| Exact manual evidence | `docs/superpowers/reports/2026-07-02-t6-mobile-care-turn-acceptance-evidence.md` | Treat the P0 as authoritative; do not re-open P1 gaps as T7 scope. |
| Known scope-outs | T6 plan K1/K2/K3 register | Preserve all three unless direct proof links one to the P0. |

## Implementation Tasks

- [ ] **T7.1 (P0, human: ~20min / CC: ~5min)** - Reproduce and localize onboarding 1.3x overflow.
  - Surfaced by: T6 manual release-readiness blocker.
  - Files: inspect onboarding practice and design widgets only.
  - Verify: manual repro path or new failing widget regression before fix.

- [ ] **T7.2 (P0, human: ~30min / CC: ~10min)** - Apply minimal onboarding layout accommodation.
  - Surfaced by: likely `_ReactionCard(height: 92)` at 1.3x.
  - Files: `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart`; optional `onboarding_design_widgets.dart` only if bottom CTA is proven source.
  - Verify: no Flutter overflow in focused widget test.

- [ ] **T7.3 (P0, human: ~30min / CC: ~10min)** - Add onboarding-practice 1.3x regression.
  - Surfaced by: missing onboarding practice viewport coverage.
  - Files: `mobile/test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart`.
  - Verify: focused onboarding test command passes.

- [ ] **T7.4 (P0, human: ~45min / CC: evidence only)** - Rerun T6 manual blocker subset.
  - Surfaced by: T6 blocked before Today / Scene 1.3x revalidation.
  - Files: evidence report only after implementation.
  - Verify: onboarding practice, Today path, Scene path, one-turn path at 1.3x.

## Completion Summary Template

Use this exact shape after implementation:

```markdown
# T7 Completion Summary

- Scope guard: pass/fail
- Overflow localized to: file/widget/state
- Fix strategy used: A/B/C/D
- Onboarding 1.3x regression: pass/fail
- Focused analyze: pass/fail
- Existing care-turn viewport guard: pass/fail
- Manual onboarding practice at 1.3x: pass/fail
- Manual Today path at 1.3x: pass/fail
- Manual Scene path at 1.3x: pass/fail
- Manual one-turn path at 1.3x: pass/fail
- T6 rerun unlocked: yes/no
- Remaining P1 evidence gaps: Garden continuity, audio aural confirmation
- Scope-outs preserved: K1, K2, K3
```

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | clear, may be stale by commit | Prior care-path scope remains valid; T7 is a narrow demo blocker fix, not product expansion. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | Skipped because the user requested a plan document only and did not explicitly authorize subagents or outside review. |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | draft_clear | Scope accepted as a mobile-only P0 fix plan. Main finding: onboarding practice lacks 1.3x viewport regression and likely over-constrains reaction cards. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | Not required before implementation because T7 forbids onboarding redesign; a design review can wait unless the minimal fix visibly changes the interaction. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Not required; commands and evidence shape are explicit. |

- **UNRESOLVED:** 0
- **VERDICT:** ENG PLAN DRAFT CLEAR FOR REVIEW. T7 should proceed only after user approval, and should remain limited to onboarding practice overflow localization, a minimal mobile UI fix, one focused regression test, and the T6 manual blocker subset rerun.

