# S01 Release Distribution Runbook

## 目标

把 M003/S01 已落地的 public release surface 固定成一条未来 agent / 运营 / 工程都能复跑的仓库内路径：

1. 公开下载入口 `/download`
2. 版本门禁升级入口 `/upgrade`
3. 受控跳转 `/download/redirect` / `/upgrade/redirect`
4. `release_distribution_events` 审计查询
5. root-safe `tool/verify_s01_distribution.dart` 校验与 smoke 入口

这份 runbook **只复用现有 Spring Boot public routes、`release_distribution_events` 审计表、`DistributionPageWebTest`、移动端 account version-blocked CTA 和 SQL query pack**；**不新增 analytics SDK、不补写 session / installation / 手机号维度，也不要求人工翻日志才能确认 release hit/failure**。

---

## 0. Root-safe 入口

### 0.1 先跑 help，确认 proof pack 入口存在

从仓库根执行：

```bash
dart run tool/verify_s01_distribution.dart --help
```

这个 wrapper 会先检查以下文件是否存在：

- `docs/runbooks/s01-release-distribution.md`
- `backend/src/main/resources/sql/s01_release_distribution_queries.sql`
- `backend/src/main/resources/db/migration/V5__create_release_distribution_tables.sql`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/DistributionPageWebTest.java`

缺任一文件时，wrapper 返回 **exit code 64** 并打印明确缺失项。

### 0.2 可选 public page smoke

本地 backend 已启动后，可从仓库根执行：

```bash
dart run tool/verify_s01_distribution.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --route=download \
  --channel=stable \
  --source=public_link \
  --expect-status=200 \
  --expect-result=page_view \
  --expect-body="下载 Baby Talk"
```

也可以验证 426 升级页：

```bash
dart run tool/verify_s01_distribution.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --route=upgrade \
  --channel=stable \
  --source=version_gate \
  --expect-status=200 \
  --expect-result=page_view \
  --expect-body="升级 Baby Talk"
```

若 smoke 失败：

- **缺 `--base-url` 或非法参数**：wrapper 返回 **64**，不静默降级
- **backend 未启动 / 连接失败**：wrapper 返回非零，并提示先执行 `mvn -f backend/pom.xml spring-boot:run`
- **请求超时**：wrapper 返回 **124**，并提示确认 backend 已启动且 `--base-url` 可达

---

## 1. 当前 runtime / UI proof surface

未来排查 S01 问题时，先对齐这些 surface，再决定看 SQL 还是复跑 smoke / web test。

### 1.1 Public routes

| Surface | 期望 | 当前定位方式 |
|---|---|---|
| `/download` | 公开下载页可访问，展示平台 CTA，并回写 `page_view` / `unavailable` / `invalid_*` 审计 | `DistributionPageWebTest` + browser / curl smoke |
| `/upgrade` | 426 升级页可访问，默认 `source=version_gate`，平台缺失时给出明确 unavailable 文案 | `DistributionPageWebTest` |
| `/download/redirect` | 只跳白名单目标，不允许 open redirect | `DistributionPageWebTest` |
| `/upgrade/redirect` | 从升级入口跳向受控白名单目标 | `DistributionPageWebTest` + smoke |
| `X-Release-Distribution-Result` | 显式返回 `page_view` / `redirect` / `unavailable` / `invalid_channel` / `invalid_source` / `invalid_platform` | controller 响应头、wrapper smoke 输出 |
| `X-Release-Distribution-Audit` | 显式返回 `recorded` / `failed`，说明审计是否写入成功 | controller 响应头、wrapper smoke 输出 |

### 1.2 App 内升级入口

| Surface | 期望 | 当前定位方式 |
|---|---|---|
| 426 响应体 `upgradeUrl` | 指向真实 `/upgrade?...` 页面，而不是 placeholder 文本 | `DistributionPageWebTest#upgradeRequiredHandshakeStillPointsToRealUpgradePage` |
| account version-blocked CTA | app 内“立即升级”按钮能打开 upgrade page；缺链接 / 非法 scheme / 打开失败都有可见状态 | `mobile/test/features/account/account_repository_test.dart` / `account_entry_screen_test.dart` |

---

## 2. 入口语义与参数合同

### 2.1 `/download`

- 面向公开直达下载页
- 默认 `source=public_link`
- 允许显式带上：
  - `channel`：release channel，例如 `stable` / `beta`
  - `source`：入口来源，例如 `public_link`
  - `platform`：可选，`android` / `ios`，用于优先推荐或 unavailable 判定

典型入口：

```text
/download?channel=stable&source=public_link
/download?channel=beta&source=public_link&platform=android
```

### 2.2 `/upgrade`

- 面向 app 内 426 version gate 跳转
- 默认 `source=version_gate`
- 参数合同与 `/download` 一致，但语义是“升级而不是首次下载”

典型入口：

```text
/upgrade?channel=stable&source=version_gate
/upgrade?channel=stable&source=version_gate&platform=ios
```

### 2.3 `/download/redirect` 与 `/upgrade/redirect`

- 只接受白名单中的 `channel + platform`
- **不允许** query 透传外部 URL
- 缺 `platform`、未知 `platform`、未知 `channel/source` 都必须返回可见失败页，而不是静默 302

典型入口：

```text
/download/redirect?channel=stable&source=public_link&platform=android
/upgrade/redirect?channel=stable&source=version_gate&platform=ios
```

---

## 3. 当前 release audit 表能回答什么

统一审计表：`release_distribution_events`

稳定字段：

- `entrypoint`：`download` / `upgrade`
- `release_channel`
- `source`
- `platform`
- `result`
- `failure_reason`
- `created_at`

它能回答：

- 哪个 `release_channel` / `source` 被访问最多
- `/download` 与 `/upgrade` 各自产生了多少 `page_view` / `redirect` / `unavailable`
- 哪个平台经常命中 `platform_target_missing`
- `invalid_channel` / `invalid_source` / `invalid_platform` 是否在增长
- 是否真的有 `upgrade` 命中，而不是只有 426 文案

它**不能**回答：

- 某个 session / 手机号 / 验证码 的访问轨迹
- 某个 account 或 installation 的逐设备行为串联
- 原始 user agent、原始 prompt / response、宝宝资料

> 当前 schema **故意不存 installation / account / session**。这不是缺口，而是 redaction 边界。若需要排查“同一设备多次走不同 source”，先复跑固定 smoke / web test，再按 `source + entrypoint + created_at` 时间窗比较，**不要**补写 PII 或 invent 新列。

---

## 4. 推荐排查顺序

严格按这个顺序，不要跳步：

1. **先看 public/runtime surface**
   - 用户是从 `/download` 公开直达，还是从 app 426 的 `/upgrade` 进入？
   - 响应头里的 `X-Release-Distribution-Result` / `X-Release-Distribution-Audit` 是什么？
2. **再跑 root-safe wrapper**
   - `dart run tool/verify_s01_distribution.dart --help`
   - 必要时加 `--smoke --base-url=...`
3. **再看 `DistributionPageWebTest` 与移动端 account tests**
   - 确认是 backend route 回归、redirect 白名单问题，还是 app 内 CTA / opener 问题
4. **最后看 SQL query pack**
   - 判断是某个 `channel/source/platform` 命中失败增多，还是单次本地复现问题

这样可以先分清：

- public 页面本身不可达
- redirect target 缺失
- channel/source 参数非法
- 审计有写入但 upgrade hit 没发生
- app 内 CTA 能展示但外链打开失败

---

## 5. SQL proof pack

统一入口：

- `backend/src/main/resources/sql/s01_release_distribution_queries.sql`

### 5.1 SQL 关注面

| 查询块 | 用来回答什么 |
|---|---|
| 日维度 result 总览 | `/download` / `/upgrade` 的访问与失败总量 |
| `release_channel + source + result` 聚合 | 哪个渠道/来源命中最多、哪里失败最多 |
| `platform + result + failure_reason` 聚合 | Android / iOS 哪个平台失败更集中 |
| `upgrade` 命中聚合 | 426 跳转是否真的进入 `/upgrade` |
| 最近事件明细 | 最近一段时间是否出现 `invalid_channel` / `unavailable` / `platform_target_missing` |
| 单 `source` / `channel` 诊断 | 比较 `public_link` 与 `version_gate` 的 hit/failure 差异 |

### 5.2 推荐查询顺序

1. 先看日维度总览，确认最近有没有 `upgrade` 命中
2. 再看 `release_channel + source + result` 聚合，判断是入口问题还是平台问题
3. 再看 `platform + failure_reason` 聚合，确认是否是 `platform_target_missing` / `unknown_platform`
4. 最后看最近事件明细，确认失败面是否与 smoke / 响应头一致

---

## 6. Failure surface 对照表

| 症状 | 先看哪里 | 应看到的明确 surface | 不应出现的坏结果 |
|---|---|---|---|
| 公开下载页打不开 | wrapper smoke + `/download` | 非 200、明确连接失败或超时提示 | 只有“打不开”，没有入口/命令提示 |
| 426 升级提示点开后无落地页 | 426 `upgradeUrl` + `/upgrade` smoke | `upgradeUrl` 指向真实 `/upgrade?...`，且页面可访问 | 文本提示要求升级，但没有真实地址 |
| redirect 没跳成功 | `/download/redirect` / `/upgrade/redirect` + `DistributionPageWebTest` | `redirect` / `unavailable` / `invalid_platform` 等明确结果 | 任意 URL 被透传跳转 |
| 渠道或来源参数错误 | wrapper / response headers / SQL | `invalid_channel` / `invalid_source` + 对应 `failure_reason` | 200 静默成功 |
| 平台未配置 | 页面提示 + SQL | `unavailable` + `platform_target_missing` | 空白页或只有 302 失败 |
| 审计表没命中 | SQL 最近事件明细 | 能确认 `audit=failed` 或根本没流量 | 只靠猜测“可能没人访问” |
| app 内 CTA 打不开 | account widget/repository tests | 缺链接、非法 scheme、打开失败都有可见 CTA 状态 | 点击后无反馈 |

---

## 7. Redaction 红线

所有 proof / SQL / runbook 输出继续只允许输出 **coarse-grained release diagnostics**：

允许输出：

- `entrypoint`
- `release_channel`
- `source`
- `platform`
- `result`
- `failure_reason`
- `created_at` 聚合或时间窗
- 426 `upgradeUrl` 是否指向 `/upgrade?...`
- account version-blocked CTA 的可见状态

禁止输出：

- session id / token
- 手机号 / 验证码
- account 标识
- installation 标识
- 宝宝资料
- 原始 prompt / response
- 原始 user agent 全量字符串

如果截图、SQL 导出、wrapper 输出里出现这些内容，先修 redaction，再继续 proof。

---

## 8. 最小复跑清单

### 8.1 Root-safe help 与 smoke

```bash
dart run tool/verify_s01_distribution.dart --help

dart run tool/verify_s01_distribution.dart \
  --smoke \
  --base-url=http://127.0.0.1:8080 \
  --route=download \
  --channel=stable \
  --source=public_link \
  --expect-status=200 \
  --expect-result=page_view \
  --expect-body="下载 Baby Talk"
```

### 8.2 backend / mobile proof

```bash
mvn -q -f backend/pom.xml -Dtest=DistributionPageWebTest test
cd mobile && flutter test test/features/account/account_repository_test.dart test/features/account/account_entry_screen_test.dart
```

### 8.3 文档 / SQL / wrapper 对齐检查

```bash
rg -n "release_distribution_events|release_channel|source|platform|failure_reason|/download|/upgrade|DistributionPageWebTest|upgradeUrl|version_gate|public_link" \
  docs/runbooks/s01-release-distribution.md \
  backend/src/main/resources/sql/s01_release_distribution_queries.sql \
  tool/verify_s01_distribution.dart
```

通过标准：

- runbook 明确区分 `/download` 与 `/upgrade` 的入口语义
- SQL 只依赖 `release_distribution_events` 与稳定字段
- wrapper 能在仓库根给出 help、缺失项、smoke 与 backend 未启动提示
- 不再引用旧 placeholder 下载链接、旧 release key 或任何 PII 维度
