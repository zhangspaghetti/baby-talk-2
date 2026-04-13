# S06 Success Metrics

## 目标

给 M001/S06 提供一套**只基于现有表与 inspect surface** 的最小成功阈值，用于判断 Android-first demo 是否值得继续放大验证。

本文件只允许复用：

- `interaction_events`
- `consent_audit_logs`
- `mentor_audit_logs`
- `mentor_turns`
- `inspect_interaction_events`
- `inspect_mentor_facts`

**不发明新的 analytics SDK、埋点服务或 cohort 系统。**

---

## 1. 指标口径边界

### 1.1 可观察到什么

- `interaction_events`：practice、revisit、garden/growth 的底层事实来源
- `consent_audit_logs`：sign-in / consent 是否真的发生
- `mentor_audit_logs`：help request、rate limit、timeout、blocked_fallback、provider 异常
- `mentor_turns`：成功或 fallback 的最终可交付回应

### 1.2 观测不到什么

- 原始安装量 / 打开量
- 推送触达
- 商店曝光 / 下载转化
- 未产生任何 practice 或 auth/mentor 事实的静默流失

因此本文件的 activation / D1 / D7 / D30 / help usage 都是**基于已被系统观测到的 practice-first cohort**，不是全量商店漏斗。

---

## 2. Cohort 定义

### 2.1 First-practice cohort

- 基准对象：`interaction_events` 中第一次出现事件的 `installation_id`
- cohort day：该 installation 的 `min(client_timestamp)` 所在日期
- 这是 D1 / D7 / D30 的统一分母

### 2.2 Activated-sync cohort

- 基准对象：在 first-practice 之后 24h 内出现 `consent_audit_logs.action = 'accept'` 且 `result = 'applied'` 的 installation/account
- 用于衡量 demo 链路里“practice 后继续 sign-in sync”的激活程度

### 2.3 Mentor help cohort

- 基准对象：Activated-sync cohort 中，7 天内至少出现一次 `mentor_audit_logs.event_type = 'chat_requested'` 的 installation
- 用于衡量 help usage

---

## 3. 最小成功阈值（M001 demo 版）

> 这些阈值是 **go / hold** 观察线，不是长期经营 KPI。样本极小时只能作方向性判断。

| 指标 | 定义 | 最小阈值 | 说明 |
|---|---|---|---|
| activation（sync activation） | first-practice cohort 中，24h 内完成 consent accept 的占比 | **>= 35%** | 说明用户不只练一次，还愿意完成登录/同步。 |
| D1 | first-practice cohort 在第 1 天再次产生 `interaction_events` 的占比 | **>= 25%** | 证明至少存在次日复访。 |
| D7 | first-practice cohort 在第 7 天再次产生 `interaction_events` 的占比 | **>= 10%** | 证明不是“一次性演示”。 |
| D30 | first-practice cohort 在第 30 天再次产生 `interaction_events` 的占比 | **>= 5%** | 只在样本成熟后评估；早期可标记为 N/A。 |
| help usage | Activated-sync cohort 中，7 天内至少一次 `chat_requested` 的占比 | **>= 15%** | 说明 Mentor 对真实使用场景有吸引力。 |
| mentor delivery rate | mentor request 中最终写入 `mentor_turns`（success 或 fallback）的占比 | **>= 90%** | blocked_fallback 也算“有交付”，timeout/malformed/unavailable 不算。 |
| blocked fallback visibility | 所有 blocked 类求助都能在 `mentor_audit_logs` / UI 中看见 `blocked_fallback` | **100% 可诊断** | 这是安全与可观察性阈值，不是增长阈值。 |

---

## 4. 指标解释口径

### 4.1 D1 / D7 / D30

- D1：first practice 后第 1~2 天窗口内再次出现 `interaction_events`
- D7：first practice 后第 7~8 天窗口内再次出现 `interaction_events`
- D30：first practice 后第 30~31 天窗口内再次出现 `interaction_events`

若样本还没有活到 D7 / D30：

- 标记为 `not-yet-matured`
- **不要**把缺数据误写成留存失败

### 4.2 activation

这里的 activation 不是“下载并打开 app”，而是：

- 用户至少做过一次 practice（已进入 first-practice cohort）
- 并在 24h 内完成 sign-in + consent accept

理由：M001 需要证明 practice → sign-in sync 这条链路有真实价值，而不仅是匿名试玩。

### 4.3 help usage

这里的 help usage 不是简单看 UI 点击，而是看 backend 真实收到：

- `mentor_audit_logs.event_type = 'chat_requested'`
- 且 installation 属于 Activated-sync cohort

如果只看本地 UI 而不看 backend audit，容易把失败重试、blocked、timeout 或无网状态误判为成功使用。

### 4.4 mentor delivery rate

下列情况都算 **有交付**：

- `mentor_turns.result = 'success'`
- `mentor_turns.result = 'fallback'`

下列情况都算 **未交付**：

- `provider_timeout`
- `provider_malformed_response`
- `provider_unavailable`
- `mentor_rate_limited`
- `invalid_session` / `consent_revoked` / `account_deleted`

---

## 5. 样本量与边界条件

| 场景 | 解释 |
|---|---|
| fresh install 零历史 | inspect CLI 显示 empty 属于正常；只有完成第一条 `interaction_events` 后才进入 cohort。 |
| 只做 practice 不登录 | 会进入 first-practice cohort，但不会进入 Activated-sync cohort。 |
| 登录后 sync / mentor 都发生一次 | 这是本 slice 期望的最小有效样本。 |
| D1 / D7 / D30 暂无数据 | 标记为 `not-yet-matured`，不要写成 0%。 |
| cohort 样本数 < 10 | 仅作方向性参考，不作为 go / no-go 的唯一依据。 |

---

## 6. 与 inspect surface 的对应关系

### `inspect_interaction_events`

用于回答：

- practice 是否真的落本地
- sync phase / pending / failed / synced 是否符合 UI banner
- local event 与 backend cohort 不一致时，问题更像是客户端还是服务端

### `inspect_mentor_facts`

用于回答：

- Mentor 的 visible status / detail / phase / correlationId 是否与 UI 一致
- blocked_fallback / timeout / retryable / contextFallbackUsed 是否被正确暴露

### SQL query pack

用于回答：

- D1 / D7 / D30 是否达到最小阈值
- sync activation 是否达到阈值
- help usage 与 mentor delivery rate 是否达到阈值

统一入口：

- `backend/src/main/resources/sql/s06_success_queries.sql`

---

## 7. 推荐判读顺序

1. 先看 `docs/runbooks/s06-demo-release.md` 中 smoke 是否完成
2. 再用 `inspect_interaction_events` / `inspect_mentor_facts` 看单台设备事实
3. 最后用 SQL query pack 汇总 cohort 级判断

这样能先分清是单机问题、环境配置问题，还是全局 success threshold 未达标。

---

## 8. 红线

- 任何 D1 / D7 / D30、activation、help usage 指标，都**不能**绕过现有表去补写手工统计。
- SQL、截图、导出结果都**不得**回显手机号、验证码、session secret、同意前宝宝 PII、raw prompt 或 raw response。
- 若 backend 表结构与本文件不一致，应先修正文档或 query pack，**不要**发明新表来“补口径”。
