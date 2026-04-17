# S04 Caregiver Practice Runbook

## 目标

把 M003/S04 的 caregiver practice 闭环固定成一条未来 agent / 工程 / 运营都能在仓库根直接复跑的 root-safe 路径：

1. 被邀请的次照护者接受 invite 后进入真实 household member 关系
2. 次照护者通过既有 `/api/v1/sync/events` 写入真实 practice 事件
3. append-only `interaction_events` 继续作为真相源
4. `household_shared_context` 投影刷新，并暴露结构化 actor / next-step
5. mobile shared surfaces（Home / Garden / shell / Mentor）可读取共享 continuity 或稳定 fallback
6. invite download fallback 继续桥接到 S01 `/download?source=caregiver_invite`
7. root-safe `tool/verify_s04_caregiver_practice.dart`、SQL query pack 与既有 tests 能给出证据链

这份 runbook **只复用仓库里已存在的 backend controller / web test、mobile widget/repository test、`interaction_events` / `household_shared_context` / `caregiver_invite_events` / `release_distribution_events` 审计表，以及 S01 / S03 proof pack**；**不要求人工翻原始日志，也不扩展 installationId / sessionId / child name / raw payload / provider raw output 暴露面**。

---

## 0. Root-safe 入口

### 0.1 先跑 help，确认 S04 proof pack 完整

从仓库根执行：

```bash
dart run tool/verify_s04_caregiver_practice.dart --help
```

wrapper 会先检查以下 proof 文件：

- `docs/runbooks/s04-caregiver-practice.md`
- `backend/src/main/resources/sql/s04_caregiver_practice_queries.sql`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverPracticeAttributionWebTest.java`
- `mobile/test/features/mentor/mentor_repository_test.dart`
- `mobile/test/features/mentor/mentor_shell_panel_test.dart`
- `docs/runbooks/s03-caregiver-invite.md`
- `tool/verify_s03_invite.dart`
- `docs/runbooks/s01-release-distribution.md`
- `tool/verify_s01_distribution.dart`
- `backend/pom.xml`
- `mobile/pubspec.yaml`

缺任一文件时，wrapper 返回 **exit code 64** 并列出缺失路径。

### 0.2 可选 shared-context smoke

当你已经拿到一个有效 `sessionId`，可直接确认 projector 刷新后的 household shared context：

```bash
dart run tool/verify_s04_caregiver_practice.dart \
  --smoke \
  --route=shared-context \
  --base-url=http://127.0.0.1:8080 \
  --session-id=session_1234 \
  --expect-status=200 \
  --expect-space-id=sleep_support \
  --expect-activity-id=bedtime_story \
  --expect-actor-role=caregiver \
  --expect-next-step-activity-id=bath_time
```

这个 smoke 会验证：

- `/api/v1/household/shared-context` 可达
- `snapshot.practice.spaceId/activityId` 存在
- `snapshot.actor.role` 存在
- `snapshot.nextStep.activityId` 存在
- 响应体里没有 `installationId` / `sessionId` / `rawPayload`

### 0.3 可选 invite download fallback smoke

如果需要证明 S04 仍然落在真实 public distribution surface，而不是绕开 S01：

```bash
dart run tool/verify_s04_caregiver_practice.dart \
  --smoke \
  --route=invite-download \
  --base-url=http://127.0.0.1:8080 \
  --token=invite_token_1234 \
  --platform=android \
  --expect-status=302 \
  --expect-result=download_fallback \
  --expect-location-contains="/download?source=caregiver_invite"
```

若 smoke 失败：

- 缺 `--base-url` / `--session-id` / `--token` 或参数非法：**64**
- backend 未启动 / 连接失败：非零退出，并提示先执行 `mvn -f backend/pom.xml spring-boot:run`
- 请求超时：**124**，并提示确认 backend、session/token、projection 是否可用

---

## 1. 当前 runtime / proof surface

### 1.1 Append-only truth source

| Surface | 期望 | 当前 proof |
|---|---|---|
| `POST /api/v1/sync/events` | 次照护者 practice 继续只写 `interaction_events` | `CaregiverPracticeAttributionWebTest` |
| `interaction_events` | 仍是原始事实，不回写 projection | SQL query pack |
| `household_shared_context` | 只保存 household 级投影，带结构化 actor / next-step | `CaregiverPracticeAttributionWebTest` + SQL |

### 1.2 Shared surfaces

| Surface | 期望 | 当前 proof |
|---|---|---|
| Home / Garden / shell | 共享 continuity 可见，next-step 缺失时停在安全禁用态 | `mobile/test/features/practice/garden_growth_home_test.dart` / `garden_growth_shell_test.dart` / `shell/household_shared_context_test.dart` |
| Mentor repository | 本地 continuity 缺口或 shared projection 更近时采用 shared caregiver context；否则留在本地建议 | `mobile/test/features/mentor/mentor_repository_test.dart` |
| Mentor panel | 明确显示 shared continuity adopted / skipped 的 headline、detail、code | `mobile/test/features/mentor/mentor_shell_panel_test.dart` |

### 1.3 Invite / distribution bridge

| Surface | 期望 | 当前 proof |
|---|---|---|
| `caregiver_invite_events(entrypoint=download)` | 记录 invite download fallback | `docs/runbooks/s03-caregiver-invite.md` + SQL |
| `release_distribution_events(source=caregiver_invite)` | 继续承接 S01 public distribution surface | `docs/runbooks/s01-release-distribution.md` + SQL |
| `tool/verify_s03_invite.dart` / `tool/verify_s01_distribution.dart` | 可独立复跑 invite / distribution 两段 evidence | S03 / S01 wrapper |

---

## 2. 推荐排查顺序

严格按这个顺序，不要跳步：

1. **先看哪个 surface 出问题**
   - practice sync 没落入 `interaction_events`？
   - projection 没刷新？
   - Home / Garden / shell / Mentor 哪个 surface 只剩 fallback？
   - invite download fallback 是否还接到 S01？
2. **先跑 wrapper help / smoke**
   - `dart run tool/verify_s04_caregiver_practice.dart --help`
   - 需要时补 `--route=shared-context` 或 `--route=invite-download`
3. **再跑 proof tests**
   - `mvn -q -f backend/pom.xml -Dtest=CaregiverPracticeAttributionWebTest,CaregiverInviteApiWebTest test`
   - `cd mobile && flutter test test/features/shell/household_shared_context_test.dart test/features/practice/garden_growth_home_test.dart test/features/practice/garden_growth_shell_test.dart test/features/mentor/mentor_repository_test.dart test/features/mentor/mentor_shell_panel_test.dart`
4. **最后再看 SQL query pack**
   - 先看 `interaction_events` / household 聚合
   - 再看 `household_shared_context`
   - 再看 projection freshness / contract gaps
   - 最后看 invite download ↔ distribution bridge

这样可以先分清：

- practice 真相源没写进去
- practice 写进去了，但 projector stale / missing
- projector 在，但 actor / next-step malformed
- shared surfaces 在，但 Mentor 仍因本地 continuity 更近而安全跳过
- invite download fallback 已经断开 S01 public distribution

---

## 3. SQL proof pack

统一入口：

- `backend/src/main/resources/sql/s04_caregiver_practice_queries.sql`

推荐查询顺序：

1. 最近 `interaction_events` role-level 事件明细
2. household 级 practice 概览（证明 append-only truth source 仍在）
3. `household_shared_context` 当前投影
4. projection freshness 审计（`projection_missing` / `projection_stale` / `projection_in_sync`）
5. projection contract gaps（`actor_missing` / `actor_unknown` / `next_step_missing` / `contract_ready`）
6. caregiver invite 审计漏斗
7. 单 token 时间线
8. `release_distribution_events(source=caregiver_invite)` bridge 对照

通过标准：

- `interaction_events` 能显示 role-level actor + activity + reaction 的最近事实
- `household_shared_context` 能显示结构化 actor / next-step 与 `latest_interaction_at` / `updated_at`
- freshness 查询能区分 projection 是否 stale
- SQL 输出不展示 child name、installationId、sessionId、raw payload

---

## 4. Failure matrix

| 症状 | 先看哪里 | 应看到的明确 surface | 不应出现的坏结果 |
|---|---|---|---|
| sync 后看不到 shared continuity | shared-context smoke + freshness SQL | `projection_stale` / `projection_missing` / `shared_context_unavailable` | 只能猜“也许没同步成功” |
| Mentor 只给本地建议 | mentor tests / panel UI / shared status card | `shared_context_skipped_local_newer` / `shared_actor_unknown` / `shared_next_step_missing` 等明确 code | 面板空白或解析 summary 文本 |
| shared actor / next-step malformed | contract gaps SQL + mentor repository test | `actor_missing` / `actor_unknown` / `next_step_missing` | 把 malformed summary 拼进建议文案 |
| projection 刷新比 practice 旧 | freshness SQL | `projection_stale` | 只有 `updated_at` 模糊变化，没有结论 |
| invite download fallback 没接上 S01 | invite-download smoke + bridge SQL | `Location` 包含 `/download?source=caregiver_invite`，distribution 表出现 `source=caregiver_invite` | 重新造一套下载入口 |
| household snapshot 读失败 | mentor repository test / panel shared status | `shared_snapshot_unavailable` / `shared_snapshot_malformed` | Mentor 崩溃或 suggestion tab 空白 |

---

## 5. Redaction 红线

允许输出：

- `entrypoint` / `source` / `platform` / `result` / `failure_reason`
- `space_id` / `activity_id` / `next_step_*`
- `latest_actor_role` / `latest_actor_source` / `latest_actor_result`
- `latest_interaction_at` / `updated_at`
- role-level actor labels（主照护者 / 次照护者）
- `Location` 是否包含 `/download?source=caregiver_invite`

禁止输出：

- child / 宝宝姓名
- `installationId`
- `sessionId`
- 原始 interaction payload
- provider raw output
- 原始 `continuitySummary` / `gardenSummary` 的解析式扩展
- 把 `summary` 文本 regex 成 actor / next-step

如果 runbook、wrapper、SQL 或 UI 里出现这些内容，先修 redaction，再继续排查。

---

## 6. 最小复跑清单

```bash
dart run tool/verify_s04_caregiver_practice.dart --help

mvn -q -f backend/pom.xml -Dtest=CaregiverPracticeAttributionWebTest,CaregiverInviteApiWebTest test

cd mobile && flutter test \
  test/features/shell/household_shared_context_test.dart \
  test/features/practice/garden_growth_home_test.dart \
  test/features/practice/garden_growth_shell_test.dart \
  test/features/mentor/mentor_repository_test.dart \
  test/features/mentor/mentor_shell_panel_test.dart

test -s docs/runbooks/s04-caregiver-practice.md && \
  test -s backend/src/main/resources/sql/s04_caregiver_practice_queries.sql
```

可选补充：

```bash
dart run tool/verify_s04_caregiver_practice.dart \
  --smoke \
  --route=shared-context \
  --base-url=http://127.0.0.1:8080 \
  --session-id=session_1234

dart run tool/verify_s04_caregiver_practice.dart \
  --smoke \
  --route=invite-download \
  --base-url=http://127.0.0.1:8080 \
  --token=invite_token_1234 \
  --platform=android
```

通过标准：

- proof pack 文件存在且 help 可读
- backend / mobile tests 覆盖 practice → projection → shared surfaces → Mentor
- SQL 能回答 stale projection、malformed contract、invite/distribution bridge
- 不需要翻原始日志也能定位“谁刚做了什么、下一步是什么、为什么现在只剩 fallback”
