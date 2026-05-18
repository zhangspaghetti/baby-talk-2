# Stage R1 Design System Issues

Version: Flutter AI Software Factory v1.0.0  
Stage: R1 - Design System Audit  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed, pending R2 design decisions

Design system score: 6 / 10.

## Summary

The app is not starting from zero: `BabyTalkColors`, `AppTheme`, `AppLayoutConstants`, localization generation, and shared widgets exist. The corrosion is in incomplete enforcement. Colors are comparatively centralized, but spacing, radius, sizing, component vocabulary, i18n usage, and semantic labels are not consistently governed.

## Findings

### DESIGN-001: Token coverage is uneven

Evidence:

- `mobile/lib/app/theme/app_theme.dart` defines a meaningful color and theme base.
- `mobile/lib/app/theme/app_layout_constants.dart` covers only a small set of layout constants.
- Static scan found 627 UI literal number candidates.

Risk: AI-generated and human-written UI will continue to drift because the spacing/radius/size vocabulary is incomplete.

R2 action: define token vocabulary without changing current visual values. Start with spacing, radius, touch target, progress height, icon size, alpha, and duration tokens.

### DESIGN-002: Repeated card, banner, empty, and status components exist

Evidence:

- Growth/garden screens define private diary, milestone, and empty cards.
- Household, share, and practice widgets define their own banner/surface shells.

Risk: Similar UI states diverge in semantics, padding, radius, copy, and error handling.

R2 action: plan shared `AppSurfaceCard`, `AppStatusBanner`, `AppMetaPill`, and `AppSectionEmptyState` components. R3 migration must preserve current copy, behavior, and keys.

### DESIGN-003: i18n migration is incomplete

Evidence:

- Generated localization files and ARB files exist.
- Some UI still hardcodes user-visible text even when ARB keys already exist.
- Static scan found 375 `Text(` candidates requiring classification.

Risk: Localization, screen-reader labels, and product voice drift.

R2 action: first migrate only hardcoded text that exactly matches existing ARB keys. New copy or copy rewrites require product approval.

### DESIGN-004: Product copy and internal/debug terms are mixed

Examples from audit include `Growth diary`, `C3 激活框`, `code`, `auth`, and `session` appearing in UI surfaces.

Risk: Parent-facing product experience can expose implementation language.

R2 action: classify these as debug-only versus user-facing product copy. Do not rewrite product language without confirmation.

### DESIGN-005: Accessibility semantics are partial and inconsistent

Evidence:

- Semantics exist in selected widgets.
- Labels mix English and Chinese.
- Dismiss/play/status labels are not uniformly localized.

Risk: Screen-reader experience is inconsistent and may not satisfy production accessibility standards.

R2 action: add semantics vocabulary to localization and plan widget tests for critical interactions.

## Behavior-Preserving Cleanup Boundary

Allowed without product behavior change:

- Move existing numbers into named tokens without changing values.
- Replace hardcoded text with existing ARB keys when rendered text remains identical.
- Add new ARB keys whose Chinese value is exactly the current string.
- Extract shared card/banner/pill components while preserving layout, keys, copy, and callbacks.

Not allowed without confirmation:

- Changing palette values.
- Changing radius hierarchy or spacing density.
- Rewriting product copy.
- Changing loading/empty/error behavior.
- Changing navigation or interaction hierarchy.

## Yellow Decisions For R2

1. Whether common card radius should standardize on 16 or preserve widespread 24 usage.
2. Whether spacing should collapse to an 8px scale plus exceptions, or preserve optical values like 6/10/14/18/20.
3. Whether internal terms are debug-only or product-facing.
4. Whether screen-reader labels should all be Chinese, with English phrase content only where semantically required.
5. Whether Growth/Garden repeated cards become shared design-system components in Phase 3 or stay feature-private with shared tokens.