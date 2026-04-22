# S03 Caregiver Invite Runbook

## 目标

把 M003/S03 的 caregiver invite 闭环固定成未来 agent / 运营 / 工程都能直接复跑的一条仓库内路径：

1. `POST /api/v1/caregiver-invites` 创建 invite token
2. `GET /invite/{token}` 公共 landing
3. `GET /invite/{token}/open-app` 受控 open-app redirect
4. `GET /invite/{token}/download` 受控 download fallback，并复用 S01 `/download?source=caregiver_invite`
5. `POST /api/v1/caregiver-invites/accept` 建立 account-level household/member 关系
6. `GET /api/v1/household/shared-context` 读取共享宝宝档案 / continuity / 花园上下文摘要
7. `caregiver_invite_events`、`household_shared_context`、`release_distribution_events(source=caregiver_invite)` 的 SQL 查询口径
8. root-safe `tool/verify_s03_invite.dart` proof pack 与 smoke 入口

这份 runbook **只复用仓库内已经落地的 controller、web tests、SQL query pack、distribution fallback 与 wrapper**，不要求翻原始日志，也不引入新的 PII / debug payload。

---

## 0. Root-safe 入口

### 0.1 先跑 help，确认 proof pack 存在

从仓库根执行：

```bash
dart run tool/verify_s03_invite.dart --help
```

wrapper 会先检查以下 proof 文件：

- `docs/runbooks/s03-caregiver-invite.md`
- `backend/src/main/resources/sql/s03_caregiver_invite_queries.sql`
- `backend/src/main/resources/db/migration/V7__create_caregiver_invite_tables.sql`
- `backend/src/main/resources/db/migration/V8__align_caregiver_invite_public_audit.sql`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverInviteApiWebTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverInviteLandingWebTest.java`
- `backend/pom.xml`

缺任一文件时，wrapper 返回 **exit code 64** 并列出缺失路径。

### 0.2 可选 public invite smoke

本地 backend 已启动后，可从仓库根执行 landing smoke：

```bash
dart run tool/verify_s03_invite.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --token=invite_token_1234 \
  --route=landing \
  --expect-status=200 \
  --expect-result=page_view \
  --expect-body="Baby Talk"
```

验证 open-app redirect：

```bash
dart run tool/verify_s03_invite.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --token=invite_token_1234 \
  --route=open-app \
  --platform=android \
  --expect-status=302 \
  --expect-result=open_app_redirect \
  --expect-location-contains="babytalk://invite/open"
```

验证 download fallback：

```bash
dart run tool/verify_s03_invite.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --token=invite_token_1234 \
  --route=download \
  --platform=android \
  --expect-status=302 \
  --expect-result=download_fallback \
  --expect-location-contains="/download?source=caregiver_invite"
```

若 smoke 失败：

- 缺 `--base-url` / `--token` 或参数非法：**64**
- backend 未启动 / 连接失败：非零退出，并提示先执行 `mvn -f backend/pom.xml spring-boot:run`
- 请求超时：**124**，并提示确认 backend、`--base-url`、`--token` 与 route 是否可达

---

## 1. 当前 runtime / proof surface

### 1.1 Public invite routes

| Surface | 期望 | 当前 proof |
|---|---|---|
| `GET /invite/{token}` | HTML 可访问，返回明确结果 header、failure header、可见 CTA | `CaregiverInviteLandingWebTest` + smoke |
| `GET /invite/{token}/open-app` | 只跳到配置驱动的 `babytalk://invite/open`，不允许 open redirect | `CaregiverInviteLandingWebTest` + smoke |
| `GET /invite/{token}/download` | 只跳到 `/download?source=caregiver_invite` | `CaregiverInviteLandingWebTest` + smoke |
| `X-Invite-Result` | `page_view` / `open_app_redirect` / `download_fallback` / `invalid` / `expired` / `already_used` / `revoked` / `unavailable` | 响应头 + smoke |
| `X-Invite-Audit` | `recorded` / `failed` | 响应头 + smoke |
| `X-Invite-Failure-Reason` | `token_not_found` / `token_expired` / `token_already_used` / `invite_revoked` / `unknown_platform` / `open_app_unconfigured` / `platform_target_missing` / `download_fallback_unconfigured` / `storage_unavailable` 等 coarse reason | 响应头 + SQL |

### 1.2 Authenticated invite / accept / shared-context routes

| Surface | 期望 | 当前 proof |
|---|---|---|
| `POST /api/v1/caregiver-invites` | 创建真实 invite token，返回 public invite URL | `CaregiverInviteApiWebTest` |
| `POST /api/v1/caregiver-invites/accept` | 基于 account_id 建 household/member 关系，并更新 shared context | `CaregiverInviteApiWebTest` |
| `POST /api/v1/caregiver-invites/{token}/revoke` | 主照护者可撤销 invite | `CaregiverInviteApiWebTest` |
| `GET /api/v1/household/shared-context` | 返回脱敏 summary + 安全 route args | `CaregiverInviteApiWebTest` |

---

## 2. 公开链路的稳定合同

### 2.1 Landing

`GET /invite/{token}`

期望：

- 返回真实 HTML，不暴露原始 child / installation / session 信息
- 展示邀请角色、来源、有效期与可见 CTA
- headers：
  - `X-Invite-Result`
  - `X-Invite-Audit`
  - `X-Invite-Failure-Reason`

典型结果：

- `page_view`
- `invalid` + `token_blank` / `token_malformed` / `token_not_found`
- `expired` + `token_expired`
- `already_used` + `token_already_used`
- `revoked` + `invite_revoked`
- `unavailable` + `open_app_unconfigured` / `storage_unavailable`

### 2.2 Open-app redirect

`GET /invite/{token}/open-app?platform=android|ios`

行为约束：

- 只允许跳到白名单 deep link：`babytalk://invite/open`
- 只允许附带 coarse route args：`token` / `source` / `role`
- 平台不合法时返回可见失败页，不做任意 redirect

典型结果：

- `open_app_redirect`
- `invalid` + `unknown_platform`
- `expired` + `token_expired`
- `already_used` + `token_already_used`
- `revoked` + `invite_revoked`
- `unavailable` + `platform_unresolved` / `platform_target_missing` / `storage_unavailable`

### 2.3 Download fallback

`GET /invite/{token}/download?platform=android|ios`

行为约束：

- 只允许受控跳到 `/download?source=caregiver_invite`
- 不允许拼接任意外链
- invite 与 distribution 两套审计需要可桥接

典型结果：

- `download_fallback`
- `invalid` + `unknown_platform`
- `expired` + `token_expired`
- `already_used` + `token_already_used`
- `revoked` + `invite_revoked`
- `unavailable` + `download_fallback_unconfigured` / `storage_unavailable`

---

## 3. 当前审计表能回答什么

### 3.1 `caregiver_invite_events`

稳定字段：

- `token`
- `entrypoint`
- `source`
- `requested_role`
- `platform`
- `result`
- `failure_reason`
- `created_at`

它能回答：

- 哪个入口（landing / open_app / download / accept / revoke）失败最多
- 哪个 result / failure reason 在增长
- 哪个平台更常命中 `unknown_platform` / `platform_target_missing`
- 同一 token 在 create / landing / open-app / download / accept 上的时间线

### 3.2 `household_shared_context`

稳定字段：

- `baby_profile_summary`
- `continuity_summary`
- `garden_summary`
- `space_id`
- `activity_id`
- `latest_interaction_at`
- `updated_at`

它能回答：

- 次照护者接受 invite 后是否已经有最新共享上下文投影
- 当前投影是否只包含 summary 与安全 route args
- continuity / garden 摘要是否落到预期 household

### 3.3 `release_distribution_events(source=caregiver_invite)`

它能回答：

- invite download fallback 是否真的承接到 S01 public distribution surface
- `caregiver_invite` 在 distribution 侧命中了哪些 `result` / `failure_reason`
- Android / iOS 哪个平台在 distribution 侧更容易失败

---

## 4. 推荐排查顺序

严格按这个顺序，不要跳步：

1. **先看用户所在 surface**
   - create、landing、open-app、download、accept、shared-context 哪一步失败？
   - `X-Invite-Result` / `X-Invite-Audit` / `X-Invite-Failure-Reason` 是什么？
2. **再跑 wrapper**
   - `dart run tool/verify_s03_invite.dart --help`
   - 必要时追加 `--smoke`
3. **再跑 backend proof tests**
   - `mvn -q -f backend/pom.xml -Dtest=CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest test`
4. **最后看 SQL query pack**
   - 先看 invite 侧 result/failure 聚合
   - 再看 `household_shared_context`
   - 最后看 `release_distribution_events(source=caregiver_invite)` bridge

这样可以先分清：

- token 是否无效 / 过期 / 已使用 / 已撤销
- landing / open-app / download 是否走了白名单路径
- distribution fallback 是否真的接上了 S01
- shared context 是否已经可用，还是 accept 后仍缺投影

---

## 5. SQL proof pack

统一入口：

- `backend/src/main/resources/sql/s03_caregiver_invite_queries.sql`

推荐查询顺序：

1. 最近 invite 事件与日维度总览
2. source / platform / result 聚合
3. 单 token 时间线 + 当前 invite 状态
4. `household_shared_context` 当前快照
5. `release_distribution_events(source=caregiver_invite)` bridge 对照

通过标准：

- `caregiver_invite_events` 能看清 create / landing / open-app / download / accept / revoke / shared_context 的结果分布
- `household_shared_context` 不包含 nickname / installation / session / raw payload
- distribution 侧能看见 `source=caregiver_invite`

---

## 6. Failure matrix

| 症状 | 先看哪里 | 应看到的 surface | 不应出现的坏结果 |
|---|---|---|---|
| invite landing 打不开 | wrapper `--route=landing` + web test | `invalid` / `expired` / `already_used` / `revoked` / `unavailable` | 500 或空白页 |
| open-app 没跳 | wrapper `--route=open-app` | `open_app_redirect`，或 `unknown_platform` / `platform_target_missing` / `platform_unresolved` | 任意 URL 被透传跳转 |
| download fallback 没接上 | wrapper `--route=download` + SQL bridge | `Location` 包含 `/download?source=caregiver_invite`，distribution 表有 `source=caregiver_invite` | 再造第二套下载入口 |
| invite 被说“不能用” | landing headers + SQL token timeline | `invalid` / `expired` / `already_used` / `revoked` 明确区分 | 全部混成同一错误文案 |
| shared context 看不到 | `CaregiverInviteApiWebTest` + `household_shared_context` | `shared_context_unavailable` 或最新投影可读 | accept 成功但没有可解释 surface |
| audit 没落盘 | `X-Invite-Audit` + SQL 最近事件 | `failed` 可见，且页面主链仍可访问 | 只能猜“可能没人访问” |

---

## 7. Redaction 红线

允许输出：

- `token`（仅用于单 token 时间线排查）
- `entrypoint`
- `source`
- `requested_role`
- `platform`
- `result`
- `failure_reason`
- `space_id` / `activity_id`
- summary 级 `baby_profile_summary` / `continuity_summary` / `garden_summary`
- `X-Invite-*` headers

禁止输出：

- child / 宝宝昵称
- `installationId`
- `sessionId`
- 原始 interaction payload
- account 标识的扩散式导出
- 原始 user agent 全量字符串
- 内部 debug / stack trace 文案

如果 runbook、wrapper、SQL 导出或截图里出现这些内容，先修 redaction，再继续排查。

---

## 8. 最小复跑清单

```bash
dart run tool/verify_s03_invite.dart --help

mvn -q -f backend/pom.xml -Dtest=CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest test

test -s docs/runbooks/s03-caregiver-invite.md && test -s backend/src/main/resources/sql/s03_caregiver_invite_queries.sql

rg -n "caregiver_invite_events|household_shared_context|caregiver_invite|open_app_redirect|download_fallback|invalid|expired|already_used|revoked|unavailable" \
  docs/runbooks/s03-caregiver-invite.md \
  backend/src/main/resources/sql/s03_caregiver_invite_queries.sql \
  tool/verify_s03_invite.dart
```

通过标准：

- runbook 明确区分 landing / open-app / download / accept / shared-context / distribution bridge
- SQL 只依赖稳定 invite / distribution / shared-context 表与字段
- wrapper 能在仓库根给出 help、缺失项、smoke 与 backend 未启动提示
- public redirect 只走白名单 `babytalk://invite/open` 与 `/download?source=caregiver_invite`
- 不引入 child / installation / session / raw payload 泄漏
