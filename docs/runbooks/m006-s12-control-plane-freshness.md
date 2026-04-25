# M006 / S12 Overview Control-Plane Freshness Runbook

## Boundary

S12 的 `Overview` 不是 KPI 大盘，也不是 transcript / share-token 浏览器。

这一页只展示管理员可见的多域 control-plane truth：

- `knowledge_ingestion`
- `knowledge_kg`
- `mentor_audit`
- `distribution`

每个 domain 只暴露：

- freshness state / source timestamp
- queue / attention 计数
- operator-safe next action
- transport / fallback 诊断

**不会展示：**

- raw mentor prompt / transcript
- raw share token / landing token
- public `admin-api` URL
- JWT / bootstrap password / refresh token
- 任何未在 `/api/admin/overview/**` 合同中的 payload

## UI truth model

Overview 页面现在有两层 transport 真相：

1. **backend transport**
   - 来自 `/api/admin/overview/summary` 和 `/api/admin/overview/stream`
   - `live` / `polling_required`
   - `degradedReason`
   - `lastSuccessfulSnapshotAt`
   - 连接/重连计数

2. **client transport**
   - `streaming`：前端 fetch-stream 正常连着
   - `polling`：前端侦测到 realtime 断开，退回 bounded polling

最终给 operator 看的 boss strip 状态是：

- `live`：backend live + client streaming
- `polling`：backend 要求 polling，或 client realtime 断开
- `recovered`：前一刻在 polling，现在重新回到 live

## Why fetch-stream instead of native EventSource

`admin-api` 目前是 stateless Bearer auth。

浏览器原生 `EventSource` 不能稳定附带 `Authorization: Bearer ...`，而 `Overview` stream endpoint 又明确受 Spring Security 保护；因此前端必须用 **`fetch` + SSE parser** 订阅 `/api/admin/overview/stream`，并复用现有 refresh/session-reset 语义。

这不是额外扩 scope，而是当前鉴权现实下保证 T01/T02 seam truthful 的必要适配。

## Failure semantics

### Summary contract failure

- 如果第一次 `summary` 就失败：页面显示显式错误，不回退 placeholder
- 如果已经有 last-good snapshot：保留当前 snapshot，并把错误放进 inline diagnostics
- `invalid_response_payload`（例如缺 freshness 字段、未知 freshness state）属于 **UI contract failure**，应该让 proof fail

### Stream failure

- stream 断开 → 进入 `polling`
- boss strip / alert 必须可见
- last-good snapshot 继续保留
- operator 可以点击 `恢复 realtime`

### Polling failure

- polling 继续失败时只更新 diagnostics，不清空当前 snapshot
- 连续失败达到预算后暂停自动 polling
- operator 可点击 `恢复 polling`

## Data surfaces to inspect

- `GET /api/admin/overview/summary`
- `GET /api/admin/overview/stream`
- `/overview` boss strip
- `/overview` domain cards
- `/overview` inline diagnostics

关键 test id：

- `overview-control-strip`
- `overview-transport-mode`
- `overview-last-good-snapshot`
- `overview-inline-diagnostics`
- `overview-domain-card-<domainKey>`
- `overview-polling-alert`
- `overview-recovery-alert`
- `overview-summary-error`

## Canonical verification

S12 的 **single replay path** 仍然固定为：

```bash
dart run tool/verify_m006_s12_control_plane_freshness.dart
```

这个不改名的 verifier 会按固定顺序重放：

1. `required_artifacts`：确认 S12 proof-pack / runbook / Playwright wiring 都在。
2. `backend_contract`：执行 `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminOverviewWebTest`。
3. `admin_web_build`：执行 `npm --prefix admin-web run build`。
4. `compose_boot`：由 verifier 自己执行 `docker compose up -d --build postgres minio db-migration app-api admin-api admin-web`。
5. `runtime_truth`：读取 `docker compose ps --all --format json`，并核验 `app-api` / `admin-api` actuator 与 `admin-web` shell。
6. `browser_proof_pack`：带 `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` 运行 `auth-and-rbac.spec.ts` + `overview-control-plane.spec.ts`。

### First drill-down signal

当 verifier 失败时，**先看首个 failing step label**，再下钻：

- `compose_boot` / `runtime_truth`
  - 先看 verifier 打出的 compose diagnostics。
  - `runtime_truth` 会指出首个 missing / unhealthy service。
- `browser_proof_pack`
  - 先看 `admin-web/playwright-report/index.html`。
  - 再看失败 spec 的 stdout/stderr。
- `backend_contract`
  - 直接看 `AdminOverviewWebTest` 输出；这一步失败时不要先怀疑前端。

### Direct browser drill-down

直接运行 Playwright 仍然是合法的二级下钻：

```bash
npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts overview-control-plane.spec.ts
```

此路径下 `admin-web/playwright.global-setup.ts` 会自己 boot compose。只有从 repo-root verifier 进入时，才通过 `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` 改为 **只校验 runtime truth，不重复 boot/build**。

### Why S13 / S14 must keep reusing this path

S13 demo wrapper、S14 release closure、README、CONTRIBUTING 都已经把 `tool/verify_m006_s12_control_plane_freshness.dart` 当作稳定下钻入口。这里如果改名或改成多入口，就会让上游 “先看哪个 proof” 重新漂移；因此后续 slice 只能复用它、扩充它的诊断，而不能换路径。

## What the Playwright proof pack covers

`admin-web/tests/overview-control-plane.spec.ts` proves:

1. super admin 打开 `/overview` 时看到真实 control plane，而不是 placeholder
2. one stale domain among fresh domains
3. realtime 断开 → polling fallback → 手动恢复 realtime → recovered
4. malformed summary refresh 触发 `invalid_response_payload`，同时保留 last-good snapshot

`admin-web/tests/auth-and-rbac.spec.ts` 继续证明：

- super admin 默认落到 `/overview`
- limited admin fail-closed 到自己唯一允许的模块
- auth refresh / revoked refresh token / malformed stored session 的 shell 行为保持显式

## Operator notes

- 如果 `overview-transport-mode = polling`，先看 `overview-inline-diagnostics`
- 如果是 client stream 断开，优先点 `恢复 realtime`
- 如果是 backend `polling_required`，等待下一次 summary 成功或手动 `重新读取 summary`
- 如果看到 `invalid_response_payload`，优先怀疑前后端 contract drift，而不是把页面当成 empty/all-clear
