---
phase: "18"
plan: "03"
---

# T03: Added the hidden `/users/admins` admin-accounts workbench and wired Users-page entry/guards around the existing admin CRUD contracts.

**Added the hidden `/users/admins` admin-accounts workbench and wired Users-page entry/guards around the existing admin CRUD contracts.**

## What Happened

I extended the admin route catalog and access typing to recognize `users:write`, `admins:read`, and `admins:write`, then added a hidden `/users/admins` route that stays behind the existing access guard without changing primary navigation or default landing behavior. On the frontend, I added `adminAccountsClient.ts` plus `AdminAccountsPage.tsx` to consume the existing `/api/admin/admins` and `/api/admin/roles` contracts directly, showing current permission context, role/admin fetch state, and inline create/disable success or failure states instead of toast-only behavior. I also updated `UsersPage.tsx` so admins who have `admins:read` get an explicit in-product entry to the hidden page, while write actions stay gated by `admins:write`. To keep the change durable, I added route/access regression coverage plus browser tests for the super-admin happy path, read-only admin behavior, and explicit `/403` denial for users-only admins.

## Verification

`npm --prefix admin-web run build` passed after the final code changes (exit 0). `npm --prefix admin-web run test:e2e -- tests/access-and-landing.spec.ts tests/admin-accounts.spec.ts` also passed after the final code changes (10/10 passing), covering hidden-route landing behavior, the Users-workspace entry, super-admin create/disable reuse of the existing backend contracts, read-only `admins:read` access, and explicit `/403` denial for direct hidden-route visits without `admins:read`.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run build` | 0 | ✅ pass | 27955ms |
| 2 | `npm --prefix admin-web run test:e2e -- tests/access-and-landing.spec.ts tests/admin-accounts.spec.ts` | 0 | ✅ pass | 95000ms |

## Deviations

None.

## Known Issues

`npm --prefix admin-web run build` still emits the pre-existing Vite chunk-size warning for the large admin bundle; the build succeeds and this task did not change the chunking strategy.

## Files Created/Modified

- `admin-web/src/app/routes.tsx`
- `admin-web/src/app/access.ts`
- `admin-web/src/pages/UsersPage.tsx`
- `admin-web/src/lib/adminAccountsClient.ts`
- `admin-web/src/pages/AdminAccountsPage.tsx`
- `admin-web/tests/admin-accounts.spec.ts`
- `admin-web/tests/access-and-landing.spec.ts`
- `admin-web/tests/helpers/admin-api.ts`
