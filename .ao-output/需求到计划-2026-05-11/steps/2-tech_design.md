### Step 2/3: tech_design（软件架构师）

# 技术方案

## 1. 技术方案概述
以 Riverpod/Notifier 作为唯一状态主栈，在现有 Flutter 应用上补 application/coordinator 层、可访问性状态播报层和质量门禁层；通过“先收口根部，再治理主路径，再固化门禁”的方式，完成一次增量式重构，而不是重写。

## 2. 系统架构设计
### 模块划分
- app/composition-root：只保留 boot、router、root shell 三类职责。
- application/boot：BootCoordinator、SessionRestoreService、ReentryDecisionService，负责启动恢复和重入判定。
- application/home：HomeOrchestrator、ContinueTodayUseCase，负责首页主 CTA 与继续练习编排。
- application/practice：PracticeSessionCoordinator、PlaybackCommand、RecordingCommand、MentorAssistCommand，负责练习主流程与状态机。
- application/account-sync：SyncSettingsCoordinator、ShareConsentUseCase，负责登录、同步、共享与高风险动作分层。
- application/accessibility：StatusAnnouncementService、FocusReturnController、MotionPreferenceService，负责动态播报、焦点返回、减少动效。
- shared/contracts：TypedRouteArgs、ErrorEnvelope、ViewState DTO、FeatureFacade 接口，定义跨模块边界。
- feature bounded contexts：practice、mentor、household、share、growth 通过 facade 和 DTO 协作，不直接引用彼此内部 presentation 类型。
- infrastructure：repository、local store、network、audio、ASR/TTS、analytics 适配器，统一作为下层实现。

### 接口设计与数据流
1. App 启动：RootShell -> BootCoordinator -> SessionRestoreService/ReentryDecisionService -> Router 决定首页、恢复页或练习页。
2. 首页继续练习：HomeOrchestrator 生成 HomeViewState -> 用户触发主 CTA -> ContinueTodayUseCase -> PracticeSessionCoordinator。
3. 练习流：PracticeSessionCoordinator 驱动单一 Notifier -> 输出 PracticeSessionState/ViewState -> UI 只读渲染并派发 command。
4. 动态反馈：练习状态变化、离线重连、录音播放、错误完成等事件统一进入 StatusAnnouncementService，并在必要时触发 FocusReturnController。
5. 账号与同步：SyncSettingsCoordinator 将登录、同步、共享、高风险设置拆分成独立 section，减少同屏决策负担。
6. CI 与 QA：默认 PR 跑 analyze、unit/widget、quick integration pack、coverage threshold；nightly 跑全量 integration；发布前追加手动无障碍实测。

## 3. 技术选型及理由
1. 状态管理：选 Riverpod/Notifier，原因是当前已存在迁移基础、可测试性更强、便于统一 command 和 view state；放弃继续双栈并存。
2. 架构模式：选模块化单体 + 轻量 application/coordinator，而不是大规模重写或立即拆包；优先在现有代码内建立清晰边界，控制迁移风险。
3. 路由：保留现有路由基础设施，但强制引入 typed route contract，逐步淘汰 dynamic route args 和 UI 直连路由细节。
4. 测试门禁：使用 Flutter 现有 test/integration_test 体系扩展 quick pack 与 coverage 阈值，而不是单独引入新测试平台，降低落地成本。
5. 无障碍：基于 Semantics、Focus、系统减少动效能力补统一服务层，避免各组件各写一套逻辑。
6. 决策记录：新增 ADR，明确状态主栈、路由契约、错误分类、无障碍门禁四类核心决策，避免后续再混用。

## 4. 数据模型设计
- AppBootState：coldStart、restoringSession、reentryTarget、blockingIssue。
- HomeTaskCardDTO：taskType、phrase、progress、primaryAction、secondaryHint。
- PracticeSessionState：phrase、playbackStatus、recordingStatus、mentorState、nextStep、errorState。
- NavigationIntent：destination、source、requiresAuth、resumeToken。
- AccessibilityEvent：type、message、priority、focusTarget。
- SyncAccountViewState：authState、syncState、shareState、riskActions。
- ErrorEnvelope：code、userMessage、recoverability、rawCause、telemetryKey。

## 5. 关键技术难点及解决思路
1. 双真相源迁移：先做状态写入口审计，再按“迁一个、删一个”策略完成 boot/reentry/home/practice/share 核心链路切换。
2. 根部热点收口：先提取 coordinator 和 contract，再把 app.dart 退化为 wiring，不在根部继续新增业务判断。
3. UX 聚焦与存量功能兼容：通过 view state 和渐进披露保留必要能力，但默认视图只暴露单一主任务。
4. 动态无障碍一致性：所有状态变化走统一 announcement service，禁止页面各自拼播报文案和焦点跳转。
5. 回归成本上升：通过 quick integration pack 保证主路径稳定，通过 nightly 和手动 a11y 清单覆盖自动化盲区。

## 6. 非功能性需求方案
1. 性能：避免在首页和练习页引入额外的同步 I/O；协调器只做编排，重计算下沉到 service/repository。
2. 安全与一致性：共享同意、账号删除、撤回同意等高风险操作独立分组并保留显式确认；错误分类区分 offline、unauthorized、data corruption、empty state。
3. 可扩展性：bounded context 只暴露 contract，后续新增 feature 优先挂在 application 层，不再直接打穿其他 feature。
4. 可观测性：关键失败统一打结构化日志，记录错误码、恢复动作和上下文来源，便于 QA 与线上排障。
5. 可访问性：关键路径以 WCAG 2.1 AA 为最低门槛，自动化覆盖语义与部分 touch target，手动验证覆盖动态场景和辅助技术差异。

## 7. 技术风险评估
1. 隐藏的 legacy 写入口可能比审计结果更多，导致迁移过程中出现漏网状态回写。
2. 导航和首页改版会改变用户路径，如缺少产品确认容易引发范围争议。
3. 屏幕阅读器、减少动效在 Android/iOS 上表现不完全一致，需要分别验证。
4. 门禁增加后 CI 时长会变长，需要控制 quick pack 在团队可接受窗口内。
5. 如果不在迁移周期内冻结相关核心 flow，新需求继续接入 legacy 层会抵消本次治理收益。
