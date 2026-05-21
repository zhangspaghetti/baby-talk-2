# REFACTOR-046: Discover/Share/Mentor Copy Leak Audit Plan

Status: done
Stage: Stage 3.5 implementation slice
Owner: mobile UI/UX
Created: 2026-05-21
Depends on: REFACTOR-045 Home/Garden copy leak audit

## Purpose

Extend the copy-leak audit beyond Home/Garden to Discover, Share, and Mentor surfaces.

The product should not show raw recovery diagnostics, fallback codes, or internal recommendation vocabulary on parent-facing surfaces. This slice keeps the behavior and data contracts unchanged while tightening visible Discover copy and verifying Share/Mentor guardrails.

## Scope

Allowed:

- Replace Discover activity recoverable-warning text with localized product copy.
- Verify Share public payload and message sanitization still blocks internal fragments.
- Verify Mentor fallback codes remain internal and visible banners use product copy.

Not allowed:

- Changing catalog recovery, share payload contracts, mentor suggestion selection, routing, account, backend, or sync behavior.
- Broad copy rewrites outside Discover/Share/Mentor leak prevention.

## Acceptance Criteria

- Discover cards do not render raw `warningMessage` from catalog/activity data.
- Discover/Share/Mentor l10n strings contain no parent-facing internal terms such as `continuity`, `recommendation`, `starter activity`, `safe fallback`, `route args`, `snapshot`, `warningMessage`, `fallbackReason`, or `debug`.
- Share tests continue to prove internal fields/fragments are excluded from payloads and share messages.
- Mentor tests continue to prove fallback and availability banners are product-facing while fallback codes stay internal.

## Verification Plan

- `flutter test test/features/shell/discover_screen_test.dart test/features/share/share_repository_test.dart test/features/share/share_notifier_test.dart test/features/mentor/mentor_shell_panel_test.dart test/features/mentor/mentor_notifier_test.dart`
- `dart analyze`
- Discover/Share/Mentor l10n internal-term scan
- Discover/Share/Mentor raw render scan for warning/fallback/reason fields
- `git diff --check`
- `bash ci/mobile-r4-release-gates.sh`

## Implementation Evidence

- `DiscoverActivityCard` now uses localized warning copy when a recoverable activity issue exists.
- Discover coverage asserts the raw activity warning is not displayed.
- Share and Mentor focused suites pass without behavior changes, preserving existing sanitization and fallback-code boundaries.