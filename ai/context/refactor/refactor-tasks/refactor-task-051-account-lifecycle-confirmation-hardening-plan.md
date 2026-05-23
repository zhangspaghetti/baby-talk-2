# REFACTOR-051 Account Lifecycle Confirmation Hardening Plan

Status: proposed

## Context

REFACTOR-050 completed account page safety grouping and made destructive actions easier to locate. The remaining trust gap is action certainty: revoke consent, logout to signed-out, and return-to-local-only all perform meaningful lifecycle changes without any explicit in-flow confirmation. Delete already has a dedicated confirmation and clearance chain, but other lifecycle actions can still be triggered by accidental taps during fast scroll.

This slice must stay presentation-only. It should harden interaction certainty without changing repository/notifier semantics, trigger mapping, or clearance behavior.

## Goal

Reduce accidental lifecycle actions on the account entry page while preserving current behavior:

- Add lightweight confirmation steps for revoke, logout, and return-to-local-only.
- Keep account deletion as the unique high-severity destructive flow with its existing confirmation + clearance behavior.
- Make each confirmation clearly explain impact differences (signed-out vs local-only vs consent revoked).
- Preserve all existing handlers, trigger paths, and side-effect semantics.

## Recommended Approach

### Option A: Lifecycle confirmation dialogs (recommended)

Add dedicated confirmation dialogs in `AccountEntryScreen` for:

1. **Logout confirmation** before `clearSession()`.
2. **Return-to-local-only confirmation** before `clearSession(revertToLocalOnly: true)`.
3. **Revoke confirmation** before `revokeConsent()`.

Keep delete confirmation as-is in its own dialog and path.

Tradeoff: introduces one extra tap for three actions, but sharply lowers accidental execution risk and clarifies lifecycle semantics in-context.

### Option B: Press-and-hold affordance only

Require long-press for revoke/logout/local-only actions and remove dialogs.

Tradeoff: lower visual interruption, but accessibility/discoverability risk is higher and behavior is less explicit.

### Option C: Snackbar undo model

Execute action immediately and show undo snackbar.

Tradeoff: adds asynchronous rollback complexity and risks semantic drift in notifier/repository behavior; not suitable for this bounded UI slice.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Add/adjust confirmation dialog widgets and copy for revoke/logout/local-only.
- Add stable keys for new dialog elements and buttons.
- Add/adjust widget tests for cancel/confirm side effects and non-side effects.
- Maintain existing section layout introduced by REFACTOR-050.

## Out of Scope

- No edits to `account_notifier.dart`, repository/data/API/store files, or local sensitive data clearance orchestrator.
- No change to delete-account confirmation flow or its clearance trigger behavior.
- No changes to router/provider wiring, `mobile/lib/app/app.dart`, shell/household/share logic.
- No new analytics events, package dependencies, persistence, or backend contracts.
- No remapping of action handlers:
  - sync retry -> `refreshRuntimeState(trigger: AccountRuntimeTrigger.manualRetry)`
  - revoke -> `revokeConsent()`
  - delete -> existing delete confirm then `deleteAccount()`
  - logout -> `clearSession()`
  - local-only -> `clearSession(revertToLocalOnly: true)`
  - close -> `Navigator.maybePop()`

## UX Contract

The page must preserve these distinctions:

1. **Logout** moves to signed-out lifecycle state but does not delete account.
2. **Return to local-only** keeps local profile mode and differs from signed-out.
3. **Revoke consent** changes consent state and future sync eligibility.
4. **Delete account** remains uniquely destructive with its existing confirmation and clearance path.
5. **Cancel always means no side effect** for all confirmation dialogs.

## Acceptance Criteria

- Revoke, logout, and local-only each require explicit user confirmation before their existing handlers run.
- Each new dialog has localized title/body/action copy from `AppLocalizations`.
- Cancel in each new dialog performs no lifecycle mutation.
- Confirm in each new dialog triggers only its own existing handler once.
- Existing delete confirmation behavior remains unchanged and still drives clearance only on confirm.
- Existing section keys and button keys from REFACTOR-050 remain available.
- No new cross-feature imports and no edits outside approved scope.

## Suggested TDD Cases

1. Tap revoke -> dialog appears; cancel leaves `revokeCalls == 0`; confirm makes `revokeCalls == 1`.
2. Tap logout -> dialog appears; cancel leaves `clearCalls == 0`; confirm makes `clearCalls == 1` and `lastClearRevertToLocalOnly == false`.
3. Tap local-only -> dialog appears; cancel leaves `clearCalls == 0`; confirm makes `clearCalls == 1` and `lastClearRevertToLocalOnly == true`.
4. Revoke/logout/local-only dialogs do not trigger delete dialog and do not call delete handler.
5. Existing delete dialog still cancels with no side effect and confirms with deletion + clearance once.
6. Close action remains direct dismiss with no lifecycle side effects.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `flutter analyze`
- `bash ci/mobile-r4-release-gates.sh`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified
- Staged credential scan before commit

## Approval Gate

Do not enter Stage 3.1 implementation until REFACTOR-051 is approved. If approved, execute Option A only.
