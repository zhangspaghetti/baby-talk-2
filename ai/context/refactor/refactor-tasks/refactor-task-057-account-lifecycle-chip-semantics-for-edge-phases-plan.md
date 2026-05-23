# REFACTOR-057 Account Lifecycle Chip Semantics for Edge Phases Plan

Status: done

## Context

REFACTOR-056 improved sync-state chip guidance. The next product-level UI/UX gap is lifecycle edge-phase clarity on account status chips and nearby hints.

The account surface currently represents revoked, deleted, and read-failure states through existing titles, banners, and phase chips. The behavior is safe, but the edge-phase meaning can still feel ambiguous:

- Parents may not immediately understand how revoked/deleted phases differ from sync lag.
- Edge-phase chip semantics can look too similar to routine sync-state chips.
- The page should keep clear boundaries: destructive/consent phases are lifecycle states, not temporary upload delays.

This slice must remain presentation-only. It must not change notifier phase mapping, deletion/revoke behavior, or clearance semantics.

## Goal

Improve readability of lifecycle edge phases without behavior changes:

- Clarify revoked/deleted/read-failure chip semantics in parent-facing language.
- Keep lifecycle edge phases visually and textually distinct from routine sync lag.
- Preserve existing phase mapping, handlers, and destructive-action semantics.
- Keep keys and behavior stable where possible.

## Recommended Approach

### Option A: Edge-phase chip labeling and helper copy polish (recommended)

- Add short localized helper text for edge phases.
- Refine phase chip wording where needed to reduce ambiguity.
- Keep all lifecycle behavior and retry/destructive actions unchanged.
- Add focused widget assertions for edge-phase wording.

Tradeoff: low implementation risk with clear trust benefits.

### Option B: Add dedicated iconography per edge phase

- Introduce new icon set or icon-color matrix.

Tradeoff: larger visual scope and extra design debt for a bounded slice.

### Option C: Hide phase chips in edge states

- Remove chips to reduce cognitive load.

Tradeoff: loses useful at-a-glance status and weakens consistency.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Refine edge-phase helper/chip copy and related display text.
- Add focused assertions for revoked/deleted/error edge-phase messaging.

## Out of Scope

- No edits to `account_notifier.dart`, repositories, services, or lifecycle semantics.
- No change to revoke/delete handler wiring or local sensitive-data clearance behavior.
- No router/provider/app-shell/household/share changes.
- No new dependencies, analytics, persistence, or backend contracts.

## UX Contract

The page must preserve these guarantees:

1. Revoked/deleted/error edge phases remain behaviorally unchanged.
2. Edge-phase messaging stays clear and non-technical.
3. Sync delay and lifecycle states are clearly differentiated.
4. Existing destructive flow safeguards remain intact.
5. Existing stable keys remain available for tests.

## Acceptance Criteria

- Edge phases render clearer localized semantics in chips/helper text.
- Revoked/deleted states are no longer easily confused with temporary sync lag.
- Existing revoke/delete/retry behavior remains unchanged.
- Existing lifecycle and account tests remain green.
- No edits outside approved scope.

## Suggested TDD Cases

1. Revoked phase shows clear lifecycle meaning distinct from pending-sync semantics.
2. Deleted phase messaging reinforces finality while keeping local-usage guidance coherent.
3. Error phase messaging remains reassuring and distinct from revoke/delete semantics.
4. Existing destructive-flow tests remain green.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter analyze`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified

## Approval Gate

REFACTOR-057 was approved and completed with Option A only.

## Implementation Outcome

REFACTOR-057 completed edge-phase chip semantic separation without changing lifecycle behavior:

- Account status chip guidance now routes by phase.
	- revoked/deleted -> lifecycle guidance
	- error -> read-failure guidance
	- other phases -> sync-lag guidance
- Existing chip keys/count generation and lifecycle/retry handlers remain unchanged.
- Focused tests now prove edge phases are not conflated with pending-sync semantics.

Verification completed locally:

- `flutter gen-l10n`
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `get_errors` on touched screen/test/generated l10n files
- `git diff --check`

Follow-up:

- Enter REFACTOR-058 as the next product-level UI/UX slice to polish account status card message hierarchy and reduce duplicate guidance density.
