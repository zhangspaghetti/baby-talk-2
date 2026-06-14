# S02 Growth Share Runbook

## 目标

把 M003/S02 已落地的成长分享闭环固定成一条未来 agent / 运营 / 工程都能直接复跑的仓库内路径：

1. `POST /api/v1/share-links` 创建脱敏分享卡片
2. `GET /share/{token}` 公共落地页与 OG 预览
3. `GET /share/{token}/open-app` 受控 open-app redirect
4. `GET /share/{token}/download` 受控下载 fallback，并串到 S01 `/download?source=share_card`
5. `share_landing_events` + `release_distribution_events(source=share_card)` 查询口径
6. root-safe `tool/verify_s02_share.dart` 文件检查与 smoke 入口

这份 runbook **只复用现有 Spring Boot public share routes、`share_landing_events` / `release_distribution_events` 审计表、`ShareLinkApiWebTest`、`ShareLandingWebTest`、mobile share / re-entry tests 和 SQL query pack**；**不新增 analytics SDK，不补写 installation / account / child 维度，也不要求人工翻原始日志才能回答“哪个 source / platform / result / failure reason 出问题了”。**

---

## 0. Root-safe 入口

### 0.1 先跑 help，确认 proof pack 入口存在

从仓库根执行：

```bash
dart run tool/verify_s02_share.dart --help
```

这个 wrapper 会先检查以下 proof 文件是否存在：

- `docs/runbooks/s02-growth-share.md`
- `backend/src/main/resources/sql/s02_share_landing_queries.sql`
- `backend/src/main/resources/db/migration/V6__create_share_landing_tables.sql`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/ShareLinkApiWebTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/ShareLandingWebTest.java`
- `mobile/test/app/share_reentry_coordinator_test.dart`
- `backend/pom.xml`
- `mobile/pubspec.yaml`

缺任一文件时，wrapper 返回 **exit code 64** 并逐项列出缺失路径。

### 0.2 可选 public share smoke

本地 backend 已启动后，可从仓库根执行 landing smoke：

```bash
dart run tool/verify_s02_share.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --token=share_token_1234 \
  --route=landing \
  --expect-status=200 \
  --expect-result=page_view \
  --expect-body="Baby Talk"
```

验证 open-app redirect：

```bash
dart run tool/verify_s02_share.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --token=share_token_1234 \
  --route=open-app \
  --platform=android \
  --expect-status=302 \
  --expect-result=open_app_redirect \
  --expect-location-contains="babytalk://share/open"
```

验证 download fallback 与 `source=share_card`：

```bash
dart run tool/verify_s02_share.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --token=share_token_1234 \
  --route=download \
  --platform=android \
  --expect-status=302 \
  --expect-result=download_fallback \
  --expect-location-contains="/download?source=share_card"
```

若 smoke 失败：

- **缺 `--base-url` / `--token` 或参数非法**：wrapper 返回 **64**，不静默降级
- **backend 未启动 / 连接失败**：wrapper 返回非零，并提示先执行 `mvn -f backend/pom.xml spring-boot:run`
- **请求超时**：wrapper 返回 **124**，并提示确认 backend、`--base-url`、`--token` 与平台参数是否可达

---

## 1. 当前 runtime / proof surface

未来排查 S02 问题时，先对齐这些 surface，再决定看 SQL、复跑 smoke，还是跑 web / mobile tests。

### 1.1 Public share routes

| Surface | 期望 | 当前定位方式 |
|---|---|---|
| `POST /api/v1/share-links` | 创建 tokenized public URL，并且只持久化 redacted frozen snapshot | `ShareLinkApiWebTest` |
| `GET /share/{token}` | 暖纸风格 landing 可访问，返回 OG meta、结果 header、错误态 HTML | `ShareLandingWebTest` + smoke |
| `GET /share/{token}/open-app` | 只跳到配置驱动的 `babytalk://share/open` 安全 target，不允许 open redirect | `ShareLandingWebTest` + smoke |
| `GET /share/{token}/download` | 只跳到 S01 `/download?source=share_card` 受控 fallback | `ShareLandingWebTest` + smoke |
| `X-Share-Landing-Result` | 显式返回 `create` / `page_view` / `open_app_redirect` / `download_fallback` / `invalid` / `expired` / `unavailable` | controller 响应头、wrapper smoke 输出 |
| `X-Share-Landing-Audit` | 显式返回 `recorded` / `failed`，说明审计是否成功写入 | controller 响应头、wrapper smoke 输出 |
| `X-Share-Landing-Failure-Reason` | 显式返回 coarse-grained failure reason，例如 `token_not_found` / `token_expired` / `platform_target_missing` | controller 响应头、SQL 查询 |

### 1.2 App 内 share / re-entry proof

| Surface | 期望 | 当前定位方式 |
|---|---|---|
| Home / Garden share CTA | loading / disabled / error 都是可见状态，不把 debug 文案暴露给用户 | `mobile/test/features/practice/garden_growth_home_test.dart` / `garden_growth_shell_test.dart` |
| share repository / view model | 只消费 growth / continuity snapshot truth source，并显式映射 create / share sheet failure | `mobile/test/features/share/share_repository_test.dart` / `share_view_model_test.dart` |
| share re-entry parser / coordinator | 合法 share link 回到既有 `PracticeRouteArgs` seam；非法 link 只回 shell fallback | `mobile/test/app/share_reentry_coordinator_test.dart` |

---

## 2. share / fallback 参数与结果合同

### 2.1 create surface

`POST /api/v1/share-links`

稳定输入语义：

- `source`: `latest_impact` / `continuity_recommendation` / `paired_progress`
- `platformHint`: 可选，`android` / `ios`
- `headline` / `storyText`：脱敏摘要
- `phraseText` / `phraseTranslation`：可选 phrase surface
- `recommendationTitle` / `recommendationReason`：可选 continuity surface
- `spaceId` / `activityId`：仅安全 route seam

create 成功后，`share_landing_events` 会写一条：

- `entrypoint=create`
- `result=create`
- `platform=<platformHint 或 null>`

### 2.2 landing surface

`GET /share/{token}`

返回：

- 暖纸风格 HTML（430px max width）
- OG meta (`og:title`, `og:description`)
- 可见 CTA：open app / download fallback
- headers：
  - `X-Share-Landing-Result`
  - `X-Share-Landing-Audit`
  - `X-Share-Landing-Failure-Reason`

典型结果：

- `page_view`
- `invalid` + `token_blank` / `token_malformed` / `token_not_found`
- `expired` + `token_expired`
- `unavailable` + `open_app_unconfigured` / `storage_unavailable`

### 2.3 open-app redirect

`GET /share/{token}/open-app?platform=android|ios`

行为约束：

- 只允许跳到配置里的 `babytalk://share/open`
- 只允许附带安全 query：`token` / `spaceId` / `activityId`
- 平台不合法时返回可见失败页，不做任意 redirect

典型结果：

- `open_app_redirect`
- `invalid` + `unknown_platform`
- `expired` + `token_expired`
- `unavailable` + `platform_unresolved` / `platform_target_missing`

### 2.4 download fallback

`GET /share/{token}/download?platform=android|ios`

行为约束：

- 只允许受控跳到 `/download?source=share_card`
- 不能透传任意外链
- share 与 release 两套审计必须连通

典型结果：

- `download_fallback`
- `invalid` + `unknown_platform`
- `expired` + `token_expired`
- `unavailable` + `download_fallback_unconfigured`

---

## 3. 当前审计表能回答什么

### 3.1 `share_landing_events`

稳定字段：

- `token`
- `source`
- `entrypoint`
- `platform`
- `result`
- `failure_reason`
- `created_at`

它能回答：

- 哪个 `source` 创建最多 share
- landing / open-app / download 哪个环节失败最多
- 哪个平台更常命中 `platform_target_missing` / `platform_unresolved`
- `invalid` / `expired` / `unavailable` 是否在增长
- 同一 token 在 landing / open-app / download 上的事件时间线

### 3.2 `release_distribution_events(source=share_card)`

稳定字段：

- `entrypoint`
- `release_channel`
- `source`
- `platform`
- `result`
- `failure_reason`
- `created_at`

它能回答：

- share download fallback 之后是否真的进入 S01 public distribution surface
- `share_card` 在 release fallback 上命中了 `page_view` / `redirect` / `unavailable` 哪些结果
- Android / iOS 哪个平台更常在 release fallback 侧失败

### 3.3 当前 redaction 边界下回答不了什么

当前 schema **故意不存 installation / account / child / session**。这不是缺口，而是 redaction 红线。它不能回答：

- 某个 account / installation 的完整回流链路
- 某个 child 的内容轨迹
- 原始 user agent、debug 文案、内部 fallback reason 对应的原始上下文

如果需要跨 share 与 release 两套 surface 做关联，当前允许的方法只有：

1. 以 `platform + source=share_card + created_at 时间窗` 做 coarse-grained 对照
2. 先复跑固定 smoke / tests，再用 SQL 比较异常前后的聚合变化

**不要**为了一次排查临时补写 PII 列，也不要把 debug 文案塞进 HTML / OG / query pack 输出。

---

## 4. 推荐排查顺序

严格按这个顺序，不要跳步：

1. **先看用户所在 surface**
   - 是 create 失败、landing 失败、open-app 不工作，还是 download fallback 没接上？
   - `X-Share-Landing-Result` / `X-Share-Landing-Audit` / `X-Share-Landing-Failure-Reason` 是什么？
2. **再跑 root-safe wrapper**
   - `dart run tool/verify_s02_share.dart --help`
   - 必要时加 `--smoke --base-url=... --token=...`
3. **再跑 contract proof tests**
   - `mvn -q -f backend/pom.xml -Dtest=ShareLinkApiWebTest,ShareLandingWebTest test`
   - `cd mobile && flutter test test/features/share/share_repository_test.dart test/features/share/share_view_model_test.dart test/features/practice/garden_growth_home_test.dart test/features/practice/garden_growth_shell_test.dart test/app/share_reentry_coordinator_test.dart`
4. **最后看 SQL query pack**
   - 先看 share 侧 result/failure 聚合
   - 再看 `release_distribution_events(source=share_card)`
   - 最后只在必要时做 platform + 时间窗 bridge 对照

这样可以先分清：

- share create payload / source / platform 合同错误
- landing token 无效或已过期
- open-app 安全 target 缺失
- download fallback 没串到 `source=share_card`
- release fallback 接上了，但某个平台 target 缺失

---

## 5. SQL proof pack

统一入口：

- `backend/src/main/resources/sql/s02_share_landing_queries.sql`

### 5.1 SQL 关注面

| 查询块 | 用来回答什么 |
|---|---|
| 最近 share 事件明细 | 最近是否真的有 create / landing / open-app / download 命中 |
| 日维度 result 总览 | 哪个 result 在增长 |
| source + platform + result 聚合 | 哪个来源 / 平台失败最多 |
| entrypoint 漏斗 | create 后 landing / open-app / download 哪一段断了 |
| 单 token 时间线 | 同一 token 是否多次 landing / 多次 fallback |
| invalid / expired / unavailable 热点 | 失败原因是否集中在 token / platform / storage |
| `share_card` release fallback 聚合 | S01 侧是否真的承接了 share fallback |
| share ↔ release bridge 对照 | 平台与时间窗上是否存在 share download_fallback 有命中，但 release 没承接 |

### 5.2 推荐查询顺序

1. 先看最近 share 事件和日维度总览，确认 result 面是否异常
2. 再看 source / platform / entrypoint 聚合，判断是 create、landing、open-app 还是 download 在断
3. 再看 `release_distribution_events(source=share_card)`，确认 fallback 是否真的接上 S01
4. 最后用 bridge 对照查询判断某个平台是否在 share 下载后没有承接到 release surface

---

## 6. Failure surface 对照表

| 症状 | 先看哪里 | 应看到的明确 surface | 不应出现的坏结果 |
|---|---|---|---|
| 创建分享失败 | `ShareLinkApiWebTest` / create API 响应 | `invalid_share_payload` / `invalid_share_source` / `invalid_share_platform` / `share_storage_unavailable` | 点击后无反馈或返回空 URL |
| landing 打不开 | wrapper `--route=landing` + `ShareLandingWebTest` | `invalid` / `expired` / `unavailable` + 明确 failure reason | 500 或空白页 |
| open-app 没跳成功 | wrapper `--route=open-app` + `ShareLandingWebTest` | `open_app_redirect`，或 `unknown_platform` / `platform_target_missing` | 任意 URL 被透传跳转 |
| download fallback 没接上 | wrapper `--route=download` + SQL | `Location` 包含 `/download?source=share_card`，release 表出现 `source=share_card` | share 与 release 两边各自为政 |
| token 无效 / 过期 | landing headers + SQL token 时间线 | `invalid:token_not_found` / `expired:token_expired` | 200 静默成功 |
| 审计表没命中 | SQL 最近事件 + `X-Share-Landing-Audit` | 能看到 `recorded` / `failed` 或时间窗里确实没流量 | 只能猜“可能没人访问” |
| app 回流失败 | `mobile/test/app/share_reentry_coordinator_test.dart` | 非法 link 明确回 shell fallback，合法 link 回 `PracticeRouteArgs` seam | 任意 link 直接推路由 |

---

## 7. Redaction 红线

所有 proof / SQL / runbook / wrapper 输出继续只允许输出 **coarse-grained share diagnostics**：

允许输出：

- `token`（只用于单 token 时间线排查，不扩散到 HTML / OG）
- `source`
- `entrypoint`
- `platform`
- `result`
- `failure_reason`
- `release_channel`
- `created_at` 聚合或时间窗
- `X-Share-Landing-*` headers
- `/download?source=share_card` 是否命中

禁止输出：

- `installationId`
- account 标识
- child / 宝宝姓名
- `eventKey`
- `fallbackReason`
- warning / debug 文案
- 原始 user agent 全量字符串
- 原始 HTML 调试片段中带内部上下文的内容

如果截图、SQL 导出、wrapper 输出里出现这些内容，先修 redaction，再继续排查。

---

## 8. 最小复跑清单

### 8.1 Root-safe help 与 smoke

```bash
dart run tool/verify_s02_share.dart --help

dart run tool/verify_s02_share.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --token=share_token_1234 \
  --route=landing \
  --expect-status=200 \
  --expect-result=page_view

dart run tool/verify_s02_share.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --token=share_token_1234 \
  --route=download \
  --platform=android \
  --expect-status=302 \
  --expect-result=download_fallback \
  --expect-location-contains="/download?source=share_card"
```

### 8.2 backend / mobile proof

```bash
mvn -q -f backend/pom.xml -Dtest=ShareLinkApiWebTest,ShareLandingWebTest test
cd mobile && flutter test test/features/share/share_repository_test.dart test/features/share/share_view_model_test.dart test/features/practice/garden_growth_home_test.dart test/features/practice/garden_growth_shell_test.dart test/app/share_reentry_coordinator_test.dart
```

### 8.3 文档 / SQL / wrapper 对齐检查

```bash
rg -n "share_landing_events|share_card|open_app|download_fallback|invalid|expired|release_distribution_events|failure_reason" \
  docs/runbooks/s02-growth-share.md \
  backend/src/main/resources/sql/s02_share_landing_queries.sql \
  tool/verify_s02_share.dart
```

通过标准：

- runbook 明确区分 create / landing / open-app / download fallback 的入口语义
- SQL 只依赖 `share_landing_events`、`release_distribution_events` 与稳定字段
- wrapper 能在仓库根给出 help、缺失项、smoke 与 backend 未启动提示
- `share_card` fallback 与 release surface 保持连通
- 不引入 installation / account / child / `eventKey` / `fallbackReason` / debug 文案
