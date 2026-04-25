# M006 / S10 Mentor Audit Incident Runbook

## Boundary

S10 的 admin mentor audit **不是完整 transcript**。

这一面只展示已经持久化、且对管理员 truthful 的 incident evidence：

- `correlation_id` 级别的单次 incident
- redacted `request_summary`
- 已实际交付给用户的 `response_text` / `response_summary`（若存在）
- `mentor_audit_logs` timeline
- 当前 live rate-limit snapshot

**不会展示：**

- 多轮会话 transcript
- raw prompt / raw provider payload
- token / session secret / 隐藏 PII
- 未持久化的 chat memory 或推断出来的上下文

如果未来真的要展示 transcript，必须先补一条可信的 `conversation_id` 持久化 bridge，再重开 D099。

## API surfaces

### Queue

`GET /api/admin/mentor/audits`

Query params:

- `installationId`（可选）
- `flag`（可选，见下方 taxonomy）
- `limit`（可选，默认 50）

返回的是 **flagged incidents only**，按最新 incident 时间倒序。

Queue item fields:

- `correlationId`
- `installationId`
- `flagCode`
- `latestPhase`
- `failureCode`
- `retryable`
- `historicalRateLimited`
- `occurredAt`

### Detail

`GET /api/admin/mentor/audits/{correlationId}`

返回的是 `scope = "incident_evidence"` 的 detail，而不是 transcript。

Detail fields:

- incident metadata：`flagCode` / `latestPhase` / `failureCode` / `retryable`
- `requestEvidence.summary`
- `deliveryState`
  - `delivered`：存在 `mentor_turns` 交付证据
  - `missing_turn`：这是一个 failure incident，只有 audit rows，没有 delivered turn
- `deliveredResponse`（仅 `deliveryState=delivered` 时存在）
- `timeline[]`：直接来自 `mentor_audit_logs`
- `liveRateLimit`：当前 installation 在 live window 内的请求计数

## Flag taxonomy

`flagCode` 是给 admin queue/filter 用的稳定分类，不等于原始 `failure_code`。

| `flagCode` | Derived from | Meaning |
|---|---|---|
| `blocked_fallback` | `phase=blocked_fallback` 或 `failure_code=blocked_fallback` | 命中安全边界，返回受控 fallback |
| `rate_limited` | `rate_limited=true` / `phase=rate_limited` / `failure_code=mentor_rate_limited` | 命中 installation 级 rate limit |
| `provider_timeout` | `failure_code=provider_timeout` | provider 超时 |
| `provider_malformed_response` | `failure_code=provider_malformed_response` | provider 返回 malformed |
| `provider_unavailable` | `failure_code=provider_unavailable` | provider 不可用 |
| `invalid_session` | `failure_code=invalid_session` | session 无效 |
| `consent_revoked` | `failure_code=consent_revoked` | consent 已撤回 |
| `account_deleted` | `failure_code=account_deleted` | 账号已删除 |
| `session_installation_mismatch` | `failure_code=session_installation_mismatch` | session 与 installation 不匹配 |
| `other_incident` | 其他非 success 终态 | 仍是 incident，但不在当前显式 taxonomy 内 |

## Historical `rateLimited` vs current live `rateLimit`

这两个信号含义不同，不能混用：

- `historicalRateLimited`
  - 来自 **该 correlation_id 的历史 audit rows**
  - 回答的是：**这次 incident 过去是否真的撞过 rate limit**
- `liveRateLimit`
  - 来自 **当前 installation 在 live window 内的 `chat_requested` count**
  - 回答的是：**如果现在再来一条请求，离上限还有多远**

因此：

- 一个老 incident 的 `historicalRateLimited=false`，但当前 `liveRateLimit.limited=true`，是完全合理的
- 一个 rate-limit incident 的 `historicalRateLimited=true`，但几分钟后再看 detail，当前 `liveRateLimit` 也可能已经恢复

## Correlation-based triage path

1. 从 queue 拿到 `correlationId` 与 `flagCode`
2. 打开 detail，先看：
   - `latestPhase`
   - `failureCode`
   - `deliveryState`
3. 再看 `timeline[]`，确认链路：
   - 是否有 `chat_requested`
   - 终态是 `blocked_fallback` / `rate_limited` / `provider_timeout` 等哪一类
4. 若 `deliveryState=delivered`，再看 `deliveredResponse.responseText`
5. 若怀疑当前 installation 仍然受限，再看 `liveRateLimit`

## SQL cross-check

### 1) 查某个 incident 的完整 audit 链

```sql
select correlation_id,
       event_type,
       phase,
       result,
       failure_code,
       retryable,
       rate_limited,
       request_summary,
       response_summary,
       reason,
       created_at
from mentor_audit_logs
where correlation_id = :correlation_id
order by audit_id asc;
```

### 2) 查 delivered turn（若存在）

```sql
select correlation_id,
       result,
       phase,
       request_summary,
       response_summary,
       response_text,
       provider_mode,
       blocked_fallback,
       retryable,
       created_at
from mentor_turns
where correlation_id = :correlation_id;
```

### 3) 查当前 installation 的 live window 计数

```sql
select count(*) as current_window_requests
from mentor_audit_logs
where installation_id = :installation_id
  and event_type = 'chat_requested'
  and created_at >= now() - interval '10 minute';
```

## Failure semantics

- unknown `correlationId`：`404 mentor_audit_not_found`
- non-auditor：admin session 有效但无 `mentor:audit` → `403 forbidden`
- disabled admin：稳定 `401 admin_account_disabled`
- missing delivered turn：detail 返回 `deliveryState = "missing_turn"`，不会伪造 transcript 或 response
- empty queue：`200 []`

## Follow-up explicitly deferred

- 真正的 `conversation_id` bridge
- transcript replay / multi-turn memory inspection
- UI 上跨 incident 聚合的 conversation drilldown

这些能力都不属于 S10；S10 只交付 truthful incident evidence。
