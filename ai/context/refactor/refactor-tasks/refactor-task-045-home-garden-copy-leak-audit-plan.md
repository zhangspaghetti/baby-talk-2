# REFACTOR-045: Home/Garden Copy Leak Audit Plan

Status: done
Stage: Stage 3.4 implementation slice
Owner: mobile UI/UX
Created: 2026-05-21
Depends on: REFACTOR-044 Garden continuation copy polish

## Purpose

Audit the shared Home/Garden continuation and growth surfaces for remaining product-facing implementation vocabulary after REFACTOR-044.

Parents should see stable, warm product copy when continuation, fallback, or garden-growth data is incomplete. Internal diagnostics such as raw recommendation labels, projection warnings, fallback reasons, and notifier messages must remain internal signals only.

## Scope

Allowed:

- Replace visible Home/Garden uses of raw `reasonLabel`, `fallbackReason`, notifier messages, and projection warnings with localized product copy.
- Keep domain, repository, route, account, backend, sync, and Garden projection behavior unchanged.
- Add focused assertions proving raw warning/fallback/projection text is not displayed.

Not allowed:

- Changing continuity recommendation selection, Garden growth calculation, event storage, or route pushing behavior.
- Refactoring feature boundaries outside the narrow UI copy audit.
- Product-wide copy audit outside Home/Garden surfaces.

## Acceptance Criteria

- Home/Garden l10n strings contain no parent-facing `continuity`, `recommendation`, `starter activity`, `safe fallback`, `route args`, `snapshot`, `projection`, or `cadence` terminology.
- Home week stats maps recommendation reasons to parent-facing labels instead of raw domain labels.
- Home and Garden growth warning/error states do not render raw projection warnings or notifier messages.
- Focused Home/Garden widget tests prove raw projection/fallback diagnostics are hidden.

## Verification Plan

- `flutter test test/features/shell/garden_growth_combined_screen_test.dart test/features/practice/critical_ui_coverage_test.dart test/smoke/app_boot_test.dart`
- `dart analyze`
- Home/Garden l10n internal-term scan
- Home/Garden raw render scan for warning/fallback/reason/projection fields
- `git diff --check`
- `bash ci/mobile-r4-release-gates.sh`

## Implementation Evidence

- Home week stats now maps `PracticeContinuityReason` to localized parent-facing labels.
- Home growth summary and Home garden mini-entry use product fallback/warning copy instead of raw notifier/projection strings.
- Garden hero, Growth tab, and combined Garden/Growth view use localized projection warning copy.
- Focused tests assert guarded projection warning copy and absence of raw projection details.