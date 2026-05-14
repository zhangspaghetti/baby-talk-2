### Step 1/4: design（软件架构师）

# 技术设计文档

## 1. 背景与目标

### 背景
Baby Talk 2 Phase 1 当前不是缺单点功能，而是存在一组相互放大的结构性问题：
- 同一 feature 同时维护 legacy ViewModel/Provider 与 Riverpod/Notifier，形成双真相源。
- 启动恢复、深链接、分享回流、邀请接受、首页承接等关键链路仍直接修改旧状态对象，导致行为不可预测。
- app 层承担了过多启动编排、会话恢复、路由判定和依赖装配逻辑，成为高频冲突热点。
- 首页、练习页、账号页和全局导航把系统复杂性直接暴露给用户，削弱“现在说一句”的主任务。
- 动态交互层尚未补齐统一状态播报、焦点管理、减少动效控制和关键组件语义，当前不能判定为 WCAG 2.1 AA 合规。
- 质量门禁不足，默认 PR 无法证明主路径稳定性和关键代码覆盖度。

### 目标
在不重写产品的前提下，用一次增量式重构完成“工程复杂性收敛 + 核心体验重构 + 发布门禁建立”的首轮闭环。

### 成功标准
1. 关键主路径只存在单一状态 Owner，不再双写 legacy 状态。
2. Home 与 Practice 首屏分别只服务“继续/开始今天这一句”和“现在说一句”。
3. 4-tab、Drawer、Mentor FAB、账号同步页的职责边界稳定且可解释。
4. 动态交互层满足发布前无障碍基线，完成屏幕阅读器、焦点、减少动效与关键语义支持。
5. 默认 PR 门禁能覆盖 analyze、targeted tests、quick integration pack、coverage 阈值。
6. 后续 feature 可通过 application/contract 边界扩展，而不是继续打穿 app 层或其他 feature 内部实现。

## 2. 方案概述
整体方案采用“模块化单体 + 单一状态主栈 + 轻量 application/coordinator 层 + A11y/service 护栏 + CI 质量门禁”的组合设计。核心思路是：保留现有 Flutter 应用主体和后端依赖不变，把 app 层收口为 composition root；将启动恢复、首页编排、练习状态机、账号同步分层、动态无障碍与错误治理下沉到 application 和 shared contract 层；同时用 Riverpod/Notifier 统一关键链路状态，并通过 ADR、测试门禁和手动无障碍回归把治理结果固化下来。

## 3. 架构设计

### 3.1 组件图

```text
+-------------------------------------------------------------+
|                         RootShell                           |
|                (boot, router, root widget only)             |
+-------------------------+-----------------------------------+
                          |
                          v
+-------------------------------------------------------------+
|                    Application Layer                        |
|  BootCoordinator   HomeOrchestrator   PracticeCoordinator   |
|  SyncSettingsCoordinator   AccessibilityServices            |
+-------------------------+-----------------------------------+
                          |
          +---------------+---------------+
          |                               |
          v                               v
+---------------------------+    +----------------------------+
|      Shared Contracts     |    |    Feature Facades         |
| TypedRouteArgs            |    | PracticeFacade             |
| ViewState DTOs            |    | MentorFacade               |
| ErrorEnvelope             |    | ShareFacade                |
| AccessibilityEvent        |    | GrowthFacade               |
+---------------------------+    +----------------------------+
          |                               |
          +---------------+---------------+
                          |
                          v
+-------------------------------------------------------------+
|                    Infrastructure Layer                     |
| Repositories | Local Store | Audio/TTS/ASR | Network | Logs |
+-------------------------------------------------------------+
```

### 3.2 分层职责
- app/composition-root
  - 仅保留依赖注入、根部路由挂接、根 widget 装配。
  - 不再直接承载业务规则、状态恢复判定或页面编排逻辑。
- application/boot
  - `BootCoordinator`：统一冷启动、热重入、会话恢复入口。
  - `SessionRestoreService`：读取本地恢复上下文。
  - `ReentryDecisionService`：根据恢复 token、分享回流、登录态决定目标路由。
- application/home
  - `HomeOrchestrator`：将分散的任务、提示、继续逻辑组装为单一 HomeViewState。
  - `ContinueTodayUseCase`：作为首页主 CTA 的唯一进入点。
- application/practice
  - `PracticeSessionCoordinator`：协调 phrase、播放、录音、Mentor 建议、下一步状态。
  - `PlaybackCommand`、`RecordingCommand`、`MentorAssistCommand`：动作显式化，避免 UI 直接调 repository。
- application/account_sync
  - `SyncSettingsCoordinator`：拆分登录同步、共享协作、高风险设置三个 section。
  - `ShareConsentUseCase`：统一共享同意、撤回与账号删除前校验。
- application/accessibility
  - `StatusAnnouncementService`：所有动态状态统一播报。
  - `FocusReturnController`：负责 Drawer、BottomSheet、Mentor 面板开闭焦点生命周期。
  - `MotionPreferenceService`：读系统减少动效设置并驱动动画降级。
- shared/contracts
  - `TypedRouteArgs`：替换 dynamic route args。
  - `ViewState DTOs`：限制 UI 只消费只读数据。
  - `ErrorEnvelope`：统一错误语义和日志键。
  - `AccessibilityEvent`：规范播报事件来源和优先级。
- feature bounded contexts
  - `practice`、`mentor`、`household`、`share`、`growth` 只对外暴露 facade/DTO。
  - 禁止跨 feature 直接引用内部 presentation 类型。

### 3.3 数据流
1. App 启动
   - `RootShell` 初始化依赖。
   - `BootCoordinator` 读取本地 session、share invite、resume token。
   - `ReentryDecisionService` 输出 `NavigationIntent`。
   - Router 根据 intent 进入 Home、Practice、AccountSync 或恢复页。
2. 首页继续链路
   - `HomeOrchestrator` 聚合今日 phrase、progress、resume 状态。
   - UI 只渲染 `HomeTaskCardDTO`。
   - 用户点击主 CTA 后进入 `ContinueTodayUseCase`。
   - `ContinueTodayUseCase` 统一调度到 `PracticeSessionCoordinator`。
3. 练习链路
   - `PracticeSessionCoordinator` 驱动单一 `PracticeSessionNotifier`。
   - 播放、录音、Mentor 请求、错误恢复全部通过 command 进入。
   - 状态变化以 `PracticeSessionState` 输出给 widget。
4. 动态反馈链路
   - `PracticeSessionCoordinator`、`SyncSettingsCoordinator`、网络层、音频层在关键状态变更时发布 `AccessibilityEvent`。
   - `StatusAnnouncementService` 根据事件优先级向屏幕阅读器播报。
   - 弹层、切页、面板开闭时由 `FocusReturnController` 维护焦点。
5. 账号与同步
   - `SyncSettingsCoordinator` 将信息分为 `AuthSectionViewState`、`ShareSectionViewState`、`RiskActionSectionViewState`。
   - 高风险动作必须先进入确认 command，再落到基础设施适配器。

### 3.4 关键接口定义

#### BootCoordinator
```dart
abstract class BootCoordinator {
  Future<NavigationIntent> resolveStartup();
}
```

#### ContinueTodayUseCase
```dart
abstract class ContinueTodayUseCase {
  Future<PracticeLaunchResult> execute(HomeTaskCardDTO task);
}
```

#### PracticeSessionCoordinator
```dart
abstract class PracticeSessionCoordinator {
  PracticeSessionState get currentState;
  Future<void> dispatch(PracticeCommand command);
  Stream<AccessibilityEvent> accessibilityEvents();
}
```

#### StatusAnnouncementService
```dart
abstract class StatusAnnouncementService {
  Future<void> announce(AccessibilityEvent event);
}
```

#### SyncSettingsCoordinator
```dart
abstract class SyncSettingsCoordinator {
  Future<SyncAccountViewState> load();
  Future<void> dispatch(SyncSettingsCommand command);
}
```

## 4. 数据模型

### 4.1 核心状态对象

#### AppBootState
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| phase | enum(coldStart, restoring, resolved, blocked) | 启动阶段 |
| hasSession | bool | 是否存在恢复中的 session |
| resumeToken | String? | 恢复 token |
| inviteToken | String? | 邀请/分享回流 token |
| blockingIssue | ErrorEnvelope? | 阻塞启动的问题 |

#### NavigationIntent
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| destination | enum(home, practice, accountSync, shareAccept, recovery) | 跳转目标 |
| source | enum(coldStart, resume, deepLink, share, invite, auth) | 来源 |
| requiresAuth | bool | 是否需要先登录 |
| payload | TypedRouteArgs? | 类型安全参数 |

#### HomeTaskCardDTO
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| taskType | enum(startToday, continueToday, recoverPractice) | 首页主任务类型 |
| phrase | String | 当前短语 |
| progressLabel | String | 简化后的进度文案 |
| primaryActionLabel | String | 主 CTA 文案 |
| secondaryHint | String? | 次要提示 |

#### PracticeSessionState
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| phrase | String | 当前练习短语 |
| meaning | String | 中文义 |
| playbackStatus | enum(idle, loading, playing, failed, completed) | 播放状态 |
| recordingStatus | enum(idle, recording, processing, failed, completed) | 录音状态 |
| mentorState | enum(hidden, available, suggesting, chatting) | Mentor 状态 |
| nextStep | enum(play, record, retry, continue) | 用户当前应做动作 |
| errorState | ErrorEnvelope? | 当前错误 |

#### SyncAccountViewState
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| authState | enum(loggedOut, loggedIn, syncing, syncFailed) | 登录/同步状态 |
| shareState | enum(notShared, shared, pendingConsent, revoked) | 共享状态 |
| riskActions | List<RiskActionItem> | 高风险动作 |
| helperText | String? | 用户说明文案 |

#### AccessibilityEvent
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| type | enum(status, error, completion, navigation, panel) | 事件类型 |
| message | String | 播报文案 |
| priority | enum(politeness, assertive) | 播报优先级 |
| focusTarget | String? | 需要回焦的语义目标 |

#### ErrorEnvelope
| 字段 | 类型 | 说明 |
| --- | --- | --- |
| code | String | 统一错误码 |
| category | enum(offline, unauthorized, dataCorruption, rateLimited, emptyState, unknown) | 错误类别 |
| userMessage | String | 用户可见文案 |
| recoverability | enum(retryable, blocking, manualAction) | 恢复方式 |
| rawCause | String? | 原始错误摘要 |
| telemetryKey | String | 日志聚合键 |

## 5. 关键技术决策

### 决策 1：状态主栈统一为 Riverpod/Notifier
- 选 A：Riverpod/Notifier 统一主栈。
- 不选 B：继续兼容 legacy ViewModel/Provider 双写。
- 原因：当前最大的不可控风险来自双真相源，继续兼容只会推迟问题并增加迁移面。
- Tradeoff：短期内要承担一次性迁移成本和回归压力，但能换取可测试和可维护的长期收益。

### 决策 2：保留模块化单体，不立即拆包/拆服务
- 选 A：在 Flutter 客户端内建立 application/coordinator/shared-contract 边界。
- 不选 B：立即做 feature package 化或服务化改造。
- 原因：当前核心问题是边界失效和状态混乱，不是部署单元不够多。
- Tradeoff：短期无法获得物理隔离收益，但能降低重构风险并加快首轮整治落地。

### 决策 3：app 层只做 composition root
- 选 A：将 boot、router、root widget 之外的逻辑下沉。
- 不选 B：继续在 app.dart 叠加分支和 wiring。
- 原因：app 层已是高冲突热点，继续堆逻辑会使任何主路径修改都回到根部。
- Tradeoff：需要新增协调器和 contract，但整体复杂度更可定位。

### 决策 4：动态无障碍能力走统一 service，而非页面各自实现
- 选 A：`StatusAnnouncementService` + `FocusReturnController` + `MotionPreferenceService`。
- 不选 B：每个页面自己调用 semantics/focus API。
- 原因：问题集中在“动态状态与面板行为不一致”，统一服务更容易做规则和回归。
- Tradeoff：需要定义事件协议，但能减少重复实现和遗漏。

### 决策 5：PR 门禁采用 quick pack + nightly + pre-release 三层模型
- 选 A：默认 PR 轻量快速、夜间补全、发布前实机兜底。
- 不选 B：所有 PR 跑全量 integration/E2E。
- 原因：全量门禁会显著拖慢开发节奏，且很多无障碍场景仍需手动验证。
- Tradeoff：需要维护分层测试策略，但更符合团队节奏与风险控制。

## 6. API 设计

本次整治以客户端架构治理为主，不引入大规模新后端域模型，但需要补齐若干内部 contract API 和对现有后端接口的调用契约。

### 6.1 内部应用层 Contract API

#### 获取启动决策
- URL: internal://boot/resolve-startup
- Method: CALL
- Request:
```json
{
  "resumeToken": "optional-string",
  "inviteToken": "optional-string",
  "hasLocalSession": true
}
```
- Response:
```json
{
  "destination": "practice",
  "source": "resume",
  "requiresAuth": false,
  "payload": {
    "sessionId": "sess_123"
  }
}
```

#### 首页主任务组装
- URL: internal://home/build-primary-task
- Method: CALL
- Request:
```json
{
  "userId": "u_123",
  "todayContext": "daily_home"
}
```
- Response:
```json
{
  "taskType": "continueToday",
  "phrase": "Good morning, baby",
  "progressLabel": "今天第 2 句",
  "primaryActionLabel": "继续今天这一句",
  "secondaryHint": "先听一遍，再跟着说"
}
```

#### 练习动作分发
- URL: internal://practice/dispatch
- Method: CALL
- Request:
```json
{
  "command": "startRecording",
  "sessionId": "sess_123",
  "context": {
    "phraseId": "phrase_456"
  }
}
```
- Response:
```json
{
  "accepted": true,
  "nextStep": "record",
  "announcement": "开始录音，请对着宝宝说这一句"
}
```

### 6.2 对现有后端接口的外部调用约束

#### 同步账户状态
- URL: /api/account/sync-status
- Method: GET
- 说明：仅由 `SyncSettingsCoordinator` 调用，UI 不直接调用 repository。
- Response 示例：
```json
{
  "authState": "logged_in",
  "syncState": "ok",
  "shareState": "shared"
}
```

#### 提交共享同意
- URL: /api/account/share-consent
- Method: POST
- Request:
```json
{
  "consent": true,
  "scope": "household"
}
```
- Response:
```json
{
  "status": "accepted",
  "effectiveAt": "2026-05-11T10:00:00Z"
}
```

#### 上传练习结果
- URL: /api/practice/session-results
- Method: POST
- Request:
```json
{
  "sessionId": "sess_123",
  "phraseId": "phrase_456",
  "playbackCompleted": true,
  "recordingCompleted": true
}
```
- Response:
```json
{
  "status": "stored",
  "nextPhraseId": "phrase_789"
}
```

## 7. 非功能需求

### 性能目标
1. Home 主 CTA 数据组装在本地已有缓存时 P95 < 150ms。
2. Practice 内部动作分发到 UI 状态更新 P95 < 100ms。
3. 启动恢复决策在本地上下文可用时 P95 < 300ms。
4. 默认 quick integration pack 控制在 10-15 分钟内。

### 可用性与容错
1. 关键动作在 offline、rate limit、auth 失效时必须输出 `ErrorEnvelope`，不可静默吞错。
2. 关键面板必须具备可恢复关闭路径和焦点返回。
3. 分享同意、账号删除、撤回同意等高风险动作必须显式确认。
4. PR 门禁失败直接阻止合并，nightly 失败触发告警与 triage。

### 可扩展性
1. 新 feature 只能通过 facade 和 application contract 进入主路径。
2. 新状态模型必须经过 ADR 或最少 architecture note，禁止继续引入双栈状态。
3. a11y 动态状态统一走事件协议，便于后续接入更多组件。

### 可观测性
1. 所有关键失败记录结构化日志：`telemetryKey`、`source`、`action`、`recoverability`。
2. 启动恢复、练习完成、同步失败、分享同意失败纳入关键监控事件。
3. 手动无障碍回归结果和 quick pack 结果归档到发布工件。

### 安全
1. 高风险动作必须校验登录态、最新 consent 状态和幂等性。
2. 恢复 token、邀请 token 不能在日志中明文落盘。
3. 同步、共享、账号操作统一做错误分类和最小化返回。

## 8. 里程碑与排期建议

### 里程碑 M1：范围冻结与护栏（1 周）
- ADR 定稿：状态主栈、路由 contract、错误模型、无障碍门禁。
- 完成状态写入口审计。
- 建立默认 PR 门禁与覆盖率初始阈值。

### 里程碑 M2：根部收口与边界建立（1 周）
- app 层收口为 composition root。
- 建立 BootCoordinator、HomeOrchestrator、TypedRouteArgs、ErrorEnvelope 等基线模块。

### 里程碑 M3：核心状态迁移（1.5-2 周）
- boot/reentry/home/practice/share/invite 核心链路迁移到单一 Notifier。
- 删除镜像 API 和关键 legacy 写入口。

### 里程碑 M4：核心体验重构（1-1.5 周）
- 首页与练习页首屏重构。
- 4-tab、Drawer、Mentor FAB、账号同步分层定稿。
- 统一术语和语义标签。

### 里程碑 M5：无障碍与清理闭环（1-1.5 周）
- 动态播报、焦点规则、减少动效落地。
- 错误分类、结构化日志、热点文件拆分。
- 完成发布前手动无障碍回归与主路径复测。

### 总排期建议
- 2 名移动端工程师 + 1 名 QA + 1 名产品/设计 owner：约 6 周。
- 若仅 1 名移动端工程师主导：约 9-10 周。

### 风险前置建议
1. 第 2 周至第 5 周对 boot/home/practice/share 相关需求启用小范围 feature freeze。
2. 为首页与导航改造保留 feature flag，确保问题可局部回退。
3. 首轮 coverage threshold 采用阶段式抬升，避免一刀切阻塞全部迭代。
