# BabyTalk 全栈 E2E 测试报告

**日期**: 周日 2026/05/24 15:55:13.19
**后端**: k8s (Docker Desktop) — namespace: babytalk
**前端测试**: Playwright (admin-web)
**移动端测试**: Flutter Integration Test (emulator: emulator-5554)

---

## 测试结果摘要

| 测试套件 | 状态 |
|---------|------|
| Admin Web (Playwright) | FAIL exit 1 |
| Mobile E2E (Flutter)   | PASS |

---

## 基础设施

```
App API:    http://127.0.0.1:8080  (kubectl port-forward -> babytalk app-api pod)
Admin API:  http://127.0.0.1:8081 (kubectl port-forward -> babytalk admin-api pod)
Admin Web:  http://127.0.0.1:3000 (Vite dev server 或 k8s pod)
Namespace:  babytalk
Dev SMS code: 246810
Commit SHA: b994318
Run batch ID: 20260524-154929
Artifacts: C:\code\AI\baby-talk-2\artifacts\e2e\2026-05-24\b994318\fullstack-20260524-154929
```

---

## 移动端测试截图 (Flutter)

以下截图由集成测试在 Android 模拟器 (emulator-5554) 上自动捕获。
截图按流程顺序排列：引导程序 -> 主屏幕 -> 练习 -> 标签页 -> 登录 -> Mentor。

### 000 onboarding welcome

<img src="screenshots/mobile/000_onboarding_welcome.png" alt="000 onboarding welcome" />

### 001 onboarding name entry

<img src="screenshots/mobile/001_onboarding_name_entry.png" alt="001 onboarding name entry" />

### 002 onboarding age selection

<img src="screenshots/mobile/002_onboarding_age_selection.png" alt="002 onboarding age selection" />

### 003 onboarding stage match

<img src="screenshots/mobile/003_onboarding_stage_match.png" alt="003 onboarding stage match" />

### 004 home shell ready

<img src="screenshots/mobile/004_home_shell_ready.png" alt="004 home shell ready" />

### 005 home starter seed

<img src="screenshots/mobile/005_home_starter_seed.png" alt="005 home starter seed" />

### 006 practice phrase 1

<img src="screenshots/mobile/006_practice_phrase_1.png" alt="006 practice phrase 1" />

### 007 practice phrase 2

<img src="screenshots/mobile/007_practice_phrase_2.png" alt="007 practice phrase 2" />

### 008 practice phrase 3

<img src="screenshots/mobile/008_practice_phrase_3.png" alt="008 practice phrase 3" />

### 009 home after practice

<img src="screenshots/mobile/009_home_after_practice.png" alt="009 home after practice" />

### 010 tab garden

<img src="screenshots/mobile/010_tab_garden.png" alt="010 tab garden" />

### 011 tab growth

<img src="screenshots/mobile/011_tab_growth.png" alt="011 tab growth" />

### 012 tab discover

<img src="screenshots/mobile/012_tab_discover.png" alt="012 tab discover" />

### 013 home before mentor

<img src="screenshots/mobile/013_home_before_mentor.png" alt="013 home before mentor" />

### 014 mentor panel overview

<img src="screenshots/mobile/014_mentor_panel_overview.png" alt="014 mentor panel overview" />

### 015 mentor chat input

<img src="screenshots/mobile/015_mentor_chat_input.png" alt="015 mentor chat input" />

### 016 mentor chat response

<img src="screenshots/mobile/016_mentor_chat_response.png" alt="016 mentor chat response" />

### 017 home before login

<img src="screenshots/mobile/017_home_before_login.png" alt="017 home before login" />

### 018 drawer open

<img src="screenshots/mobile/018_drawer_open.png" alt="018 drawer open" />

### 019 account entry screen

<img src="screenshots/mobile/019_account_entry_screen.png" alt="019 account entry screen" />

### 020 account signed in synced

<img src="screenshots/mobile/020_account_signed_in_synced.png" alt="020 account signed in synced" />

---

## Admin Web 测试截图 (Playwright)

完整的 HTML 报告（含所有页面截图）位于：
`admin-web/playwright-report/index.html`

测试覆盖范围：

| 功能模块 | 测试文件 |
|---------|---------|
| 登录 / 登出 | tests/login.spec.ts |
| 控制台概览 | tests/overview.spec.ts |
| 用户管理 | tests/users.spec.ts |
| 知识库操作 | tests/knowledge-ops.spec.ts |
| Mentor 审核 | tests/mentor-audit.spec.ts |
| 分发统计 | tests/distribution-stats.spec.ts |
| 花园数据 | tests/garden.spec.ts |
| 成长追踪 | tests/growth.spec.ts |

