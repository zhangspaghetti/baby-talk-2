# S06 Continuity / Mentor / Retention Proof Pack Runbook

## 目标

把 M002/S03 的 final-assembly 验证链固定成一条未来 agent 可直接复跑的仓库内路径：

1. cold boot / recent activity continuity
2. Home / Garden / Mentor 下一步一致性
3. Mentor 本地辅导与 timeout / blocked fallback 可见性
4. inspect triage
5. SQL retention / mentor delivery proof

这份 runbook **只复用现有 append-only events、mentor fact log、inspect wrapper、测试与 SQL query pack**；**不新增 progress store、analytics、埋点服务或新留存系统**。

---

## 0. Root-safe 入口

### 0.1 一条 proof pack 入口

从仓库根执行：

```bash
dart run tool/verify_s06.dart --inspect
dart run tool/verify_s06.dart --integration
```

含义：

- `--inspect`：顺序代理 root-safe inspect wrappers
  - `dart run tool/inspect_interaction_events.dart --help`
  - `dart run tool/inspect_mentor_facts.dart --help`
- `--integration`：顺序代理当前 S03 proof tests
  - `mobile/test/smoke/app_boot_test.dart`
  - `mobile/test/features/mentor/mentor_shell_panel_test.dart`
  - `mobile/integration_test/s06_full_chain_release_flow_test.dart`
- 不带参数：同时执行两组 proof。

### 0.2 失败合同

- 缺失 `mobile/`、缺失 root wrapper、缺失 `mobile/tool/*`、缺失测试文件：wrapper 返回 **exit code 64**。
- 任一步测试失败：wrapper 返回对应非零 exit code，并打印 **失败 step label**。
- 任一步超时：wrapper 终止该 step，并返回 **124**。

---

## 1. 当前 runtime / UI proof surface

未来排查 S03 问题时，先对齐这些 surface，再决定看 inspect 还是 SQL。

### 1.1 Continuity / Home / Garden

| Surface | 期望 | 当前定位方式 |
|---|---|---|
| `PracticeContinuityViewModel.status` | 有明确 ready / disabled / timeout 等状态 | Home / Garden debug 文案与测试断言 |
| `PracticeContinuityViewModel.lastRefreshReason` | cold boot / account runtime 变更后有明确 refresh reason | `app_boot_test.dart` / Home-Garden 行为 |
| `PracticeContinuityViewModel.disabledReason` | continuity timeout / bad args / provider 缺失时给出明确禁用原因 | Home / Garden disabled state |
| Home 下一步 CTA | `home-start-practice-<activityId>` | Home 测试与 UI key |
| Garden 下一步 CTA | `garden-continue-target-<activityId>` | Garden 测试与 UI key |
| `GardenGrowthViewModel.status` / `message` | growth 有明确 ready / disabled / message | Garden / Growth runtime 文案 |

### 1.2 Account / Mentor / Boot gate

| Surface | 期望 | 当前定位方式 |
|---|---|---|
| `AccountViewModel.runtimeChangeToken` | account runtime 变更可驱动 continuity / account 刷新 | Home / Account 联动 |
| `AccountViewModel.submissionMessage` | sync / sign-in / refresh 失败不能静默 | Account banner / 文案 |
| Mentor banner `code / phase / correlationId` | timeout / blocked_fallback / unavailable 都有明确 banner | `mentor_shell_panel_test.dart` / `s06_full_chain_release_flow_test.dart` |
| boot route gate key | `boot-route-gate-ready` / `boot-route-gate-failed` 明确 | `app_boot_test.dart` / integration boot failure |

---

## 2. 推荐排查顺序

严格按这个顺序，不要跳步：

1. **先看测试 / UI surface**：判断是 continuity、boot gate、account sync，还是 Mentor 失败面。
2. **再看 inspect wrappers**：判断本地 append-only facts 是否存在、是否 redacted、是否与 UI 一致。
3. **再看 SQL query pack**：判断 retention / help usage / mentor delivery 指标是否成立。
4. **最后再看环境或回归**：重跑 proof tests，区分代码回归与本机 toolchain / backend 环境问题。

这样可以先分清：

- 单机本地事实缺失
- UI/route gate 回归
- Mentor delivery 失败
- retention / query drift
- 还是纯环境阻塞

---

## 3. Proof pack 顺序

### 3.1 Smoke：cold boot / continuity 基线

```bash
cd mobile && flutter test test/smoke/app_boot_test.dart
```

覆盖点：

- fresh install 进入 onboarding，而不是直接 guest home
- completed snapshot 存在时 cold boot 进入 shell
- recent activity 会 seed continuity recommendation
- Garden 能展示 `garden-continue-target-<activityId>`
- malformed snapshot / 目录失败时进入 `boot-route-gate-failed`

重点断言：

- `boot-route-gate-ready`
- `boot-route-gate-failed`
- `garden-continue-target-feeding_time`
- `PracticeContinuityViewModel.lastRefreshReason == 'boot_seed_recent_activity'`

### 3.2 Widget：Mentor shell / local fallback surface

```bash
cd mobile && flutter test test/features/mentor/mentor_shell_panel_test.dart
```

覆盖点：

- shell / standalone home 都能打开同一 Mentor 面板
- 离线或 onboarding 缺失时仍有本地建议，不出现空白面板
- chat tab 可见 retry / phase / first-note 等失败 surface
- 面板打开、求助提交、回应交付会落本地 mentor facts

重点断言：

- `mentor-panel-banner`
- `mentor-chat-phase-chip`
- `mentor-chat-retry-button`
- `MentorFactType.panelOpened`
- `MentorFactType.chatRequested`
- `MentorFactType.chatResponseDelivered`

### 3.3 Integration：full chain continuity → sync → Mentor

```bash
cd mobile && flutter test integration_test/s06_full_chain_release_flow_test.dart \
  --dart-define=BABY_TALK_API_BASE_URL=http://127.0.0.1:18080 \
  --dart-define=BABY_TALK_API_VERSION=1.2.0
```

覆盖点：

- onboarding → starter practice → Garden / Growth
- sign-in / sync 后 recent result 与 account 状态一致
- Mentor blocked prompt 时展示 `blocked_fallback`
- timeout 时展示 `code · timeout` / `phase · provider_timeout`
- integration 结束后 inspect 读到同一 installation 的 mentor facts / sync facts

重点断言：

- `blocked_fallback`
- `phase · blocked_fallback`
- `fallback · yes`
- `correlationId`
- `boot-route-gate-failed`
- `provider_timeout`

---

## 4. Inspect triage

### 4.1 Root-safe help

从仓库根执行：

```bash
dart run tool/inspect_interaction_events.dart --help
dart run tool/inspect_mentor_facts.dart --help
```

这两个 wrapper 只负责代理到 `mobile/tool/*`，不会要求你手动 `cd mobile` 才能发现入口是否存在。

### 4.2 Interaction events：continuity / sync triage

```bash
cd mobile && dart run tool/inspect_interaction_events.dart \
  --directory <absolute-app-support-dir> \
  --limit 20
```

先看这些字段：

- `pendingEvents`
- `syncedEvents`
- `failedEvents`
- `lastSyncPhase`
- `lastSyncAt`
- `lastSyncError`
- 最近事件的 `activityId / phraseId / reactionType / syncState`

判读方式：

- Home 的 `home-start-practice-<activityId>` 与 Garden 的 `garden-continue-target-<activityId>` 应该能映射回 inspect 里最近的 `activityId`。
- 如果 UI 有 continuity 卡片，但 inspect 没有 recent activity，优先怀疑 UI seed / route gating 回归。
- 如果 inspect 有 recent activity，但 Home / Garden 没有对应 CTA，优先怀疑 continuity refresh / disabledReason / bad args。

### 4.3 Mentor facts：timeout / blocked fallback triage

```bash
cd mobile && dart run tool/inspect_mentor_facts.dart \
  --directory <absolute-app-support-dir> \
  --limit 20
```

先看这些字段：

- `eventType`
- `phase`
- `correlationId`
- `visibleStatus`
- `visibleDetail`
- `retryable`
- `contextFallbackUsed`

判读方式：

- `blocked_fallback`：应看到可交付 fact，而不是只有失败日志。
- `provider_timeout`：应看到 `retryable=true` 与可见 timeout surface，而不是聊天 UI 空白挂住。
- `correlationId`：UI banner、inspect facts、backend audit 应能串起来。

---

## 5. SQL proof pack

统一入口：

- `docs/runbooks/s06-success-metrics.md`
- `backend/src/main/resources/sql/s06_success_queries.sql`

### 5.1 SQL 关注面

| 表 / 查询 | 用来回答什么 |
|---|---|
| `interaction_events` | recent activity continuity、first-practice cohort、D1 / D7 / D30 |
| `consent_audit_logs` | activation（practice 后 24h 内 accept/applied） |
| `mentor_audit_logs` | chat_requested、timeout、rate_limited、blocked_fallback 相关审计 |
| `mentor_turns` | success / fallback 是否真的形成可交付回应 |
| `retained_rate_d1_pct` | D1 retention 聚合结果 |
| `mentor_delivery_rate_pct` | mentor request → delivered 的聚合结果 |

### 5.2 先看 continuity，再看 retention

推荐顺序：

1. 先看 SQL 里的 recent continuity query，确认 installation 最近一次 `activity_id`
2. 再比对 inspect / UI key：
   - `home-start-practice-<activityId>`
   - `garden-continue-target-<activityId>`
3. 最后再看 cohort 级 retention / mentor delivery 指标

这样可以避免把“单台设备 continuity 没对齐”误当成“全局留存差”。

---

## 6. Failure surface 对照表

| 症状 | 先看哪里 | 应看到的明确 surface | 不应出现的坏结果 |
|---|---|---|---|
| continuity timeout | Home / Garden + inspect | `disabledReason`、continuity status、明确 message | 空白 CTA / 无提示 |
| continuity bad args | Home / Garden + smoke test | disabled state + reason code | 点击后错误导航 |
| boot route gate failure | cold boot smoke / integration | `boot-route-gate-failed` + retry | 直接跳错页面 |
| account/provider timeout | Account banner / inspect | `submissionMessage` 或 sync error | 静默失败 |
| Mentor timeout | Mentor banner / inspect | `code · timeout`、`phase · provider_timeout`、retryable | chat flow hang 住 |
| blocked fallback | Mentor banner / inspect / SQL | `blocked_fallback`、`correlationId`、fallback delivered | 只有失败，没有可见建议 |
| inspect wrapper 缺失 | `dart run tool/verify_s06.dart --inspect` | exit code 64 + 明确缺失路径 | 静默成功 |

---

## 7. Redaction 红线

所有 proof surface 继续只允许输出 **redacted diagnostics**：

- 禁止回显 raw prompt
- 禁止回显 raw response
- 禁止回显手机号 / 验证码
- 禁止回显 session secret / token
- 禁止回显同意前宝宝 PII

允许输出的只有：

- `activityId / phraseId / reactionType / syncState`
- `code / phase / correlationId`
- `visibleStatus / visibleDetail`
- 聚合 retention / mentor delivery 指标

如果截图、SQL 导出、inspect 文本里出现未脱敏原文，先修 redaction，再继续 proof。

---

## 8. 最小复跑清单

### 8.1 Root-safe proof

```bash
dart run tool/verify_s06.dart --inspect
dart run tool/verify_s06.dart --integration
```

### 8.2 文档 / SQL 对齐检查

```bash
rg -n "app_boot_test|mentor_shell_panel_test|s06_full_chain_release_flow_test|home-start-practice-|garden-continue-target-|blocked_fallback|mentor_delivery_rate_pct|retained_rate_d1_pct" \
  tool/verify_s06.dart \
  docs/runbooks/s06-demo-release.md \
  docs/runbooks/s06-success-metrics.md \
  backend/src/main/resources/sql/s06_success_queries.sql
```

通过标准：

- root-safe wrapper 能找到 inspect 入口与 smoke/widget/integration 入口
- runbook 明确指出 current continuity surface 与 Mentor failure surface
- success metrics 与 SQL query pack 仍只依赖现有表
- 不再引用旧 generic key、旧流程或新 analytics 假设
