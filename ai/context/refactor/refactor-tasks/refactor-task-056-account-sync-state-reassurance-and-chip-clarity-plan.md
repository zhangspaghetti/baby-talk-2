# REFACTOR-056 Account Sync-State Reassurance and Chip Clarity Plan

Status: done

## Context

REFACTOR-055 improved account read-failure fallback messaging. The next product-level UI/UX gap on the account surface is sync-state interpretation.

The account page already exposes pending/synced/failed chips, phase headlines, and sync-related helper copy. The behavior is useful, but the product meaning of the chips and counts can still feel terse:

- Parents may not immediately understand what the pending/synced/failed chips mean for their current use.
- Sync-state numbers are visible, but the surface could do more to explain whether action is needed now.
- The page should reassure users when partial sync states are acceptable and indicate when retry matters, without sounding technical.

This slice must remain presentation-only. It must not change sync counting, notifier logic, or retry semantics.

## Goal

Make sync-state surfaces easier to understand at a glance:

- Clarify what the sync chips mean in product language.
- Add light reassurance when pending or failed counts do not block current practice.
- Preserve existing counts, chip keys, and manual retry behavior.
- Keep the account surface parent-facing and non-technical.

## Recommended Approach

### Option A: Chip meaning and sync reassurance polish (recommended)

- Add a short localized explanation near sync-state chips or surrounding helper text.
- Tighten pending/failed explanatory copy to say what is safe now and when retry matters.
- Keep all chip data, counts, and retry handlers unchanged.
- Add focused widget assertions for the sync-state helper copy.

Tradeoff: low risk and high readability improvement.

### Option B: Convert chips into verbose cards

- Replace compact chips with larger explanatory components.

Tradeoff: more layout churn than needed for this bounded slice.

### Option C: Hide failed counts unless retry is available

- Conditionally simplify the surface by removing some state details.

Tradeoff: obscures useful information and changes current visibility semantics.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Adjust sync helper/reassurance copy near current chips or state summary.
- Add a small non-interactive explanation of chip meaning.
- Add focused widget assertions for sync-state explanatory copy.

## Out of Scope

- No edits to `account_notifier.dart`, repositories, or sync-state calculation logic.
- No changes to pending/synced/failed counts or chip keys.
- No changes to retry semantics or handler wiring.
- No router/provider/app-shell/household/share changes.
- No new dependencies, analytics, persistence, or backend contracts.

## UX Contract

The page must preserve these guarantees:

1. Sync-state counts remain accurate and unchanged.
2. Pending or failed counts do not imply local data loss.
3. Retry remains the explicit recovery action where already available.
4. Chip meaning stays parent-facing and non-technical.
5. Existing chip keys remain stable.

## Acceptance Criteria

- Account sync-state area shows clearer localized meaning for current chips/counts.
- Pending/failed states explicitly say that current practice can continue.
- Existing chip keys and counts remain unchanged.
- Existing retry and lifecycle tests remain green.
- No edits outside approved scope.

## Suggested TDD Cases

1. Pending-sync state shows explanatory copy for what pending means.
2. Failed-sync state shows reassurance that current practice can continue plus retry context.
3. Chip keys and counts remain unchanged in widget tests.
4. Existing sign-in, upgrade, error, and lifecycle tests remain green.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter analyze`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified

## Approval Gate

REFACTOR-056 was approved and completed with Option A only.

## Implementation Outcome

REFACTOR-056 completed sync-state reassurance and chip clarity polish without changing counts or retry behavior:

- Account status chips now include a short product-facing guidance note clarifying that pending/failed counts do not block current practice and manual retry can be used when convenient.
- Existing sync chip keys, counts, and retry semantics remain unchanged.
- Focused widget coverage now asserts the new guidance on account status card surfaces.

Verification completed locally:

- `flutter gen-l10n`
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `get_errors` on touched screen/test/generated l10n files

Follow-up:

- Enter REFACTOR-057 as the next product-level UI/UX slice to clarify account lifecycle chip semantics for revoked/deleted/read-failure phases.
