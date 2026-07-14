# T6 Mobile Care Turn Acceptance Evidence

Date: 2026-07-02
Branch: `gsd/v0.1-milestone`
Verdict: `blocked`

## Reader And Action

This report is for the next engineer or reviewer picking up T6. After reading it, they should be able to understand why T6 is blocked, which evidence already passed, and what the next fix-planning slice should cover without reopening backend, `mobile_v2`, reaction contract, or broad Garden redesign scope.

## T6 Completion Summary

- Scope guard: pass with note. `HEAD=f8e524566856b33e9f1a6c371261180badb04e86`; `backend/` and `mobile_v2/` clean. Worktree has the approved untracked T6 plan doc.
- Targeted care-turn tests: pass. All seven targeted `critical_ui_coverage_test.dart` cases passed, plus `discover_screen_test.dart` scene smoke passed.
- Copy firewall: pass. Today/Scene firewall and care_path/one-turn firewall both passed.
- Focused analyze: pass. `flutter analyze --no-pub` on 9 demo-path items: `No issues found`.
- Full critical UI baseline: fail; only K1 failures? yes. Exactly the two registered PhraseCard failures failed.
- Full analyze baseline: fail; exactly 13 known issues? yes.
- NativeAssetsManifest serial caveat: not reproduced in serial targeted/full commands.
- Device/manual validation: partial/fail. Emulator evidence captured, but 1.3x pressure exposed a visible Flutter overflow before Today/Scene could be revalidated.
- Demo verdict: blocked.
- Blockers:
  - Manual 1.3x accessibility pressure hit `BOTTOM OVERFLOWED BY 7.0 PIXELS` during onboarding practice, blocking a clean release-readiness verdict.
  - Manual Garden tab continuity was not completed; one-turn `花园留痕` appeared, but navigating to `花园` and confirming related state was not verified.
  - `听一下` was tapped without visible failure, but audio output itself was not aurally confirmable from this run.
- Follow-ups that can wait: K1 PhraseCard baseline repair, K2 full analyze cleanup, K3 parallel NativeAssetsManifest race cleanup.

## Commit / Scope Guard

- HEAD: `f8e524566856b33e9f1a6c371261180badb04e86`
- `backend/`: clean
- `mobile_v2/`: clean
- Initial review status had only the approved T6 plan document untracked.
- No code changes, test changes, backend changes, `mobile_v2` changes, or commits were made as part of this report.

## Automated Evidence

Required targeted automated gates passed:

- Targeted care-turn tests passed.
- Discover scene smoke passed.
- Today CTA opened the real one-turn route in automated coverage.
- Scene CTA opened the real one-turn route in automated coverage.
- One-turn listen -> said -> reaction -> next support -> Garden trace passed in automated coverage.
- Viewport and touch target matrix passed in automated coverage.
- Care-turn semantics-only coverage passed.
- Route re-entry and back-exit stayed one-turn clean in automated coverage.
- Shell labels used Today/Scene and Garden remained index 2 in automated coverage.

Copy and analyzer gates passed:

- Today/Scene copy firewall passed.
- care_path / one-turn copy firewall passed.
- Focused `flutter analyze --no-pub` passed on the demo-path items.

Baseline awareness:

- Full `critical_ui_coverage_test.dart` failed only on K1:
  - `Active PhraseCard stacks play affordance at high text scale`
  - `Active PhraseCard stacks play affordance in narrow width`
- Full `flutter analyze --no-pub` reported only K2: 13 known scope-out issues.
- NativeAssetsManifest serial race did not reproduce in the serial targeted or full commands.

## Manual Device Evidence

- Device/emulator: `emulator-5554`
- OS: Android 15 / API 35
- Model: `sdk_gphone64_x86_64`
- Size: `1170x2532` override on `1280x2856`
- Density: `480`
- Build mode: debug APK
- Text scale sequence: `1.0` -> `1.3` -> restored to `1.0`

Observed manual path evidence:

- At text scale 1.0, onboarding was completed on the emulator.
- The app reached the `今天` shell.
- The `今天 / 场景 / 花园 / 我` bottom navigation was visible.
- Today current care node was visible.
- Today `现在说一句` opened the real `今日一句` one-turn screen.
- `听一下` was tappable and did not visibly fail.
- `我说了` revealed the canonical reaction choices.
- Selecting `配合` produced `下一句照护支持`.
- The one-turn screen showed `花园留痕`.
- Back returned to the Today shell without completion-summary framing.
- Scene tab was visible at index 1 and its card CTA `现在说一句` opened the one-turn screen cleanly.

Incomplete manual evidence:

- At text scale 1.3, manual Today/Scene revalidation did not complete because onboarding practice exposed a visible overflow first.
- Garden tab continuity was not completed after the one-turn trace.
- Audio output was not aurally confirmed.

## Blockers

- P0: 1.3x pressure hit `BOTTOM OVERFLOWED BY 7.0 PIXELS` during onboarding practice, blocking Today/Scene revalidation.
- P1: Garden tab continuity not completed.
- P1: Audio output not aurally confirmed.

## Verdict

- Verdict: `blocked`
- Demo-ready: no
- Release-ready: no

The automated care-turn acceptance evidence is strong, but manual release-readiness remains blocked by the 1.3x overflow and incomplete Garden/audio manual checks.

## Follow-Ups That Can Wait

- K1 PhraseCard stacking baseline
- K2 full analyze 13 known issues
- K3 parallel NativeAssetsManifest race

## Recommended Next Slice

Next slice: T7 Manual Demo Blocker Fix Plan.

Recommended boundaries:

- mobile-only
- focused on the 1.3x overflow localization/fix
- rerun T6 manual evidence after the focused fix
- no backend changes
- no `mobile_v2` changes
- no reaction contract changes
- no Garden visual redesign
