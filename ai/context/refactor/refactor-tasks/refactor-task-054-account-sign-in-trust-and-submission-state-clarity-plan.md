# REFACTOR-054 Account Sign-In Trust and Submission-State Clarity Plan

Status: done

## Context

REFACTOR-053 improved the upgrade-blocked recovery story on the account surface. The next product-level UI/UX gap is the sign-in entry itself.

The current account page already guards phone/code validation, preserves local-only behavior, and exposes submit success/error states. The behavior is safe, but the trust story around sign-in still has room to improve:

- Parents see phone and verification fields, but the form does not strongly reinforce what this flow will and will not change before submission.
- Validation and submission feedback exists, but the hierarchy between pre-submit trust guidance and post-submit status messaging could be clearer.
- The page should reduce hesitation by answering two product questions earlier: will this affect my local practice records, and what should I expect after submitting?

This slice must remain presentation-only. It must not change sign-in validation rules, repository/notifier logic, session persistence, or routing behavior.

## Goal

Make the sign-in form feel safer and more predictable without changing behavior:

- Clarify that the sign-in flow does not erase or overwrite local practice records.
- Make pre-submit guidance and post-submit status messages easier to scan.
- Keep existing validation behavior, submit handler wiring, and success/error semantics unchanged.
- Preserve the current field keys and submit button behavior.

## Recommended Approach

### Option A: Trust note and submission-state copy polish (recommended)

- Tighten localized copy near the sign-in form.
- Add or refine a small trust note that explains local records remain safe before submission.
- Ensure success-state helper copy clearly explains what the user should do next.
- Cover invalid input, successful placeholder sign-in, and the signed-out/local-only entry copy in widget tests.

Tradeoff: high product clarity for low behavior risk.

### Option B: Add a pre-submit confirmation dialog

- Show a dialog before sign-in submit.

Tradeoff: extra friction for a non-destructive action with little safety benefit.

### Option C: Collapse guidance into validation messages only

- Remove helper copy and rely on field errors/submission messages.

Tradeoff: lower visual density, but weakens trust and predictability for first-time caregivers.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Adjust sign-in helper/trust copy and submission-state explanatory copy.
- Add a small non-interactive trust note near the sign-in form if needed.
- Add focused widget assertions for signed-out/local-only guidance and successful submit messaging.

## Out of Scope

- No edits to `account_notifier.dart`, repositories, account services, local stores, or persistence behavior.
- No changes to phone/code validation rules or submit handler semantics.
- No changes to router/provider/app-shell/household/share flows.
- No new dependencies, analytics, persistence, or backend contracts.

## UX Contract

The page must preserve these guarantees:

1. Signing in does not imply local data loss.
2. Invalid input is blocked before repository write, as today.
3. Successful submit preserves the current signed-in pending-sync behavior.
4. Guidance remains supportive, not diagnostic or implementation-heavy.
5. Field keys and submit button behavior remain unchanged.

## Acceptance Criteria

- Sign-in area shows localized trust guidance that local practice records remain safe.
- Signed-out/local-only sign-in entry copy is more predictable and parent-facing.
- Success-state helper copy explains what happens next without exposing implementation terms.
- Existing validation and submit tests remain green.
- No edits outside approved scope.

## Suggested TDD Cases

1. Signed-out or local-only entry shows trust guidance near the sign-in form.
2. Invalid phone/code still blocks repository writes and preserves current errors.
3. Successful placeholder sign-in still transitions to pending-sync and shows the refined next-step message.
4. Existing account lifecycle and upgrade tests remain green.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter analyze`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified

## Approval Gate

REFACTOR-054 was approved and completed with Option A only.

## Implementation Outcome

REFACTOR-054 completed sign-in trust and submission-state copy polish without changing validation or submit behavior:

- The sign-in form now carries a stable trust note that explicitly says local practice records are not cleared by account sign-in.
- Submit-success guidance now better explains the next step and that pending records will continue trying to upload.
- Existing field keys, submit button behavior, and validation semantics remain unchanged.

Verification completed locally:

- `flutter gen-l10n`
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `get_errors` on touched screen/test/generated l10n files
- `git diff --check`

Follow-up:

- Enter REFACTOR-055 as the next product-level UI/UX slice to clarify account read-failure fallback and retry confidence on the account surface.
