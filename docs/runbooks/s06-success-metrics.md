# S06 Success Metrics

## 目标

给 M002/S03 提供一套**只基于现有表、现有 inspect surface 与当前 continuity UI key** 的最小成功阈值，用于判断 recent activity continuity → Mentor 本地辅导 → retention proof 是否成立。

本文件只允许复用：

- `interaction_events`
- `consent_audit_logs`
- `mentor_audit_logs`
- `mentor_turns`
- `inspect_interaction_events`
- `inspect_mentor_facts`

**不发明新的 analytics SDK、埋点服务、progress store 或 cohort 系统。**

---

## 1. 指标边界

### 1.1 SQL / inspect 能证明什么

- `interaction_events`：recent activity continuity、first-practice cohort、D1 / D7 / D30
- `consent_audit_logs`：practice 后 sign-in / consent accept 是否真的发生
- `mentor_audit_logs`：help request、timeout、rate limit、blocked_fallback 等审计轨迹
- `mentor_turns`：最终是否形成可交付的 success / fallback response
- `inspect_interaction_events`：单设备上的 continuity / sync 队列状态是否与 UI 一致
- `inspect_mentor_facts`：Mentor 的 `code / phase / correlationId / retryable / contextFallbackUsed` 是否与 UI 一致

### 1.2 SQL / inspect 不能证明什么

- 商店曝光 / 下载 / 安装漏斗
- 未产生任何 practice / auth / mentor 事实的静默流失
- 推送触达与渠道效果
- 原始 prompt / response 质量细节（这些也不允许在 proof 面回显）

因此这里的 activation / D1 / D7 / D30 / help usage 都是**基于已进入 first-practice cohort 的 continuity-first 样本**，不是全量下载漏斗。

---

## 2. 当前 continuity 合同

### 2.1 UI key 与 SQL 的映射

SQL 不直接看到 widget key，但它能证明 recent activity 所指向的 `activity_id`；UI 再把这个 `activity_id` 渲染成当前 surface：

- Home：`home-start-practice-<activityId>`
- Garden：`garden-continue-target-<activityId>`

当 `PracticeContinuityViewModel.reason == recentActivity` 时，这两个 key 的 `<activityId>` 应与 inspect / SQL 里最近一次 `interaction_events.activity_id` 对齐。

### 2.2 为什么这是 retention proof 的一部分

S03 要证明的不只是“留存指标存在”，还要证明：

1. recent activity 的事实真的落到了 append-only `interaction_events`
2. Home / Garden 的下一步推荐没有漂移
3. 后续 Account / Mentor 仍建立在同一条 continuity 链上

如果 SQL 看见最近 activity，但 Home / Garden key 不一致，这不是 retention 数据缺失，而是 continuity surface drift。

---

## 3. Cohort 定义

### 3.1 First-practice cohort

- 基准对象：`interaction_events` 中第一次出现事件的 `installation_id`
- cohort day：该 installation 的 `min(client_timestamp)` 所在日期
- 这是 `retained_rate_d1_pct` / D7 / D30 的统一分母

### 3.2 Activated-sync cohort

- 基准对象：在 first-practice 后 24h 内出现 `consent_audit_logs.action = 'accept'` 且 `result = 'applied'` 的 installation/account
- 用于衡量 practice → sign-in / consent / sync 是否真的发生

### 3.3 Mentor help cohort

- 基准对象：Activated-sync cohort 中，7 天内至少出现一次 `mentor_audit_logs.event_type = 'chat_requested'` 的 installation
- 用于衡量 help usage

---

## 4. 最小成功阈值

> 这些阈值是 demo / go-hold 观察线，不是长期经营 KPI。样本很小时只能做方向性判断。

| 指标 | 定义 | 最小阈值 | 说明 |
|---|---|---|---|
| activation（sync activation） | first-practice cohort 中，24h 内完成 consent accept 的占比 | **>= 35%** | 说明 practice 后愿意继续走登录/同步。 |
| D1 | first-practice cohort 在第 1~2 天窗口内再次产生 `interaction_events` 的占比 | **>= 25%** | 证明至少存在次日复访。 |
| D7 | first-practice cohort 在第 7~8 天窗口内再次产生 `interaction_events` 的占比 | **>= 10%** | 证明不是一次性演示。 |
| D30 | first-practice cohort 在第 30~31 天窗口内再次产生 `interaction_events` 的占比 | **>= 5%** | 样本成熟前可标记 `not-yet-matured`。 |
| help usage | Activated-sync cohort 中，7 天内至少一次 `chat_requested` 的占比 | **>= 15%** | 说明 Mentor 不是摆设。 |
| mentor delivery rate | mentor request 中最终写入 `mentor_turns`（`success` 或 `fallback`）的占比 | **>= 90%** | query 名称为 `mentor_delivery_rate_pct`。 |
| blocked fallback visibility | blocked 类求助都能在 UI / inspect / SQL 看见 `blocked_fallback` | **100% 可诊断** | 安全与可观察性阈值。 |

---

## 5. 指标解释口径

### 5.1 D1 / D7 / D30

- D1：first practice 后第 1~2 天窗口内再次出现 `interaction_events`
- D7：first practice 后第 7~8 天窗口内再次出现 `interaction_events`
- D30：first practice 后第 30~31 天窗口内再次出现 `interaction_events`

如果样本还没活到 D7 / D30：

- 标记为 `not-yet-matured`
- **不要**把缺样本误写成 retention failure

### 5.2 activation

这里的 activation 不是“下载并打开 app”，而是：

1. 用户至少做过一次 practice（已经进入 first-practice cohort）
2. 且在 24h 内完成 sign-in + consent accept

这能证明 continuity 不只停留在匿名试玩，而是继续进入 sync 链路。

### 5.3 help usage

这里的 help usage 不是简单看 UI 点击，而是 backend 真正收到：

- `mentor_audit_logs.event_type = 'chat_requested'`
- 且 installation 属于 Activated-sync cohort

如果只看 UI，不看 audit，很容易把 timeout / rate limit / blocked fallback / 无网状态误判为成功使用。

### 5.4 mentor delivery rate

下列情况都算 **有交付**：

- `mentor_turns.result = 'success'`
- `mentor_turns.result = 'fallback'`

下列情况都算 **未交付**：

- `provider_timeout`
- `provider_malformed_response`
- `provider_unavailable`
- `mentor_rate_limited`
- `invalid_session`
- `consent_revoked`
- `account_deleted`

### 5.5 blocked fallback visibility

`blocked_fallback` 不是“失败就算了”，而是必须同时满足：

1. UI 有明确 `code / phase / correlationId`
2. `inspect_mentor_facts` 能看到可交付 fact
3. SQL 能在 `mentor_turns` / `mentor_audit_logs` 中定位

如果只看到 audit failure，看不到 delivered fallback，就不算达标。

---

## 6. 样本量与边界条件

| 场景 | 解释 |
|---|---|
| fresh install 零历史 | inspect 显示 empty 属于正常；只有第一条 `interaction_events` 写入后才进入 cohort。 |
| 只做 practice 不登录 | 会进入 first-practice cohort，但不会进入 Activated-sync cohort。 |
| Home / Garden key 已有 activityId，但 inspect 没 recent activity | 优先怀疑 continuity UI drift 或 seed 错误，而不是 SQL retention 问题。 |
| Mentor 只有 blocked_fallback | 仍算 delivered；重点是是否可诊断。 |
| D1 / D7 / D30 暂无数据 | 标记 `not-yet-matured`，不要写成 0%。 |
| cohort 样本数 < 10 | 仅作方向性参考，不作为唯一 go / no-go 依据。 |

---

## 7. 与 inspect / runbook 的对应关系

### `inspect_interaction_events`

用于回答：

- recent activity 是否真的落地
- `pendingEvents / syncedEvents / failedEvents / lastSyncPhase` 是否与 UI 一致
- Home `home-start-practice-<activityId>` 与 Garden `garden-continue-target-<activityId>` 是否对应同一最近 activity

### `inspect_mentor_facts`

用于回答：

- Mentor 的 `code / phase / correlationId / retryable / contextFallbackUsed` 是否与 UI 一致
- blocked_fallback / timeout 是否都有明确本地事实，而不是只有一层 banner

### SQL query pack

用于回答：

- `retained_rate_d1_pct` / D7 / D30 是否达到阈值
- activation / help usage / `mentor_delivery_rate_pct` 是否达到阈值
- blocked_fallback 是否仍能在现有表中定位

统一入口：

- `backend/src/main/resources/sql/s06_success_queries.sql`
- `docs/runbooks/s06-demo-release.md`

---

## 8. 推荐判读顺序

1. 先看 runbook 里的 smoke / widget / integration proof 是否完成
2. 再看 inspect，确认单设备 continuity / Mentor local facts
3. 最后用 SQL 做 cohort 级 retention / mentor delivery 汇总

这样能先分清是：

- 单台设备 continuity surface 有漂移
- Mentor timeout / blocked fallback 可见性问题
- 还是 cohort 指标本身未达阈值

---

## 9. 红线

- 任何 activation / D1 / D7 / D30 / help usage / mentor delivery 指标，都**不能**绕过现有表去补手工统计。
- 任何截图、SQL 结果、inspect 输出都**不得**回显 raw prompt、raw response、手机号、验证码、session secret、同意前宝宝 PII。
- 若文档、runbook、query pack 与当前测试 surface 不一致，应优先修正文档或 query pack，**不要**发明新表或新 analytics 去补口径。
