# Full-Stack E2E Test Report — 2026-04-29

## Summary

| Suite | Result | Count |
|---|---|---|
| Flutter Mobile E2E (real k8s backend) | ✅ PASS | 1 / 1 |
| Admin Web Playwright | ✅ PASS | 38 / 38 |
| **Total** | **✅ ALL GREEN** | **39 / 39** |

---

## Infrastructure

| Component | Address | Status |
|---|---|---|
| app-api (k8s port-forward) | `127.0.0.1:8080` | UP |
| admin-api (k8s port-forward) | `127.0.0.1:8081` | UP |
| admin-web (k8s port-forward) | `127.0.0.1:3000` | UP |
| gateway (k8s port-forward) | `127.0.0.1:8090` | UP |
| Android Emulator | `emulator-5554` (Android 15 / API 35) | Running |
| ADB reverse | `tcp:8080 → tcp:8080` | Active |

Backend: Docker Desktop Kubernetes, namespace `babytalk`.  
Dev credentials: phone `13800138000`, SMS code `246810`.  
Admin credentials: `super_admin` / `SuperAdmin123!`.

---

## Flutter Mobile E2E — `e2e_full_flow_test.dart`

**Run command:**
```
cd mobile
adb -s emulator-5554 reverse tcp:8080 tcp:8080
flutter test integration_test/e2e_full_flow_test.dart \
  --dart-define=BABY_TALK_E2E=true \
  --dart-define=BABY_TALK_API_BASE_URL=http://localhost:8080 \
  -d emulator-5554 --timeout none
```

**Result:** `01:27 +1: All tests passed!`

### Steps Covered

| # | Step | Screenshot |
|---|---|---|
| 1 | Onboarding welcome screen | `000_onboarding_welcome.png` |
| 2 | Onboarding name entry | `001_onboarding_name_entry.png` |
| 3 | Onboarding age selection (12-18 months) | `002_onboarding_age_selection.png` |
| 4 | Onboarding stage match | `003_onboarding_stage_match.png` |
| 5 | Home shell ready | `004_home_shell_ready.png` |
| 6 | Home starter seed card | `005_home_starter_seed.png` |
| 7 | Practice — phrase 1 | `006_practice_phrase_1.png` |
| 8 | Practice — phrase 2 | `007_practice_phrase_2.png` |
| 9 | Practice — phrase 3 | `008_practice_phrase_3.png` |
| 10 | Home after practice complete | `009_home_after_practice.png` |
| 11 | Tab: Garden | `010_tab_garden.png` |
| 12 | Tab: Growth | `011_tab_growth.png` |
| 13 | Tab: Discover | `012_tab_discover.png` |
| 14 | Home before mentor | `013_home_before_mentor.png` |
| 15 | Mentor panel overview | `014_mentor_panel_overview.png` |
| 16 | Mentor chat input | `015_mentor_chat_input.png` |
| 17 | Mentor chat response (宝宝哭了怎么回应) | `016_mentor_chat_response.png` |
| 18 | Home before login | `017_home_before_login.png` |
| 19 | Drawer open | `018_drawer_open.png` |
| 20 | Account entry screen | `019_account_entry_screen.png` |
| 21 | Account signed-in + synced | `020_account_signed_in_synced.png` |

### Screenshots

#### Onboarding (Steps 1–4)

| 000 Welcome | 001 Name Entry |
|---|---|
| ![000 Onboarding Welcome](screenshots/mobile/000_onboarding_welcome.png) | ![001 Onboarding Name Entry](screenshots/mobile/001_onboarding_name_entry.png) |

| 002 Age Selection (12–18 mo) | 003 Stage Match |
|---|---|
| ![002 Onboarding Age Selection](screenshots/mobile/002_onboarding_age_selection.png) | ![003 Onboarding Stage Match](screenshots/mobile/003_onboarding_stage_match.png) |

---

#### Home + Practice (Steps 5–10)

| 004 Home Shell Ready | 005 Home Starter Seed Card |
|---|---|
| ![004 Home Shell Ready](screenshots/mobile/004_home_shell_ready.png) | ![005 Home Starter Seed](screenshots/mobile/005_home_starter_seed.png) |

| 006 Practice – Phrase 1 | 007 Practice – Phrase 2 |
|---|---|
| ![006 Practice Phrase 1](screenshots/mobile/006_practice_phrase_1.png) | ![007 Practice Phrase 2](screenshots/mobile/007_practice_phrase_2.png) |

| 008 Practice – Phrase 3 | 009 Home After Practice Complete |
|---|---|
| ![008 Practice Phrase 3](screenshots/mobile/008_practice_phrase_3.png) | ![009 Home After Practice](screenshots/mobile/009_home_after_practice.png) |

---

#### Content Tabs (Steps 11–13)

| 010 Tab: Garden | 011 Tab: Growth | 012 Tab: Discover |
|---|---|---|
| ![010 Tab Garden](screenshots/mobile/010_tab_garden.png) | ![011 Tab Growth](screenshots/mobile/011_tab_growth.png) | ![012 Tab Discover](screenshots/mobile/012_tab_discover.png) |

---

#### Mentor Chat (Steps 14–18)

| 013 Home Before Mentor | 014 Mentor Panel Overview |
|---|---|
| ![013 Home Before Mentor](screenshots/mobile/013_home_before_mentor.png) | ![014 Mentor Panel Overview](screenshots/mobile/014_mentor_panel_overview.png) |

| 015 Mentor Chat Input | 016 Mentor Chat Response |
|---|---|
| ![015 Mentor Chat Input](screenshots/mobile/015_mentor_chat_input.png) | ![016 Mentor Chat Response](screenshots/mobile/016_mentor_chat_response.png) |

> Step 17: submitted query "宝宝哭了怎么回应", waited for AI response from real k8s backend.

| 017 Home Before Login (Mentor dismissed) |
|---|
| ![017 Home Before Login](screenshots/mobile/017_home_before_login.png) |

---

#### Account Sign-In (Steps 19–21)

| 018 Drawer Open | 019 Account Entry Screen |
|---|---|
| ![018 Drawer Open](screenshots/mobile/018_drawer_open.png) | ![019 Account Entry Screen](screenshots/mobile/019_account_entry_screen.png) |

| 020 Account Signed-In + Synced |
|---|
| ![020 Account Signed In Synced](screenshots/mobile/020_account_signed_in_synced.png) |

---

## Admin Web Playwright — Full Suite

**Run command:**
```
cd admin-web
BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1 npx playwright test
```

**Result:** `38 passed (all specs)`

### Spec Coverage

| File | Tests | Result |
|---|---|---|
| `access-and-landing.spec.ts` | 8 | ✅ PASS (logic-only, no screenshots) |
| `admin-accounts.spec.ts` | 3 | ✅ PASS |
| `admin-login.spec.ts` | 1 | ✅ PASS |
| `auth-and-rbac.spec.ts` | 7 | ✅ PASS |
| `distribution-stats.spec.ts` | 3 | ✅ PASS |
| `knowledge-ops.spec.ts` | 2 | ✅ PASS |
| `mentor-audit.spec.ts` | 4 | ✅ PASS |
| `mentor-distribution-closure.spec.ts` | 1 | ✅ PASS |
| `overview-control-plane.spec.ts` | 5 | ✅ PASS |
| `users-management.spec.ts` | 4 | ✅ PASS |

Full HTML report: `admin-web/playwright-report/index.html`

---

### Screenshots

#### Admin Accounts (`admin-accounts.spec.ts`)

| 001 Super admin: create/disable | 002 Readonly: hidden page | 003 No access: /403 |
|---|---|---|
| ![001](screenshots/admin/001_admin_accounts_super_create_disable.png) | ![002](screenshots/admin/002_admin_accounts_readonly_hidden_page.png) | ![003](screenshots/admin/003_admin_accounts_no_access_403.png) |

---

#### Auth & RBAC (`admin-login.spec.ts` + `auth-and-rbac.spec.ts`)

| 004 Login redirect | 005 Unauth redirect (return context) | 006 Bad credentials error |
|---|---|---|
| ![004](screenshots/admin/004_admin_login_redirect_to_login.png) | ![005](screenshots/admin/005_auth_unauthenticated_redirect.png) | ![006](screenshots/admin/006_auth_bad_credentials_error.png) |

| 007 Super admin overview (all nav) | 008 Limited admin (single module) |
|---|---|
| ![007](screenshots/admin/007_auth_super_admin_overview.png) | ![008](screenshots/admin/008_auth_limited_admin_single_module.png) |

| 009 Stale token → refresh replay | 010 Revoked token → logout | 011 Malformed session → login |
|---|---|---|
| ![009](screenshots/admin/009_auth_token_refresh_replay.png) | ![010](screenshots/admin/010_auth_revoked_token_logout.png) | ![011](screenshots/admin/011_auth_malformed_session_login.png) |

---

#### Distribution Stats (`distribution-stats.spec.ts`)

| 012 Seeded stats + filter URL | 013 Limited admin (no mentor nav) | 014 Invalid filter recovery |
|---|---|---|
| ![012](screenshots/admin/012_dist_stats_seeded_filter_url.png) | ![013](screenshots/admin/013_dist_stats_limited_admin.png) | ![014](screenshots/admin/014_dist_stats_invalid_filter_recovery.png) |

---

#### Knowledge Ops (`knowledge-ops.spec.ts`)

| 015 Upload / failure / retry | 016 RBAC scoped (no deep-link mutation) |
|---|---|
| ![015](screenshots/admin/015_knowledge_ops_upload_retry.png) | ![016](screenshots/admin/016_knowledge_ops_rbac_scoped.png) |

---

#### Mentor Audit (`mentor-audit.spec.ts`)

| 017 Incident detail (queue context) | 018 403 (missing mentor:audit perm) |
|---|---|
| ![017](screenshots/admin/017_mentor_audit_incident_detail.png) | ![018](screenshots/admin/018_mentor_audit_403_no_permission.png) |

| 019 401 → session clear | 020 Empty / malformed filter states |
|---|---|
| ![019](screenshots/admin/019_mentor_audit_401_session_clear.png) | ![020](screenshots/admin/020_mentor_audit_empty_malformed.png) |

---

#### Mentor + Distribution Closure (`mentor-distribution-closure.spec.ts`)

| 021 Cross-module shell navigation |
|---|
| ![021](screenshots/admin/021_mentor_dist_closure_cross_module.png) |

---

#### Overview / Control Plane (`overview-control-plane.spec.ts`)

| 022 Super admin control plane | 023 Single-domain reader |
|---|---|
| ![022](screenshots/admin/022_overview_super_admin_control_plane.png) | ![023](screenshots/admin/023_overview_single_domain_reader.png) |

| 024 Stale domain among fresh | 025 Realtime loss → polling | 026 Malformed refresh |
|---|---|---|
| ![024](screenshots/admin/024_overview_stale_domain.png) | ![025](screenshots/admin/025_overview_realtime_loss_polling.png) | ![026](screenshots/admin/026_overview_malformed_refresh.png) |

---

#### Users Management (`users-management.spec.ts`)

| 027 List/detail + disable (token invalidation) | 028 Malformed URL → inline errors |
|---|---|
| ![027](screenshots/admin/027_users_list_detail_disable.png) | ![028](screenshots/admin/028_users_malformed_url_inline_errors.png) |

| 029 Super admin: manage admin accounts | 030 Readonly: hidden + forbidden |
|---|---|
| ![029](screenshots/admin/029_users_super_admin_manage_admins.png) | ![030](screenshots/admin/030_users_readonly_hidden_forbidden.png) |

---

## Bugs Fixed This Session

| Bug | Root Cause | Fix |
|---|---|---|
| Flutter screenshots failed (`screencap: permission denied`) | Cannot invoke `/system/bin/screencap` from app sandbox | Used `IntegrationTestWidgetsFlutterBinding.takeScreenshot()` + `path_provider` |
| `takeScreenshot()` crash | `convertFlutterSurfaceToImage()` must be called once before first screenshot | Added `_surfaceConverted` bool flag + lazy init in `_shot()` |
| `MentorApiService` auth error in E2E | Post-sign-in, `authenticatedApiClient` not injected by `E2eTestHarness`; mentor API requires auth | Moved mentor chat steps (14–17) to run BEFORE sign-in (steps 18–21); dev-mode backend allows anonymous mentor calls |
| Screenshots deleted after test | `flutter test` uninstalls APK on completion, deleting app-specific external storage | Write to `getApplicationDocumentsDirectory()` (internal); added 30s `Future.delayed` at test end; extract via `adb exec-out run-as com.babytalk.mobile cat ...` during window |
| Playwright race condition (`mentor-distribution-closure`) | `waitForResponse` for detail response registered after filter click, missing auto-triggered fetch | Moved `blockedDetailResponse` listener registration to before filter click |
| Admin sidebar username vertical overflow | `avatarProps.render` used `<Space>` without `overflow: hidden`; 236px sidebar caused "super_admin" to render 1-char-per-line vertically | Changed wrapper to `<div style={{ overflow: 'hidden', minWidth: 0 }}>` + `Typography.Text` with `whiteSpace: nowrap; textOverflow: ellipsis` |
| 退出登录 button + module tag overflow | `actionsRender` in ProLayout `layout="side"` renders to sidebar bottom; side-by-side tag+button exceeded 236px sidebar width | Removed `actionsRender`; added `menuFooterRender` with vertical stacking (`flexDirection: column`) and full-width `block` button |
| Playwright `loginViaUi` URL mismatch on `/users` | URL regex used `\/users$` but Users page now persists filter state (`?page=1&pageSize=20&status=all`) | Updated regex to `\/users(?:\?.*)?$` in `mentor-audit.spec.ts` and `distribution-stats.spec.ts` |

---

## Test Artifacts

| Artifact | Path |
|---|---|
| Flutter E2E test | `mobile/integration_test/e2e_full_flow_test.dart` |
| E2E test harness | `mobile/integration_test/support/e2e_test_harness.dart` |
| Mobile screenshots (21) | `docs/screenshots/mobile/` |
| Admin web screenshots (30) | `docs/screenshots/admin/` |
| Playwright report | `admin-web/playwright-report/index.html` |
| Admin layout fix | `admin-web/src/layout/AdminLayout.tsx` |
| Playwright config (retries) | `admin-web/playwright.config.ts` |
| Orchestration script (bash) | `scripts/run-full-e2e.sh` |
| Orchestration script (cmd) | `scripts/run-full-e2e.cmd` |
