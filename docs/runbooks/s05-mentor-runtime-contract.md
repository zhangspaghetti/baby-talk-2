# S05 Mentor Runtime Contract / Runbook

## 目标

T03 为 `POST /api/v1/mentor/chat` 提供最小可验证后端真相源：

- **匿名 installation 级访问**，可选 `X-Session-Id` 关联到已登录账号
- **单次 text-first 响应**，不做流式会话、不返回 raw provider body
- **稳定失败语义**：`401 / 403 / 426 / 429 / 502 / 503 / 504 / 400`
- **redacted 持久化**：`mentor_turns` 仅保存受控响应文本与摘要；`mentor_audit_logs` 仅保存 redacted request/response summary、phase、failureCode、rate-limit 命中结果
- **dev provider seam**：默认 `dev`，支持 `[timeout]` / `[malformed]` / `[unavailable]` 故障注入

## 环境变量合同

| Key | 默认值 | 说明 |
|---|---|---|
| `BABY_TALK_MENTOR_PROVIDER_MODE` | `dev` | Mentor provider 模式；当前只实现 `dev`。其他值会稳定返回 `provider_unavailable`。 |
| `BABY_TALK_MENTOR_PROVIDER_TIMEOUT` | `PT4S` | Provider 超时预算；当前主要作为运行合同说明。 |
| `BABY_TALK_MENTOR_RATE_LIMIT_MAX_REQUESTS` | `3` | 单 installation 在窗口内允许的 chat request 数。 |
| `BABY_TALK_MENTOR_RATE_LIMIT_WINDOW` | `PT10M` | installation 级 rate limit 窗口。 |
| `BABY_TALK_MENTOR_PROMPT_MAX_LENGTH` | `280` | 单次 prompt 允许的最大字符数。 |
| `BABY_TALK_MENTOR_RESPONSE_MAX_LENGTH` | `280` | 受控文本响应允许的最大字符数；超出视为 malformed。 |
| `BABY_TALK_MENTOR_SIMULATE_TIMEOUT_TOKEN` | `[timeout]` | prompt 中包含该 token 时，dev provider 模拟 timeout。 |
| `BABY_TALK_MENTOR_SIMULATE_MALFORMED_TOKEN` | `[malformed]` | prompt 中包含该 token 时，dev provider 模拟 malformed response。 |
| `BABY_TALK_MENTOR_SIMULATE_UNAVAILABLE_TOKEN` | `[unavailable]` | prompt 中包含该 token 时，dev provider 模拟 provider unavailable。 |
| `BABY_TALK_MIN_SUPPORTED_VERSION` | `1.2.0` | 沿用现有 `X-App-Version` / `426 Upgrade Required` 合同。 |
| `BABY_TALK_UPGRADE_URL` | `https://example.com/baby-talk/download` | 426 响应头与响应体中的升级地址。 |

固定配置（当前写死在 `application.yml`，后续可再外提）：

- `allowed-surfaces = [home, discover, garden, growth, standalone_home]`
- `allowed-modes = [single_turn]`
- `blocked-keywords = [slap, hit, 体罚, 羞辱, 打宝宝]`

## HTTP Contract

### Request

`POST /api/v1/mentor/chat`

Headers:

- `X-App-Version: 1.2.0`（必需，沿用全局版本门禁）
- `X-Session-Id: sess_xxx`（可选；缺失时走匿名 installation 访问）

Body:

```json
{
  "installationId": "install-alpha",
  "prompt": "宝宝哭了我现在该怎么说？",
  "surface": "home",
  "mode": "single_turn",
  "correlationId": "mentor_demo_001",
  "contextSummary": "optional-redacted-context"
}
```

### Success Response

```json
{
  "correlationId": "mentor_demo_001",
  "responseText": "先把语速放慢，只说一句：\"I'm here with you.\" 抱近一点，停半拍，再描述你看到的感受。",
  "code": "ok",
  "phase": "response_delivered",
  "retryable": false,
  "fallbackUsed": false,
  "authenticated": false,
  "rateLimit": {
    "limited": false,
    "limit": 3,
    "remaining": 2,
    "windowSeconds": 600
  },
  "respondedAt": "2026-04-10T00:00:00Z"
}
```

### Blocked / Fallback Response

命中安全边界时仍返回 `200`，但 `code/phase` 稳定为 `blocked_fallback`：

```json
{
  "correlationId": "mentor_demo_002",
  "responseText": "我先不给出可能伤害宝宝或让关系变糟的做法。先把自己和宝宝都放到安全位置，只说一句：\"I'm here with you.\" 如果你担心安全，请先找身边的大人或专业支持。",
  "code": "blocked_fallback",
  "phase": "blocked_fallback",
  "retryable": false,
  "fallbackUsed": true,
  "authenticated": true,
  "rateLimit": {
    "limited": false,
    "limit": 3,
    "remaining": 2,
    "windowSeconds": 600
  },
  "respondedAt": "2026-04-10T00:00:00Z"
}
```

### Structured Error Shapes

所有服务内错误统一返回：

```json
{
  "timestamp": "2026-04-10T00:00:00Z",
  "status": 504,
  "code": "provider_timeout",
  "message": "小禾老师暂时没有来得及回应，请稍后再试。",
  "details": {
    "correlationId": "mentor_demo_003",
    "phase": "provider_timeout",
    "retryable": true,
    "rateLimited": false,
    "remaining": 2
  }
}
```

## Stable Failure Codes

| HTTP | `code` | `details.phase` | 何时出现 | Retryable |
|---|---|---|---|---|
| 400 | `missing_prompt` / `missing_installationId` / `invalid_surface` / `invalid_mode` / `prompt_too_long` / `invalid_installation_id` | 同 code | 输入非法 | 视情况而定（当前大多 false） |
| 401 | `invalid_session` | `invalid_session` | `X-Session-Id` 缺失对应 session 或已失效 | true |
| 403 | `consent_revoked` | `consent_revoked` | 提供的 session 已 revoked | true |
| 403 | `account_deleted` | `account_deleted` | 提供的 session/account 已 deleted | false |
| 403 | `session_installation_mismatch` | `session_installation_mismatch` | session 与 installationId 不匹配 | false |
| 426 | `app_version_required` / `app_version_unsupported` | N/A | 缺失或低于最低版本 | false |
| 429 | `mentor_rate_limited` | `rate_limited` | installation 窗口内请求过多 | true |
| 502 | `provider_malformed_response` | `provider_malformed_response` | provider/dev seam 返回空文本或 malformed | true |
| 503 | `provider_unavailable` | `provider_unavailable` | provider mode 未实现或显式 unavailable | true |
| 504 | `provider_timeout` | `provider_timeout` | provider/dev seam timeout | true |

## 审计与表结构

### `mentor_turns`

保存**成功或 fallback 的单次 turn**：

- `correlation_id`
- `installation_id`
- `session_id_hint` / `account_id_hint`（可空）
- `surface` / `mode`
- `result`（`success` / `fallback`）
- `phase`（`response_delivered` / `blocked_fallback`）
- `request_summary`（redacted）
- `response_summary`（redacted）
- `response_text`（受控最终文本，不是 raw provider body）
- `provider_mode`
- `blocked_fallback`
- `retryable`
- `created_at`

### `mentor_audit_logs`

保存**所有关键相位**：

- `chat_requested`
- `chat_response_delivered`
- `blocked_fallback`
- `provider_timeout`
- `provider_malformed_response`
- `provider_unavailable`
- `invalid_session`
- `consent_revoked`
- `account_deleted`
- `session_installation_mismatch`
- `rate_limited`

关键字段：

- `correlation_id`
- `phase`
- `result`（`accepted / success / fallback / error / rejected`）
- `failure_code`
- `retryable`
- `rate_limited`
- `reason`（redacted）
- `request_summary` / `response_summary`（redacted）

## Redaction Rules

绝不在 `mentor_turns` / `mentor_audit_logs` / visible error 中回显：

- raw prompt / raw provider response body
- 手机号、验证码
- `sess_*` / token / challenge secret
- 同意前宝宝档案字段

当前实现通过 request preview 规则进行最小 redaction：

- `1xxxxxxxxxx` → `[redacted-phone]`
- `sess_*` / `token_*` / `challenge_*` → `*_ [redacted]` 风格摘要
- 4-8 位纯数字验证码 → `[redacted-code]`
- `contextSummary` 只记录 `present/len`，不保存原文

## Curl Smoke

### 1) Anonymous happy path

```bash
curl -sS http://localhost:8080/api/v1/mentor/chat \
  -H 'Content-Type: application/json' \
  -H 'X-App-Version: 1.2.0' \
  -d '{
    "installationId":"install-alpha",
    "prompt":"宝宝哭了我现在该怎么说？",
    "surface":"home",
    "mode":"single_turn",
    "correlationId":"mentor_smoke_ok"
  }'
```

### 2) Blocked fallback

```bash
curl -sS http://localhost:8080/api/v1/mentor/chat \
  -H 'Content-Type: application/json' \
  -H 'X-App-Version: 1.2.0' \
  -d '{
    "installationId":"install-alpha",
    "prompt":"我想体罚他，怎么办？",
    "surface":"home",
    "mode":"single_turn",
    "correlationId":"mentor_smoke_blocked"
  }'
```

### 3) Simulate timeout

```bash
curl -sS http://localhost:8080/api/v1/mentor/chat \
  -H 'Content-Type: application/json' \
  -H 'X-App-Version: 1.2.0' \
  -d '{
    "installationId":"install-alpha",
    "prompt":"请给我一个建议 [timeout]",
    "surface":"home",
    "mode":"single_turn",
    "correlationId":"mentor_smoke_timeout"
  }'
```

### 4) With session

先走现有 S03 auth/verify 获取 `sessionId`，再调用：

```bash
curl -sS http://localhost:8080/api/v1/mentor/chat \
  -H 'Content-Type: application/json' \
  -H 'X-App-Version: 1.2.0' \
  -H 'X-Session-Id: sess_xxx' \
  -d '{
    "installationId":"install-alpha",
    "prompt":"宝宝不肯睡，我现在该怎么说？",
    "surface":"growth",
    "mode":"single_turn",
    "correlationId":"mentor_smoke_session"
  }'
```

## SQL Inspection

### 查最近一次成功 / fallback turn

```sql
select correlation_id,
       installation_id,
       result,
       phase,
       blocked_fallback,
       provider_mode,
       created_at,
       request_summary,
       response_summary
from mentor_turns
order by created_at desc;
```

### 查某次 correlation 的完整审计链

```sql
select correlation_id,
       event_type,
       phase,
       result,
       failure_code,
       retryable,
       rate_limited,
       reason,
       created_at
from mentor_audit_logs
where correlation_id = 'mentor_smoke_timeout'
order by audit_id asc;
```

### 查 installation 的 rate limit 窗口足迹

```sql
select installation_id,
       event_type,
       phase,
       result,
       rate_limited,
       created_at
from mentor_audit_logs
where installation_id = 'install-alpha'
order by created_at desc;
```

## 故障排查顺序

1. **先看 HTTP `code` / `details.phase`**
   - `provider_timeout` / `provider_malformed_response` / `mentor_rate_limited` / `invalid_session` / `consent_revoked` 能直接决定移动端 banner 与 retryability。
2. **再看 `correlationId` 对应 audit 链**
   - 确认是否出现 `chat_requested`，以及终态是 `chat_response_delivered`、`blocked_fallback`、`provider_timeout` 还是 `rate_limited`。
3. **成功 / fallback 时再看 `mentor_turns`**
   - 检查是否真正落了受控 response；若只有 audit 没有 turn，通常是错误路径而不是成功路径。
4. **确认是否是版本门禁**
   - 426 不会写 mentor audit；要看 `X-Min-Supported-Version` / `X-Upgrade-Url`。
5. **确认是否是 session 问题**
   - `invalid_session` / `consent_revoked` / `account_deleted` / `session_installation_mismatch` 都会写 mentor audit，但不会写 turn。
6. **确认是否是 rate limit**
   - 看 `mentor_audit_logs.rate_limited = true` 与 `failure_code = mentor_rate_limited`。

## Regression Proof

T03 交付后的最小 proof pack：

```bash
cd backend && mvn -q -Dtest=MentorServiceTest,MentorWebTest,AuthConsentSyncWebTest test
```

覆盖点：

- anonymous happy path
- valid session 关联
- blocked fallback
- invalid session 401
- revoked session 403
- version 426
- provider timeout / malformed
- installation rate limit
- 账号/同步回归 `AuthConsentSyncWebTest`
