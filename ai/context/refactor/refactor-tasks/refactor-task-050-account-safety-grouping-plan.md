# REFACTOR-050 Account Safety Grouping Plan

Status: proposed

## Context

REFACTOR-049 completed the family trust preview slice. The next product-level trust gap is the account entry page. It currently carries account status, login, version upgrade, sync retry, household context, invite creation, consent revocation, account deletion, logout, local-only fallback, and close actions in one long surface. The behavior is mostly guarded, but the information architecture makes it hard for a caregiver to answer: what is my current account state, what is the one best next action, what is recovery, and what is risky.

This slice must remain presentation-only. Account deletion and local sensitive data clearance have already been approved and verified in earlier refactors; REFACTOR-050 must not reinterpret those semantics.

## Goal

Make the account entry page safer to scan without changing account behavior:

- The top of the page clearly states the current account/sync state and the single primary next action.
- Recovery actions stay visible but are separated from login/upgrade and destructive account actions.
- Logout, return-to-local-only, consent revocation, and account deletion are described with distinct product language.
- High-risk actions are visually isolated from routine account and sync actions.
- Household context and invite cards remain available but do not compete with the account state decision.

## Recommended Approach

### Option A: Account entry safety grouping (recommended)

Reorganize `AccountEntryScreen` into stable sections:

1. **Current status:** phase headline, status banner, stable reassurance that sync failures do not block practice and local records stay available.
2. **Primary action:** exactly one primary CTA for the current phase, such as login/consent or upgrade.
3. **Recovery:** sync retry and status reload actions, preserving existing handlers and enabled states.
4. **Family context:** existing household shared-context and invite cards, visually demoted below account status/recovery.
5. **Account management:** logout and return-to-local-only, with copy that distinguishes signed-out from local-only fallback.
6. **Danger zone:** consent revocation and account deletion, with deletion keeping its existing confirmation dialog and clearance chain.

Tradeoff: touches a high-risk page, but the blast radius stays bounded if implementation only moves widgets, localizes page/dialog copy, and adds characterization tests before changing layout.

### Option B: Account copy-source cleanup

Move visible account page strings and delete dialog copy into l10n without changing layout.

Tradeoff: lower risk, but it does not reduce the current mis-tap and hierarchy problem.

### Option C: Household/shared-context residual copy cleanup

Clean remaining household/share implementation terms such as raw `activity` wording and non-localized banners.

Tradeoff: useful follow-up, but REFACTOR-049 already improved family trust. Account safety is now the higher-value product risk.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Section wrappers, titles, helper copy, spacing, button grouping, and keys inside `AccountEntryScreen`.
- Localizing the delete confirmation dialog copy without changing its confirm/cancel behavior.
- Adding page-level characterization tests for logout, local-only fallback, revoke, delete cancel/confirm, manual sync retry, and zone separation.

## Out of Scope

- No changes to `account_notifier.dart`, account repositories, account API services, local stores, clearance orchestrators, or sync phase logic.
- No changes to `mobile/lib/app/app.dart`, router wiring, provider wiring, or backend contracts.
- No household/share/shell component behavior changes.
- No change to action handler binding: sync retry still calls manual runtime refresh, revoke still calls revoke consent, delete still opens its own confirmation then calls delete account, logout still clears the local session, local-only fallback still calls clear session with `revertToLocalOnly: true`, and close still calls `Navigator.maybePop()`.
- No merging delete/revoke/logout/local-only handlers or confirmation dialogs.
- No hiding destructive actions in icon-only controls, menus, long-press gestures, or swipe actions.
- No new package, route, analytics layer, or storage migration.
- No new confirmation step for revoke/logout/local-only fallback unless split into a separate approved slice.

## UX Contract

The implementation should preserve these distinctions:

1. **Logout is not deletion:** logout clears the account session but keeps local practice records available.
2. **Local-only fallback is not signed-out:** returning to local-only preserves the local baby profile mode.
3. **Consent revocation is not account deletion:** revoke stops account consent/sync semantics but does not run the account deletion clearance path.
4. **Delete is uniquely destructive:** delete keeps a visible confirmation dialog and is the only action that triggers account deletion clearance.
5. **Recovery is always reachable:** sync retry and read retry remain visible where currently applicable.

## Acceptance Criteria

- Account entry page renders explicit localized sections for current status, primary action, recovery, family context, account management, and danger zone.
- At most one primary filled CTA is shown in the primary action section for a given phase.
- Version-blocked upgrade remains visible and keeps its existing disabled/enabled behavior.
- Manual sync retry remains reachable and still uses `AccountRuntimeTrigger.manualRetry`.
- Household shared-context and invite cards remain visible and retain existing props/handlers.
- Logout and local-only fallback are visually separate from delete/revoke and have distinct helper copy.
- Revoke and delete sit in a danger zone, but revoke does not share delete's confirmation dialog or handler.
- Delete confirmation dialog remains visible, cancel has no side effects, and confirm triggers the existing account deletion + local sensitive data clearance path exactly once.
- Close remains a simple page-dismiss action and does not call account, sync, revoke, delete, logout, or local-only handlers.
- All new user-visible copy comes from `AppLocalizations`.
- Interactive controls keep at least the 48dp minimum target.
- No new cross-feature imports and no edits outside the approved scope.

## Suggested TDD Cases

1. Signed-out/local-only page shows the primary login action and does not mix it with the danger zone.
2. Version-blocked page shows upgrade in the primary/recovery area and keeps destructive actions visually separated.
3. Signed-in page shows account management and danger zone sections with distinct logout/local-only/revoke/delete copy.
4. Manual sync retry still calls `AccountRuntimeTrigger.manualRetry`.
5. Logout routes to signed-out state without triggering revoke/delete/clearance.
6. Return-to-local-only routes to local-only state without triggering revoke/delete/clearance.
7. Revoke calls revoke consent and does not open the delete confirmation dialog.
8. Delete cancel triggers no clearance; delete confirm triggers the existing clearance path exactly once.
9. Close dismisses the account page through the existing navigator path and triggers no account lifecycle action.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `flutter analyze`
- `bash ci/mobile-r4-release-gates.sh`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/household/share/shell files were not modified
- Staged credential scan before commit

## Approval Gate

Do not enter Stage 3.1 implementation until REFACTOR-050 is approved. If approved, execute Option A only. If stronger revoke/logout confirmation behavior is desired, split it into a separate REFACTOR-051 so account lifecycle semantics stay reviewable.