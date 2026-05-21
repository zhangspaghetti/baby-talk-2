# REFACTOR-043: Practice C3 Product Polish Plan

Status: done
Stage: Stage 3.2 implementation slice
Owner: mobile UI/UX
Created: 2026-05-21
Depends on: REFACTOR-042 onboarding activation mini-scene

## Purpose

Turn the existing practice session C3 surface from a mechanically correct exercise screen into a parent-facing daily speaking moment.

REFACTOR-042 now gets a parent to the first local phrase. The next product risk is what happens after that first spark: the practice screen must make it obvious what to say, when to play audio, and how to record the baby's response without exposing internal state labels.

This slice preserves the current repository, route, audio, and event behavior. It only changes presentation copy/layout and focused widget coverage.

## Product Intent

The screen should answer three questions quickly:

- What do I say now?
- Can I hear it once?
- What did my baby do?

Current issues to remove:

- Visible internal label `C3 激活框`.
- Visible raw state values such as `idle`, `playing`, `completed`, `saved`.
- Instructional copy that describes implementation state instead of coaching a parent.
- A horizontal play/help row that has no explicit high text-scale regression coverage.

## Scope

Allowed:

- Localize the activation frame kicker, semantics label, phrase step label, and status labels.
- Replace technical helper copy with warm care-scene coaching copy.
- Reuse the existing audio controller and `PracticeSessionNotifier` state machine.
- Stack the active phrase play button and hint text when the card is narrow or text scale is high.
- Add focused widget tests for parent-facing C3 copy, localized progress, and high text-scale layout.

Not allowed:

- Practice repository or Isar schema changes.
- Route/account/backend changes.
- New packages.
- Auto-flow, timers, analytics, notifications, or new event types.
- Changing reaction semantics or event payloads.

## Acceptance Criteria

- Practice session progress uses the existing localized `practiceProgress` string.
- The active phrase area no longer displays `C3 激活框` or raw state names.
- Status chips communicate parent-facing states such as playback readiness and save progress.
- The primary audio affordance remains at least 48dp.
- At high text scale, the play affordance and coaching hint stack vertically without overlap.
- Existing practice reaction recording behavior remains unchanged.

## Verification Plan

- Focused practice UI widget coverage.
- `flutter test test/features/practice/critical_ui_coverage_test.dart`
- `flutter test test/smoke/a11y_semantics_test.dart`
- `dart analyze`
- `git diff --check`

## Implementation Evidence

- Active phrase copy no longer exposes `C3 激活框`, `STEP`, or raw playback/save state labels.
- Practice progress and phrase step labels use generated localization APIs.
- Active phrase play affordance stacks under high text scale and narrow width with widget coverage.
- Playback timeout keeps the phrase in place with retry-oriented parent-facing copy.
- Audio playback, reaction recording, and repository write behavior remain covered by focused tests.