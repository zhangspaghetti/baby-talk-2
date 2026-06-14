---
phase: "18"
plan: "04"
---

# T04: Added compose-backed users-management Playwright proof for disable/account_deleted and hidden admin-account flows.

**Added compose-backed users-management Playwright proof for disable/account_deleted and hidden admin-account flows.**

## What Happened

- Extracted `admin-web/tests/helpers/mobile-api.ts` so browser proofs mint real consumer tokens through `/api/v1/auth/challenges` → `/api/v1/auth/verify` → `/api/v1/consent/accept`, instead of using DB shortcuts or mocked API responses.
- Hardened `admin-web/tests/helpers/admin-api.ts` malformed-payload handling so seed/setup failures stop with explicit helper errors.
- Reworked `admin-web/tests/users-management.spec.ts` into the canonical S05 browser proof: URL-backed users list/detail state, reason-required disable UX, post-disable `app-api` bootstrap failure with stable `account_deleted` JSON, super_admin admin-account create/duplicate-username/unknown-role/disable coverage, and users-only hidden-route `/403` proof.
- The first e2e run exposed one non-obvious shared-table behavior: disabling a consumer tombstones the phone number to `deleted:<accountId>`, so an unchanged `query=<original phone>` correctly empties the list. I updated the assertion to prove the preserved query plus `selected-not-in-list` warning instead of expecting the deleted row to remain visible under the old phone filter.

## Verification

Fresh verification after the final code edit passed end-to-end. `npm --prefix admin-web run build` completed successfully. `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminUsersWebTest,AdminRbacWebTest` passed and preserved the backend users/RBAC contract proof. `npm --prefix admin-web run test:e2e -- users-management.spec.ts` passed with 4/4 scenarios on the real docker-compose stack. `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts users-management.spec.ts` passed with 11/11 scenarios, confirming the new users proof did not regress the existing shell/auth canonical flow.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 35800ms |
| 2 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminUsersWebTest,AdminRbacWebTest` | 0 | ✅ pass | 36200ms |
| 3 | `npm --prefix admin-web run test:e2e -- users-management.spec.ts` | 0 | ✅ pass | 110600ms |
| 4 | `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts users-management.spec.ts` | 0 | ✅ pass | 104600ms |

## Deviations

None.

## Known Issues

Existing Vite chunk-size warnings (>500 kB chunks in the admin-web build) remain and are outside this task's scope; they did not fail build or E2E verification.

## Files Created/Modified

- `admin-web/tests/users-management.spec.ts`
- `admin-web/tests/helpers/mobile-api.ts`
- `admin-web/tests/helpers/admin-api.ts`
