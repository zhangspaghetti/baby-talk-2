# REFACTOR-047: App-Wide Product Copy Scan Plan

Status: done
Stage: Stage 3.6 implementation slice
Owner: mobile UI/UX
Created: 2026-05-21
Depends on: REFACTOR-046 Discover/Share/Mentor copy leak audit

## Purpose

Run a broader product-facing copy scan across the mobile app after the focused continuation and Discover audits.

The app should not explain itself to parents using implementation words such as route args, snapshots, projections, debug labels, sync seams, or raw phase codes. This slice keeps behavior unchanged and only rewrites visible text that can appear in app UI.

## Scope

Allowed:

- Replace l10n strings containing internal vocabulary with parent-facing Chinese copy.
- Replace direct UI strings in boot failure, account sync chips, and practice entry fallback copy.
- Keep test names, domain models, repository diagnostics, and debug-only code outside the product-facing copy requirement.

Not allowed:

- Changing boot routing, account sync behavior, household shared context behavior, Discover routing, Practice route parsing, backend, sync, or storage contracts.
- Removing diagnostic fields used internally by tests or repositories.

## Acceptance Criteria

- `mobile/lib/l10n/app_zh.arb` has no product-facing matches for the scanned internal terms.
- Direct UI text/message/tooltip strings in `mobile/lib/**` have no matches for the scanned internal terms.
- Boot, account, household, Discover, growth, and practice-entry fallback copy remain user-facing and actionable.

## Verification Plan

- `flutter test test/features/practice/critical_ui_coverage_test.dart test/smoke/app_boot_test.dart test/features/account/account_entry_screen_test.dart test/features/household/household_widget_coverage_test.dart test/features/shell/discover_screen_test.dart`
- `flutter test test/features/mentor/mentor_shell_panel_test.dart test/features/mentor/mentor_notifier_test.dart`
- `dart analyze`
- all-l10n internal-term scan
- direct UI string internal-term scan
- `git diff --check`
- `bash ci/mobile-r4-release-gates.sh`

## Implementation Evidence

- Boot failure copy no longer exposes onboarding read details.
- Account copy no longer shows shell/session/seam/snapshot terms, raw sync phase codes, or raw status labels.
- Household, Discover, Growth, Practice entry fallback, and Mentor shared-suggestion copy no longer exposes route args, projection, activity-card, continuity, guest/local-only, or event implementation terms.
- Remaining scan hits were classified as non-product-facing identifiers, test names/keys, generated model diagnostics, protocol headers, or debug-only text.
- Focused UI tests, Mentor tests, analyze, scans, diff checks, and R4 gate passed after the cleanup.