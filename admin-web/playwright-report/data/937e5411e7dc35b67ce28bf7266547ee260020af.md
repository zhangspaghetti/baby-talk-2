# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: knowledge-ops.spec.ts >> knowledge ops workspace >> shows the real ingestion queue, contradiction split view, and notification pane on /knowledge-ops
- Location: ..\..\..\..\..\..\..\Users\zhang\.gsd\projects\67565506c51a\worktrees\M006\admin-web\tests\knowledge-ops.spec.ts:6:3

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: getByTestId('knowledge-ingestion-queue')
Expected: visible
Timeout: 10000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 10000ms
  - waiting for getByTestId('knowledge-ingestion-queue')

```

# Page snapshot

```yaml
- generic [ref=e5]:
  - complementary [ref=e7]:
    - generic [ref=e8]:
      - generic [ref=e10] [cursor=pointer]:
        - generic [ref=e11]: BT
        - heading "BabyTalk Admin" [level=1] [ref=e12]
      - menu [ref=e14]:
        - menuitem "home Overview" [ref=e15] [cursor=pointer]:
          - link "home Overview" [ref=e17]:
            - /url: /overview
            - generic [ref=e18]:
              - img "home" [ref=e20]:
                - img [ref=e21]
              - generic [ref=e23]: Overview
        - menuitem "team Users" [ref=e24] [cursor=pointer]:
          - link "team Users" [ref=e26]:
            - /url: /users
            - generic [ref=e27]:
              - img "team" [ref=e29]:
                - img [ref=e30]
              - generic [ref=e32]: Users
        - menuitem "read Knowledge Ops" [ref=e33] [cursor=pointer]:
          - link "read Knowledge Ops" [ref=e35]:
            - /url: /knowledge-ops
            - generic [ref=e36]:
              - img "read" [ref=e38]:
                - img [ref=e39]
              - generic [ref=e41]: Knowledge Ops
        - menuitem "safety-certificate Mentor & Safety" [ref=e42] [cursor=pointer]:
          - link "safety-certificate Mentor & Safety" [ref=e44]:
            - /url: /mentor/audits
            - generic [ref=e45]:
              - img "safety-certificate" [ref=e47]:
                - img [ref=e48]
              - generic [ref=e50]: Mentor & Safety
        - menuitem "bar-chart Distribution Stats" [ref=e51] [cursor=pointer]:
          - link "bar-chart Distribution Stats" [ref=e53]:
            - /url: /distribution/stats
            - generic [ref=e54]:
              - img "bar-chart" [ref=e56]:
                - img [ref=e57]
              - generic [ref=e59]: Distribution Stats
      - generic [ref=e60]:
        - generic [ref=e61]:
          - generic [ref=e63]:
            - img "user" [ref=e65] [cursor=pointer]:
              - img [ref=e66]
            - generic [ref=e68] [cursor=pointer]: Super Admin
          - generic [ref=e69]: super_admin
        - generic [ref=e70]:
          - generic [ref=e73] [cursor=pointer]: Knowledge Ops
          - button "logout 退出登录" [ref=e76] [cursor=pointer]:
            - img "logout" [ref=e78]:
              - img [ref=e79]
            - generic [ref=e81]: 退出登录
      - img [ref=e83] [cursor=pointer]
  - main [ref=e86]:
    - generic [ref=e87]:
      - generic [ref=e88]:
        - navigation [ref=e89]:
          - list [ref=e90]:
            - listitem [ref=e91]: Admin Shell
            - listitem [ref=e92]: /
            - listitem [ref=e93]: Knowledge Ops
        - generic [ref=e95]:
          - generic "Knowledge Ops" [ref=e96]
          - generic "ingestion queue + KG review 的占位入口。" [ref=e97]
        - generic [ref=e101]:
          - generic [ref=e103]: super_admin 默认落到 Overview，避免多模块账号直接跳进某个单工作面。
          - generic [ref=e105]:
            - generic [ref=e107]:
              - generic [ref=e109]: "user: super_admin"
              - generic [ref=e111]: "current: Knowledge Ops"
              - generic [ref=e113]: "visible modules: 5"
            - generic [ref=e115]:
              - generic [ref=e117]: Overview
              - generic [ref=e119]: Users
              - generic [ref=e121]: Knowledge Ops
              - generic [ref=e123]: Mentor & Safety
              - generic [ref=e125]: Distribution Stats
            - generic [ref=e129]: super_admin
            - generic [ref=e131]:
              - generic [ref=e133]: admins:read
              - generic [ref=e135]: admins:write
              - generic [ref=e137]: distribution:read
              - generic [ref=e139]: kg:read
              - generic [ref=e141]: kg:review
              - generic [ref=e143]: mentor:audit
              - generic [ref=e145]: rag:read
              - generic [ref=e147]: rag:write
              - generic [ref=e149]: rbac:read
              - generic [ref=e151]: rbac:write
              - generic [ref=e153]: users:read
              - generic [ref=e155]: users:write
            - generic [ref=e157]:
              - generic [ref=e159]: "access token expires at: 2026-04-24T11:56:29.675014496Z"
              - generic [ref=e161]: "refresh token expires at: 2026-05-01T11:41:29.751010475Z"
      - generic [ref=e165]:
        - alert [ref=e167]:
          - img "info-circle" [ref=e168]:
            - img [ref=e169]
          - generic [ref=e171]:
            - generic [ref=e172]: Knowledge Ops 先落空壳，不做假数据
            - generic [ref=e173]: Ingestion queue、KG review split-view 与 retry / resolve 行为会在后续切片落地；当前页面只证明 shell、权限 metadata 与 placeholder 能真实挂载。
        - generic [ref=e176]:
          - generic [ref=e180]:
            - generic [ref=e183]: 权限门槛
            - generic [ref=e185]:
              - generic [ref=e187]:
                - text: 本模块接受
                - code [ref=e189]: rag:read
                - text: 或
                - code [ref=e191]: kg:read
                - text: 。
              - generic [ref=e193]:
                - generic [ref=e195]: knowledge access enabled
                - generic [ref=e197]: rag:read enabled
                - generic [ref=e199]: kg:read enabled
          - generic [ref=e203]:
            - generic [ref=e206]: 后续真实模块范围
            - generic [ref=e208]:
              - generic [ref=e209]: • ingestion queue 与 retry state
              - generic [ref=e210]: • KG contradiction split-view 与 resolve flow
              - generic [ref=e211]: • queue/deep-link state 复原与协作 handoff 上下文
```

# Test source

```ts
  1  | import { expect, test, type Page } from '@playwright/test';
  2  | 
  3  | const sessionStorageKey = 'babytalk.admin.session';
  4  | 
  5  | test.describe('knowledge ops workspace', () => {
  6  |   test('shows the real ingestion queue, contradiction split view, and notification pane on /knowledge-ops', async ({ page }) => {
  7  |     await loginViaUi(page);
  8  | 
  9  |     await page.goto('/knowledge-ops');
  10 | 
  11 |     await expect(page.getByTestId('knowledge-ops-page')).toBeVisible();
> 12 |     await expect(page.getByTestId('knowledge-ingestion-queue')).toBeVisible();
     |                                                                 ^ Error: expect(locator).toBeVisible() failed
  13 |     await expect(page.getByTestId('knowledge-contradiction-list')).toBeVisible();
  14 |     await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();
  15 |     await expect(page.getByTestId('knowledge-inline-diagnostics')).toBeVisible();
  16 |   });
  17 | });
  18 | 
  19 | async function loginViaUi(page: Page, username = 'super_admin', password = 'SuperAdmin123!') {
  20 |   await page.goto('/login');
  21 |   await page.evaluate((storageKey) => window.localStorage.removeItem(storageKey), sessionStorageKey);
  22 | 
  23 |   const loginResponse = page.waitForResponse(
  24 |     (response) => response.url().includes('/api/admin/auth/login') && response.request().method() === 'POST',
  25 |   );
  26 |   const meResponse = page.waitForResponse(
  27 |     (response) => response.url().includes('/api/admin/me') && response.request().method() === 'GET',
  28 |   );
  29 | 
  30 |   await page.getByLabel('用户名').fill(username);
  31 |   await page.getByLabel('密码').fill(password);
  32 |   await page.getByTestId('login-submit').click();
  33 | 
  34 |   expect((await loginResponse).status()).toBe(200);
  35 |   expect((await meResponse).status()).toBe(200);
  36 |   await expect(page).toHaveURL(/\/overview$|\/users$|\/knowledge-ops$|\/mentor\/audits$|\/distribution\/stats(?:\?.*)?$/);
  37 |   await expect(page.getByTestId('protected-shell')).toBeVisible();
  38 | }
  39 | 
```