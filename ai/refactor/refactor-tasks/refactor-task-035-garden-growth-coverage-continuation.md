# REFACTOR-035 Garden Growth Coverage Continuation

---
id: REFACTOR-035
title: Garden growth combined screen coverage continuation
status: draft
priority: high
phase: 4
assignee: AI, pending human R4 track confirmation
created: 2026-05-20
estimated: 0.5-1 day
---

## Goal

Raise global Flutter LCOV toward the 80% R4 target by adding behavior-preserving widget regression coverage for `GardenGrowthCombinedScreen` and its growth-tab states.

## Legacy Code Location

No physical `lib/legacy/` move is involved. This is a behavior-preserving coverage task for existing source at `mobile/lib/features/shell/presentation/screens/garden_growth_combined_screen.dart`.

## Original Functionality Description

1. The screen renders a segmented control with garden and growth tabs.
2. The garden tab shows the garden hero, continue card, loading/empty state, and patch cards from the garden snapshot.
3. The growth tab shows the latest impact, projection warning, diary section, and milestones section.
4. Diary and milestone sections show only the first visible subset on the combined screen.
5. The `查看全部` buttons are present only when diary entries exceed 3 or milestones exceed 6, but their current callbacks only trigger haptics and contain TODO navigation comments.
6. Shared household and share cards remain visible below the selected tab when their notifiers are available.
7. Pull-to-refresh refreshes garden data and continuity data when the continuity notifier exists.

## Refactoring Approach

This task is test-first and report-oriented. It should not refactor production code unless a tiny testability seam is unavoidable and separately justified.

1. Add widget tests that build the combined screen with controlled provider/notifier state.
2. Cover loading, empty, growth impact, diary visible-limit, milestones visible-limit, and shared warning/banner branches where feasible.
3. Assert that current visible behavior remains unchanged, including the fact that view-all buttons do not navigate yet.
4. Run focused tests first, then full `flutter test --coverage --concurrency=1`.
5. Update coverage and verification artifacts with the new LCOV result.

## Target Location

- `mobile/test/features/shell/garden_growth_combined_screen_test.dart` or an existing shell/widget coverage test file, following current test conventions.
- `ai/refactor/audit-reports/refactor-035-garden-growth-coverage-continuation.md` for the completion report if approved and executed.

## Allowed Changes

- Add widget regression tests for `GardenGrowthCombinedScreen`.
- Add minimal test fixtures/fakes required by those tests.
- Update R4 verification and coverage artifacts after tests run.
- Update the refactor task status after completion.

## Forbidden Changes

⚠️ The following must not change during this task:

- Do not implement the diary or milestone `查看全部` navigation TODOs.
- Do not change tab labels, route paths, visible strings, snapshot semantics, or provider wiring.
- Do not change production UI layout, colors, spacing, haptics, or data-loading behavior.
- Do not touch destructive local data lifecycle wiring.
- Do not move source files into `lib/legacy/`.

## Acceptance Criteria

- [ ] Focused widget tests pass.
- [ ] `flutter analyze` passes.
- [ ] `flutter test --coverage --concurrency=1` passes.
- [ ] Global LCOV is recalculated and compared against the 80% target.
- [ ] Existing behavior is unchanged; no production code change unless explicitly documented as a testability seam.
- [ ] Completion report is written under `ai/refactor/audit-reports/`.
- [ ] A conventional commit records the task result if implementation is approved.

## Regression Test Requirements

- [ ] Loading or idle garden state.
- [ ] Empty garden/growth data state.
- [ ] Growth tab with latest impact and projection warning.
- [ ] Diary entries over the visible limit show the view-all button and only the preview subset.
- [ ] Milestones over the visible limit show the view-all button and only the preview subset.
- [ ] Diary and milestone empty cards render correct localized messages.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Widget construction requires broad app providers | Medium | Medium | Prefer existing test harnesses and fakes; avoid production DI changes |
| Tests become brittle around localized copy | Medium | Low | Prefer keys and stable semantics where available |
| Accidentally implementing TODO navigation | Low | Medium | Explicit forbidden change; tests should assert current non-navigation behavior only if practical |
| Coverage gain insufficient for 80% | High | Low | Treat as one coverage slice; select next slice from LCOV ranking if needed |

## Review Checklist

- [ ] No behavior, routing, copy, or data model changes.
- [ ] Tests follow existing Flutter test style.
- [ ] Coverage report evidence is updated.
- [ ] R4 production-readiness status is updated accurately.

## Known Decisions

- R0/R1/R2/R3 and REFACTOR-001 through REFACTOR-034 are complete.
- Global LCOV is 73.91% as of REFACTOR-034.
- Production readiness remains blocked until global coverage reaches 80% or an explicit exception is approved.
- `GardenGrowthCombinedScreen` is the third-largest current LCOV gap in existing data: 244 found lines, 107 hit, 137 missed, 43.85% line coverage.

## Authorizations

- No implementation is authorized until HDR-R4-002 is confirmed.
- Read-only analysis and draft task planning are allowed under existing governance records.

## Dependencies

- REFACTOR-034 global coverage stabilization.
- HDR-R4-002 next production-readiness track confirmation.