# E2E Test Report — 2026-04-29

**Version:** 1.2.0.1  
**Branch:** `feat/pgvector-infra`  
**Overall status: ✅ ALL PASSING**

| Suite | Tool | Tests | Status |
|---|---|---|---|
| Admin Web | Playwright | 38 | ✅ 38/38 |
| Flutter unit | flutter test | 223 | ✅ 223/223 |
| Flutter e2e_smoke | flutter integration_test | 2 | ✅ 2/2 |
| Flutter s01 | flutter integration_test | 1 | ✅ 1/1 |
| Flutter s02 | flutter integration_test | 1 | ✅ 1/1 |
| Flutter s03 | flutter integration_test | 1 | ✅ 1/1 |
| Flutter s06 | flutter integration_test | 3 | ✅ 3/3 |

---

## Admin Web — Playwright (38 tests)

Tests run against a live local stack via `playwright.config.ts`.  
Global setup/teardown in `playwright.global-setup.ts` / `playwright.global-teardown.ts`.

### `access-and-landing.spec.ts` — admin access and default landing
- single-domain admins land on their only module and keep overview hidden
- multi-domain admins reuse the same route metadata for overview nav and landing
- hidden admin route preserves typed write permissions without changing the primary landing
- knowledge-only admins land on /knowledge-ops while keeping write/review capability codes typed
- empty or unknown permissions fail closed instead of exposing every module
- login/forbidden helpers only keep path-prefixed context
- route catalog rejects duplicate landing weights so default landing stays deterministic
- unknown route lookups fail safely

### `admin-accounts.spec.ts` — admin accounts hidden route
- super admins can open the hidden page from Users and reuse existing create/disable contracts
- admins with users:read + admins:read can enter the hidden page but cannot write
- users-only admins do not see the entry and direct hidden-route visits land on explicit /403

### `admin-login.spec.ts` — legacy /protected login smoke
- keeps the compatibility alias redirecting unauthenticated visitors to /login

### `auth-and-rbac.spec.ts` — auth and rbac browser proof
- redirects unauthenticated visits to /login with visible return context
- shows a visible error for bad credentials
- lands super admins on overview and keeps all primary navigation visible
- lands limited admins on their single module, hides unrelated nav, and makes forbidden deep links explicit
- replays the original bootstrap request after exactly one refresh when the access token is stale
- clears the stored session and returns to /login when the refresh token has been revoked
- clears malformed stored session JSON before redirecting back to /login

### `distribution-stats.spec.ts` — distribution stats workspace
- shows truthful seeded stats, keeps filter query in URL, and redacts share tokens
- lands distribution-only admins in stats workspace and hides mentor-only navigation
- normalizes invalid URL filters to safe defaults while keeping query context recoverable

### `knowledge-ops.spec.ts` — knowledge ops workspace
- handles real ingestion upload/failure/retry and KG mark-read/resolve while keeping context inline
- keeps sub-surface visibility scoped to the admin capability actually granted and forbids deep-link mutations

### `mentor-audit.spec.ts` — mentor audit workspace
- uses real mentor incidents, keeps queue context in URL, and shows incident-first detail states
- shows stable 403 UI when current backend permissions omit mentor:audit
- clears stale local session and returns to login when /api/admin/me is 401
- shows explicit empty, missing-detail, and malformed-filter states

### `mentor-distribution-closure.spec.ts` — mentor + distribution closure proof
- keeps mentor incident evidence and distribution redaction truthful across shared shell navigation

### `overview-control-plane.spec.ts` — overview control plane proof
- renders the truthful overview control plane for super admins
- lets single-domain overview readers deep-link into /overview while keeping hidden domains fail-closed
- renders one stale domain among fresh domains from the overview summary contract
- falls back to polling after realtime loss, keeps the last good snapshot visible, and marks recovery
- keeps the last good snapshot visible and surfaces contract failure on malformed summary refresh

### `users-management.spec.ts` — users management workspace
- shows URL-backed list/detail state, requires a reason, and invalidates stale mobile tokens after disable
- keeps malformed URL context visible and surfaces detail/list failures inline
- super admins can manage hidden admin accounts and surface backend validation inline
- users-only admins keep /users/admins hidden, fail closed on deep links, and cannot disable users

---

## Flutter Mobile — Integration Tests

All integration tests run against emulator `emulator-5554` via `flutter test integration_test/<file> -d emulator-5554`.

### s01 — `s01_guest_practice_flow_test.dart`

**Scenario:** Guest (unauthenticated) offline practice with cold-boot recovery

**Test:** `guest 离线练习在冷启动后仍能恢复最近一次本地结果`

Flow:
1. Cold-boot with empty local DB → `home-restore-banner` shown, `recent-result-empty` widget visible
2. Start practice session → complete 3 phrases
3. Warm restart (same DB, new repository instance) → `recent-result-summary` found; last phrase and reaction type restored
4. Assert: `3 条本地记录` label correct; `All clean. · 宝宝放松` last result shown

Backend: none (fully offline)

---

### s02 — `s02_personalized_onboarding_flow_test.dart`

**Scenario:** Fresh install completes onboarding then persists personalized shell across cold boot

**Test:** `fresh install 完成 onboarding 后进入个性化 shell，冷启动后跳过 onboarding 并恢复最近结果`

Flow:
1. Fresh install → `onboarding-local-only-banner` shown; `boot-route-onboarding` active
2. Complete onboarding (name + age bucket + stage match)
3. Shell loaded → `shell-ready` key present; title shows `<childName> 的首页`
4. Complete starter practice session (3 events)
5. Cold-boot (new app widget, same DB) → `boot-route-shell` active; onboarding skipped
6. Assert: `recent-result-summary` found with correct last phrase and record count

Backend: none (fully offline)

---

### s03 — `s03_account_sync_restore_flow_test.dart`

**Scenario:** Offline practice → sign-in sync → logout → re-login restore

**Test:** `离线练习后登录同步，退出再登录仍能恢复 recent result`

Flow:
1. Pre-seed local DB with 3 practice events (`install_s03_integration_test`)
2. Boot app → `home-local-only-banner` present; `3 条本地记录` shown
3. Open account entry → enter phone `13800138000` / code `246810` → submit
4. Wait for `account-status-signed-in-synced` → 3 events synced to backend
5. Close account screen (scroll to `account-close-button` + `ensureVisible`)
6. Wait for `home-loading` to disappear (continuity refresh)
7. Scroll home list to `home-local-only-banner` → wait for `recent-result-summary`
8. Assert: `已同步 3` chip visible; `recent-result-summary` found
9. Open account entry → tap logout → confirm logout
10. Cold-boot (new app widget, same DB) → re-login with same credentials
11. Bootstrap from backend → `recent-result-summary` restored; `已同步 3` chip present

Backend: `InMemoryDemoBackend` (in-process HTTP, port auto-assigned)  
Credentials: phone `13800138000`, code `246810`  
Installation ID: `install_s03_integration_test`

---

### s06 — `s06_full_chain_release_flow_test.dart`

Full-chain release proof: onboarding → practice → sync → mentor → edge cases.  
Uses `FullChainTestHarness` + `InMemoryDemoBackend` with 250 ms simulated response delay.

#### Test 1: `fresh install 会从真实 app 入口串起 onboarding 到 mentor blocked fallback 全链路 proof`

Flow:
1. Fresh install → `onboarding-local-only-banner` shown; `boot-route-shell` absent
2. Complete onboarding → `shell-ready`; title shows `<childName> 的首页`
3. Complete starter practice (3 events) → `recent-result-summary`, `3 条本地记录`, `All clean. · 宝宝放松` asserted
4. Scroll to `home-garden-mini-entry` and `home-growth-summary` → verify garden projection ready
5. Switch to 花园 tab → verify `garden-hero-card` and `garden-patch-daily_care` with `3 次练习事件`
6. Switch to 成长 tab → verify `growth-space-daily_care`
7. Sign in and sync → `account-status-signed-in-synced`; `bootstrapCount ≥ 1`; `storedEventCount = 3`
8. Close account screen (scroll + `ensureVisible` + `warnIfMissed: false`)
9. Switch to home tab → scroll to `home-local-only-banner` → wait for `recent-result-summary`
10. Assert: `已同步 3` chip visible (present in both `home-account-card` and `shell-account-card`)
11. Submit mentor prompt `[blocked]` → verify `mentor-chat-banner`, `安全降级`, `blocked_fallback` code/phase
12. Assert: sync queue `pendingCount=0`, `syncedCount=3`, `failedCount=0`, `lastSyncPhase=batch_ack_applied`
13. Assert: mentor fact history contains `panelOpened`, `chatRequested`, `chatResponseDelivered` with `phase=blocked_fallback`

#### Test 2: `malformed completed snapshot 会停在 boot failure surface，而不是直接跳过 onboarding`

Flow:
1. Inject `completedSnapshotLoader` that throws `FormatException('malformed onboarding snapshot')`
2. Boot → `boot-route-gate-failed` shown; `boot-route-shell` and `onboarding-local-only-banner` absent
3. Assert: `本地档案读取失败` error text visible

#### Test 3: `Mentor timeout 会显示可见 banner 与 phase，而不是让聊天流程 hang 住`

Flow:
1. Fresh install + complete onboarding
2. Submit mentor prompt `[timeout]`
3. Assert: `mentor-chat-banner` present; `mentor-chat-response-card` absent
4. Assert: `超时` banner text; `code · timeout`; `phase · provider_timeout`
5. Dispose app → read `MentorFactType.chatFailed` from local store
6. Assert: `phase=provider_timeout`, `visibleStatus=timeout`, `retryable=true`

Backend: `InMemoryDemoBackend` (in-process HTTP)  
Credentials: phone `13800138000`, code `246810`  
Installation ID: `install_s06_full_chain_test`

---

## Test Infrastructure Notes

### `InMemoryDemoBackend`
- In-process HTTP server (Dart `shelf`), started before each test, disposed in `tearDown`
- Handles: `/api/v1/auth/challenge`, `/api/v1/auth/consent`, `/api/v1/auth/refresh`, `/api/v1/sync/push`, `/api/v1/mentor/query`
- Phone `13800138000` → challenge code `246810`; JWT uses `sessionId` as both access/refresh token
- Returns 3 stored practice events for `install_s03_integration_test` and `install_s06_full_chain_test`
- `simulatedSlowResponse: 250ms` in s06 harness to surface real timing behaviour
- `bootstrapCount` counter used to assert backend was actually called

### `FullChainTestHarness` (s06 only)
- Static helpers: `scrollHomeToTop`, `scrollHomeTo`, `pumpUntilFound`, `pumpUntil`
- `switchToHomeTab()`: waits for `account-entry-surface` to close → removes snackbar → taps tab 0 → waits for `<childName> 的首页`
- `signInAndSync()`: enters phone/code, dismisses keyboard, `ensureVisible` submit, `warnIfMissed:false` tap, waits for `account-status-signed-in-synced` (30 s)
- `practiceContinuityRefreshTimeout: Duration.zero` — disables 4 s timeout for deterministic test behaviour
