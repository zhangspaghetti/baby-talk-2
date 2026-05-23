# REFACTOR-052 Account Delete Dialog Localization and Severity Clarity Plan

Status: done

## Context

REFACTOR-051 completed confirmation hardening for revoke, logout, and local-only transitions. The next product-level UI/UX gap on the same account lifecycle surface is consistency and trust wording for the delete-account confirmation dialog.

Today, delete confirmation copy is still hard-coded inside `AccountEntryScreen`. This creates three product risks:

- Dialog text cannot be centrally evolved with the rest of account lifecycle copy.
- Future wording adjustments are harder to review and regression-test through localization keys.
- Severity hierarchy can drift because delete copy is not governed by the same l10n contract used by revoke/logout/local-only confirmations.

This slice must remain presentation-only. It must not change delete behavior, trigger wiring, or local sensitive data clearance semantics.

## Goal

Unify delete confirmation copy with the existing localization contract while preserving current behavior:

- Move delete dialog title/body/action/cancel labels into `AppLocalizations`.
- Keep delete as the unique destructive action and keep its current confirm/cancel flow.
- Keep all existing delete keys and handler wiring stable.
- Add focused widget expectations that verify l10n-backed delete dialog copy appears with the existing dialog and buttons.

## Recommended Approach

### Option A: Localize delete dialog copy only (recommended)

- Add dedicated account-delete confirmation keys in `app_zh.arb`.
- Regenerate l10n outputs.
- Replace hard-coded delete dialog text in `AccountEntryScreen` with localization getters.
- Extend account entry widget tests to assert the localized delete title/body/action labels are rendered.

Tradeoff: smallest blast radius and cleanest path to consistency.

### Option B: Localize and restyle destructive zone simultaneously

- Include additional visual hierarchy changes (spacing/colors/typography) while localizing copy.

Tradeoff: higher UI regression risk and harder to isolate behavior-safe verification.

### Option C: Defer localization and keep hard-coded copy

- Make no code change and keep current Chinese constants in the screen file.

Tradeoff: lowest immediate effort but keeps governance and product-copy debt in a high-risk surface.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Add/delete dialog l10n keys and generated getters.
- Replace delete dialog hard-coded strings with localization getters.
- Add or adjust focused widget assertions for delete dialog copy and key stability.

## Out of Scope

- No edits to `account_notifier.dart`, repositories, API/store, or local sensitive data clearance orchestrator.
- No change to delete handler semantics: confirm still calls `deleteAccount()` once and drives existing clearance path.
- No changes to revoke/logout/local-only confirmation behavior added in REFACTOR-051.
- No router/provider/app-shell/household/share changes.
- No new dependencies, analytics, routes, persistence, or backend contracts.

## UX Contract

The page must preserve these destructive-action guarantees:

1. Delete remains the uniquely destructive account action.
2. Delete confirm dialog wording is clear, parent-facing, and localized.
3. Cancel in delete dialog means no side effect.
4. Confirm in delete dialog triggers the existing delete + clearance path only once.
5. Revoke/logout/local-only confirmations remain distinct from delete wording and behavior.

## Acceptance Criteria

- Delete dialog title/body/cancel/confirm labels are sourced from `AppLocalizations`.
- `AccountEntryScreen` no longer contains hard-coded delete confirmation Chinese literals.
- Existing dialog and button keys remain unchanged:
  - `account-delete-confirm-dialog`
  - `account-delete-cancel-button`
  - `account-delete-confirm-button`
- Existing delete flow behavior remains unchanged in widget tests.
- No edits outside approved scope.

## Suggested TDD Cases

1. Tap delete shows delete confirm dialog with localized title/body and action labels.
2. Tap delete then cancel keeps `deleteCalls == 0` and does not trigger clearance.
3. Tap delete then confirm keeps existing deletion + clearance behavior.
4. Revoke/logout/local-only confirmation tests remain green, proving no cross-action regression.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `flutter analyze`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified

## Approval Gate

REFACTOR-052 was approved and completed with Option A only.

## Implementation Outcome

REFACTOR-052 completed delete-dialog localization on the account entry surface without changing destructive behavior:

- Delete confirmation title/body/action labels now come from `AppLocalizations`.
- Existing delete dialog keys and handler wiring remain unchanged.
- Focused widget coverage now asserts the localized destructive dialog copy is rendered before confirmation.

Verification completed locally:

- `flutter gen-l10n`
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `get_errors` on touched screen/test/generated l10n files
- `git diff --check`

Follow-up:

- Enter REFACTOR-053 as the next product-level UI/UX slice to improve version-blocked upgrade confidence and recovery wording on the account surface while preserving existing handlers.
