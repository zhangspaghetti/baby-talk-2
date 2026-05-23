# REFACTOR-059 Account Status Helper Parity and Consistency Pass Plan

Status: done

## Context

REFACTOR-058 reduced dense-state helper duplication in AccountStatusCard. The next product-level UI/UX gap is helper parity and consistency between home status card and account entry status section.

Current behavior is safe, but copy and helper priority can still diverge between the two surfaces over time:

- Home card and account entry may present similar states with slightly different helper emphasis.
- Users can move between surfaces and perceive inconsistent guidance hierarchy.
- The product should keep one consistent rule set for what helper text is primary/secondary per phase.

This slice must remain presentation-only. It must not alter account state semantics, phase mapping, or handler behavior.

## Goal

Align helper messaging strategy across home and account surfaces:

- Apply consistent helper-priority rules for the same phase.
- Reduce wording drift for shared state semantics.
- Preserve current actions and behavior.
- Keep testability high with stable keys where possible.

## Recommended Approach

### Option A: Cross-surface helper parity pass (recommended)

- Audit phase-by-phase helper rendering in both surfaces.
- Normalize helper priority and wording for shared states.
- Add focused assertions for parity in 2-3 representative phases.

Tradeoff: high coherence gain with low technical risk.

### Option B: Fully shared presenter abstraction

- Extract helper-render logic into a shared presenter layer.

Tradeoff: larger refactor risk, outside bounded UI slice.

### Option C: Keep divergence and only tweak copy in one surface

- Patch only one view to reduce effort.

Tradeoff: preserves inconsistency and future regressions.

## Scope

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/test/features/account/account_entry_screen_test.dart`
- `mobile/lib/l10n/app_zh.arb`
- Generated l10n files after `flutter gen-l10n`

Allowed implementation work:

- Align helper display conditions and wording between home and account surfaces.
- Add focused parity assertions in existing widget tests.

## Out of Scope

- No edits to notifier/repository/services or phase mapping semantics.
- No changes to button handlers or destructive/retry behavior.
- No router/provider/app-shell/household/share changes.
- No new dependencies, analytics, persistence, or backend contracts.

## UX Contract

The page must preserve these guarantees:

1. Same phase should communicate with equivalent helper hierarchy across surfaces.
2. Critical status and actions remain obvious.
3. Reduced duplication does not hide required guidance.
4. Behavior remains unchanged.
5. Existing stable keys remain available where possible.

## Acceptance Criteria

- At least 2 representative phases show helper parity across home and account surfaces.
- No contradictory guidance remains between the two surfaces for the same phase.
- Existing account behavior tests remain green.
- No edits outside approved scope.

## Suggested TDD Cases

1. Version-blocked helper hierarchy is consistent across home and account surfaces.
2. Error-state helper hierarchy is consistent across home and account surfaces.
3. Pending-sync helper priority remains coherent across surfaces.
4. Existing action-path tests remain green.

## Verification Plan

- `flutter gen-l10n`
- `dart_format` on edited Dart files
- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter analyze`
- `git diff --check`
- Staged scope scan proving notifier/repository/app/shell/household/share files were not modified

## Approval Gate

Do not enter Stage 3.1 implementation until REFACTOR-059 is approved. If approved, execute Option A only.

## Implementation Outcome

REFACTOR-059 completed with Option A (cross-surface helper parity pass) and remained presentation-only:

- Account entry status helper now uses the same phase-body resolver as home status card for shared phases.
- Error phase now suppresses submission helper in account entry, matching home helper-priority behavior.
- Added focused parity assertions for version-blocked and pending-sync helper consistency across home/account surfaces.

Verification completed locally:

- `flutter test test/features/account/account_entry_screen_test.dart`
- `flutter test test/features/account/account_repository_test.dart`
- `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart`
- `get_errors` on touched files
- `git diff --check`

Follow-up:

- Enter REFACTOR-060 as next product-level UI/UX slice.
