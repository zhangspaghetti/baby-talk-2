# T7 Manual Demo Blocker Fix Evidence

Date: 2026-07-02
HEAD: `ac101962`
Scope: P0-only onboarding practice overflow fix. No commit created.

## Summary

- T7.1 reproduce/localize: PASS.
- T7.2 minimal fix: PASS.
- T7.3 regression test: PASS.
- T7.4 manual blocker subset rerun: PASS.
- T6 P0 rerun status: unblocked for the 1.3x overflow P0.

## Overflow Localization

Repro profile:

- Device/widget viewport: `390x844dp`.
- Text scale: `1.3`.
- Path: fresh onboarding -> bath scene -> onboarding practice -> tap `我 说 了` -> reaction picker.

Failing pre-fix widget regression produced:

```text
FlutterError:<A RenderFlex overflowed by 7.0 pixels on the bottom.>
```

Render tree localization:

- File: `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart`.
- State: `OnboardingPracticeScreen` reaction picker state after tapping `我 说 了`.
- Widget: `_ReactionCard`, specifically the `Column` inside the third reaction card for `BabyReaction.noResponse`.
- Longest label: `没反应也没关系`.
- Cause: fixed card height `92` left only `70dp` inner height after padding; at 1.3x the 34dp icon + 7dp gap + 36dp two-line label required about `77dp`.
- Bottom CTA was checked in the same render tree and was not the overflow source: `_BottomActionBar` measured `78dp` outer / `56dp` inner button without overflow.

## Fix Strategy

Used plan option A:

```text
_ReactionCard
  fixed height: 92
    -> constraints: BoxConstraints(minHeight: 92)
```

The row can now grow with the tallest reaction card, and the surrounding `ListView` absorbs the extra height. No copy, color, route, reaction contract, global text scale, or onboarding flow changes were made.

## Automated Evidence

Focused onboarding regression:

```powershell
cd C:\code\AI\baby-talk-2\mobile
flutter test --no-pub --concurrency=1 test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart
```

Result:

```text
All tests passed.
```

Focused analyze:

```powershell
cd C:\code\AI\baby-talk-2\mobile
flutter analyze --no-pub lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart lib/features/onboarding/presentation/widgets/onboarding_design_widgets.dart test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart
```

Result:

```text
No issues found.
```

Existing T6 care-turn viewport guard:

```powershell
cd C:\code\AI\baby-talk-2\mobile
flutter test --no-pub --concurrency=1 test/features/practice/critical_ui_coverage_test.dart --plain-name "Practice session screen fits"
```

Result:

```text
Practice session screen fits 427x952dp @ 1.0 with 48dp controls
Practice session screen fits 427x952dp @ 1.3 with 48dp controls
Practice session screen fits 390x844dp @ 1.3 with 48dp controls
All tests passed.
```

Format and diff checks:

```powershell
dart format --output=none --set-exit-if-changed lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart
git diff --check
```

Result: PASS.

Scope guard:

```powershell
git diff --name-only -- backend mobile_v2
git status --short -- backend mobile_v2
```

Result: no output. `backend/` and `mobile_v2/` remain untouched.

Status note: `docs/superpowers/plans/2026-07-02-t7-manual-demo-blocker-fix-plan.md`
was already an untracked, user-approved plan document before implementation
started. It was read for alignment and not modified as part of this fix.

## Manual Device Evidence

Device:

```text
emulator-5554
Android 15 / API 35
wm size: Physical 1280x2856, Override 1170x2532
wm density: 480
Effective viewport: 390x844dp
font_scale during validation: 1.3
font_scale restored after validation: 1.0
```

Manual onboarding practice at 1.3:

- Fresh onboarding scene opened.
- Bath scene tapped.
- Initial phrase state showed `I love bath time with you.` and bottom `我 说 了` CTA without overflow.
- Tapped `我 说 了`.
- Reaction picker state showed no Flutter overflow stripes.
- After a small scroll, `开心回应`, `玩水了`, and `没反应也没关系` were visible/readable.
- `adb logcat -d` search for `RenderFlex overflowed`, `BOTTOM OVERFLOWED`, and `overflowed by` returned no matches after the manual run.

Manual Today path at 1.3:

- Completed/skipped onboarding via `稍后再说` -> `去首页看看`.
- Today tab opened and displayed the Bath time card.
- `现在说一句` CTA was reachable after scrolling.
- Tapping it opened the one-turn `今日一句` screen.

Manual Scene path at 1.3:

- Bottom `场景` tab opened.
- First scene card showed `现在说一句`.
- Tapping it opened the one-turn `今日一句` screen.

Manual one-turn path at 1.3:

- `听一下` was tappable and changed the phrase card to `已听过一次`.
- `我说了` opened the reaction prompt.
- `配合` was reachable after scrolling and accepted.
- `下一句照护支持` appeared.
- `花园留痕` appeared after scrolling.

## Scope-Outs Preserved

- K1 preserved: did not fix PhraseCard stacking baseline; the demo path did not require `PhraseCard`.
- K2 preserved: did not clean full analyze 13-issue baseline; focused analyze passed.
- K3 preserved: used serial `--concurrency=1` focused Flutter commands; no asset-manifest workaround added.

## Remaining P1 Evidence Gaps

- Garden continuity across the Garden tab remains P1 evidence, not fixed here.
- Audio aural confirmation remains P1 evidence, not fixed here.

## Changed Files

- `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart`
- `mobile/test/features/onboarding/presentation/screens/onboarding_practice_screen_test.dart`
- `docs/superpowers/reports/2026-07-02-t7-manual-demo-blocker-fix-evidence.md`

Pre-existing untracked file preserved:

- `docs/superpowers/plans/2026-07-02-t7-manual-demo-blocker-fix-plan.md`
