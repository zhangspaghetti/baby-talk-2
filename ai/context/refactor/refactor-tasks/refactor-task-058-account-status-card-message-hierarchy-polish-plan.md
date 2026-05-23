# REFACTOR-058 Account Status Card Message Hierarchy Polish Plan

Status: done

## Context

REFACTOR-057 separated edge-phase chip semantics. The next product-level UI/UX gap is message hierarchy density inside account status card areas.

Current status card surfaces can show headline, body, error banner, chips, chip guidance, submission message, upgrade hint, and upgrade reassurance together. Behavior is correct, but in some combinations message density becomes high and can reduce scan speed.

This slice must remain presentation-only. It must not change account state semantics, handlers, or phase mapping.

## Goal

Improve readability of the status card by polishing message hierarchy:

- Keep critical state information obvious.
- Reduce perceived duplication between helper lines.
- Preserve existing semantics and actions.
- Keep tests stable with minimal key churn.

## Recommended Approach

### Option A: Priority-ordered message hierarchy (recommended)

- Define a strict display priority for helper lines in each phase.
- Keep at most one secondary reassurance line in dense states.
- Preserve all existing actions and status labels.
- Add focused widget assertions for priority ordering in key phases.

Tradeoff: strong readability gain with low behavior risk.

### Option B: Collapse helper lines into expandable text

- Move secondary information behind a "more" interaction.

Tradeoff: adds interaction complexity and hidden content risk.

### Option C: Remove chip guidance entirely

- Simplify by dropping guidance lines.

Tradeoff: reduces clarity for sync-state interpretation.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Reorder or conditionally suppress helper text lines in status card zones.
- Minor copy tightening to remove repetition.
- Focused assertions on message presence/absence under selected phases.

## Out of Scope

- No edits to notifier/repository/services or phase mapping semantics.
- No changes to revoke/delete/retry/upgrade/sign-in handler wiring.
- No router/provider/app-shell/household/share changes.
- No new dependencies, analytics, persistence, or backend contracts.

## UX Contract

The page must preserve these guarantees:

1. Critical status always stays visible.
2. Dense states do not overwhelm the user with duplicate guidance.
3. Actions remain discoverable and behaviorally unchanged.
4. Edge-phase semantics remain separated from sync-lag semantics.
5. Existing stable keys remain available where possible.

## Acceptance Criteria

- At least one dense phase shows reduced helper duplication.
- Status card readability improves without hiding critical state/action info.
- Existing account behavior tests remain green.
- No edits outside approved scope.

## Suggested TDD Cases

1. Version-blocked phase keeps critical upgrade info while avoiding duplicate reassurance lines.
2. Error phase keeps retry guidance while avoiding stacked repetitive helper text.
3. Pending-sync phase keeps sync guidance but does not duplicate equivalent status text.
4. Existing lifecycle and action-path tests remain green.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter analyze`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified

## Approval Gate

REFACTOR-058 was approved and completed with Option A only.

## Implementation Outcome

REFACTOR-058 completed account status-card message hierarchy polish with behavior preserved:

- Added a simple message-priority rule to reduce dense-state duplication: when upgrade helper is present, suppress sync chip guidance.
- Kept critical upgrade/error/retry signals visible while reducing low-priority overlap.
- Preserved existing state semantics and handlers.
- Added focused assertions for presence/absence combinations in key phases.

Verification completed locally:

- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `get_errors` on touched files
- `git diff --check`

Follow-up:

- Enter REFACTOR-059 as the next product-level UI/UX slice to align AccountStatusCard helper priority rules between home card and account entry status section language consistency.
