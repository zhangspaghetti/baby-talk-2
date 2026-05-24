# REFACTOR-060 Execution Slice Kickoff (2026-05-24)

Task: REFACTOR-060 Account status helper density trim and error-state wording unification
Status: in_progress
Owner: mobile UI/UX

## Entry Condition
- Preceding governance check completed with second full-regression validation:
  - Batch `20260524-154929`
  - Script result: exit code `1` (Admin Web fail, Mobile pass)
- Product/UI slice entry approved by user instruction: "再进入下一个产品级 UI/UX 切片"

## Slice Boundary (Hard)
1. Presentation-only changes.
2. No account state semantics changes.
3. No notifier/repository/handler rewiring.
4. No router/provider/app-shell changes.

## Target Surface
- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/lib/l10n/app_zh.arb`
- `mobile/test/features/account/account_entry_screen_test.dart`

## First Implementation Batch (B1)
1. Identify dense helper phases in AccountStatusCard/account entry view.
2. Keep one primary helper sentence for dense phases; keep retry/action guidance explicit.
3. Unify duplicated error-adjacent wording in zh copy while preserving semantics.
4. Add/adjust focused widget assertions for:
   - error phase helper hierarchy
   - one dense non-error phase helper hierarchy

## Batch B1 Verification Commands
1. `cd mobile && flutter gen-l10n`
2. `cd mobile && flutter test test/features/account/account_entry_screen_test.dart`
3. `cd mobile && flutter analyze`

## Exit Criteria for B1
1. Error-phase helper text is less repetitive but still explicit on action guidance.
2. At least one dense non-error phase removes redundant helper stacking.
3. No behavior contract changes; focused tests and analyze pass.
