# T5 Care Turn QA / Device Validation / UX Hardening Plan

Date: 2026-07-01
Status: Draft for user review
Branch: `gsd/v0.1-milestone`
Base commit: `c440841cdce6c786b345b15dca91456db3a51b2f`
Scope: planning only. No code implementation, no commit.

## Prerequisite State

- T2 care_path facade is complete.
- T3 Today / Scene IA adapter is complete.
- T4 One-utterance loop is complete and committed: `c440841cdce6c786b345b15dca91456db3a51b2f`.
- Worktree was clean at plan start.
- `PracticeSessionScreen` now uses the care-path one-utterance loop, not the legacy practice execution path.
- `mobile_v2` is no longer the product implementation mainline.
- Full `flutter analyze --no-pub` still has 13 known scope-out issues. They are not T5 blockers unless a T5 touched-file focused analyze or test fails because of one.
- A `NativeAssetsManifest.json` race appeared once under parallel Flutter test execution. Serial focused tests passed.

## T5 Scope Challenge

T5 should be a QA hardening slice, not a second implementation slice. The product loop already exists after T4; T5 earns its keep by proving the loop works from real entry points, on constrained viewports, with readable semantics, and without old lesson/progress copy leaking back in.

Target loop:

```text
今天 / 场景
  -> 现在说一句
  -> 听一下
  -> 我说了
  -> 宝宝反应
  -> 下一句照护支持
  -> 花园痕迹
```

Minimum complete T5:

1. Route smoke proves Today and Scene CTAs reach the one-turn screen with correct `PracticeRouteArgs`.
2. Re-entry and back/exit behavior proves no stale reaction state and no completion summary.
3. Widget viewport tests cover 427x952dp, 390x844dp, and 1.3x text scale.
4. Semantics smoke proves parent-facing Chinese labels, especially the five reaction chips.
5. Copy firewall scans Today, Scene, and `PracticeSessionScreen` visible surfaces without false positives from internal identifiers.
6. Test execution policy records the `NativeAssetsManifest.json` race and keeps T5 focused tests serial.

Scope reduction guard:

- Do not build a generalized device automation framework.
- Do not repair broader Flutter analyze debt.
- Do not refactor Garden/Growth visuals.
- Do not rework Today/Scene visuals.
- Do not extract or rename `PracticeSessionScreen` just to satisfy naming purity.
- Production edits, if any, must be limited to obvious broken spacing, touch target, semantics label, or visible copy issues found by the new tests.

Complexity budget:

- Expected production files: 0 to 3.
- Expected test/tool files: 3 to 5.
- Expected docs: optional QA evidence note only if device validation results need a durable record.
- New public classes/services: 0.
- If implementation wants more than 3 production files, stop and re-scope before coding.

Search check:

- No new SDK, device lab, backend API, storage, routing framework, reaction type, or analytics system is introduced.
- This is [Layer 1]: reuse Flutter widget tests, existing Riverpod overrides, existing route contracts, and existing copy firewall tests.

## Existing Test Harness Reuse Map

| T5 need | Existing asset | Current state | T5 reuse decision |
| --- | --- | --- | --- |
| Practice one-turn screen harness | `mobile/test/features/practice/critical_ui_coverage_test.dart` | Already pumps `PracticeSessionScreen`, injects `_CarePathScreenPracticeRepository`, `_ScreenPracticeAudioController`, `carePathNotifierProvider`, and Garden trace fakes | Extend this file for screen route/re-entry/viewport tests unless it becomes too large. |
| Today CTA route args | `critical_ui_coverage_test.dart` test `HomeScreen primary care CTA routes with expected args` | Captures `PracticeRouteArgs` with a route sentinel | Upgrade or add a sibling test that routes into real `PracticeSessionScreen` and verifies one-turn content. |
| Scene CTA route args | `mobile/test/features/shell/discover_screen_test.dart` test `Discover care CTA triggers opener with route args` | Captures args through injected `practiceOpener` | Add a route smoke variant that opens actual `/practice` screen, or keep opener capture plus a `PracticeRouteEntry` screen assertion if route wiring would duplicate too much setup. |
| Route contract | `mobile/test/app/app_route_contract_test.dart` | Freezes canonical `/practice` and legacy named-route arg handoff | Reuse as lower-level contract; do not duplicate canonical path assertions in T5. |
| Semantics pattern | `mobile/test/smoke/a11y_semantics_test.dart` | Uses `tester.ensureSemantics()`, `find.bySemanticsLabel`, and touch target assertions | Reuse pattern. Place care-turn semantics in `critical_ui_coverage_test.dart` if private fakes are needed; only create a new a11y file if helpers are extracted. |
| Touch target constants | `AppLayoutConstants.minTouchTarget` | Existing test asserts `PhraseCard` play button >= 48 | Reuse constant for `practice-listen-once`, `practice-said-button`, and reaction chip keys. |
| T3 copy firewall | `mobile/test/tool/verify_t3_today_scene_copy_firewall_test.dart` | Scans Home, shell, Discover, and targeted l10n keys | Extend terms or add T5-specific test; avoid making T3's intent broader than Today/Scene IA. |
| T4 copy firewall | `mobile/test/tool/verify_care_path_copy_firewall_test.dart` | Scans care_path source and T4 one-turn l10n keys | Extend for T5 visible one-turn surfaces, or split a clearer `verify_t5_care_turn_copy_firewall_test.dart`. |
| Garden trace assertions | `critical_ui_coverage_test.dart` | Existing T4 screen test expects `花园留痕`, `花圃醒来了`, and `配合了 hello。` | Reuse and add route-level coverage only if route smoke does not already exercise trace after reaction. |

Recommendation:

- Keep T5 tests in existing focused files first. Extract a test-only harness only if route + viewport + semantics additions would duplicate the same repository fakes across multiple files.

## Device / Viewport Validation Plan

Automated widget viewport smoke:

| Case | Logical size | Text scale | Purpose |
| --- | ---: | ---: | --- |
| Pixel 9 Pro target | 427x952dp | 1.0 | Primary device shape. |
| Pixel 9 Pro accessible text | 427x952dp | 1.3 | Required large-text validation. |
| Narrow fallback | 390x844dp | 1.3 | Smaller common phone shape with harder copy pressure. |

Implementation shape:

1. Add a small test helper like `_setViewport(tester, Size(427, 952), textScale: 1.3)` using `tester.view.physicalSize`, `tester.view.devicePixelRatio = 1.0`, and `tester.binding.platformDispatcher.textScaleFactorTestValue`.
2. Pump `PracticeSessionScreen` with the T4 care-path harness.
3. For each case, verify these surfaces render and can be scrolled into view:
   - `practice-current-utterance`
   - `practice-listen-once`
   - `practice-said-button`
   - reaction chip row after `我说了`
   - `practice-next-support` after selecting a reaction
   - `practice-garden-trace` when latest impact exists
4. Assert no Flutter overflow exception after pump, tap, reaction, and scroll.
5. Assert all actionable controls are at least `AppLayoutConstants.minTouchTarget` in both dimensions:
   - `practice-listen-once`
   - `practice-said-button`
   - `reaction-bath_time_warm_water-cooperating`
   - `reaction-bath_time_warm_water-hesitant`
   - `reaction-bath_time_warm_water-resisting`
   - `reaction-bath_time_warm_water-no_response`
   - `reaction-bath_time_warm_water-other`

Manual/device validation:

1. Use a Pixel 9 Pro emulator or physical device when available.
2. Confirm Android display size approximates 427x952dp. If only pixel dimensions are available, record physical size and density from `adb shell wm size` and `adb shell wm density`.
3. Run the app in debug and exercise:
   - Today CTA -> one-turn screen -> listen -> said -> reaction -> next support -> Garden trace -> back.
   - Scene CTA -> one-turn screen -> back before reaction.
   - Same entry twice -> no stale reaction chips.
4. Turn on 1.3x text scale in system accessibility settings or equivalent emulator setting.
5. Record only T5-relevant issues. Do not capture broad visual redesign requests.

Acceptance:

- Current utterance, listen button, said button, reaction chips, next support, and Garden trace are visible or reachable by normal vertical scroll.
- No text is clipped in buttons/chips.
- No horizontal overflow.
- All touch targets are >= 48dp.
- Any required production fix is minimal: spacing, wrapping, min-height, semantics label, or copy only.

## Accessibility / Semantics Plan

Add a care-turn semantics smoke using `tester.ensureSemantics()`.

Required assertions:

| Surface | Expected semantics |
| --- | --- |
| Main sentence | `Warm water.` is readable; Chinese support text `温温的水。` is readable. |
| Listen action | Button semantics reads `听一下`, not only an icon or internal key. |
| Said action | Button semantics reads `我说了`, not only an icon or internal key. |
| Reaction prompt | Parent-facing prompt reads as visible Chinese copy. |
| Reaction chips | Exact Chinese labels: `配合`, `犹豫`, `不想`, `没反应`, `其他`. |
| Next support | `下一句照护支持` and next sentence copy are readable after reaction. |
| Garden trace | `花园留痕` and latest-impact copy are readable when present. |

Negative assertions:

- Semantics tree must not expose legacy progress/session/internal labels:
  - `session-progress`
  - `practice-progress-text`
  - `practice-completion-view`
  - `PracticeSessionNotifier`
  - `practice route 参数`
  - `第 1 /`
  - `完成总结`
  - English wire values such as `cooperating`, `hesitant`, `resisting`, `no_response`.

Implementation guidance:

- Prefer adding explicit `Semantics(label: ...)` only where the test shows a real ambiguity.
- Do not wrap the whole screen in a single merged label that hides child controls.
- Preserve `SceneReactionChipRow`'s current chip-level semantics; if touch targets need hardening, use `ConstrainedBox(minHeight: 48, minWidth: 48)` or equivalent without changing reaction contract.

## Copy Firewall Hardening Plan

T5 should harden the visible product language across the three entry surfaces:

```text
Today path: HomeScreen / Today card / Today CTA
Scene path: DiscoverScreen / scene activity cards / Scene CTA
One-turn path: PracticeSessionScreen / T4 one-turn l10n keys
```

Blocked visible terms:

```text
练习
课程
进度
完成
第 N 句
第 1 /
task
XP
streak
lesson
session
progress
completion
```

Targeted source/l10n scanning:

1. Keep scanning `mobile/lib/features/practice/presentation/screens/home_screen.dart`.
2. Keep scanning `mobile/lib/features/shell/presentation/screens/discover_screen.dart`.
3. Add or keep scanning `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`.
4. Scan targeted l10n values in `mobile/lib/l10n/app_zh.arb`:
   - T3 Today/Scene keys already listed in `verify_t3_today_scene_copy_firewall_test.dart`.
   - T4 one-turn keys already listed in `verify_care_path_copy_firewall_test.dart`.
   - Any new T5 accessibility/help/error copy keys.

False-positive firewall:

- Do not fail on internal identifiers:
  - `PracticeRouteArgs`
  - `PracticeRouteEntry`
  - `PracticeSessionScreen`
  - file paths containing `practice`
  - provider/test class names
- Do fail on visible `Text(...)`, button labels, ARB values, snackbar copy, fallback copy, and semantics labels.
- For English blocked terms like `task`, `session`, and `progress`, prefer ARB value scans and rendered widget text scans over raw source-wide scans.

Rendered widget scan:

1. Pump Today, Scene, and one-turn surfaces.
2. Collect visible `Text` widget strings for the focused flow.
3. Assert none contain blocked terms.
4. Keep the scan local to these surfaces; do not run a full repo copy purge.

Acceptance:

- The T5 flow reads as care support, not lesson/progress/task completion.
- Copy tests do not force broad renames of internal `practice` package names or route identifiers.

## Test Stability Plan

NativeAssetsManifest race handling:

- Treat the observed `NativeAssetsManifest.json` failure as a Flutter test runner/build artifact race unless it reproduces in a serial focused run.
- T5 must not make a parallel full-suite run a blocker.
- T5 focused verification should run from `mobile/`, not the monorepo root.
- Any multi-file Flutter test command must use `--concurrency=1`.
- Prefer one file per command for the route/viewport/semantics widget tests.
- Tool-only copy firewall tests may use `--no-test-assets` if they do not pump widgets and the flag is stable locally.

Tests that must be serial for T5:

```text
test/features/practice/critical_ui_coverage_test.dart
test/features/shell/discover_screen_test.dart
test/smoke/a11y_semantics_test.dart, if extended for care-turn semantics
test/tool/verify_t3_today_scene_copy_firewall_test.dart
test/tool/verify_care_path_copy_firewall_test.dart
any new test/tool/verify_t5_care_turn_copy_firewall_test.dart
```

Retry policy:

1. If a focused serial test fails with product assertion failure, fix within T5 scope.
2. If a focused serial test fails with `NativeAssetsManifest.json`, rerun the same command once serial.
3. If the same race repeats twice serial, record it as an environment/tooling blocker and run `flutter clean` only as an explicit follow-up validation step, not as a hidden default.
4. If full analyze reports the known 13 issues, record them as scope-out unless they appear in T5 touched files.

Do not:

- Add sleeps or timing hacks to mask test races.
- Mark unrelated full-suite failures as T5 failures.
- Change backend, storage, reaction contract, or `mobile_v2` to improve test stability.

## File-Level Implementation Plan

### T5.1 Route Smoke / App Flow Tests

Files:

- `mobile/test/features/practice/critical_ui_coverage_test.dart`
- `mobile/test/features/shell/discover_screen_test.dart`

Plan:

1. Add Today route smoke:
   - Pump `HomeScreen` in a `MaterialApp.router`.
   - Route `/practice` to `PracticeSessionScreen(routeEntry: PracticeRouteEntry.fromObject(state.extra))`.
   - Reuse existing Home provider overrides.
   - Tap `home-today-primary-cta`.
   - Assert actual one-turn content appears: `practice-current-utterance`, `听一下`, `我说了`, expected phrase.
   - Assert args are `home/song_time`, `PracticeRouteEntrySource.inApp`.
2. Add Scene route smoke:
   - Pump `DiscoverScreen` with catalog loader and route/opener handoff.
   - Tap first `现在说一句`.
   - Assert actual one-turn content appears for `daily_care/bath_time`.
   - Assert args are `daily_care/bath_time`.
3. Add repeated-entry route smoke:
   - Enter once, tap `我说了`, verify chips.
   - Pop/close or hide route.
   - Enter again with same args.
   - Assert no reaction chip is visible until `我说了` is tapped again.
4. Add back/exit smoke:
   - Push `/practice`, then back.
   - Assert no `practice-completion-view`, no `PracticeCompletionView`, no `完成总结`, and parent route is visible.

Allowed production follow-up:

- Only fix route state reset if a focused test proves stale state.

### T5.2 Viewport / Touch Target Tests

Files:

- `mobile/test/features/practice/critical_ui_coverage_test.dart`

Plan:

1. Add table-driven viewport helper.
2. Cover 427x952dp at 1.0, 427x952dp at 1.3, and 390x844dp at 1.3.
3. Exercise one full care turn in each case.
4. Assert no overflow exceptions.
5. Assert 48dp touch targets for listen, said, and every reaction chip.

Allowed production follow-up:

- Minimal spacing/wrapping/min-size changes in:
  - `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`
  - `mobile/lib/features/practice/presentation/widgets/scene_reaction_chip_row.dart`

### T5.3 Accessibility / Semantics Smoke

Files:

- Preferred: `mobile/test/features/practice/critical_ui_coverage_test.dart`
- Optional if cleanly extractable: `mobile/test/smoke/a11y_semantics_test.dart`

Plan:

1. Add care-turn semantics test using `tester.ensureSemantics()`.
2. Assert main sentence, listen, said, reaction chips, next support, and Garden trace are read as Chinese/user-facing labels.
3. Assert legacy/internal labels are not present.

Allowed production follow-up:

- Add explicit `Semantics` labels only for ambiguous controls.
- Do not change reaction values or add reaction types.

### T5.4 Copy Firewall Hardening

Files:

- `mobile/test/tool/verify_t3_today_scene_copy_firewall_test.dart`
- `mobile/test/tool/verify_care_path_copy_firewall_test.dart`
- Optional clearer split: `mobile/test/tool/verify_t5_care_turn_copy_firewall_test.dart`

Plan:

1. Keep T3 Today/Scene scan targeted.
2. Keep T4 one-turn l10n scan targeted.
3. Add T5 visible-surface scan that covers Home, Discover, and PracticeSession together.
4. Add allowlist for identifiers and paths so `PracticeRouteArgs` / `PracticeSessionScreen` do not fail the test.
5. Add rendered-widget text scan only if raw source scanning creates false positives.

Allowed production follow-up:

- Visible copy and l10n generated files only:
  - `mobile/lib/l10n/app_zh.arb`
  - `mobile/lib/l10n/app_localizations.dart`
  - `mobile/lib/l10n/app_localizations_zh.dart`
  - focused visible strings in Today/Scene/Practice if tests prove leakage.

### T5.5 Device Validation Evidence

Files:

- Optional report after implementation: `docs/superpowers/reports/2026-07-01-t5-care-turn-device-validation.md`

Plan:

1. Run automated viewport tests first.
2. Run manual Pixel 9 Pro or emulator smoke if a device is available.
3. Record exact device, text scale, pass/fail notes, and any accepted scope-out issue.
4. Do not add screenshots unless they reveal a real T5 blocker.

### T5.6 Test Stability Record

Files:

- This plan file or optional T5 verification report.

Plan:

1. Use serial commands in the verification section.
2. Record whether `NativeAssetsManifest.json` reproduced.
3. If race reproduces only under parallel execution, keep it as a known test-runner caveat, not a product defect.

## Verification Commands

Run from the `mobile/` package root.

Focused format:

```powershell
cd C:\code\AI\baby-talk-2\mobile
& 'C:\software\flutter\bin\dart.bat' format --set-exit-if-changed `
  lib\features\practice\presentation\screens\practice_session_screen.dart `
  lib\features\practice\presentation\widgets\scene_reaction_chip_row.dart `
  test\features\practice\critical_ui_coverage_test.dart `
  test\features\shell\discover_screen_test.dart `
  test\tool\verify_t3_today_scene_copy_firewall_test.dart `
  test\tool\verify_care_path_copy_firewall_test.dart
```

Focused analyze:

```powershell
cd C:\code\AI\baby-talk-2\mobile
& 'C:\software\flutter\bin\flutter.bat' analyze --no-pub `
  lib\features\practice\presentation\screens\practice_session_screen.dart `
  lib\features\practice\presentation\widgets\scene_reaction_chip_row.dart `
  lib\features\practice\presentation\screens\home_screen.dart `
  lib\features\shell\presentation\screens\discover_screen.dart `
  test\features\practice\critical_ui_coverage_test.dart `
  test\features\shell\discover_screen_test.dart `
  test\tool\verify_t3_today_scene_copy_firewall_test.dart `
  test\tool\verify_care_path_copy_firewall_test.dart
```

Serial focused tests:

```powershell
cd C:\code\AI\baby-talk-2\mobile
& 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
  test\features\practice\critical_ui_coverage_test.dart

& 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
  test\features\shell\discover_screen_test.dart

& 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
  test\smoke\a11y_semantics_test.dart

& 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
  test\tool\verify_t3_today_scene_copy_firewall_test.dart

& 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
  test\tool\verify_care_path_copy_firewall_test.dart
```

If a new T5 firewall file is added:

```powershell
cd C:\code\AI\baby-talk-2\mobile
& 'C:\software\flutter\bin\flutter.bat' test --no-pub --concurrency=1 `
  test\tool\verify_t5_care_turn_copy_firewall_test.dart
```

Optional full analyze record, not a T5 gate:

```powershell
cd C:\code\AI\baby-talk-2\mobile
& 'C:\software\flutter\bin\flutter.bat' analyze --no-pub
```

Expected: may still report the 13 existing scope-out issues. T5 fails only if a T5 touched file introduces a new issue or a focused test fails.

Manual device commands:

```powershell
cd C:\code\AI\baby-talk-2\mobile
adb devices
adb shell wm size
adb shell wm density
& 'C:\software\flutter\bin\flutter.bat' run -d <device-id>
```

Manual checklist:

- Today CTA opens one-turn screen.
- Scene CTA opens one-turn screen.
- `听一下` plays or shows graceful audio fallback.
- `我说了` reveals reaction chips.
- Chips read and display `配合 / 犹豫 / 不想 / 没反应 / 其他`.
- Selecting a chip shows next support and Garden trace.
- Back/exit returns without completion summary.
- Re-entering does not show stale chips or stale next support.

## Failure Modes

| Codepath | Failure mode | User impact | T5 coverage | Handling |
| --- | --- | --- | --- | --- |
| Today CTA route | `state.extra` missing or wrong | Parent lands in fallback or wrong care scene | Today route smoke with real `PracticeSessionScreen` | Fix CTA arg source only. |
| Scene CTA route | Opener captures args but app route integration breaks | Scene path looks tested but real route fails | Scene route smoke into one-turn screen | Keep route test actual enough to render one-turn content. |
| Repeated entry | Reaction prompt or next support persists | Parent sees stale baby reaction state | Re-entry test after hide/pop | Reset screen-local reaction/audio state on route lifecycle. |
| Back/exit | Legacy completion summary appears | Flow feels like a course completion | Back/exit smoke | Keep `PracticeCompletionView` out of one-turn route. |
| Viewport | Row buttons or chips clip at 390dp/1.3x | Main action becomes hard to use | viewport and touch target tests | Wrap, stack, or increase min sizes minimally. |
| Semantics | Chips read wire values or internal labels | Screen reader users hear implementation details | semantics smoke | Add explicit labels; preserve canonical reaction contract. |
| Copy firewall | Raw scan catches identifiers | False failures force pointless renames | allowlist and rendered text scan | Scan visible strings and ARB values, not internal route names. |
| Garden trace | `latestImpact` absent after save | Parent doubts whether the turn was recorded | existing + route-level trace assertion | Use existing generic trace fallback only if current UI already supports it. |
| NativeAssetsManifest | Parallel asset build race | Unreliable local verification | serial commands with `--concurrency=1` | Re-run serial; record race if parallel-only. |
| Full analyze debt | Existing 13 issues distract T5 | QA slice balloons into cleanup | focused analyze | Scope out unless T5 touched-file blocker. |

Critical gaps to avoid:

```text
Route args only tested with sentinels, not with the actual one-turn screen.
Viewport tests only assert text exists, but never measure 48dp touch targets.
Copy firewall scans raw identifiers and forces product-irrelevant renames.
NativeAssetsManifest race gets "fixed" by sleeps or unrelated cleanup.
```

## Explicitly Not In Scope

- No backend changes.
- No `mobile_v2` changes.
- No reaction contract change.
- No new `CareReactionType`.
- No new `BabyReactionType`.
- No new local storage.
- No new backend API.
- No Garden/Growth visual refactor.
- No Today/Scene visual redesign.
- No dynamic practice generation changes.
- No ASR/STT.
- No full internal rename from `practice` to `care_path`.
- No fix for the 13 existing full-analyze issues unless one directly blocks T5 focused tests in a touched file.
- No PhraseCard stacking baseline repair unless it directly blocks T5 route/viewport tests.
- No generalized device automation framework.
- No broad screenshot/golden refresh.
- No commit from this planning step.

## Worktree Sequencing

Recommended implementation is mostly serial because the route, viewport, semantics, and copy tests share the same one-turn harness and may touch the same large test file.

Dependency table:

| Step | Modules touched | Depends on |
| --- | --- | --- |
| T5.1 Route smoke | `critical_ui_coverage_test.dart`, `discover_screen_test.dart` | T4 screen complete |
| T5.2 Viewport/touch tests | `critical_ui_coverage_test.dart` | T5.1 harness decisions |
| T5.3 Semantics smoke | `critical_ui_coverage_test.dart` or `a11y_semantics_test.dart` | T5.1 harness decisions |
| T5.4 Copy firewall | `test/tool/*copy_firewall_test.dart` | final copy surface known |
| T5.5 Minimal polish | focused production files only if tests fail | T5.1-T5.4 failures |
| T5.6 Serial verification | no production files | all |

Parallelization:

```text
Lane A: route smoke + viewport + semantics
  -> any minimal production polish
  -> serial focused tests

Lane B: copy firewall terms and allowlist
  -> serial copy firewall tests
```

Conflict flags:

- Keep one owner for `critical_ui_coverage_test.dart`.
- Keep one owner for `app_zh.arb` if copy changes are needed.
- Do not parallelize edits to generated localization files.
- Do not run Flutter widget test files in parallel for T5 verification.

Implementation tasks:

- [ ] **T5.1 (P1, human: ~90min / CC: ~30min)** - route smoke - Prove Today and Scene CTAs enter actual one-turn screen with correct route args.
  - Surfaced by: real user loop starts from Today/Scene, not direct screen pump.
  - Files: `mobile/test/features/practice/critical_ui_coverage_test.dart`, `mobile/test/features/shell/discover_screen_test.dart`.
  - Verify: serial focused route/widget tests.

- [ ] **T5.2 (P1, human: ~75min / CC: ~25min)** - viewport and touch targets - Add 427x952dp, 390x844dp, and 1.3x text-scale coverage.
  - Surfaced by: device validation requirement.
  - Files: `mobile/test/features/practice/critical_ui_coverage_test.dart`.
  - Verify: serial focused widget test; no overflow; >=48dp controls.

- [ ] **T5.3 (P1, human: ~60min / CC: ~20min)** - accessibility semantics - Add care-turn semantics smoke and negative internal-label assertions.
  - Surfaced by: screen reader and parent-facing copy requirement.
  - Files: `mobile/test/features/practice/critical_ui_coverage_test.dart` or `mobile/test/smoke/a11y_semantics_test.dart`.
  - Verify: serial focused semantics test.

- [ ] **T5.4 (P1, human: ~45min / CC: ~15min)** - copy firewall - Harden Today/Scene/Practice visible-copy scan without identifier false positives.
  - Surfaced by: lesson/progress/completion framing risk.
  - Files: `mobile/test/tool/verify_t3_today_scene_copy_firewall_test.dart`, `mobile/test/tool/verify_care_path_copy_firewall_test.dart`, optional `mobile/test/tool/verify_t5_care_turn_copy_firewall_test.dart`.
  - Verify: serial copy firewall tests.

- [ ] **T5.5 (P2, human: ~60min / CC: ~20min)** - optional minimal polish - Fix only proven spacing/copy/accessibility breaks.
  - Surfaced by: T5 tests or manual device check.
  - Files: `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`, `mobile/lib/features/practice/presentation/widgets/scene_reaction_chip_row.dart`, l10n files only if necessary.
  - Verify: rerun failed focused test, then full focused serial set.

- [ ] **T5.6 (P1, human: ~45min / CC: ~15min)** - stability/evidence - Run serial verification and record NativeAssetsManifest outcome.
  - Surfaced by: previous parallel test race.
  - Files: optional T5 report only.
  - Verify: commands in this plan.

TODOS.md updates:

- No `TODOS.md` update is recommended for T5.
- Reason: T5 is an approved focused QA hardening slice. Existing broad backlog and full-analyze debt should not be reclassified as T5 work.

Retrospective learning applied:

- T4 converted `PracticeSessionScreen` to care-path one-turn. T5 should protect that route and UX with focused tests instead of reopening the architecture.
- Prior local Flutter testing should run from `mobile/` package root for package resolution and should be serial when asset build races are suspected.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | not run | Not requested for T5; product goal is already constrained by T2-T4. |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | Skipped; user asked for a planning document only. |
| Eng Review | `/plan-eng-review` | Architecture & tests | 1 | draft_clear | Primary decision: keep T5 QA-first, add route/viewport/semantics/copy-firewall tests, and allow only minimal polish if focused tests prove breakage. |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | Optional after implementation if viewport/manual device checks surface visual quality issues; broad redesign is out of scope. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Not applicable; test stability guidance is included in this eng plan. |

**UNRESOLVED:** 0

**VERDICT:** ENG PLAN DRAFT CLEAR FOR REVIEW - T5 may proceed after user approval as a mobile-only QA / device validation / UX hardening slice covering Today route, Scene route, care-turn viewport/touch targets, semantics, copy firewall, serial test stability, and optional minimal polish. No backend, `mobile_v2`, reaction-contract, storage/API, dynamic practice, ASR/STT, Garden/Growth visual refactor, Today/Scene visual redesign, full-analyze cleanup, or broad PhraseCard repair is approved by this plan.
