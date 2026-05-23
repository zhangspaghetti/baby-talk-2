# REFACTOR-053 Account Upgrade-Blocked Reassurance and Recovery Clarity Plan

Status: done

## Context

REFACTOR-052 finished localization cleanup for the delete confirmation dialog. The next product-level UI/UX gap on the same account surface is the version-blocked upgrade state.

The current account page correctly exposes an upgrade CTA, retry action, disabled handling when `upgradeUrl` is absent, and launcher-failure messaging. The behavior is guarded, but the product story is still weaker than it should be:

- Parents can see that an upgrade is needed, but the safe next step and fallback path are not explained with enough confidence.
- When the upgrade entry is unavailable or opening the page fails, the surface reports failure but does not strongly reassure that local practice and records remain available.
- Upgrade-blocked and retry states still compete visually instead of clearly answering: what should I do now, and what is still safe while I wait?

This slice must remain presentation-only. It must not change upgrade URL wiring, notifier logic, retry trigger mapping, or account persistence behavior.

## Goal

Make the upgrade-blocked account state feel safer and easier to recover from:

- Clarify the primary next step when upgrade is required.
- Add reassurance copy that local practice and local records remain available while upgrade is pending.
- Distinguish between three user-visible states:
  - upgrade available and tappable
  - upgrade required but entry temporarily unavailable
  - upgrade page failed to open and should be retried
- Preserve existing handlers and button enablement rules.

## Recommended Approach

### Option A: Upgrade reassurance copy and helper hierarchy polish (recommended)

- Tighten localized title/body/hint copy for the version-blocked state.
- Add a short reassurance note near the upgrade/retry area that explicitly says local records remain safe.
- Keep upgrade as the primary action and retry as the recovery action without changing their handlers.
- Cover upgrade-available, upgrade-unavailable, and launch-failed states with focused widget expectations.

Tradeoff: product-value focused with low behavior risk.

### Option B: Add another confirmation before opening the upgrade page

- Require an extra dialog before leaving to the upgrade page.

Tradeoff: higher friction with little safety gain because opening the upgrade page is not destructive.

### Option C: Automatically fall back to retry when upgrade open fails

- Remap open failure into an automatic runtime retry.

Tradeoff: changes behavior semantics and could hide the real issue; out of scope for this bounded UI slice.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Adjust upgrade-state localized copy, helper text, and local reassurance note.
- Reorder or restyle only within the existing account primary/recovery section structure.
- Add focused widget assertions for upgrade available, unavailable, and launcher-failure wording.

## Out of Scope

- No edits to `account_notifier.dart`, repositories, link opener services, API/store files, or sync semantics.
- No changes to upgrade URL sourcing or `canOpenUpgradePage` logic.
- No change to retry trigger mapping: manual retry must remain `AccountRuntimeTrigger.manualRetry`.
- No router/provider/app-shell/household/share changes.
- No new dependencies, analytics, persistence, or backend contracts.

## UX Contract

The page must preserve these recovery guarantees:

1. Upgrade remains the primary action only when a real upgrade entry exists.
2. Retry remains a secondary recovery action and still calls the existing manual retry path.
3. Unavailable upgrade entry must not look actionable.
4. Launcher failure must preserve the upgrade button and show a clear retryable message.
5. Local practice and local records must be explicitly described as safe while upgrade is pending.

## Acceptance Criteria

- Version-blocked state shows localized, parent-facing copy that clearly explains the next step.
- Upgrade unavailable state shows localized fallback wording that explains what to do next without implying data loss.
- Launcher failure state shows localized retryable wording while preserving the existing upgrade CTA.
- Local records/practice reassurance is visible in the version-blocked flow.
- Existing button keys and handler bindings remain unchanged.
- No edits outside approved scope.

## Suggested TDD Cases

1. Upgrade available state shows primary upgrade CTA plus reassurance that local records remain available.
2. Missing `upgradeUrl` keeps the upgrade button disabled and shows the localized fallback explanation.
3. Launcher failure keeps the upgrade button visible and shows localized retryable failure wording.
4. Manual retry still calls `AccountRuntimeTrigger.manualRetry`.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter analyze`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified

## Approval Gate

REFACTOR-053 was approved and completed with Option A only.

## Implementation Outcome

REFACTOR-053 completed version-blocked reassurance and recovery copy polish without changing upgrade or retry behavior:

- Version-blocked account surfaces now show a stable reassurance note that local practice records remain available while upgrade is pending.
- Upgrade-available and upgrade-unavailable helper copy is tighter and more parent-facing.
- Existing upgrade/retry button keys and handler bindings remain unchanged.

Verification completed locally:

- `flutter gen-l10n`
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `get_errors` on touched screen/test/generated l10n files
- `git diff --check`

Follow-up:

- Enter REFACTOR-054 as the next product-level UI/UX slice to clarify sign-in form trust messaging and submission-state guidance on the account surface.
