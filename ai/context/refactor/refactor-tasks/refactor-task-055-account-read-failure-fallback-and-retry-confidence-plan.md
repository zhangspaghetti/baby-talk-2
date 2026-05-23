# REFACTOR-055 Account Read-Failure Fallback and Retry Confidence Plan

Status: done

## Context

REFACTOR-054 improved sign-in trust and submit-state clarity. The next product-level UI/UX gap on the account surface is the read-failure state.

The current account flow already exposes an error phase, keeps the page available, and offers a retry action. The behavior is safe, but the fallback story can still be clearer:

- Parents should immediately understand that the account page failed to load, but current practice access is still safe.
- Retry is available, yet the page could better explain what retry does and what remains usable before retry succeeds.
- Error messaging should reassure rather than feel diagnostic or internal.

This slice must remain presentation-only. It must not change load/retry behavior, repository/notifier logic, or routing semantics.

## Goal

Make account read-failure states feel safer and easier to recover from:

- Clarify what failed and what is still usable.
- Make retry intent clearer without changing the retry handler.
- Keep the account page from sounding diagnostic or implementation-heavy.
- Preserve existing error/retry keys and behavior.

## Recommended Approach

### Option A: Error fallback reassurance and retry guidance polish (recommended)

- Tighten localized read-failure copy.
- Add a small fallback reassurance note near the error/retry surface.
- Keep existing retry control and handler unchanged.
- Add focused widget assertions for error-state reassurance and retry guidance.

Tradeoff: small surface, high trust value, low behavior risk.

### Option B: Show expandable technical details

- Add more diagnostic detail for advanced troubleshooting.

Tradeoff: increases cognitive load and leaks implementation concerns into a caregiver surface.

### Option C: Auto-retry without user action

- Retry automatically on load failure.

Tradeoff: changes behavior semantics and may hide failure conditions; out of scope.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Adjust error-phase helper/reassurance copy.
- Add a small non-interactive retry guidance note if needed.
- Add focused widget assertions for load-failure messaging and retry visibility.

## Out of Scope

- No edits to `account_notifier.dart`, repositories, services, or persistence behavior.
- No changes to retry handler wiring or reload semantics.
- No router/provider/app-shell/household/share changes.
- No new dependencies, analytics, persistence, or backend contracts.

## UX Contract

The page must preserve these guarantees:

1. Read failure does not imply local practice data loss.
2. Retry remains the existing recovery action.
3. Error messaging stays parent-facing and non-diagnostic.
4. Existing status and retry keys remain stable.
5. The page continues to feel usable even when account state cannot be read.

## Acceptance Criteria

- Error state shows localized reassurance that current practice access remains available.
- Retry guidance is clearer and still uses the existing retry handler.
- The page does not expose implementation-heavy diagnostic language.
- Existing error/retry tests remain green.
- No edits outside approved scope.

## Suggested TDD Cases

1. Error state renders clearer fallback reassurance and retry guidance.
2. Retry button remains visible and wired as before.
3. Recovery after retry still returns to signed-out state in the existing test harness.
4. Existing sign-in, upgrade, and lifecycle tests remain green.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter analyze`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified

## Approval Gate

REFACTOR-055 was approved and completed with Option A only.

## Implementation Outcome

REFACTOR-055 completed read-failure fallback and retry-confidence polish without changing reload behavior:

- Read-failure copy now reassures that current practice remains usable and retry can happen later.
- The error state now shows a short retry-guidance note clarifying that reload does not clear local records.
- Existing error-state and retry button keys and handlers remain unchanged.

Verification completed locally:

- `flutter gen-l10n`
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `get_errors` on touched screen/test/generated l10n files
- `git diff --check`

Follow-up:

- Enter REFACTOR-056 as the next product-level UI/UX slice to clarify sync-state reassurance and status-chip meaning on the account surface.
