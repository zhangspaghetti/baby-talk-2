---
phase: "18"
plan: "01"
---

# T01: Expanded /api/admin/users into a paged list/detail/disable contract with shared-table delete semantics and DB-backed MockMvc proof.

**Expanded /api/admin/users into a paged list/detail/disable contract with shared-table delete semantics and DB-backed MockMvc proof.**

## What Happened

I replaced the placeholder users backend with a real admin workbench contract in three layers. `AdminUserReadRepository` now supports paged/filterable list reads, account detail reads with bounded recent session and consent-audit history, and the shared-table write primitives needed for account disable. `AdminUsersService` now normalizes list filters, validates contract values, wraps storage failures in stable admin error codes, and applies disable by mirroring the established consumer delete lifecycle: delete `interaction_events`, mark `account_sessions` as `deleted` with `revoked_at`, tombstone `accounts.phone_number`, set `latest_consent_status=deleted`, and append a `consent_audit_logs` delete row. `AdminUsersController` now exposes `GET /api/admin/users`, `GET /api/admin/users/{accountId}`, and reason-required `PATCH /api/admin/users/{accountId}/disable`, with write access locked behind `users:write`.

I added `AdminUsersWebTest` to prove the contract and the underlying shared-table effects together. The new test covers filtered pagination, detail payload shape, bounded session/audit evidence, required disable reason, read-only admin write denial, duplicate disable semantics, empty-history accounts, and DB side effects including account tombstoning, session revocation timestamps, interaction-event deletion, consent-audit insertion, and leaving `account_refresh_tokens` active so downstream app guards can still resolve the stale mobile token as `account_deleted`. I also updated `AdminRbacWebTest` to assert the new paged list response shape so the existing RBAC proof remains valid.

During verification, the first `AdminUsersWebTest` run exposed a bad SQL `ESCAPE` clause in the list filter query. I treated that as a single-hypothesis storage-layer bug, simplified the query to a prepared-statement prefix `LIKE`, and reran the planned commands until both passed.

## Verification

Ran the task-plan verification commands with the Windows wrapper required by the slice plan.

1. `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminUsersWebTest` — passed after fixing the list-filter SQL, and the test now proves:
   - paged/filterable `/api/admin/users` responses
   - `/api/admin/users/{accountId}` detail payloads with recent session + consent evidence
   - reason-required disable validation and `users:write` authorization
   - stable `applied` / `duplicate` disable semantics with timestamps
   - shared-table side effects in `accounts`, `account_sessions`, `interaction_events`, `consent_audit_logs`, and `account_refresh_tokens`
2. `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminUsersWebTest,AdminRbacWebTest` — passed, confirming the new users contract and the existing live-RBAC regression suite still work together.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminUsersWebTest` | 0 | ✅ pass | 29700ms |
| 2 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminUsersWebTest,AdminRbacWebTest` | 0 | ✅ pass | 30400ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUserReadRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUsersService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUsersController.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminUsersWebTest.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminRbacWebTest.java`
