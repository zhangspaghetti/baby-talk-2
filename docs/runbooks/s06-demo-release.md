# S06 Android-first Demo / Release Runbook

## 目标

把 M001/S06 既有 seam 收口成一条可重复执行的 Android-first 演示路径：

1. fresh install
2. onboarding
3. practice
4. garden / growth 反馈
5. sign-in sync
6. Mentor 求助
7. profile APK 产物验证

这份 runbook 只复用仓库里已经存在的移动端、backend、inspect CLI、integration proof 与 SQL 查询包；**不引入新的 analytics 子系统**。

---

## 0. 先决条件

### 目录约束

- Flutter 构建、测试、安装包输出都发生在 `mobile/` 子工程。
- **不要**在仓库根目录直接执行 `flutter build apk ...`，根目录没有 `pubspec.yaml`，会直接报 `No pubspec.yaml file found`。
- Windows 上不要用 `test -f ...` 检查 APK 是否存在；请改用 PowerShell `Test-Path`，或在支持 POSIX 的 shell 中使用 `[ -f ... ]`。

### 运行时前提

- 已安装 Flutter / Android SDK / JDK 17。
- backend 可通过 `mvn -q -f backend/pom.xml test` 与 `spring-boot:run` 启动。
- 若要做真机 smoke，需要至少一台可安装 Android APK 的设备。
- release 签名不是本 runbook 的内建能力：`mobile/android/key.properties` 缺失时，release build 会显式失败，避免误产出 debug-signed 包。

---

## 1. 环境合同

### 1.1 Mobile build-time dart-define

| Key | 作用位置 | 默认值 | 演示要求 |
|---|---|---|---|
| `BABY_TALK_API_BASE_URL` | mobile HTTP client | `http://127.0.0.1:8080` | profile/demo build 时必须显式指向可达 backend；不能把真机包留在 `127.0.0.1`。 |
| `BABY_TALK_API_VERSION` | mobile `X-App-Version` | `1.2.0` | 与 backend `BABY_TALK_MIN_SUPPORTED_VERSION` 对齐。 |

### 1.2 Backend env contract

| Key | 作用位置 | 默认值 | 演示要求 |
|---|---|---|---|
| `BABY_TALK_MIN_SUPPORTED_VERSION` | backend version gate | `1.2.0` | 低于该版本返回 `426 Upgrade Required`。 |
| `BABY_TALK_UPGRADE_URL` | backend 426 header/body | `https://example.com/baby-talk/download` | 演示环境必须替换成真实下载页或受控占位下载页。 |
| `BABY_TALK_SMS_PROVIDER_MODE` | auth challenge provider | `dev` | M001 演示允许用 dev stub；上线前必须切换真实短信能力。 |
| `BABY_TALK_MENTOR_PROVIDER_MODE` | mentor provider | `dev` | M001 演示允许 dev provider，仍要保留 timeout / malformed / unavailable failure surface。 |

> 说明：`BABY_TALK_UPGRADE_URL` 不是 Flutter dart-define，而是 backend 通过 `X-Upgrade-Url` header 和响应体回传给客户端的升级指引。

---

## 2. Backend 启动与合同预检

### 2.1 先跑 backend proof

```bash
mvn -q -f backend/pom.xml -Dtest=ApiVersionHandshakeWebTest,AuthConsentSyncWebTest,MentorWebTest test
```

只有这组 contract tests 通过，才继续做 build / install / smoke。

### 2.2 启动 backend（开发 / 演示环境）

#### PowerShell

```powershell
$env:BABY_TALK_MIN_SUPPORTED_VERSION = '1.2.0'
$env:BABY_TALK_UPGRADE_URL = 'https://demo.example.com/download'
$env:BABY_TALK_SMS_PROVIDER_MODE = 'dev'
$env:BABY_TALK_MENTOR_PROVIDER_MODE = 'dev'
mvn -q -f backend/pom.xml spring-boot:run
```

#### POSIX shell

```bash
BABY_TALK_MIN_SUPPORTED_VERSION=1.2.0 \
BABY_TALK_UPGRADE_URL=https://demo.example.com/download \
BABY_TALK_SMS_PROVIDER_MODE=dev \
BABY_TALK_MENTOR_PROVIDER_MODE=dev \
mvn -q -f backend/pom.xml spring-boot:run
```

如需本地文件库，默认 H2 file DB 已由 `backend/src/main/resources/application.yml` 提供，无需额外修改。

---

## 3. Android-first profile APK 构建

### 3.1 构建命令

```bash
cd mobile && flutter build apk --profile \
  --dart-define=BABY_TALK_API_BASE_URL=https://demo.example.com \
  --dart-define=BABY_TALK_API_VERSION=1.2.0
```

### 3.2 产物路径

- `mobile/build/app/outputs/flutter-apk/app-profile.apk`

### 3.3 产物存在性检查

#### PowerShell

```powershell
Test-Path mobile/build/app/outputs/flutter-apk/app-profile.apk
```

#### POSIX shell

```bash
[ -f mobile/build/app/outputs/flutter-apk/app-profile.apk ]
```

### 3.4 身份与权限检查

```bash
rg -n "Baby Talk|com\.babytalk\.mobile|INTERNET" \
  mobile/android/app/build.gradle.kts \
  mobile/android/app/src/main/AndroidManifest.xml \
  mobile/ios/Runner/Info.plist \
  mobile/ios/Runner.xcodeproj/project.pbxproj
```

期望看到：

- Android package / namespace：`com.babytalk.mobile`
- App label：`Baby Talk`
- Android 主 manifest 含 `android.permission.INTERNET`
- iOS display name / bundle metadata 不再保留模板值

---

## 4. 安装与真机 smoke 顺序

### 4.1 安装

1. 将 `mobile/build/app/outputs/flutter-apk/app-profile.apk` 安装到 Android 真机。
2. 若设备上已有旧 demo，先卸载，确保是 **fresh install**。
3. 首次启动时确认没有历史数据污染。

### 4.2 主链路 smoke

按下面顺序走一次完整链路：

1. **fresh install / first open**：确认进入 onboarding，而不是恢复页。
2. **onboarding**：完成基础设置，进入首页。
3. **practice**：完成 starter practice，确认 recent result 可见。
4. **garden / growth**：确认花园 patch、成长 summary 与投影反馈已出现。
5. **sign-in sync**：进入账号面板，完成 challenge / verify / consent / sync，确认 sync banner、phase、可见 code 与 recent result 状态变更。
6. **Mentor 求助**：
   - 先走一次普通求助，确认 `code=ok` / `phase=response_delivered`。
   - 再走一次 blocked fallback，确认 `code=blocked_fallback`、`fallbackUsed=true`、`correlationId` 可见。
7. **upgrade visibility**：若故意制造低版本 / 错版本环境，客户端必须看到 `426` 对应的升级指引，而不是静默失败。

### 4.3 边界条件解释

- **首次安装零历史**：本地 inspect 允许显示 empty，不算失败；只要 onboarding→practice 能产生第一条事件即可。
- **只做 practice 不登录**：属于允许路径；此时不应把“未同步”误判为“同步失败”。
- **登录后 sync / mentor 各发生一次**：这是本切片最小有效 smoke；若只验证 practice，不算完成 S06。
- **D1 / D7 / D30 尚无数据**：只记为“样本未成熟”，不是“留存失败”。

---

## 5. 诊断入口与排查顺序

### 5.1 总顺序

未来 agent 或执行者在 smoke 失败时，按这个顺序排查：

1. **看 UI 上的 banner / code / phase / correlationId**
2. **看本地 inspect CLI**（判断 practice / sync / mentor 本地事实是否存在）
3. **看 SQL query pack**（判断 backend 审计与成功阈值口径是否成立）
4. **最后回放 integration proof / backend contract tests**（判断是否是代码回归，而不是环境或数据问题）

### 5.2 Inspect CLI

#### 从仓库根查看帮助（root-safe wrapper）

```bash
dart run tool/inspect_interaction_events.dart --help
dart run tool/inspect_mentor_facts.dart --help
```

#### 查看 practice / sync 本地事实

```bash
cd mobile && dart run tool/inspect_interaction_events.dart \
  --directory <absolute-app-support-dir> \
  --limit 20
```

可观察信号：

- `pendingEvents` / `syncedEvents` / `failedEvents`
- `lastSyncPhase`
- `lastSyncAt`
- `lastSyncError`
- 最近一批 `eventKey / localEventId / installationId / activityId / phraseId / reactionType / syncState`

#### 查看 Mentor 本地事实

```bash
cd mobile && dart run tool/inspect_mentor_facts.dart \
  --directory <absolute-app-support-dir> \
  --limit 20
```

可观察信号：

- `eventType`
- `phase`
- `correlationId`
- `visibleStatus / visibleDetail`
- `retryable`
- `contextFallbackUsed`

> Redaction 约束：`inspect_interaction_events` 与 `inspect_mentor_facts` 只能输出 redacted diagnostics；不得回显手机号、验证码、session secret、同意前宝宝 PII、raw prompt 或 raw response。

### 5.3 SQL query pack

成功阈值与 backend 审计查询统一看：

- `docs/runbooks/s06-success-metrics.md`
- `backend/src/main/resources/sql/s06_success_queries.sql`

排查重点：

1. `interaction_events`：practice / revisit / D1-D7-D30 cohort
2. `consent_audit_logs`：sign-in / consent 是否真正落账
3. `mentor_audit_logs`：chat_requested / rate_limited / timeout / malformed / blocked_fallback
4. `mentor_turns`：成功或 fallback 的最终可交付 response 是否存在

### 5.4 Integration proof / wrapper

```bash
dart run tool/verify_s06.dart --inspect
dart run tool/verify_s06.dart --integration
```

若 `--integration` 失败，优先区分：

- **设备/模拟器缺失**：环境问题
- **Flutter / Gradle 构建失败**：构建合同问题
- **test assertion 失败**：代码回归
- **backend 不可达或 version gate 不匹配**：环境配置问题

---

## 6. 常见失败面与定位提示

| 症状 | 先看哪里 | 常见原因 | 下一步 |
|---|---|---|---|
| `No pubspec.yaml file found` | 当前命令执行目录 | 在仓库根直接跑 Flutter build/test | 切到 `mobile/` 后重试。 |
| APK 没产出 | `mobile/build/app/outputs/flutter-apk/` | build 未在 `mobile/` 中执行、dart-define 缺失、Gradle 失败 | 先复查 build 命令，再看 Flutter/Gradle stderr。 |
| sync banner 报错 | `inspect_interaction_events` + `consent_audit_logs` | session 失效、consent 未完成、版本门禁、网络失败 | 先看 `lastSyncPhase` / `lastSyncError`，再查 consent 审计。 |
| Mentor 显示 timeout / unavailable / fallback | `inspect_mentor_facts` + `mentor_audit_logs` | provider timeout、rate limit、blocked keyword、安装包指错环境 | 先看 `phase / correlationId`，再查 SQL audit。 |
| version blocked | UI banner + backend response headers | `BABY_TALK_API_VERSION` 低于 backend 最低支持版本 | 对齐 `BABY_TALK_API_VERSION` 与 `BABY_TALK_MIN_SUPPORTED_VERSION`。 |
| 只有 practice 成功，garden/growth 没刷新 | 本地 inspect + integration proof | 事件落本地但投影未刷新，或 smoke 顺序错误 | 先确认 interaction event 已存在，再复跑 S06 full-chain proof。 |

---

## 7. 外部 admin blocker checklist

以下事项**不在当前代码仓库内自动完成**；若缺项，M001 只能算 Android-first 演示版，不算可正式发布版：

- [ ] ICP / 备案路径明确，下载页或官网文案可合法上线
- [ ] 短信模板已申请并通过审核，非 dev provider 的 challenge/verify 路径可切换
- [ ] 企业认证 / 主体资质材料已准备，满足商店与短信服务要求
- [ ] 隐私政策、用户协议、儿童/未成年人相关披露页已准备，并与账号/同步/求助行为一致
- [ ] Android 下载地址、签名物料、上传 keystore 与轮换责任人明确
- [ ] Android 包名、应用名、图标、版本号策略已冻结到可分发语义
- [ ] iOS 签名、Bundle ID、TestFlight 路径与责任人明确（即便 M001 先走 Android-first，也要把路径写清）
- [ ] 演示环境的 `BABY_TALK_UPGRADE_URL` 指向受控下载页，而不是模板占位地址
- [ ] smoke 截图 / SQL 截图 / CLI 输出已做 redaction 审查

---

## 8. 交付前最小检查清单

### 必跑命令

```bash
flutter analyze mobile
cd mobile && flutter test integration_test/s03_account_sync_restore_flow_test.dart
cd mobile && flutter test integration_test/s06_full_chain_release_flow_test.dart
mvn -q -f backend/pom.xml -Dtest=ApiVersionHandshakeWebTest,AuthConsentSyncWebTest,MentorWebTest test
dart run tool/inspect_interaction_events.dart --help
dart run tool/inspect_mentor_facts.dart --help
cd mobile && flutter build apk --profile --dart-define=BABY_TALK_API_BASE_URL=https://demo.example.com --dart-define=BABY_TALK_API_VERSION=1.2.0
```

### 产物与文档

- [ ] `mobile/build/app/outputs/flutter-apk/app-profile.apk` 存在
- [ ] `docs/runbooks/s06-success-metrics.md` 已同步最新 D1 / D7 / D30 解释口径
- [ ] `backend/src/main/resources/sql/s06_success_queries.sql` 未引入仓库外的新表
- [ ] 手工 smoke 至少跑过一次完整链路并记录结果

---

## 9. 成功阈值入口

最小 success metrics、解释口径与 SQL 见：

- `docs/runbooks/s06-success-metrics.md`
- `backend/src/main/resources/sql/s06_success_queries.sql`

关键词：`D1` / `D7` / `D30`、activation、revisit、help usage、blocked_fallback、rate_limited。
