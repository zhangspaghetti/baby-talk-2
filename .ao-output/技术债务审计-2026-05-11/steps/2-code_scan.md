### Step 2/4: code_scan（代码审查员）

整体看，mobile 端的 feature 划分和 repository 边界仍然清楚，但代码质量层面的主要债务已经从单点实现问题，演变成了迁移过程中累积的系统性复杂度：旧的 ViewModel + Provider 与新的 Notifier + Riverpod 同时存在，入口层和多个页面为兼容两套状态源引入了重复实现、dynamic 桥接和静默降级的错误处理。

最主要的问题有两类：
1. 状态管理双轨并存，导致同一业务能力同时维护两套对象图与生命周期。
2. 多个关键文件已经成长为超大类或超大入口文件，复杂度和回归成本都在持续上升。

做得好的地方：
- feature 内仍保持了 data / domain / presentation 的基本边界，像 repository、local store、api service 的分层是清晰的，见 [mobile/lib/app/providers/repository_providers.dart](mobile/lib/app/providers/repository_providers.dart#L1)。
- 旧屏幕至少显式加了废弃标记，说明团队已经识别到迁移目标，见 [mobile/lib/features/shell/presentation/screens/garden_screen.dart](mobile/lib/features/shell/presentation/screens/garden_screen.dart#L18) 和 [mobile/lib/features/shell/presentation/screens/growth_screen.dart](mobile/lib/features/shell/presentation/screens/growth_screen.dart#L10)。

#### 🔴 阻塞项

- 🔴 状态管理双轨并存，已经形成双真相源。
  影响：同一功能在旧 Provider/ViewModel 和新 Riverpod/Notifier 中各维护一份状态与生命周期，修复缺陷或增加字段时需要双写，容易出现页面读旧状态、流程读新状态的分裂。
  证据：[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L397)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L405)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L408)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L413)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L422) 仍创建旧 ViewModel；同时 [mobile/lib/app/app.dart](mobile/lib/app/app.dart#L517)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L521)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L531)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L535)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L538) 又覆写新 Notifier。旧页面仍在消费旧对象，如 [mobile/lib/features/mentor/presentation/widgets/mentor_panel_sheet.dart](mobile/lib/features/mentor/presentation/widgets/mentor_panel_sheet.dart#L19) 和 [mobile/lib/features/shell/presentation/screens/garden_screen.dart](mobile/lib/features/shell/presentation/screens/garden_screen.dart#L26)。新页面则直接消费 Notifier，如 [mobile/lib/features/shell/presentation/app_shell_screen.dart](mobile/lib/features/shell/presentation/app_shell_screen.dart#L223)。
  建议修复方案：按 feature 逐个切换到单一状态栈；先让 app.dart 只装配一种状态对象，再删除桥接 widget 和旧 ViewModel，避免长期并存。

- 🔴 深链接 / 回流编排仍硬绑定旧 ViewModel，迁移边界不闭合。
  影响：分享回流、邀请接受等关键流程仍通过旧 Provider 树查找 HouseholdViewModel、PracticeContinuityViewModel、GardenGrowthViewModel，导致 Riverpod 无法成为真正唯一入口，迁移后极易出现“UI 看的是新状态，回流流程改的是旧状态”。
  证据：[mobile/lib/app/app_reentry_orchestrator.dart](mobile/lib/app/app_reentry_orchestrator.dart#L25)、[mobile/lib/app/app_reentry_orchestrator.dart](mobile/lib/app/app_reentry_orchestrator.dart#L26)、[mobile/lib/app/app_reentry_orchestrator.dart](mobile/lib/app/app_reentry_orchestrator.dart#L27) 把查找类型定义成旧 ViewModel；[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L280)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L281)、[mobile/lib/app/app.dart](mobile/lib/app/app.dart#L282) 注入 _lookupViewModel；真正执行也走旧对象，[mobile/lib/app/app_reentry_orchestrator.dart](mobile/lib/app/app_reentry_orchestrator.dart#L208)、[mobile/lib/app/app_reentry_orchestrator.dart](mobile/lib/app/app_reentry_orchestrator.dart#L242)。
  建议修复方案：把 orchestrator 依赖改成 use case / command 接口，而不是具体 ViewModel；如果必须过渡，至少在最外层做一次适配，不要让核心回流逻辑知道旧状态类。

#### 🟡 建议项

- 🟡 ViewModel 与 Notifier 成对复制，重复代码已经可见。
  影响：同一业务规则会在两份实现中漂移，维护者很难确认修复是否已覆盖全部分支；mentor/account 这类大类尤其容易出现“一边修了另一边没修”。
  证据：[mobile/lib/features/account/presentation/account_notifier.dart](mobile/lib/features/account/presentation/account_notifier.dart#L12) 明确写着 replaces AccountViewModel 且 API intentionally mirrors the old ViewModel，而旧类 [mobile/lib/features/account/presentation/account_view_model.dart](mobile/lib/features/account/presentation/account_view_model.dart#L12) 仍在；同类替代关系也存在于 [mobile/lib/features/household/presentation/household_notifier.dart](mobile/lib/features/household/presentation/household_notifier.dart#L12)、[mobile/lib/features/onboarding/presentation/onboarding_notifier.dart](mobile/lib/features/onboarding/presentation/onboarding_notifier.dart#L14)、[mobile/lib/features/practice/presentation/practice_continuity_notifier.dart](mobile/lib/features/practice/presentation/practice_continuity_notifier.dart#L14)、[mobile/lib/features/practice/presentation/garden_growth_notifier.dart](mobile/lib/features/practice/presentation/garden_growth_notifier.dart#L9)、[mobile/lib/features/mentor/presentation/mentor_notifier.dart](mobile/lib/features/mentor/presentation/mentor_notifier.dart#L30)。
  建议修复方案：不要继续复制 API；要么抽出共享控制器/状态机，要么尽快完成单边迁移并删掉旧类。

- 🟡 桥接组件通过 dynamic 接口同时兼容两套状态对象，类型系统已经失效。
  影响：字段重命名、返回值变化、空值语义变化都无法在编译期暴露，回归只能靠人工点页面；同时“viewModel”这个命名已经不再表示真实类型，降低阅读效率。
  证据：[mobile/lib/features/share/presentation/widgets/share_callout_card.dart](mobile/lib/features/share/presentation/widgets/share_callout_card.dart#L7) 说明同时接受 ShareViewModel / ShareNotifier，且 [mobile/lib/features/share/presentation/widgets/share_callout_card.dart](mobile/lib/features/share/presentation/widgets/share_callout_card.dart#L22) 直接使用 dynamic；相同模式还出现在 [mobile/lib/features/household/presentation/widgets/household_shared_context_card.dart](mobile/lib/features/household/presentation/widgets/household_shared_context_card.dart#L255)、[mobile/lib/features/household/presentation/widgets/household_invite_card.dart](mobile/lib/features/household/presentation/widgets/household_invite_card.dart#L23)、[mobile/lib/features/practice/presentation/widgets/home_growth_summary_card.dart](mobile/lib/features/practice/presentation/widgets/home_growth_summary_card.dart#L13)、[mobile/lib/features/practice/presentation/widgets/home_garden_mini_entry.dart](mobile/lib/features/practice/presentation/widgets/home_garden_mini_entry.dart#L15)。命名混乱的直接例子见 [mobile/lib/features/account/presentation/screens/account_entry_screen.dart](mobile/lib/features/account/presentation/screens/account_entry_screen.dart#L318)，这里从 householdNotifierProvider 读取的对象仍命名为 householdViewModel。
  建议修复方案：定义小而稳定的只读接口或 ViewState DTO，让 widget 依赖显式协议，而不是 dynamic；同时把变量名改成 notifier / state / controller 这类真实抽象。

- 🟡 入口和仓储文件已经膨胀成高复杂度热点。
  影响：单文件承担过多职责，测试粒度变粗，任何修改都容易触发大面积回归和冲突。
  证据：扫描结果显示 [mobile/lib/app/app.dart](mobile/lib/app/app.dart) 约 1059 行，既负责启动装配、双 DI、路由、回流编排，也负责 provider override；[mobile/lib/features/practice/data/repositories/practice_repository.dart](mobile/lib/features/practice/data/repositories/practice_repository.dart) 约 1169 行，方法从 [mobile/lib/features/practice/data/repositories/practice_repository.dart](mobile/lib/features/practice/data/repositories/practice_repository.dart#L259) 一直铺到 [mobile/lib/features/practice/data/repositories/practice_repository.dart](mobile/lib/features/practice/data/repositories/practice_repository.dart#L802)，同时覆盖目录加载、事件记录、恢复、汇总、导入、生命周期关闭；[mobile/lib/features/account/data/repositories/account_repository.dart](mobile/lib/features/account/data/repositories/account_repository.dart) 约 905 行；[mobile/lib/features/mentor/presentation/mentor_view_model.dart](mobile/lib/features/mentor/presentation/mentor_view_model.dart) 约 931 行。
  建议修复方案：按用例拆分，至少把 app.dart 中的启动引导、路由、reentry、状态装配拆开；把 PracticeRepository 拆成 event log、restore、catalog、sync summary 等更窄的服务。

- 🟡 错误处理大量静默降级，真实故障被折叠成“正常默认值”。
  影响：插件故障、数据损坏、格式异常和本地 I/O 问题会被伪装成“在线”“已登出”“空摘要”“忽略失败”，既不利于定位问题，也会误导 UI 行为。
  证据：[mobile/lib/app/providers/repository_providers.dart](mobile/lib/app/providers/repository_providers.dart#L153) 中 connectivityChecker 对 MissingPluginException 和任意异常都返回 true；[mobile/lib/features/account/data/repositories/account_repository.dart](mobile/lib/features/account/data/repositories/account_repository.dart#L436) 遇到 FormatException 只写入泛化状态；[mobile/lib/features/account/data/repositories/account_repository.dart](mobile/lib/features/account/data/repositories/account_repository.dart#L681) 本地快照解析失败直接回 signedOut；[mobile/lib/features/account/data/repositories/account_repository.dart](mobile/lib/features/account/data/repositories/account_repository.dart#L689) 任何同步摘要读取失败都回空 PracticeSyncSummary；[mobile/lib/features/practice/data/repositories/practice_repository.dart](mobile/lib/features/practice/data/repositories/practice_repository.dart#L810) 安装 ID 创建失败静默回退；[mobile/lib/features/practice/presentation/screens/practice_session_screen.dart](mobile/lib/features/practice/presentation/screens/practice_session_screen.dart#L92) TTS 失败被完全吞掉。
  建议修复方案：保留原始错误原因并上报到统一 telemetry/logger；把“读不到”和“确实为空”区分开；仅对明确可恢复的异常做降级。

- 🟡 mentor 迁移停在半路，新旧实现同时存在但主路径仍旧走旧实现。
  影响：团队已经为 Riverpod 付出了迁移成本，但核心交互仍走旧对象，等于同时维护两套实现却没有得到统一收益。
  证据：[mobile/lib/app/providers/repository_providers.dart](mobile/lib/app/providers/repository_providers.dart#L277) 已经提供 mentorNotifierProvider，但入口仍创建旧的 [mobile/lib/app/app.dart](mobile/lib/app/app.dart#L413) MentorViewModel；真实 UI 也仍在消费旧类型，如 [mobile/lib/features/mentor/presentation/widgets/mentor_panel_sheet.dart](mobile/lib/features/mentor/presentation/widgets/mentor_panel_sheet.dart#L19)、[mobile/lib/features/mentor/presentation/widgets/mentor_panel_sheet.dart](mobile/lib/features/mentor/presentation/widgets/mentor_panel_sheet.dart#L62)、[mobile/lib/features/mentor/presentation/widgets/mentor_suggestion_tab.dart](mobile/lib/features/mentor/presentation/widgets/mentor_suggestion_tab.dart#L18)。
  建议修复方案：优先挑一条完整用户路径把 mentor 全量切到 Notifier；如果短期不迁移，就先移除未接入的新 provider，避免形成伪完成状态。

- 🟡 已废弃屏幕仍保留在主代码树中，形成近似死代码。
  影响：增加搜索噪音，拖慢新人理解成本，也会继续拉高“必须双兼容”的心理负担。
  证据：[mobile/lib/features/shell/presentation/screens/garden_screen.dart](mobile/lib/features/shell/presentation/screens/garden_screen.dart#L19) 和 [mobile/lib/features/shell/presentation/screens/growth_screen.dart](mobile/lib/features/shell/presentation/screens/growth_screen.dart#L11) 都已标记 Deprecated；符号用量分析只返回定义本身，没有任何调用点；当前 live shell 使用的是 [mobile/lib/features/shell/presentation/app_shell_screen.dart](mobile/lib/features/shell/presentation/app_shell_screen.dart#L101) HomeScreen 与 [mobile/lib/features/shell/presentation/app_shell_screen.dart](mobile/lib/features/shell/presentation/app_shell_screen.dart#L105) GardenGrowthCombinedScreen。
  建议修复方案：确认无测试依赖后直接删除；如果还要短暂保留，移动到明确的 legacy 目录并附带移除截止时间。

#### 💭 小改进

- 💭 主路径页面还留有可点击但未实现的 TODO。
  影响：问题不致命，但会让 QA 和用户遇到“有按钮没结果”的体验断层。
  证据：[mobile/lib/features/shell/presentation/screens/garden_growth_combined_screen.dart](mobile/lib/features/shell/presentation/screens/garden_growth_combined_screen.dart#L326) 的“查看全部日记”未接路由；[mobile/lib/features/shell/presentation/screens/garden_growth_combined_screen.dart](mobile/lib/features/shell/presentation/screens/garden_growth_combined_screen.dart#L359) 的“查看全部里程碑”也未接路由。
  建议修复方案：要么尽快补齐路由，要么在未实现前隐藏 CTA，避免把 TODO 暴露给用户流程。

如果只选一个最高杠杆切入点，我建议先把一个完整 feature 彻底迁到单一状态栈，例如 account 或 mentor。只要双轨状态还在，其他重构大概率都会被兼容层吞掉收益。