# BabyProfile Option Catalog Follow-up Plan

Date: 2026-07-10
Status: follow-up only
Scope: future plan; no B2.1 implementation

## Goal

Replace hard-coded `AGE_RANGES` and `PARENT_GOALS` with versioned domain catalogs. Preserve stable API codes while allowing labels, ordering, availability, and ranking behavior to evolve independently.

## Domain contract

Each option carries:

```text
stable_code
enabled
display_order
localized_label
catalog_version
ranking_strategy_key
```

`stable_code` is immutable once published. `enabled=false` hides an option from new selection without invalidating historical profile rows. `display_order` is deterministic within catalog/version. `localized_label` is stored per locale, not embedded in Java enums. `ranking_strategy_key` selects backend ranking behavior without exposing implementation details to clients.

## Persistence

Use dedicated typed tables, not `common_config` and not YAML sets:

```text
baby_profile_age_range_options
baby_profile_parent_goal_options
baby_profile_option_versions
baby_profile_option_labels
```

Age-range and parent-goal option tables own immutable `stable_code` primary keys. `baby_profile_option_versions` owns versioned `enabled`, `display_order`, and `ranking_strategy_key` rows keyed by option type, stable code, and catalog version. Labels reference one versioned row. `baby_profiles` FKs target stable identity tables, avoiding an ambiguous FK into multiple catalog versions.

Required constraints:

- Stable identity tables enforce globally unique stable codes per option type; version rows enforce one row per stable code/catalog version.
- `enabled` and `display_order` are non-null; display order is non-negative.
- Locale labels are unique per option/version/locale.
- `ranking_strategy_key` is non-blank and constrained to registered strategy keys.
- `baby_profiles.age_range` and `baby_profiles.parent_goal` migrate to explicit foreign-key-backed codes after existing data validation/backfill.
- Migration order: create catalogs, seed versioned options, validate/backfill profiles, add FKs, then remove obsolete application constants.

## Read-only API

Add authenticated and installation-safe read-only options API:

```text
GET /api/v1/baby-profile/options?locale=zh-CN
```

Response returns catalog version plus enabled age-range and parent-goal options ordered by `display_order`. Fields: stable code, localized label, display order. `rankingStrategyKey` remains server-side unless a later client contract explicitly needs it.

Unknown locale uses explicit configured fallback locale. Disabled options are omitted from discovery responses but remain resolvable for existing profiles.

## Service boundaries

- Mapper/repository owns catalog and localized-label reads.
- Domain service validates selected stable codes against current or historically valid rows.
- Ranking service resolves `ranking_strategy_key`; controller never switches on option code.
- Cache key includes option type, locale, and catalog version.

## Migration and tests

- Migration smoke verifies tables, named constraints, indexes, seeds, FKs, and rollback-safe ordering.
- Repository tests verify stable-code uniqueness, enabled filtering, deterministic order, locale fallback, and historical disabled resolution.
- Service tests verify profile write validation and ranking strategy lookup.
- Controller tests verify read-only response, version, localization, and no leakage of internal strategy keys.
- Regression tests prove existing saved age range/parent goal values remain readable after FK migration.

## Scope guard

No B2.1 code changes. No YAML `Set` replacement. No `common_config` table. No mobile/admin UI. No mutation API until a separate admin/catalog-governance plan is approved.
