# REFACTOR-049 Family Trust Preview Plan

Status: proposed

## Context

REFACTOR-048 completed the Growth preview sheet polish. The next product-level UI/UX gap is the family trust surface that spans sharing, household invitation, and the shell family drawer. The app already has guarded share drafts, invite creation, invite re-entry, and household shared-context state. What is still weak is confidence: before a parent shares or invites, the UI does not clearly show what will be sent, who can use the link, what stays private, and what the family state means.

This should remain a product-surface slice, not an account lifecycle or app-composition slice. Account deletion, logout, consent revocation, repository wiring, invite accept semantics, re-entry orchestration, and `app.dart` decomposition stay out of scope.

## Goal

Make the family sharing moments feel safe and understandable:

- Parents can preview the family-safe story before opening the share sheet.
- Primary caregivers can understand an invite link before regenerating or sending it.
- The shell drawer summarizes household state with product language instead of raw phase strings.
- Account surfaces benefit only indirectly where they already render shared household/share components. REFACTOR-049 must not edit account files or change destructive/auth flows.

## Recommended Approach

### Option A: Family trust preview slice (recommended)

Add a lightweight trust layer around existing share and household UI:

- `ShareCalloutCard` gets a no-route preview sheet that shows the current share draft, what is included, and what is intentionally omitted before the share sheet opens.
- `HouseholdInviteCard` presents invite role, expiry, recipient expectation, and privacy scope before the create/regenerate action.
- The shell drawer replaces raw `lastPhase` display with stable household status copy.
- Existing widget tests cover ready, disabled, loading, and error states.

Tradeoff: crosses share, household, and shell presentation files, but remains UI-only and testable.

### Option B: Account page safety grouping

Re-layout the account entry page into primary task, recovery, and high-risk sections.

Tradeoff: high value, but it sits next to delete/revoke/logout flows. It risks accidentally changing the approved destructive lifecycle UX, so it should follow after the shared trust components are safer.

### Option C: `app.dart` composition decomposition

Start the long-postponed app composition split.

Tradeoff: real engineering value, but low direct user value and high route/provider risk. It should be a separate engineering slice after current product surfaces stop leaking trust ambiguity.

## Scope

Primary files:

- `mobile/lib/features/share/presentation/widgets/share_callout_card.dart`
- `mobile/lib/features/household/presentation/widgets/household_invite_card.dart`
- `mobile/lib/features/household/presentation/widgets/household_shared_context_card.dart` only if shared household status labels need a local helper cleanup.
- `mobile/lib/features/shell/presentation/app_shell_screen.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Expected tests:

- `mobile/test/features/practice/critical_ui_coverage_test.dart` for `ShareCalloutCard` in Home context.
- `mobile/test/features/household/household_widget_coverage_test.dart` for invite and shared-context states.
- A shell drawer widget test if existing shell coverage has a stable harness; otherwise add the smallest focused test around the status-label helper.

## Out of Scope

- No account deletion, logout, consent revocation, or local data clearance changes.
- No repository, API, re-entry coordinator, router, or `app.dart` wiring changes.
- No new package, route, analytics layer, backend contract, or generated model change.
- No account page file changes. If an account page layout change seems necessary, stop and split it into REFACTOR-050.
- No display of raw invite failure payloads, raw household phase names, raw activity IDs, or implementation fallback explanations.

## UX Contract

The implementation should make three promises visible:

1. **What gets shared:** the visible preview matches the current sanitized share draft and does not expose private IDs, account details, phone numbers, raw warnings, or implementation fallback text.
2. **Who can act:** invite actions clearly distinguish primary caregiver authority from caregiver read-only state.
3. **What happens next:** the drawer and invite card explain whether the family link is ready, waiting, unavailable, or safely disabled using parent-facing language.

## Acceptance Criteria

- Share card has a product-visible preview action when a draft exists, and tapping it opens a real preview sheet/dialog containing the current sanitized share draft before the platform share sheet opens.
- Share preview explains included content and omitted private details in localized copy.
- Invite card no longer leads with raw URL as the primary information; role, expiry, and safety scope are visually above or adjacent to the URL.
- Shell drawer no longer renders `householdSnapshot.lastPhase` directly.
- Shell drawer maps household status into explicit localized labels:
	- ready/accepted/synced states: `共享已接通`
	- invite-created or waiting states: `邀请待确认`
	- unavailable/error/timeout states: `共享暂时不可用`
	- disabled/read-only states: `仅可查看共享`
	- null/unknown/default states: `共享待同步`
- Existing share/invite buttons preserve enabled/disabled behavior.
- Existing retry and busy states remain reachable and covered.
- All new user-visible copy and semantics come from `AppLocalizations`.
- All new interactive controls meet the 48dp minimum target.
- No new cross-feature imports beyond already-existing presentation dependencies.

## Suggested TDD Cases

1. Share ready state shows a preview action; tapping it opens preview content with parent-facing privacy copy, and raw implementation terms/private identifiers are absent.
2. Share disabled/loading/error states keep the current CTA behavior and do not show a misleading preview.
3. Invite primary caregiver state shows role, expiry, visible privacy scope, and create/regenerate action without making the URL the only information.
4. Invite caregiver state stays read-only and explains that the primary caregiver manages invites.
5. Shell drawer maps ready, waiting, unavailable, disabled, null, and unknown `lastPhase` values to localized household status labels and never renders the raw phase string.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test mobile/test/features/practice/critical_ui_coverage_test.dart`
- `flutter test mobile/test/features/household/household_widget_coverage_test.dart`
- Any added shell drawer focused test
- `dart analyze`
- `bash ci/mobile-r4-release-gates.sh`
- `git diff --check`
- Staged credential scan before commit

## Approval Gate

Do not enter Stage 3.1 implementation until REFACTOR-049 is approved. If approved, execute Option A only. If the user wants a larger account page redesign, split that into a separate REFACTOR-050 so destructive account flows stay isolated.