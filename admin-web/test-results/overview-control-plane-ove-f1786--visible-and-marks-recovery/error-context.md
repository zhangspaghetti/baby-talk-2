# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: overview-control-plane.spec.ts >> overview control plane proof >> falls back to polling after realtime loss, keeps the last good snapshot visible, and marks recovery
- Location: tests\overview-control-plane.spec.ts:82:3

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: getByTestId('overview-polling-alert')
Expected: visible
Timeout: 10000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 10000ms
  - waiting for getByTestId('overview-polling-alert')

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
        - menuitem "safety-certificate Mentor Audit" [ref=e42] [cursor=pointer]:
          - link "safety-certificate Mentor Audit" [ref=e44]:
            - /url: /mentor/audits
            - generic [ref=e45]:
              - img "safety-certificate" [ref=e47]:
                - img [ref=e48]
              - generic [ref=e50]: Mentor Audit
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
          - generic [ref=e73] [cursor=pointer]: Overview
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
            - listitem [ref=e93]: Overview
        - generic [ref=e95]:
          - generic "Overview" [ref=e96]
          - generic "多域 freshness、transport fallback 与 next-action 的统一 control plane。" [ref=e97]
        - generic [ref=e101]:
          - generic [ref=e103]: super_admin 默认落到 Overview，避免多模块账号直接跳进某个单工作面。
          - generic [ref=e105]:
            - generic [ref=e107]:
              - generic [ref=e109]: "user: super_admin"
              - generic [ref=e111]: "current: Overview"
              - generic [ref=e113]: "visible modules: 5"
            - generic [ref=e115]:
              - generic [ref=e117]: Overview
              - generic [ref=e119]: Users
              - generic [ref=e121]: Knowledge Ops
              - generic [ref=e123]: Mentor Audit
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
              - generic [ref=e159]: "access token expires at: 2026-04-25T02:14:06.468746504Z"
              - generic [ref=e161]: "refresh token expires at: 2026-05-02T01:59:06.469462041Z"
      - generic [ref=e165]:
        - generic [ref=e167]:
          - generic [ref=e170]: Overview control plane
          - generic [ref=e172]:
            - generic [ref=e174]:
              - generic [ref=e176]: "transport: recovered"
              - generic [ref=e178]: "source: streaming"
              - generic [ref=e180]: "backend: live"
              - generic [ref=e182]: "visible domains: 4"
              - generic [ref=e184]: "degraded domains: 0"
              - generic [ref=e186]: "last good snapshot: 2026/4/25 09:59:06"
            - generic [ref=e188]: realtime 已恢复；当前重新回到 stream 驱动，最近一次 fallback 原因是 network_error。最后成功快照时间：2026/4/25 09:59:06。
            - button "重新读取 summary" [ref=e192] [cursor=pointer]:
              - generic [ref=e193]: 重新读取 summary
        - alert [ref=e195]:
          - img "check-circle" [ref=e196]:
            - img [ref=e197]
          - generic [ref=e199]:
            - generic [ref=e200]: Overview realtime 已恢复
            - generic [ref=e201]: 恢复时间：2026/4/25 09:59:07；上一次 fallback 原因：network_error。
        - alert [ref=e203]:
          - img "exclamation-circle" [ref=e204]:
            - img [ref=e205]
          - generic [ref=e207]:
            - generic [ref=e208]: polling 未成功更新快照
            - generic [ref=e209]: 无法连接 admin-api。请确认 admin-api 已启动。（network_error）；当前继续显示最后成功快照。
        - generic [ref=e211]:
          - generic [ref=e214]: Inline diagnostics
          - generic [ref=e216]:
            - generic [ref=e217]: Overview 只显示多域 freshness / queue / next action；不会回显 transcript、share token、raw mentor payload 或 public admin-api URL。
            - generic [ref=e219]:
              - generic [ref=e221]: "summary: ready"
              - generic [ref=e223]: "stream: streaming"
              - generic [ref=e225]: "polling: idle"
              - generic [ref=e227]: "lastEventId: 14"
              - generic [ref=e229]: "lastHeartbeat: 2026/4/25 09:59:08"
              - generic [ref=e231]: "connections: 6 / reconnects: 6"
              - generic [ref=e233]: "generatedAt: 2026/4/25 09:59:06"
        - generic [ref=e235]:
          - generic [ref=e236]:
            - generic [ref=e238]:
              - generic [ref=e240]:
                - generic [ref=e241]: Knowledge ingestion
                - generic [ref=e243]: updating
              - generic [ref=e245]: rag:read
            - generic [ref=e247]:
              - generic [ref=e249]: 该 domain 仍有进行中的工作流，Overview 会把它标成 updating，而不是假装 all clear。
              - generic [ref=e251]:
                - generic [ref=e253]: "queue: 22"
                - generic [ref=e255]: "attention: 21"
                - generic [ref=e257]: "allClear: false"
                - generic [ref=e259]: "updatedAt: 2026/4/25 04:21:01"
              - generic [ref=e261]:
                - generic [ref=e263]: "pending: 1"
                - generic [ref=e265]: "processing: 0"
                - generic [ref=e267]: "failed: 21"
                - generic [ref=e269]: "completed: 33"
              - generic [ref=e271]:
                - generic [ref=e273]: "next action: Retry failed ingestion jobs"
                - link "打开 Knowledge ingestion" [ref=e275] [cursor=pointer]:
                  - /url: /knowledge-ops?view=ingestion&status=failed
                  - button "打开 Knowledge ingestion" [ref=e276]:
                    - generic [ref=e277]: 打开 Knowledge ingestion
          - generic [ref=e278]:
            - generic [ref=e280]:
              - generic [ref=e282]:
                - generic [ref=e283]: Knowledge contradictions
                - generic [ref=e285]: stale
              - generic [ref=e287]: kg:read
            - generic [ref=e289]:
              - generic [ref=e291]: 该 domain 已超过 freshness 窗口，需要 operator 重新确认当前工作面是否仍然准确。
              - generic [ref=e293]:
                - generic [ref=e295]: "queue: 58"
                - generic [ref=e297]: "attention: 58"
                - generic [ref=e299]: "allClear: false"
                - generic [ref=e301]: "updatedAt: 2026/4/25 04:21:08"
              - generic [ref=e303]:
                - generic [ref=e305]: "open: 29"
                - generic [ref=e307]: "escalated: 29"
                - generic [ref=e309]: "unread_notifications: 29"
                - generic [ref=e311]: "resolved: 11"
              - generic [ref=e313]:
                - generic [ref=e315]: "next action: Review escalated contradictions"
                - link "打开 Knowledge contradictions" [ref=e317] [cursor=pointer]:
                  - /url: /knowledge-ops?view=kg-review&status=escalated
                  - button "打开 Knowledge contradictions" [ref=e318]:
                    - generic [ref=e319]: 打开 Knowledge contradictions
          - generic [ref=e320]:
            - generic [ref=e322]:
              - generic [ref=e324]:
                - generic [ref=e325]: Mentor audit
                - generic [ref=e327]: stale
              - generic [ref=e329]: mentor:audit
            - generic [ref=e331]:
              - generic [ref=e333]: 该 domain 已超过 freshness 窗口，需要 operator 重新确认当前工作面是否仍然准确。
              - generic [ref=e335]:
                - generic [ref=e337]: "queue: 65"
                - generic [ref=e339]: "attention: 65"
                - generic [ref=e341]: "allClear: false"
                - generic [ref=e343]: "updatedAt: 2026/4/25 06:38:25"
              - generic [ref=e345]:
                - generic [ref=e347]: "flagged_incidents: 65"
                - generic [ref=e349]: "blocked_fallback: 32"
                - generic [ref=e351]: "rate_limited: 33"
                - generic [ref=e353]: "retryable: 33"
              - generic [ref=e355]:
                - generic [ref=e357]: "next action: Review blocked fallback incidents"
                - link "打开 Mentor audit" [ref=e359] [cursor=pointer]:
                  - /url: /mentor/audits?flag=blocked_fallback
                  - button "打开 Mentor audit" [ref=e360]:
                    - generic [ref=e361]: 打开 Mentor audit
          - generic [ref=e362]:
            - generic [ref=e364]:
              - generic [ref=e366]:
                - generic [ref=e367]: Distribution stats
                - generic [ref=e369]: all_clear
              - generic [ref=e371]: distribution:read
            - generic [ref=e373]:
              - generic [ref=e375]: 当前没有待处理积压，但该 domain 仍保持真实 freshness / next-action contract。
              - generic [ref=e377]:
                - generic [ref=e379]: "queue: 0"
                - generic [ref=e381]: "attention: 0"
                - generic [ref=e383]: "allClear: true"
                - generic [ref=e385]: "updatedAt: 2026/4/25 06:38:26"
              - generic [ref=e387]:
                - generic [ref=e389]: "release_total_events: 106"
                - generic [ref=e391]: "release_failure_events: 0"
                - generic [ref=e393]: "share_total_events: 78"
                - generic [ref=e395]: "share_failure_events: 0"
              - generic [ref=e397]:
                - generic [ref=e399]: "next action: All clear"
                - link "打开 Distribution stats" [ref=e401] [cursor=pointer]:
                  - /url: /distribution/stats?range=30d
                  - button "打开 Distribution stats" [ref=e402]:
                    - generic [ref=e403]: 打开 Distribution stats
```

# Test source

```ts
  1   | import { expect, test, type Page, type Route } from '@playwright/test';
  2   | import { createAdminWithPermissions } from './helpers/admin-api';
  3   | 
  4   | test.describe('overview control plane proof', () => {
  5   |   test('renders the truthful overview control plane for super admins', async ({ page }) => {
  6   |     await loginViaUi(page, { expectedUrl: /\/overview$/ });
  7   |     await waitForOverviewReady(page);
  8   | 
  9   |     await expect(page.getByTestId('overview-transport-mode')).toContainText(/live|polling|recovered/);
  10  |     await expect(page.getByText('truthful placeholder')).toHaveCount(0);
  11  |   });
  12  | 
  13  |   test('lets single-domain overview readers deep-link into /overview while keeping hidden domains fail-closed', async ({
  14  |     page,
  15  |     request,
  16  |   }) => {
  17  |     const distributionReader = await createAdminWithPermissions(request, ['distribution:read'], 'Distribution Reader');
  18  | 
  19  |     await loginViaUi(page, {
  20  |       username: distributionReader.username,
  21  |       password: distributionReader.password,
  22  |       expectedUrl: /\/distribution\/stats(?:\?.*)?$/,
  23  |     });
  24  | 
  25  |     await page.goto('/overview');
  26  | 
  27  |     await expect(page).toHaveURL(/\/overview$/);
  28  |     await expect(page.getByTestId('overview-control-strip')).toBeVisible();
  29  |     await expect(page.getByTestId('overview-inline-diagnostics')).toBeVisible();
  30  |     await expect(page.getByTestId('overview-last-good-snapshot')).not.toContainText('—');
  31  |     await expect(page.getByTestId('overview-visible-domain-count')).toContainText('1');
  32  |     await expect(page.getByTestId('overview-hidden-domain-note')).toContainText('其余 3 个 domain 保持 fail-closed');
  33  |     await expect(page.getByTestId('overview-domain-card-distribution')).toBeVisible();
  34  |     await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toHaveCount(0);
  35  |     await expect(page.getByTestId('overview-domain-card-knowledge_kg')).toHaveCount(0);
  36  |     await expect(page.getByTestId('overview-domain-card-mentor_audit')).toHaveCount(0);
  37  |     await expect(page.getByTestId('workspace-link-overview')).toHaveCount(0);
  38  |   });
  39  | 
  40  |   test('renders one stale domain among fresh domains from the overview summary contract', async ({ page }) => {
  41  |     await loginViaUi(page, { expectedUrl: /\/overview$/ });
  42  |     await waitForOverviewReady(page);
  43  | 
  44  |     const pattern = '**/api/admin/overview/summary';
  45  |     let intercepted = false;
  46  |     const handler = async (route: Route) => {
  47  |       if (intercepted || new URL(route.request().url()).pathname !== '/api/admin/overview/summary') {
  48  |         await route.continue();
  49  |         return;
  50  |       }
  51  | 
  52  |       intercepted = true;
  53  |       await route.fulfill({
  54  |         status: 200,
  55  |         contentType: 'application/json',
  56  |         body: JSON.stringify(
  57  |           buildOverviewSummaryPayload({
  58  |             mentorState: 'stale',
  59  |             mentorUpdatedAt: minutesAgo(32),
  60  |             transportMode: 'live',
  61  |           }),
  62  |         ),
  63  |       });
  64  |     };
  65  | 
  66  |     await page.route(pattern, handler);
  67  |     try {
  68  |       await page.getByTestId('overview-refresh-button').click();
  69  |     } finally {
  70  |       await page.unroute(pattern, handler);
  71  |     }
  72  | 
  73  |     expect(intercepted).toBe(true);
  74  |     await expect(page.getByTestId('overview-domain-state-mentor_audit')).toContainText('stale');
  75  |     await expect(page.getByTestId('overview-domain-state-distribution')).toContainText('fresh');
  76  |     await expect(page.getByTestId('overview-domain-next-action-mentor_audit')).toHaveAttribute(
  77  |       'href',
  78  |       '/mentor/audits?flag=blocked_fallback',
  79  |     );
  80  |   });
  81  | 
  82  |   test('falls back to polling after realtime loss, keeps the last good snapshot visible, and marks recovery', async ({
  83  |     page,
  84  |   }) => {
  85  |     await loginViaUi(page, { expectedUrl: /\/overview$/ });
  86  |     await waitForOverviewReady(page);
  87  |     await expect(page.getByTestId('overview-transport-source')).toContainText('streaming');
  88  | 
  89  |     await page.context().setOffline(true);
> 90  |     await expect(page.getByTestId('overview-polling-alert')).toBeVisible();
      |                                                              ^ Error: expect(locator).toBeVisible() failed
  91  |     await expect(page.getByTestId('overview-transport-mode')).toContainText('polling');
  92  |     await expect(page.getByTestId('overview-last-good-snapshot')).not.toContainText('—');
  93  |     await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toBeVisible();
  94  | 
  95  |     await page.context().setOffline(false);
  96  |     await page.getByTestId('overview-resume-live').click();
  97  | 
  98  |     await expect(page.getByTestId('overview-recovery-alert')).toBeVisible();
  99  |     await expect(page.getByTestId('overview-transport-mode')).toContainText('recovered');
  100 |     await expect(page.getByTestId('overview-last-good-snapshot')).not.toContainText('—');
  101 |   });
  102 | 
  103 |   test('keeps the last good snapshot visible and surfaces contract failure on malformed summary refresh', async ({
  104 |     page,
  105 |   }) => {
  106 |     await loginViaUi(page, { expectedUrl: /\/overview$/ });
  107 |     await waitForOverviewReady(page);
  108 | 
  109 |     const pattern = '**/api/admin/overview/summary';
  110 |     let intercepted = false;
  111 |     const handler = async (route: Route) => {
  112 |       if (intercepted || new URL(route.request().url()).pathname !== '/api/admin/overview/summary') {
  113 |         await route.continue();
  114 |         return;
  115 |       }
  116 | 
  117 |       intercepted = true;
  118 |       await route.fulfill({
  119 |         status: 200,
  120 |         contentType: 'application/json',
  121 |         body: JSON.stringify(buildMalformedOverviewSummaryPayload()),
  122 |       });
  123 |     };
  124 | 
  125 |     await page.route(pattern, handler);
  126 |     try {
  127 |       await page.getByTestId('overview-refresh-button').click();
  128 |     } finally {
  129 |       await page.unroute(pattern, handler);
  130 |     }
  131 | 
  132 |     expect(intercepted).toBe(true);
  133 |     await expect(page.getByTestId('overview-summary-error')).toContainText('invalid_response_payload');
  134 |     await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toBeVisible();
  135 |     await expect(page.getByTestId('overview-control-strip')).toBeVisible();
  136 |   });
  137 | });
  138 | 
  139 | async function waitForOverviewReady(page: Page) {
  140 |   await expect(page.getByTestId('overview-control-strip')).toBeVisible();
  141 |   await expect(page.getByTestId('overview-inline-diagnostics')).toBeVisible();
  142 |   await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toBeVisible();
  143 |   await expect(page.getByTestId('overview-domain-card-knowledge_kg')).toBeVisible();
  144 |   await expect(page.getByTestId('overview-domain-card-mentor_audit')).toBeVisible();
  145 |   await expect(page.getByTestId('overview-domain-card-distribution')).toBeVisible();
  146 |   await expect(page.getByTestId('overview-last-good-snapshot')).not.toContainText('—');
  147 | }
  148 | 
  149 | async function loginViaUi(
  150 |   page: Page,
  151 |   options: {
  152 |     username?: string;
  153 |     password?: string;
  154 |     expectedUrl: RegExp;
  155 |   },
  156 | ) {
  157 |   const username = options.username ?? 'super_admin';
  158 |   const password = options.password ?? 'SuperAdmin123!';
  159 | 
  160 |   await page.goto('/login');
  161 | 
  162 |   const loginResponse = page.waitForResponse(
  163 |     (response) => exactApiPath(response.url(), '/api/admin/auth/login') && response.request().method() === 'POST',
  164 |   );
  165 |   const meResponse = page.waitForResponse(
  166 |     (response) => exactApiPath(response.url(), '/api/admin/me') && response.request().method() === 'GET',
  167 |   );
  168 | 
  169 |   await page.getByLabel('用户名').fill(username);
  170 |   await page.getByLabel('密码').fill(password);
  171 |   await page.getByTestId('login-submit').click();
  172 | 
  173 |   expect((await loginResponse).status()).toBe(200);
  174 |   expect((await meResponse).status()).toBe(200);
  175 |   await expect(page).toHaveURL(options.expectedUrl);
  176 |   await expect(page.getByTestId('protected-shell')).toBeVisible();
  177 | }
  178 | 
  179 | function exactApiPath(rawUrl: string, pathname: string): boolean {
  180 |   return new URL(rawUrl).pathname === pathname;
  181 | }
  182 | 
  183 | function buildOverviewSummaryPayload(input: {
  184 |   transportMode: 'live' | 'polling_required';
  185 |   mentorState?: 'fresh' | 'stale' | 'degraded';
  186 |   mentorUpdatedAt?: string;
  187 | }) {
  188 |   const generatedAt = minutesAgo(1);
  189 |   const snapshotAt = minutesAgo(2);
  190 |   const mentorState = input.mentorState ?? 'fresh';
```