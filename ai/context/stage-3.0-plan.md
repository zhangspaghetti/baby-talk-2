# Mobile UI/UX Stage 3.0 Plan

> Status: Draft for human approval. Do not enter Stage 3.1 implementation until this plan is approved.
>
> Reader: mobile engineers and agentic workers who will execute the Flutter UI/UX refactor in small vertical slices.
>
> Goal: turn the existing partial foundations into enforceable UI/UX, architecture, i18n, async-state, and accessibility contracts without a big-bang rewrite.

## 1. Stage and Risk Boundary

This work is ASF Stage 3.0: design, planning, task decomposition, and acceptance criteria. It is not an implementation pass.

Allowed in Stage 3.0:

- Audit current mobile UI/UX and architecture evidence.
- Define contracts for design tokens, localization, accessibility, async states, and feature boundaries.
- Split work into file-level vertical slices with a dependency DAG.
- Define verification commands and manual QA expectations.

Not allowed without explicit human approval:

- Deleting existing production code.
- Rebuilding the mobile app from scratch.
- Adding new third-party dependencies.
- Changing backend/public API contracts.
- Combining visual redesign with risky account deletion, local data clearance, or bootstrap/router rewrites in the same slice.

## 2. Evidence Baseline

The mobile app already has useful foundations and should not be treated as greenfield:

- `mobile/lib/app/theme/app_theme.dart` defines `BabyTalkColors`, light/dark `ThemeData`, typography, shadows, and design-system color constants.
- `mobile/lib/app/theme/app_layout_constants.dart` defines spacing, radius, content width, input padding, button height, and minimum touch target constants.
- `mobile/pubspec.yaml` includes `flutter_localizations`, `intl`, and `flutter.generate: true`.
- `mobile/lib/l10n/` contains generated localization code and ARB source.
- Multiple widgets already use `Semantics`, especially in onboarding, practice, mentor, and shell surfaces.
- Repository and provider boundaries exist under `features/*/data/repositories` and `mobile/lib/app/providers/repository_providers.dart`.

The problem is inconsistent adoption:

- `mobile/lib/app/app.dart` is a composition giant: bootstrap, multiple `MaterialApp` branches, repository/notifier wiring, router resolution, and feature imports live together.
- User-visible strings still appear directly in widgets, including account deletion dialog, onboarding preview copy, Growth labels, and some mentor/debug chips.
- Raw layout numbers still appear in feature widgets despite `AppLayoutConstants` existing.
- UI state handling is not governed by one loading/error/empty/data contract.
- Accessibility exists as point fixes, not as a release gate.
- Feature boundaries exist by directory, but app-level composition still knows too much about feature internals.

## 3. Stage 3.0 Design Review

These decisions are accepted for this plan unless a human reviewer changes them:

1. Preserve the existing warm-paper visual direction and improve consistency rather than introduce a new brand language.
2. Use the existing `AppTheme`, `BabyTalkColors`, and `AppLayoutConstants` as the token source of truth.
3. Improve one visible user flow per Stage 3.1 slice.
4. Start with Growth/Garden Growth because it is visible, lower risk than account/auth, and contains repeated card patterns, hardcoded text, and raw spacing.
5. Defer `app.dart` decomposition until at least one UI slice proves the contracts.
6. Do not require new packages for this iteration.

Human approval required before Stage 3.1:

- Approve Growth/Garden Growth as the first implementation slice.
- Approve that existing design tokens are the source of truth for the next iteration.
- Approve deferring `app.dart` decomposition until after the first visible UI slice.

## 4. Contracts

### 4.1 Design Token Contract

Migrated screens and widgets must use:

- `context.appColors` for product colors.
- `Theme.of(context).textTheme` plus existing `AppTheme` typography helpers for text.
- `AppLayoutConstants` for spacing, radius, padding, max content width, button height, and minimum touch targets.

Migrated code must not introduce new raw `Color(0x...)`, `EdgeInsets.*`, `SizedBox` spacing, fixed radii, or fixed component dimensions unless the value is a local visual calculation and is named in a private constant.

### 4.2 Localization Contract

All user-visible text in migrated surfaces must come from `AppLocalizations` and ARB entries.

Allowed exceptions:

- Test keys.
- Developer/debug labels that are hidden from normal users.
- Server/domain content already delivered as localized display text.

Every new localization entry must have a clear key name and preserve interpolation placeholders for dynamic content.

### 4.3 Accessibility Contract

Migrated surfaces must satisfy:

- Interactive targets are at least 48dp in both dimensions.
- Custom cards, chips, icon buttons, and non-standard controls expose meaningful `Semantics` labels.
- Semantic labels must also be localized unless they are developer-only diagnostics.
- Text remains readable under system text scaling.
- Loading, error, and empty states have screen-reader-usable text.

### 4.4 Async State Contract

Migrated user-facing data surfaces must render four states consistently:

- Loading: progress indicator or existing app shimmer/skeleton pattern.
- Error: localized error title/body and retry action when retry is possible.
- Empty: friendly localized explanation and next action.
- Data: stable layout that does not jump when optional sections appear.

Riverpod `AsyncValue` should be preferred for new or migrated async UI. Existing `ChangeNotifier` flows may remain during migration, but each migrated screen must adapt its state into the same four-state presentation contract.

### 4.5 Feature Boundary Contract

New or migrated feature work must not increase direct feature knowledge in `mobile/lib/app/app.dart`.

Preferred direction:

- Feature-owned presentation widgets stay under `features/<name>/presentation`.
- Shared visual primitives stay under `mobile/lib/app/widgets` only when they are truly cross-feature.
- Repositories stay behind provider/contract boundaries.
- Cross-feature access goes through explicit contracts, not direct imports between arbitrary feature internals.

## 5. Task DAG

```text
A. Approve Stage 3.0 plan
   -> B. Lock UI/i18n/a11y/async contracts for migrated code
      -> C. Slice 1: Growth/Garden Growth visible UI migration
         -> D. Extract only proven shared primitives from Growth slice
            -> E. Slice 2: Onboarding preview and save-state UX
            -> F. Slice 3: Practice phrase/card interaction UX
               -> G. Slice 4: Account/Household high-risk surfaces
                  -> H. Slice 5: app.dart composition decomposition
```

Do not start a downstream slice until its dependencies are verified.

## 6. File-Level Slice Plan

### Slice 1: Growth/Garden Growth UI Contract Migration

Purpose: make one visible user flow conform to tokens, l10n, component hierarchy, accessibility, and state contracts.

Primary files:

- `mobile/lib/features/shell/presentation/screens/growth_screen.dart`
- `mobile/lib/features/shell/presentation/screens/garden_growth_combined_screen.dart`
- `mobile/lib/features/shell/presentation/widgets/*` as needed for existing shell widgets
- `mobile/lib/l10n/app_zh.arb`
- generated l10n files after Flutter generation

Allowed support files:

- `mobile/lib/app/widgets/app_surface_card.dart`
- `mobile/lib/app/widgets/app_empty_state.dart`
- `mobile/lib/app/widgets/app_shimmer.dart`
- `mobile/lib/app/theme/app_layout_constants.dart` only if an existing token is missing and the addition is approved as a token, not as a one-off value

Acceptance criteria:

- Growth/Garden Growth has no normal user-visible hardcoded strings.
- Repeated Growth card structure is consolidated only where duplication is proven in this slice.
- Raw spacing/radius values in touched Growth UI are replaced with existing tokens or named constants.
- Interactive controls meet 48dp target requirements.
- Main cards and actions have localized semantic labels where needed.
- Loading, error, empty, and data states are explicitly represented or documented as not applicable for that widget.
- No behavior change to data calculation, repository logic, navigation, or account/session flows.

### Slice 2: Onboarding Preview and Save-State UX

Primary files:

- `mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart`
- `mobile/lib/features/onboarding/presentation/widgets/*`
- `mobile/lib/l10n/app_zh.arb`

Acceptance focus:

- Remove remaining hardcoded onboarding copy.
- Standardize preview card spacing, semantics, and save-failure messaging.
- Preserve existing onboarding state behavior.

### Slice 3: Practice Phrase/Card Interaction UX

Primary files:

- `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`
- `mobile/lib/features/practice/presentation/widgets/reaction_chip_row.dart`
- `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`
- `mobile/lib/l10n/app_zh.arb`

Acceptance focus:

- Localize semantic labels such as phrase-card labels.
- Standardize interaction target size and feedback.
- Keep playback/save behavior unchanged.

### Slice 4: Account/Household High-Risk Surfaces

Primary files:

- `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- `mobile/lib/features/household/presentation/widgets/*`
- `mobile/lib/l10n/app_zh.arb`

Acceptance focus:

- Localize account deletion dialog and household copy.
- Preserve destructive-action flow exactly.
- Add semantics without weakening confirmation safeguards.

### Slice 5: App Composition Decomposition

Primary files:

- `mobile/lib/app/app.dart`
- `mobile/lib/app/providers/repository_providers.dart`
- `mobile/lib/app/router/*`
- feature provider/contract files as needed

Acceptance focus:

- Reduce `app.dart` responsibilities without changing routes or launch behavior.
- Move composition into focused app-level modules.
- Do not combine this with visual UI changes.

## 6.1 AI Directory Governance Migration Track

Purpose: migrate project governance documents toward ASF 2.7.2 directory boundaries while preserving audit evidence.

Primary files:

- `ai/GOVERNANCE_VERSION`
- `ai/core/*`
- `ai/tech-stacks/flutter/*`
- `ai/integrations/README.md`
- `ai/operations/README.md`
- `ai/runtime/.gitignore`
- `ai/context/ai-directory-migration-plan.md`

Non-destructive Stage 3.0 actions:

- Add the target ASF layout scaffold.
- Record the current legacy layout audit.
- Define migration waves and explicit approval questions.

Approved and executed:

- Moving `ai/context/completed-decisions/` to `ai/context/resolved-decisions/`.
- Moving `ai/refactor/**` to `ai/context/refactor/**`.

Still blocked until human approval:

- Deleting empty legacy buckets such as `design-system/`, `enforcement/`, `engineering/`, `product/`, `reports/`, `reviews/`, and `tasks/`.
- Moving architecture documents from `ai/architecture/` to `ai/context/architecture/`.

Acceptance criteria:

- The new target scaffold exists and is versioned.
- No existing governance evidence is deleted or moved without approval.
- The migration plan lists current layout, target layout, migration waves, approval questions, and verification steps.
- Documentation migration commits remain separate from Flutter product code commits.

## 7. Verification Strategy

Every Stage 3.1 slice must run the smallest relevant verification first, then widen if needed.

Required for every slice:

- `flutter analyze` from `mobile/`.
- Targeted `flutter test` for changed widgets/notifiers when tests exist or are added.
- LSP diagnostics on changed Dart files.
- Manual QA on the touched flow in emulator/device or a test harness, with observed behavior recorded.

Additional for localization changes:

- Run Flutter generation if ARB changes require generated l10n updates.
- Verify the touched screen compiles against generated localization getters.

Additional for accessibility changes:

- Inspect Semantics behavior through widget tests where practical.
- Manually verify the primary screen-reader label intent for custom controls.

## 8. Definition of Done for Stage 3.0

Stage 3.0 is complete when:

- This plan is reviewed and approved by the human owner.
- Pending decisions in Section 3 are resolved.
- The first Stage 3.1 slice is confirmed as Growth/Garden Growth.
- No implementation begins before approval.

## 9. First Stage 3.1 Dispatch Template

Use this only after human approval.

Task: migrate Growth/Garden Growth visible UI to the mobile UI contracts.

Must do:

- Touch only the Slice 1 files unless a compile error proves another file is necessary.
- Replace user-visible hardcoded strings with `AppLocalizations` entries.
- Replace raw spacing/radius in touched UI with existing tokens or named local constants.
- Add or localize Semantics for custom interactive/non-standard controls.
- Preserve data behavior, repository behavior, navigation, and route keys.
- Run `flutter analyze`, targeted tests, LSP diagnostics, and manual QA.

Must not do:

- Do not edit account deletion, onboarding, practice playback, repository logic, backend APIs, or `app.dart` composition in Slice 1.
- Do not add dependencies.
- Do not rename routes or public test keys unless a test is updated in the same slice.
