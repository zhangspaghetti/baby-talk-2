# REFACTOR-060 Account Status Helper Density Trim and Error Wording Unification Plan

Status: in_progress

Kickoff: 2026-05-24 (after second full-regression validation batch `20260524-154929`)

## Context

REFACTOR-059 aligned helper source and priority between home/account surfaces. The next product-level UI/UX slice is to trim helper density in high-noise phases while keeping critical guidance unchanged.

Current behavior is consistent, but two polish risks remain:

- Error-related wording can still feel repetitive when status text, retry guidance, and last-error copy appear together.
- Some dense states still stack multiple helper lines that are semantically adjacent.

This slice must remain presentation-only and must not alter account state semantics or handler behavior.

## Goal

- Reduce helper text density in error/dense phases.
- Keep one clear primary helper sentence per phase.
- Preserve all actions and behavior.
- Keep tests stable with focused presence/absence assertions.

## Recommended Approach

### Option A: Density trim with wording unification (recommended)

- Keep one primary helper in dense phases.
- Keep retry/action guidance explicit and unchanged.
- Tighten repeated error-adjacent wording in localized copy.
- Add focused assertions for error and one dense non-error phase.

Tradeoff: improves readability with low risk.

### Option B: Collapsible helper details

- Hide secondary helper text behind an expand action.

Tradeoff: adds interaction complexity.

### Option C: Copy-only edits in one surface

- Change wording without display-rule cleanup.

Tradeoff: partial fix that can drift again.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Small helper visibility refinements for dense phases.
- Minor wording unification for error-related helper lines.
- Focused widget assertions on helper hierarchy.

## Out of Scope

- No edits to notifier/repository/services or phase mapping semantics.
- No changes to action handlers (retry/revoke/delete/upgrade/sign-in).
- No router/provider/app-shell/household/share changes.
- No new dependencies, analytics, persistence, or backend contracts.

## UX Contract

1. Critical status and primary action guidance remain obvious.
2. Error phases avoid stacked repetitive helper text.
3. Dense-phase readability improves without hiding required guidance.
4. Behavior remains unchanged.
5. Stable keys remain available where possible.

## Acceptance Criteria

- Error phase presents one primary helper plus explicit retry guidance without contradictory repetition.
- At least one dense non-error phase shows reduced helper stacking.
- Existing account behavior tests remain green.
- No edits outside approved scope.

## Suggested TDD Cases

1. Error phase keeps retry guidance and suppresses duplicate helper copy.
2. Dense phase (version-blocked or pending-sync) shows one primary helper hierarchy.
3. Existing action-path tests remain green.

## Verification Plan

- `flutter gen-l10n`
- `dart format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `flutter analyze`
- `git diff --check`

## Approval Gate

Do not enter Stage 3.1 implementation until REFACTOR-060 is approved.
