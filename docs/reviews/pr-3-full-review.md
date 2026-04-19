# PR #3 完整 Review 报告 (gsd → main)

> **审查时间**: 2026-04-18
> **审查范围**: `origin/main...origin/gsd`，324 files changed, +64,684 / −5,546
> **涉及 Milestone**: M001（开口验证闭环）、M002（连续使用与留存强化）、M003（扩张与分发能力）
> **技术栈**: Spring Boot 4 + JDK 21（后端）, Flutter/Dart（移动端）, H2 (PostgreSQL mode) / Flyway
> **测试结果**: 后端 43 个测试全部通过；Android 模拟器上实际执行 4 个 Flutter 集成测试，4 个失败

---

## 目录

1. [P1 — 必须修复才能合并](#p1--必须修复才能合并)
2. [P2 — 强烈建议修复](#p2--强烈建议修复)
3. [P3 — 可延后的改进项](#p3--可延后的改进项)
4. [已检查但排除的候选项](#已检查但排除的候选项)
5. [工程架构审查](#工程架构审查)
6. [设计审查](#设计审查)
7. [运行验证与发布就绪度补充](#运行验证与发布就绪度补充)
8. [审查限制](#审查限制)

---

## P1 — 必须修复才能合并

### P1-1: SMS 验证流存在竞态条件，重试可变 5xx

**证据**:
- `verifyChallenge()` 先调用 `markChallengeVerified(challengeId, now)` 再执行 `findActiveAccountByPhone(...).orElseGet(insertAccount(...))`，无锁/无 CAS。
- `markChallengeVerified()` 的 SQL 为 `UPDATE ... WHERE challenge_id = ?`，**没有** `AND status = 'pending'` 条件守护。
- `accounts.phone_number` 有唯一约束 — 两个并发成功验证都观察到"无 active account"，然后竞争 `insertAccount()`，后者将抛出唯一约束冲突异常。
- 实际黑盒并发验证已复现：本地启动后端后，对同一个 `challengeId` 连续进行 10 轮、每轮 50 个并发 `POST /api/v1/auth/verify`。第 6 轮出现 `200:2, 400:48`，且同一个 challenge 返回了 **2 个不同的 `sessionId`**，证明同一 challenge 可被并发消费两次。

**引用**:
- [AuthConsentSyncService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java#L101-L113) — 无状态守护的验证 → 创建流
- [AuthConsentSyncRepository.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java#L60-L66) — `markChallengeVerified` 缺少 `status = 'pending'`

**影响**: 客户端合法的"双击/重试"在已存在账号场景下会直接拿到两个有效 session；首次登录场景进一步可能打到 `accounts.phone_number` 唯一约束并表现为 5xx，而不是幂等成功或稳定合约错误。

**修复方案**:
1. `markChallengeVerified` SQL 加 `WHERE challenge_id = ? AND status = 'pending'`，检查 affected rows。
2. 账户创建使用 `INSERT ... ON CONFLICT(phone_number) DO NOTHING RETURNING *` 或在创建前对 phone 加行锁。

---

### P1-2: Caregiver invite 接受与撤销之间不是原子的

**证据**:
- `acceptInvite()` 流程：检查资格 → `insertMember()` → `refreshSharedContextProjection()` → `markInviteAccepted(token)` → 返回成功。
- `markInviteAccepted()` SQL 有 `WHERE status = 'pending'`，**但调用方不检查 affected rows**。
- 若 `revokeInvite()` 在 `insertMember()` 之后、`markInviteAccepted()` 之前将 invite 改为 `revoked`，则：membership 已创建，但 invite 记录保持 `revoked` 状态 — 状态分裂。

**引用**:
- [CaregiverInviteService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/CaregiverInviteService.java#L128-L170) — accept 流程，membership 在 mark 之前已插入
- [CaregiverInviteRepository.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/CaregiverInviteRepository.java#L163-L178) — `markInviteAccepted` 不返回 affected rows

**影响**: 家庭成员状态与邀请状态发生分歧 — 双击、双设备、或"边看边撤销"皆可触发。同样，`revokeInvite()` 与 `acceptInvite()` 之间也未序列化 — 并发执行可导致 invite 已撤销但 membership 已创建的矛盾状态（Codex 对抗性审查补充确认）。

**修复方案**:
1. 在 `acceptInvite()` 开头先原子地 claim invite：`UPDATE ... WHERE token = ? AND status = 'pending' RETURNING *`，0 rows 即直接返回合约错误。
2. 只有 claim 成功后才 `insertMember()`。

---

### P1-3: Mentor 频率限制存在 TOCTOU，可被并发请求绕过

**证据**:
- `chat()` 先 `countRequestsSince(installationId, windowStart)` 读计数，再插入 audit/turn 行。
- `countRequestsSince()` 是普通 `SELECT COUNT(*)` 无锁。
- 相同 installation 的多个并发请求均可观察到同一个 pre-limit 计数并全部通过。

**引用**:
- [MentorService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java#L51-L84) — 频率限制逻辑
- [MentorRepository.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorRepository.java#L19-L30) — 无锁计数查询

**影响**: 配置为 1 次/窗口的限制在并发流量下可被突破。

**修复方案**: 使用原子性原语 — Redis `INCR` + TTL，或数据库行级锁/序列化计数器。

---

### P1-4: PR 提交了 H2 数据库运行时文件和 trace

**证据**:
- diff 包含 `.data/babytalk.mv.db`（二进制）、`.data/babytalk.trace.db`、`backend/.data/babytalk.mv.db`、`backend/.data/babytalk.lock.db`。
- trace 包含运行时错误文本，lock 包含主机私有地址和锁元数据。
- `.gitignore` 中**没有** `.data/` 或 `backend/.data/` 的忽略规则。

**引用**:
- [.gitignore](.gitignore#L1-L31) — 缺少 `.data/` 规则
- `gsd_diff.patch` 行 9-12, 108-123 — 被追踪的数据库文件

**影响**: 污染 PR，泄露运行时内部信息，导致未来 diff 噪声。

**修复方案**:
1. `git rm --cached .data/ backend/.data/`
2. `.gitignore` 添加 `.data/` 和 `backend/.data/`。

---

### P1-5: MentorController.ChatRequest 缺少 @Valid 注解

**证据**:
- `MentorController.chat()` 的 `@RequestBody ChatRequest request` 没有 `@Valid` 注解。
- `ChatRequest` record 的字段也没有 `@NotBlank` / `@Size` 等 Bean Validation 注解。
- 虽然 `MentorService` 内部有 `normalizeInstallationId()` / `normalizePrompt()` 做手动验证，但这与其他 Controller（如 `AuthConsentSyncController` 使用 `@Valid @NotBlank`）风格不一致。

**引用**:
- [MentorController.java](backend/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java#L1-L50) — 无 @Valid
- [AuthConsentSyncController.java](backend/src/main/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncController.java) — 使用 @Valid 做对比

**影响**: 风险较低（因为 Service 层有手动校验），但违背"validation at system boundary"原则，且 JSON 反序列化错误消息可能泄露内部结构。

**修复方案**: 在 `ChatRequest` 上添加 `@Valid`，在字段上添加 `@NotBlank @Size` 注解以与其他 Controller 保持一致。

---

### P1-6: SMS 验证码无尝试计数器，可在线暴力破解

**证据**:
- `verifyChallenge()` 仅检查 `challengeId` 存在 + `status == 'pending'` + 未过期 + code 匹配。
- **没有** 尝试次数计数器、失败锁定、或逐次递增延迟。
- `sms_challenges` 表无 `attempt_count` / `locked_at` 字段。
- 验证码为 4-8 位纯数字（`\\d{4,8}`），在 challenge TTL 窗口内暴力搜索空间仅 10^4 ~ 10^8。

**引用**:
- [AuthConsentSyncService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java#L78-L105) — verifyChallenge 无 attempt 计数
- [V3 migration](backend/src/main/resources/db/migration/V3__create_accounts_and_sync_tables.sql#L23-L33) — sms_challenges 表无 attempt_count 字段

**影响**: 攻击者获取 challengeId 后，可用脚本在 TTL 窗口内穷举所有可能的验证码组合，成功后以受害者身份登录。

**修复方案**:
1. `sms_challenges` 表增加 `attempt_count INT NOT NULL DEFAULT 0` 字段。
2. 每次验证失败递增计数器，达到阈值（如 5 次）后将 challenge 标记为 `expired`（`failure_reason = 'max_attempts_exceeded'`）。
3. 考虑对 `/api/v1/auth/verify` 端点增加 IP 级速率限制。

**发现来源**: Codex 对抗性审查

---

### P1-7: Mentor 外部 Provider 调用在 @Transactional 事务内 — 连接池饥饿风险

**证据**:
- `MentorService.chat()` 标注 `@Transactional(noRollbackFor = ContractException.class)`，整个方法在一个数据库事务中执行。
- 方法中调用 `mentorProvider.respond(...)` 发起外部 LLM API 请求（可能耗时数秒到数十秒）。
- 在 provider 响应期间，数据库连接持续被持有（HikariCP 默认 pool size = 10）。
- 若 LLM provider 延迟或宕机，所有并发 mentor 请求将耗尽连接池，导致整个 API 不可用（包括 auth、invite 等无关端点）。

**引用**:
- [MentorService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java#L39) — `@Transactional` 覆盖整个 `chat()` 方法
- [MentorService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java#L147-L155) — `mentorProvider.respond()` 外部调用在事务内

**影响**: LLM provider 慢响应或超时 → 连接池枯竭 → 全站 API 502/503。这是一个可被外部因素触发的全局可用性问题。

**修复方案**:
1. 将 `chat()` 方法拆分：先在事务中完成前置验证和 audit 写入，再在事务外调用 provider，最后在新事务中写入结果。
2. 或使用编程式事务管理（`TransactionTemplate`）仅包裹数据库操作。
3. 为 provider 调用设置严格超时（如 30s）。

**发现来源**: Codex 对抗性审查

---

## P2 — 强烈建议修复

### P2-1: 竞态条件没有对应的并发测试

**证据**:
- Auth 测试覆盖 happy path 和幂等重复事件摄入，但不测并发验证。
- Invite 测试覆盖顺序 accept/already-used/revoke-then-accept，但不测并发 accept-vs-revoke。
- Mentor 测试覆盖顺序"首次 ok，第二次被限"，但不测同窗口并发请求。

**引用**:
- [AuthConsentSyncWebTest.java](backend/src/test/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncWebTest.java#L53)
- [CaregiverInviteApiWebTest.java](backend/src/test/java/com/zhangspaghetti/babytalk/web/CaregiverInviteApiWebTest.java#L251)
- [MentorWebTest.java](backend/src/test/java/com/zhangspaghetti/babytalk/web/MentorWebTest.java#L198)

**修复方案**: 针对 verify、invite accept/revoke、mentor chat 频率限制添加并发测试。

---

### P2-2: `tool/verify_s06.dart` 内标签错误标为 S03

**证据**:
- S06 wrapper 打印 `S03 proof pack`、`S03 smoke`、`S03 continuity / mentor / retention proof pack 完成`。

**引用**:
- [tool/verify_s06.dart](tool/verify_s06.dart#L13) — `S03 proof pack`
- [tool/verify_s06.dart](tool/verify_s06.dart#L43) — `S03 smoke`

**修复方案**: 把消息统一改为 S06，保持证明脚本与其对应的 milestone 对齐。

---

### P2-3: 移动端 — 退出登录/删除账号后状态清理不完整

**证据**:
- `AccountViewModel.clearSession()` 和 `deleteAccount()` 调用 `_bumpRuntimeToken()` 通知监听者，但不主动：
  - 取消正在进行的 API 请求
  - 清除 Mentor 聊天历史和 facts
  - 清除 Household 共享上下文缓存
  - 刷新 Practice sync queue（旧事件可能在重新登录后与错误账号同步）

**引用**:
- [account_view_model.dart](mobile/lib/features/account/presentation/account_view_model.dart#L366-L430) — clearSession / deleteAccount

**影响**: 用户退出后重新登录可能看到上一个账号残留的 mentor 聊天或同步旧事件到新账号。

**修复方案**: 在 `clearSession()` / `deleteAccount()` 成功后广播一个 "session_cleared" 事件，各模块监听后清除自身缓存状态。

---

### P2-4: 移动端 — Mentor sessionId 的读取与 API 调用之间有 await 间隙

**证据**:
- `MentorViewModel.submitChat()` 在行 346 读 `_accountViewModel.snapshot.session?.sessionId`，之后经过 `await _appendFactSafely(...)` 再到行 360 发起 `sendChat()` — 在 `await` 期间，session 可能因并发操作（如用户同时退出）变为 null。

**引用**:
- [mentor_view_model.dart](mobile/lib/features/mentor/presentation/mentor_view_model.dart#L345-L375)

**影响**: Flutter 是单线程 event loop，风险在于 `await` 点让出执行权后 session 状态可能已变。

**修复方案**: 在 `await` 之后、发起 API 调用之前重新验证 session 有效性，或在方法入口捕获 snapshot 后立即使用。

---

### P2-5: 移动端 — HomeScreen 多个 unawaited 初始化无依赖序保证

**证据**:
- `HomeScreen.initState()` 中多次 `unawaited()` 调用 `accountViewModel.initialize()`、`continuityViewModel.initialize()` 等。
- 不保证 account 初始化在 continuity 之前完成 — 如果 continuity 读取了未加载的 account session，将得到 stale 数据。

**引用**:
- [home_screen.dart](mobile/lib/features/practice/presentation/screens/home_screen.dart#L54-L67)

**修复方案**: 建立初始化依赖链：先 `await accountViewModel.initialize()`，再启动依赖它的 ViewModel 初始化。

---

### P2-6: 移动端 — 网络请求无重试逻辑

**证据**:
- Share link 创建、Household invite 创建、Mentor API 调用均在首次网络错误（timeout / 503）后直接失败。
- 无指数退避、无重试队列。

**引用**:
- [share_repository.dart](mobile/lib/features/share/data/repositories/share_repository.dart#L65-L150)
- [household_repository.dart](mobile/lib/features/household/data/repositories/household_repository.dart#L128-L165)
- [mentor_api_service.dart](mobile/lib/features/mentor/data/services/mentor_api_service.dart)

**修复方案**: 为可重试的请求实现 exponential backoff retry wrapper（最多 2-3 次）。

---

### P2-7: 移动端 — Household Repository 并发操作缺序列化

**证据**:
- `HouseholdRepository` 分别追踪 `_refreshFuture`、`_acceptFuture`、`_createFuture` 三个独立 Future。
- 无 mutex 或队列序列化 — 若用户在 `refreshSharedContext()` 进行中快速调用 `createInvite()`，两者可同时写入冲突的 snapshot 到本地存储。

**引用**:
- [household_repository.dart](mobile/lib/features/household/data/repositories/household_repository.dart#L53-L85)

**修复方案**: 通过单一操作 mutex 序列化所有仓库操作。

---

### P2-10: Flutter — 无障碍支持几乎缺失

**证据**:
- 整个 `mobile/lib/` 目录仅有 **2 处** `Semantics` 使用：`reaction_chip_row.dart` 和 `quick_select_card.dart`。
- 所有其他可交互组件（按钮、卡片、输入框、导航项）**没有** `semanticsLabel`、`excludeSemantics` 或 accessibility hint。
- 屏幕阅读器（TalkBack / VoiceOver）用户将无法理解大部分 UI 元素的功能。
- 没有 accessibility 相关测试。

**引用**:
- [reaction_chip_row.dart](mobile/lib/features/practice/presentation/widgets/reaction_chip_row.dart#L25) — 仅有的 Semantics 之一
- [quick_select_card.dart](mobile/lib/features/onboarding/presentation/widgets/quick_select_card.dart#L21) — 仅有的 Semantics 之二

**影响**: App 对视障/运动障碍用户基本不可用。如面向中国市场，需符合工信部无障碍相关要求。

**修复方案**: 为所有可交互组件添加 `Semantics` 包装或使用 Material 组件内置的 accessibility 属性。

---

### P2-11: Flutter — 所有中文字符串硬编码，无国际化框架

**证据**:
- 无 `AppLocalizations`、无 `.arb` 文件、无 `intl` 包。
- 所有用户可见文本直接写在 Dart 代码中（如 `'离线种子已就绪'`、`'正在把宝宝反应写入本地记录…'`、`'保存失败'` 等）。
- 每次文案修改都需要修改代码、重新编译。
- `pubspec.yaml` 中未配置 `generate: true` 或 flutter_localizations。

**引用**:
- [home_screen.dart](mobile/lib/features/practice/presentation/screens/home_screen.dart#L234-L259) — 大量硬编码中文
- [practice_session_view_model.dart](mobile/lib/features/practice/presentation/practice_session_view_model.dart#L300-L316) — 状态消息硬编码

**影响**: 无法支持多语言；文案修改需要工程师介入而非配置化管理。

**修复方案**: 引入 `flutter_localizations` + `intl` 包，将文案抽取到 `.arb` 文件。

---

## P3 — 可延后的改进项

### P3-1: Session token 使用文件存储（非 Keystore/Keychain）

- `AccountLocalStore` 将 `sessionId` 序列化为 JSON 写入文件系统。
- 在共享设备场景下，该文件可能被其他应用读取（取决于 OS 权限）。
- **建议**: 迁移到 `flutter_secure_storage`（Android Keystore / iOS Keychain）。

### P3-2: Household API 响应解析缺防御性 null check

- `HouseholdApiService` 解析 `householdId`、`role` 等字段时未做 null check。
- API 返回部分/无效 JSON 时将 crash 而非抛出明确异常。
- **引用**: [household_api_service.dart](mobile/lib/features/household/data/services/household_api_service.dart#L244-L265)

### P3-3: Practice event sync 失败后无重试队列

- `markEventsFailed()` 将事件标记为 failed，但不重新入队。
- 网络超时导致的失败事件将永久停留在 failed 状态。
- **引用**: [practice_repository.dart](mobile/lib/features/practice/data/repositories/practice_repository.dart#L680-L710)

### P3-4: Share / Invite token 格式不一致

- Share token pattern: `r'^[A-Za-z0-9_-]{8,64}$'`（最少 8 字符）
- Invite token pattern: `r'^[A-Za-z0-9_-]{12,64}$'`（最少 12 字符）
- 无明确文档说明差异原因。
- **引用**: [share_reentry_coordinator.dart](mobile/lib/app/share_reentry_coordinator.dart#L4-L5)、[invite_reentry_coordinator.dart](mobile/lib/app/invite_reentry_coordinator.dart#L5)

### P3-5: Account sync 操作无超时

- `refreshRuntimeState()` 无 timeout — API 挂起时 Future 永不完成，UI 永远显示 spinner。
- **建议**: 添加 30s timeout。

### P3-6: M001-SUMMARY.md 为占位符

- `.gsd/milestones/M001-SUMMARY.md` 为 auto-mode 恢复失败的占位文档，不是真实的 milestone 总结。
- **建议**: 补充真实内容或标记为已知缺失。

### P3-8: SMS 验证码和 invite token 以明文存储在数据库中

**证据**:
- `sms_challenges.verification_code` 为 `varchar(16)` 明文存储。
- `caregiver_invites.token` 为 `varchar(64)` 明文存储。
- 若数据库被泄露（备份、只读副本、SQL 注入），验证码和 invite token 可直接使用，无需破解。

**引用**:
- [V3 migration](backend/src/main/resources/db/migration/V3__create_accounts_and_sync_tables.sql#L26) — `verification_code varchar(16)` 明文
- [V7 migration](backend/src/main/resources/db/migration/V7__create_caregiver_invite_tables.sql#L31) — `token varchar(64)` 明文

**当前风险**: **低** — SMS 验证码有 TTL，invite token 为一次性使用。但防御纵深角度，明文存储增加了数据库泄露后的攻击面。

**建议**: 验证码可存储 hash（验证时比对 hash），invite token 可拆分为 selector + hashed verifier 模式。

**发现来源**: Codex 对抗性审查

### P3-9: Flutter — `activity?.phrases.first` 无空列表防护

**证据**:
- [home_screen.dart](mobile/lib/features/practice/presentation/screens/home_screen.dart#L248) — Guest 模式下使用 `activity?.phrases.first.english`。
- 若 `activity` 非 null 但 `phrases` 为空列表，`.first` 将抛出 `StateError: No element`。
- 当前依赖 seed content 保证至少一个 phrase，但这是运行时假设而非编译期保证。

**影响**: Seed content 更新意外引入空 phrase list 时，Guest 模式首页会 crash。

**修复方案**: 使用 `activity?.phrases.firstOrNull?.english ?? 'Continuity unavailable.'`。

### P3-10: Flutter — 固定宽度/比例布局在极端屏幕上不适配

**证据**:
- Onboarding `GridView` 使用 `crossAxisCount: 4` + `childAspectRatio: 0.76`，在 320pt 窄屏 + 大字体模式下文字溢出。
- Drawer 宽度硬编码 `310`，窄屏几乎全覆盖、宽屏 tablet 太窄。
- 无 `MediaQuery.textScalerOf(context)` 适配。

**影响**: 大字体模式和极端屏幕尺寸下 UI 裁剪或布局异常。

### P3-11: Flutter — Widget 测试覆盖存在盲区

**证据**:
- `GrowthScreen` 完全没有 widget 测试。
- `AppShellScreen` 的 tab 切换和 drawer 交互没有测试。
- `_ReentryOverlay` 显示/消失逻辑没有 widget 测试。
- 已覆盖：practice session、garden home、onboarding、account entry、mentor panel/VM、share VM、household VM。

**影响**: UI 回归风险在未测试的 screen 中无法被自动化捕获。

---

## 已检查但排除的候选项

| 候选问题 | 排除原因 |
|---------|---------|
| `sync/events` 部分 batch commit | 方法有 `@Transactional`，`ContractException` 继承 `RuntimeException`，projection 失败会回滚整个事务。 |
| Open redirect 风险 | 所有重定向目标来自 `application.yml` 配置（非用户输入），redirect URI 不可被外部控制。 |
| SQL 注入 | 全部 SQL 使用 `?` 占位符（JdbcTemplate parameterized queries），SQL 文件中无字符串拼接。 |
| XSS in landing pages | 使用 `HtmlUtils.htmlEscape()` 转义所有插入 HTML 的动态值。 |
| `_audioCompletionSubscription` 内存泄露 | 实际 `dispose()` 方法（practice_session_view_model.dart L452）正确调用了 `_audioCompletionSubscription?.cancel()`。 |
| share_view_model cancel/failure 消息丢失 | 代码始终传播了 cancel/failure 路径的 message。 |
| mentor_view_model TTS 失败静默 | 通过 `_audioStatusMessage` / `_audioStatusCode` 正确表面化。 |
| DevMentorProvider 安全性 | 仅用于开发模式，使用配置开关控制，不涉及真实 LLM 调用。 |

---

## 工程架构审查

> **审查视角**: 架构设计、分层合理性、事务边界、错误处理策略、运维就绪度、构建与测试基础设施

### E-1: ingestEvents 事务内 catch DuplicateKeyException — PostgreSQL 兼容性问题

**类别**: 事务边界 | **严重度**: Engineering Concern

**证据**:
- [AuthConsentSyncService.java#L203-L218](backend/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java#L203) — `ingestEvents()` 标记 `@Transactional`，循环内逐条 `insertInteractionEvent`，catch `DuplicateKeyException` 归入 `duplicateEventKeys`。
- 在 PostgreSQL 中，一个事务内的**任何 SQL 异常**（含唯一约束违反）会使事务进入 **aborted** 状态，后续 SQL 将全部失败（`current transaction is aborted, commands ignored until end of transaction block`）。
- 当前 H2 PostgreSQL 兼容模式不复现此行为，**切换到真实 PostgreSQL 时 batch 中首条重复之后的所有 insert 都会失败**。

**修复方案**: 使用 `INSERT ... ON CONFLICT(event_key) DO NOTHING`，或每条 insert 用 `SAVEPOINT` 隔离。

### E-2: 零日志 — 生产环境完全无法排查问题

**类别**: 运维就绪度 | **严重度**: Engineering Concern

**证据**:
- 整个后端代码**无一处** `org.slf4j.Logger` import（已验证 grep 结果为 0 匹配）。
- [ApiExceptionHandler.java#L48-L50](backend/src/main/java/com/zhangspaghetti/babytalk/web/ApiExceptionHandler.java#L48) — `handleUnexpected(Exception)` 仅返回通用 JSON 响应，**不记录异常堆栈**。
- 所有事件仅写入数据库审计表。数据库本身不可用时，错误完全无处追踪。

**修复方案**: 
1. `ApiExceptionHandler.handleUnexpected` 加 `log.error("Unexpected error", exception)`
2. Provider 调用（SMS、Mentor）加 WARN/INFO 日志
3. 事务失败路径加 ERROR 日志

### E-3: java.version=17 与实际 JDK 21 不一致

**类别**: 配置管理 | **严重度**: Engineering Concern

**证据**:
- [pom.xml#L22](backend/pom.xml#L22) 声明 `<java.version>17</java.version>`
- README 和项目描述声明使用 JDK 21
- maven-compiler-plugin 按 17 编译，可能丢失 JDK 21 特性（如 record patterns、virtual threads 等）

**修复方案**: 统一为 `<java.version>21</java.version>`。

### E-4: 缺少 PostgreSQL driver 依赖

**类别**: 依赖管理 | **严重度**: Engineering Concern

**证据**:
- [pom.xml](backend/pom.xml) 仅有 `com.h2database:h2` runtime 依赖，无 `org.postgresql:postgresql`。
- 部署到真实 PostgreSQL 环境时需手动添加 driver，当前 CI/CD 流水线无法验证 PostgreSQL 兼容性。

**修复方案**: 添加 `org.postgresql:postgresql` 为 runtime scope。

### E-5: Actuator 仅暴露 health + info，缺少运维关键端点

**类别**: 运维就绪度 | **严重度**: Engineering Concern

**证据**:
- [application.yml#L19-L21](backend/src/main/resources/application.yml#L19) — `management.endpoints.web.exposure.include: health,info`
- 缺少 `metrics`（JVM/连接池指标）、`flyway`（migration 状态验证）、`loggers`（动态调整日志级别）

**修复方案**: 至少添加 `metrics,flyway`，生产环境配合认证或网络隔离。

### E-6: AuthConsentSyncService 是 God Service（~400 行，4 个子领域）

**类别**: 分层与职责分离 | **严重度**: Recommendation

**证据**:
- [AuthConsentSyncService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java) 承担认证（challenge/verify）、同意（accept/revoke/delete）、同步（ingest/bootstrap）、审计 4 个领域职责。
- 任一子领域变更影响整个 service 类的测试和维护。

**建议**: 拆分为 `AuthChallengeService`、`ConsentService`、`SyncService`。

### E-7: Service 类硬编码 HTML 模板，业务与视图强耦合

**类别**: 代码组织 | **严重度**: Recommendation

**证据**:
- `DistributionService`、`ShareLandingService`、`CaregiverInviteService` 各自包含 `renderLandingHtml()` 方法，在 Java 字符串中硬编码 HTML/CSS 模板。
- HTML 模板无法独立预览/测试，修改需重新编译部署。

**建议**: 使用 Thymeleaf 或 FreeMarker 模板引擎抽离视图层。

### E-8: 测试清理依赖手动 DELETE — 脆弱模式

**类别**: 测试基础设施 | **严重度**: Recommendation

**证据**:
- [AuthConsentSyncWebTest.java#L40-L46](backend/src/test/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncWebTest.java#L40) — `@BeforeEach` 中按 FK 顺序手动 DELETE 所有表。
- 新增表后忘记添加 DELETE 会导致数据泄漏，删除顺序必须手动与 FK 保持同步。

**建议**: 使用 `@Sql("/cleanup.sql")` 或 `Flyway.clean()` + 重建方式。

### E-9: V9 使用 `ADD COLUMN IF NOT EXISTS` — Flyway 反模式

**类别**: Schema 演进 | **严重度**: Recommendation

**证据**:
- [V9 migration](backend/src/main/resources/db/migration/V9__extend_household_shared_context_for_caregiver_attribution.sql) 使用 `ADD COLUMN IF NOT EXISTS`，若列已存在意味着手动修改过 schema，Flyway checksum 校验与实际不同步。

**建议**: 去掉 `IF NOT EXISTS`，让 Flyway 完全控制 schema 演进。

### E-10: Repository 类在 service 包下，分层界限模糊

**类别**: 代码组织 | **严重度**: Observation

- 所有 Repository 类（`AuthConsentSyncRepository`、`MentorRepository` 等）与 Service 类同在 `service` 包，无独立 `repository` 包。

### E-11: Mobile — app.dart 单文件承担所有 DI 和生命周期

**类别**: Mobile 架构 | **严重度**: Recommendation

**证据**:
- [app.dart](mobile/lib/app/app.dart) ~500 行，包含 boot 状态、多个 typedef、所有 Provider 注册（14 个嵌套 Provider）。
- 测试和修改都很困难。

**建议**: 将 DI 配置抽取到独立的 `provider_scope.dart`，boot 逻辑抽取到 `app_boot.dart`。

### E-12: ShareReentryCoordinator 与 InviteReentryCoordinator 高度同构

**类别**: Mobile 架构 | **严重度**: Observation

- 两个 coordinator 结构几乎完全一致（state 字段、acceptUri、takePending、markHandled 等），仅 dispatch target 和 parser 不同。
- 可抽取 `ReentryCoordinator<T>` 泛型基类，减少 ~150 行重复代码。

---

## 设计审查

> **审查视角**: 视觉一致性、DESIGN.md 合规性、交互模式、品牌实现、错误/空/加载状态

### D-1: 面向用户的界面包含开发内部文本（5 处）

**类别**: UX 内容 | **严重度**: Design Issue — 必须修复

**证据**:
- [phrase_card.dart#L240](mobile/lib/features/practice/presentation/widgets/phrase_card.dart#L240) — 状态标签显示 `"音频 · idle"` `"保存 · idle"` 等英文技术词（idle/playing/completed/error/saving/saved）
- [phrase_card.dart#L191](mobile/lib/features/practice/presentation/widgets/phrase_card.dart#L191) — 说明文字包含技术描述："点按播放真实本地音频，再选择宝宝反应。状态会直接暴露为 idle / playing / completed / error。"
- [activation_frame.dart#L42](mobile/lib/features/practice/presentation/widgets/activation_frame.dart#L42) — 显示 `"C3 激活框"` — 内部设计编号
- [app_shell_screen.dart#L320](mobile/lib/features/shell/presentation/app_shell_screen.dart#L320) — Drawer 底部包含开发笔记
- 分发页面底部 footnote："如果当前平台没有可用入口，请联系发布同学确认 channel/source 配置是否已补齐。" — "发布同学"、"channel/source 配置"是运营内部术语

**用户影响**: 目标用户（中国父母）看到技术术语会困惑，严重破坏"温暖亲切"的产品调性。

### D-2: 所有 HTML 落地页缺少 og:image 社交预览图

**类别**: 社交分享 | **严重度**: Design Issue

**证据**:
- [ShareLandingService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/ShareLandingService.java) — 有 og:title/description，无 og:image
- [CaregiverInviteService.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/CaregiverInviteService.java) — 同上
- DistributionService — 完全没有 og: 标签

**用户影响**: 在微信/QQ 中分享链接时，卡片没有预览图，点击率大打折扣。微信是核心分享渠道。

### D-3: Fraunces 字体 w500 字重未注册，核心排版回退

**类别**: 排版系统 | **严重度**: Design Issue

**证据**:
- DESIGN.md 指定 Hero/Title1/Title2 使用 Fraunces w500
- [pubspec.yaml](mobile/pubspec.yaml) 只注册了 weight 400（Regular）和 700（Bold）
- [app_theme.dart](mobile/lib/app/theme/app_theme.dart#L47) `displayMedium` 使用 `FontWeight.w500`
- Flutter 会回退到最近字重 400，英文短语显示偏细

**用户影响**: 英文短语视觉层级偏弱，Fraunces "绘本台词"温暖感打折扣。

### D-4: 分发页 max-width: 720px 不符合 DESIGN.md 规定的 430px

**类别**: 视觉一致性 | **严重度**: Design Issue

**证据**:
- DESIGN.md 规定 web landing page 最大宽度 430px
- Share/Invite 页面：430px ✓
- [body_platform_android.html#L33](body_platform_android.html#L33) — Distribution 页面：720px ✗

**用户影响**: 下载页在大屏幕上与分享/邀请页视觉不一致。

### D-5: HTML CTA 按钮文字未居中

**类别**: 交互设计 | **严重度**: Design Issue

**证据**:
- [body_platform_android.html#L70](body_platform_android.html#L70) — `.cta-link` 设为 `display: block` 但无 `text-align: center`
- 按钮文本左对齐，看起来像列表项而非 CTA 按钮

### D-6: 三组 MediaPalette 色值定义不统一

**类别**: 设计系统 | **严重度**: Design Recommendation

**证据**:
- DistributionService 有 8 个字段，ShareLandingService 10 个，CaregiverInviteService 10 个
- 同一色值 `#3B8577` 被命名为 `info`、`english`、`positive` 三种 token 名
- DistributionService 缺少 `bgSunken`、`bgAccentSoft`

**建议**: 抽取到统一的 `DesignTokens` 类或配置中。

### D-7: 阴影值偏差 — 与 DESIGN.md 不匹配

**类别**: 设计 Token | **严重度**: Design Recommendation

| Token | DESIGN.md | app_theme.dart 实际值 |
|---|---|---|
| shadow-sm offset | 0 1px | 0 2px |
| shadow-sm blur | 3px | 6px |
| shadow-md offset | 0 2px | 0 6px |
| shadow-md blur | 12px | 16px |

- [app_theme.dart](mobile/lib/app/theme/app_theme.dart#L24) 阴影视觉上更"浮起"，不符合克制阴影策略。

### D-8: 圆角半径与 DESIGN.md 不匹配

**类别**: 设计 Token | **严重度**: Design Recommendation

- DESIGN.md 规定按钮/输入框用 `--radius-sm`(8px)，[app_theme.dart](mobile/lib/app/theme/app_theme.dart#L115) InputDecorationTheme border radius 设为 16px
- DESIGN.md 规定卡片用 `--radius-md`(16px)，CardThemeData 全局默认却设为 24px

### D-9: HTML 落地页未引入 Fraunces 字体

**类别**: 排版系统 | **严重度**: Design Observation

- Share landing CSS `.quote-text` 使用 `font-family: Fraunces, Georgia, serif`，但无 `@font-face` 或 CDN 引入
- 实际回退到 Georgia，失去品牌差异化衬线体效果
- 中国大陆 Google Fonts 不可用，需自托管

### D-10: 暗色模式完全缺失

**类别**: 视觉设计 | **严重度**: Design Observation

- DESIGN.md 有完整暗色模式策略（暖深色 `#1C1816`），设计决策 log 记录"跟随系统设置"
- [app_theme.dart](mobile/lib/app/theme/app_theme.dart) 只有 `Brightness.light`
- HTML 页面硬编码 `color-scheme: light`
- 如为有意推迟到 Phase 2，建议在 DESIGN.md 决策日志中标注

### D-11: 设计 Token 实现对照总结

| Token | DESIGN.md 期望值 | 实际值 | 状态 |
|---|---|---|---|
| `--bg-base` | #FFF8F0 | #FFF8F0 | ✓ |
| `--accent` | #FF8C42 | #FF8C42 | ✓ |
| `--english` | #3B8577 | #3B8577 | ✓ |
| `--radius-sm` (按钮/输入框) | 8px | 16px | ✗ |
| `--radius-md` (卡片) | 16px | 24px (CardTheme) | ✗ |
| `--shadow-sm` offset | 0 1px | 0 2px | ✗ |
| `--shadow-md` blur | 12px | 16px | ✗ |
| Fraunces w500 | 注册 | 未注册 | ✗ |
| Landing max-width | 430px | 720px (Distribution) | ✗ |
| Play button min size | 56-72px | 72px | ✓ |
| Touch target | ≥48px | 48px | ✓ |

---

## 运行验证与发布就绪度补充

> **补充范围**: 文档完整性、部署产物、Android 模拟器集成测试、实际并发验证、LLM provider 真实接入能力、轻量性能基线、真实渲染截图

### R-1: 顶层文档入口严重不足，README 不能支持接手、联调或部署

**证据**:
- [README.md](README.md) 只有一行标题 `# baby-talk-2`，没有项目简介、启动步骤、环境变量、测试方法、目录说明、常见故障。
- [mobile/README.md](mobile/README.md) 仍然是 Flutter 默认模板，不包含本项目的模块说明、运行方式、模拟器命令或联调方式。
- 仓库虽然有较完整的场景 runbook（如 [docs/runbooks/s01-release-distribution.md](docs/runbooks/s01-release-distribution.md) 到 [docs/runbooks/s06-success-metrics.md](docs/runbooks/s06-success-metrics.md)），但缺少一个把开发、测试、部署、验收串起来的权威入口文档。

**影响**: 新成员、测试同学、运维同学无法只靠仓库文档完成本地启动和发布前核查，交接成本高，发布依赖口头知识。

### R-2: 缺少 Docker / Helm / docker compose 产物，无法做标准化部署验证

**证据**:
- 仓库搜索未发现 `Dockerfile`、`docker-compose*.yml`、`compose*.yml`、`Chart.yaml`、`values.yaml`。
- 当前本地验证只能依赖手工 `mvn spring-boot:run` 与 `flutter run`，不存在可复用的容器化本地联调脚本，也不存在 K8s/Helm 发布描述。

**影响**: 无法进行一致的本地依赖编排、预发部署演练或 CI/CD 镜像验证；“可运行”仍停留在开发者个人机器环境。

### R-3: Android 模拟器集成测试已实际执行，但 4 个关键流程全部失败

**实际执行环境**:
- 设备: `emulator-5756`（Android 15 / API 35）
- 命令: `flutter test integration_test -d emulator-5756 --reporter expanded`

**结果**:
- [mobile/integration_test/s01_guest_practice_flow_test.dart](mobile/integration_test/s01_guest_practice_flow_test.dart) 失败：`Timed out waiting for expected widget`
- [mobile/integration_test/s02_personalized_onboarding_flow_test.dart](mobile/integration_test/s02_personalized_onboarding_flow_test.dart) 失败：`onboarding-age-card-12-18` 点击 hit-test 警告后超时
- [mobile/integration_test/s03_account_sync_restore_flow_test.dart](mobile/integration_test/s03_account_sync_restore_flow_test.dart) 失败：`Bad state: No element`
- [mobile/integration_test/s06_full_chain_release_flow_test.dart](mobile/integration_test/s06_full_chain_release_flow_test.dart) 失败：`Bad state: No element`，仅其中一个子用例通过

**影响**: 当前分支虽然存在集成测试资产，但在真实 Android 模拟器上并不稳定可用，不能把这些测试当成发布前通过证据。

### R-4: 实际并发场景已验证，P1-1 不是理论问题

**证据**:
- 本地启动后端后，对同一个 challenge 做 10 轮并发验证，每轮 50 个并发请求，全部带 `X-App-Version: 1.2.0`。
- 第 6 轮返回：`200:2, 400:48`；两个成功响应对应两个不同的 `sessionId`。
- 其余轮次通常为 `200:1, 400:49`，错误码稳定为 `challenge_not_pending`。

**结论**: `verifyChallenge()` 的竞态窗口在真实运行中可被触发，同一 challenge 会被并发消费两次。

### R-5: LLM provider 仍只有 dev seam，既不支持 OAuth，也没有 API key 接入实现

**证据**:
- [MentorProviderConfiguration.java](backend/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java#L10-L20) 只有 `providerMode=dev` 时才返回 `DevMentorProvider`。
- 非 `dev` 模式直接抛出 `ProviderUnavailableException`，提示“尚未实现，请先使用 dev seam 或接入真实 provider”。
- [application.yml](backend/src/main/resources/application.yml#L81-L89) 中只有 `provider-mode`、timeout、rate limit 等通用配置，没有 OAuth client、token endpoint、API key、proxy 或 secret 配置。

**影响**: 当前仓库并不存在“真实 LLM provider 的认证与行为”这条运行路径，因此也谈不上已验证 OAuth、API key、超时重试或真实错误语义。

### R-6: 仅完成了轻量本地基准，不构成正式压测或部署验收

**证据**:
- 本地对 `POST /api/v1/auth/challenges` 做了 50 次顺序请求微基准：`201:50`，平均 `3.62ms`，`p50=3.49ms`，`p95=4.16ms`，`p99=5.69ms`。
- 该结果基于单机、H2 文件库、本地无网络抖动环境，仅能说明“开发机下接口响应很快”，不能外推到 PostgreSQL、真实容器、真实流量。
- 仓库中未发现 benchmark、load test、k6/JMeter/Gatling 等脚本。

**影响**: 当前只有“本地可跑”的弱证据，没有容量、退化、真实依赖或部署回归方面的把握。

### R-7: 已在模拟器上完成真实首屏渲染核验，但冷启动存在明显卡顿信号

**证据**:
- 已使用 `flutter run -d emulator-5756` 真机启动 App，并抓取首屏截图 [tmp/emulator-home.png](tmp/emulator-home.png)。
- 首屏视觉上无明显文字溢出，Warm Paper 色系、主 CTA、卡片层级都已实际渲染。
- 运行日志同时出现 `Skipped 49 frames`、`Skipped 120 frames`，说明冷启动/首帧阶段存在主线程卡顿。

**影响**: “代码看起来没问题”与“真实设备上体验平滑”不是一回事。当前至少说明首屏能正常显示，但启动流畅度还有优化空间。

---

## 审查限制

1. **Codex 交叉审查已完成** — 使用 shengsuanyun provider (`openai/gpt-5.3-codex`)，聚焦 8 个核心后端文件，消耗 68,435 tokens，产出 9 个发现（2 新 P1、1 新 P3、4 重复、2 误报）。
2. **移动端集成测试已运行但未通过** — Android 模拟器上 4 个集成测试全部失败，因此当前只能证明“已实际执行”，不能证明“流程已稳定通过”。
3. **并发测试已执行但覆盖面有限** — 已真实复现 `auth/verify` 竞态；`invite accept/revoke`、mentor rate limit 仍主要依赖代码审查，尚未完成同等级别的黑盒并发回归。
4. **LLM provider 实际行为仍不可测** — 原因不是“这次没测”，而是仓库尚未实现真实 provider 接入路径，只有 `DevMentorProvider` stub。
5. **工程架构审查已补充轻量运行证据** — 已完成本地启动、轻量微基准和 H2 环境验证；但仍未完成 PostgreSQL、容器化部署、预发环境或正式压测验证。
6. **设计审查已补充真实设备截图** — 已在 Android 模拟器核验首屏渲染；但尚未覆盖多机型、多字号、整条 onboarding/practice/share/invite 可视化走查。

---

## 合并建议

| 类型 | 数量 | 要求 |
|------|------|------|
| P1 — 阻塞合并 | 7 | **全部修复后方可合并** |
| P2 — 强烈建议 | 11 | 建议在合并前或紧随合并后修复 |
| P3 — 延后 | 11 | 可在下个迭代处理 |
| Engineering Concern | 5 | 建议在生产部署前解决 |
| Engineering Recommendation | 6 | 中期改进项 |
| Design Issue | 5 | 建议在发布前修复 |
| Design Recommendation | 3 | 设计优化项 |

**结论**: 当前状态 **不建议合并**。P1-1 到 P1-7 是数据完整性、安全性和可用性问题，在真实用户流量下会被触发。工程架构审查发现 PostgreSQL 兼容性问题（E-1）和零日志（E-2）应在生产部署前解决。设计审查发现面向用户的开发内部文本（D-1）和缺少社交预览图（D-2）应在发布前修复。

建议：
1. 先修复 P1-1 ~ P1-7（安全和数据完整性问题）
2. 修复 D-1（移除面向用户的开发内部文本）
3. 修复 E-1（PostgreSQL 兼容性）和 E-2（添加日志）
4. 添加 og:image 社交预览图（D-2）
5. 补充竞态条件的并发测试
6. 重新运行全部测试确认无 regression
7. 重新提交 review

---

## 附录：对抗性审查（Adversarial Review）

> **方法**: Codex CLI（shengsuanyun provider, `openai/gpt-5.3-codex`）+ Claude 对抗性子代理独立审查
> **Codex 状态**: ✅ 成功完成。使用 `codex exec` 聚焦审查 8 个核心后端文件，消耗 68,435 tokens，产出 9 个发现。
> **Claude 对抗性子代理**: ✅ 成功完成。以下为经验证的新发现。

### 新发现 — 经代码验证

#### P2-8: 缺少安全响应头（X-Frame-Options / CSP / X-Content-Type-Options）

**证据**:
- [WebConfig.java](backend/src/main/java/com/zhangspaghetti/babytalk/config/WebConfig.java) 仅注册 `ApiVersionInterceptor`，未设置任何安全头。
- `pom.xml` 中**未引入 `spring-boot-starter-security`**，因此 Spring Boot 不会自动添加安全头。
- 多个端点返回 `text/html` 响应（`/download`、`/share/{token}` 等），缺少 `X-Frame-Options: DENY` 使其暴露于 clickjacking 风险。

**影响**: 攻击者可将分发/分享页面嵌入 iframe 进行 clickjacking，或在无 CSP 的情况下利用潜在 XSS 向量。

**修复方案**: 添加安全头拦截器：
```java
response.setHeader("X-Frame-Options", "DENY");
response.setHeader("X-Content-Type-Options", "nosniff");
response.setHeader("Content-Security-Policy", "default-src 'self'; style-src 'self' 'unsafe-inline'");
```

---

#### P2-9: @PathVariable token 无长度约束

**证据**:
- [ShareLandingController.java](backend/src/main/java/com/zhangspaghetti/babytalk/web/ShareLandingController.java#L68-L90) — `@PathVariable("token") String token` 无 `@Size` / `@Pattern` 约束。
- [CaregiverInviteController.java](backend/src/main/java/com/zhangspaghetti/babytalk/web/CaregiverInviteController.java) — 同样的问题。
- 虽然 SQL 查询已参数化（不存在注入），但攻击者可发送超长 token（如 10MB）导致不必要的数据库查询和内存分配。

**影响**: 轻度 DoS 向量 — 大量超长 token 请求可增加 GC 压力和数据库 I/O。

**修复方案**: 在 `@PathVariable` 上添加 `@Size(max = 64)` 约束（控制器已标注 `@Validated`，约束可直接生效）。

---

#### P3-7: 内部审计查询缺少 LIMIT 子句

**证据**:
- [DistributionRepository.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/DistributionRepository.java#L43-L55) — `listRecentEvents()` 无 `LIMIT`
- [AuthConsentSyncRepository.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java#L193) — `listAuditEntries(accountId)` 无 `LIMIT`
- [MentorRepository.java](backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorRepository.java#L130) — `listAuditRowsByCorrelationId()` 无 `LIMIT`

**当前风险**: **低** — 这些方法**未被任何 Controller 暴露**，仅在测试和内部工具中使用。但随着项目演进，若被错误暴露为 API 端点，将成为 OOM DoS 向量。

**修复方案**: 添加 `LIMIT` 参数（如 `LIMIT 1000`），防止未来误用。

---

### 对抗性审查 — 排除的候选项

| 候选项 | 来源 | 子代理判定 | 验证结果 |
|--------|------|-----------|---------|
| DistributionController @RequestParam 缺少验证 → 日志注入 | Claude | P1 | **❌ 误报** — `DistributionService.normalize()` 在记录/持久化前已对所有参数做 `normalizeOrDefault()` 和 `normalizeKey()` 处理 |
| Invite 状态转换 CHECK CONSTRAINT 缺失 | Claude | P2 | **❌ 重复** — 已在 P1-2 中覆盖（`markInviteAccepted` 有 `WHERE status='pending'` 但调用方不检查返回值） |
| DistributionController 无 @Size 注解 | Claude | P1 | **❌ 过度** — 参数是 optional 的 query params，Service 层已有 allowlist 校验，未匹配的值会走 error 路径 |
| SMS verify race — 重复 session | Codex | P1 | **✅ 已有** — 与 P1-1 重复（markChallengeVerified 缺少 status='pending' 守护） |
| Account 创建非原子 | Codex | P2 | **✅ 已有** — P1-1 的子场景（insertAccount 竞争唯一约束） |
| Invite acceptance race | Codex | P1 | **✅ 已有** — 与 P1-2 重复 |
| Mentor rate limit TOCTOU | Codex | P2 | **✅ 已有** — 与 P1-3 重复 |
| Raw DB error text leaks schema info | Codex | P2 | **❌ 误报** — `ApiExceptionHandler.handleUnexpected()` 返回固定文本 "服务端处理失败。" + 空 details，不泄露 DB 内部信息 |

---

## 更新后的合并建议

| 类型 | 数量 | 要求 |
|------|------|------|
| P1 — 阻塞合并 | 7 | **全部修复后方可合并** |
| P2 — 强烈建议 | 11 | 建议在合并前或紧随合并后修复 |
| P3 — 延后 | 11 | 可在下个迭代处理 |
| Engineering Concern | 5 | 建议在生产部署前解决 |
| Engineering Recommendation | 6 | 中期改进项 |
| Design Issue | 5 | 建议在发布前修复 |
| Design Recommendation | 3 | 设计优化项 |
| Design Observation | 3 | 可延后到 Phase 2 |

**结论不变**: 当前状态 **不建议合并**。需优先修复 7 个 P1 问题。

**全量审查覆盖**:
- ✅ 代码审查 — 后端 + 移动端全量代码审查（P1~P3）
- ✅ Codex 对抗性审查 — 聚焦 8 个核心后端文件（68,435 tokens）
- ✅ Claude 对抗性审查 — 独立验证 + 新发现
- ✅ Flutter UI/UX 审查 — 无障碍、国际化、布局适配
- ✅ 工程架构审查 — 事务边界、分层、运维就绪度、依赖管理
- ✅ 设计审查 — 设计 Token 合规、品牌一致性、社交分享、交互模式
