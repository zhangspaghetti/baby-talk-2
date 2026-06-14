# M006 S11 — Distribution stats admin contract

## Purpose

`GET /api/admin/distribution/stats` is the truthful read-only admin seam for S11. It reuses the existing raw truth sources:

- `release_distribution_events`
- `share_landing_events`

It does **not** introduce rollups, backfills, or a second analytics vocabulary in this slice.

## RBAC / access

- Endpoint: `GET /api/admin/distribution/stats`
- Permission: `distribution:read`
- Missing permission: `403 forbidden`
- Disabled admin session: `401 admin_account_disabled`

## Query contract

Accepted query params:

- `range=7d|30d|90d`
- `channel=all|stable|beta`

Normalization rules:

- missing `range` → use configured default (`30d` today)
- missing `channel` → `all`
- blank / unknown `range` → `400 invalid_distribution_stats_range`
- blank / unknown `channel` → `400 invalid_distribution_stats_channel`
- recent detail rows always use a **fixed configured limit** (`200` today); the client cannot request an unbounded page

## Truth boundary

### 1. Release distribution

`channel` is truthful here because `release_distribution_events` has `release_channel`.

Affected sections:

- `releaseOverview`
- `releaseTrend`
- release side of `shareHandoff`
- `detailRows[]` where `surface = release_distribution`

### 2. Share raw funnel

`share_landing_events` has **no** `release_channel` column.

So these sections are intentionally **not channel-filtered**:

- `shareOverview`
- `shareTrend`
- `shareFunnel`
- `detailRows[]` where `surface = share_landing`

Do **not** fake a channel dimension for raw share rows.

### 3. Share → release handoff

`shareHandoff` is split truthfully:

- share side = `share_landing_events(entrypoint='download', result='download_fallback')`
- release side = `release_distribution_events(source='share_card')`

When `channel != all`, only the **release side** is filtered by channel.

## Response semantics

Top-level sections:

- `applied`
  - `range`
  - `channel`
  - `detailLimit`
  - `windowStartedAt`
- `channelScopeNote`
- `releaseOverview`
- `releaseTrend[]`
- `shareOverview`
- `shareTrend[]`
- `shareFunnel[]`
- `shareHandoff`
- `detailRows[]`

Section summaries expose stable observability fields:

- `totalEvents`
- `successfulEvents`
- `failureEvents`
- `lastSeenAt`

`shareHandoff` additionally exposes:

- `totalShareDownloadFallbackEvents`
- `totalReleaseShareCardEvents`
- `releaseMinusShare`
- `shareLastSeenAt`
- `releaseLastSeenAt`
- `trend[]`

## Detail row normalization

Each `detailRows[]` item is normalized to:

- `surface` (`release_distribution` | `share_landing`)
- `createdAt`
- `channel` (nullable; only release rows have a value)
- `source`
- `entrypoint`
- `platform`
- `result`
- `failureReason`

## Redaction boundary

Never expose in this admin surface:

- raw `share_landing_events.token`
- consumer identifiers
- session identifiers
- refresh/access tokens
- any extra PII beyond the coarse event dimensions above

## Query-pack mapping

This contract intentionally mirrors the existing proof SQL, but on the modularized paths:

- release trend / summary semantics:
  - `backend/app-api/src/main/resources/sql/s01_release_distribution_queries.sql`
- share trend / funnel / handoff semantics:
  - `backend/app-api/src/main/resources/sql/s02_share_landing_queries.sql`

The admin read model lives at:

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsReadRepository.java`

## Failure inspection checklist

1. Call `GET /api/admin/distribution/stats?range=30d&channel=stable`
2. Confirm `applied` reflects the requested filters
3. Read `channelScopeNote` before interpreting share numbers
4. Compare release-side counts against `release_distribution_events`
5. Compare share-side counts against `share_landing_events`
6. If a handoff gap appears, compare share `download_fallback` vs release `source=share_card`
7. If detail rows look suspicious, verify no `token` / identifiers leaked into the payload
