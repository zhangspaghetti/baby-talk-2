# Flutter Mobile 设计规格实现完成度审计

> 审计日期：2026-05-29
> 审计范围：对照 [docs/superpowers/README.md](../README.md) 收录的页面 / 架构 / 组件设计规格，逐项核对 `mobile/lib` 中的实现是否完成。
> 方法：只读探查（不修改代码），按页面分组并行核对，记录文件证据与缺口。

> ⚠️ 2026-06 复盘更新（本审计快照已部分过时）：审计后多项缺口已闭环，下列结论以代码为准（只读核实）：
> - **Garden V2 🔴→✅**：肥料"待领取/领取/施肥"系统与 UI 已完整实现（`FertilizerStateEntity`/`garden_fertilizer_repository`/`GardenFertilizerNotifier`/`GardenFertilizerPanel`，接入 garden tab + Home 红点 + confetti 庆祝），garden 测试 21/21 绿。详见 specs/2026-06-01-garden-v2-fertilizer-implementation-plan.md。
> - **Growth V2 🔴→✅**：周/月/年多维度已实现（`GrowthPeriod{week,month,year}` + `GrowthBarBucket` 柱状图 + trend + streak + 场景覆盖推荐，`growth_insights_panel.dart`/`growth_insights_notifier.dart`，接入 garden_growth_combined_screen:475），含 `growth_insights_panel_test`/`growth_insights_notifier_test`。
> - **组件规格 🔴→🟢 大体闭环**：13 组件多数已抽到 `app/widgets/`（MentorBubble/EnglishPhrase/AudioButton/InputField/Toast/Card/ScenePill/SegmentTab 等）+ 按钮身份(色/高/圆角)集中到 `app_theme` 的 filled/outlined/text ButtonTheme；私有重复 widget 已清除。详见 /memories/repo/baby-talk-2-component-extraction.md。
> - **InputField 前置条件已满足**：`AppLayoutConstants.smallRadius = 8` 已存在，组件规范里对 InputField 抽取的硬阻断项已闭环，相关 checklist 仅是旧快照。
> - **跨页一致性 🟡→改善**：圆角 token 化(shell/practice/mentor)、大屏限宽(me_screen + settings 系列 `ConstrainedBox(maxContentWidth=430)`) 已统一。
> - **Discover「换一批」🟡→非缺口（已被设计取代）**：discover-design spec §16.3「去掉换一批，用排序替代」明确演进——当前 Discover 的场景内排序(最常用/最新/全部)正是其替代实现，审计"缺换一批"判断已被 spec 自身推翻。
> - **Auth 🟡→✅**：密码登录/注册/确认密码/忘记密码/重置密码/CAPTCHA 全套(`discoverModePasswordLogin`/`discoverModeRegister`/`discoverResetPasswordTitle`/`discoverCaptchaTitle`)已实现。
> - **Growth V1 汇总/场景覆盖 🟡→✅**：`HomeGrowthSummaryCard` + garden_growth_repository §7「累计句数/场景覆盖/坚持天数」里程碑已实现。


## 一、完成度总览

| 规格 | 状态 | 关键证据 | 主要缺口 |
|---|---|---|---|
| **Shell V2**（四 Tab + “我”页） | ✅ 完成 | [app_shell_screen.dart](../../../mobile/lib/features/shell/presentation/app_shell_screen.dart)（4 Tab NavigationBar）、6 个设置子路由、`meSettings`/`meGrowth` 路由齐全 | 无 |
| **架构设计**（分层/状态/数据/路由） | 🟡 大体完成 | feature-first 12 模块、Riverpod providers、GoRouter、`BabyTalkColors` ThemeExtension | Discover/Garden 缺独立 `data/` 层；Garden+Growth 合并未拆分 |
| **Onboarding V21** | 🟡 部分 | 萌芽动画 [app_seed_sprout.dart](../../../mobile/lib/app/widgets/app_seed_sprout.dart)、reaction chips | 缺独立场景选择页、完成页；组件分散在练习页 |
| **Auth V11**（渐进披露） | 🟡 部分 | `/account` 路由、验证码字段、文案齐全 | 缺密码登录/注册/重置密码页、CAPTCHA、渐进披露流程 |
| **Home A/B（B 方向）** | 🟡 部分 | `home-b-care-moment-title`/`-mentor-bubble`/`-scene-card`/`-quick-rescue-row` 全部存在 | A 方向未实现（设计已定 B，属正常）；缺“换一批” |
| **Practice**（当前一句执行） | 🟡 约 70% | phrase-card 优先布局、reaction chips、自动推进、coach tip | “说完了”按钮未独立（用 reaction 隐式保存）；音频失败重试路径未验证 |
| **Discover V1** | 🟡 约 75% | 搜索 + 场景筛选 + 排序 + 空态齐全 | 缺“换一批”随机推荐（spec §9） |
| **Garden V1**（真实练习痕迹） | 🟡 约 60% | patch/flower 卡片、阶段标签 | 缺带宝宝反应的逐条练习痕迹列表 |
| **Garden V2**（单株成长） | 🟡 部分 | 花朵阶段枚举、`calculateFlowerStage()` | 缺肥料“待领取/领取/施肥”系统与 UI |
| **Growth V1**（温暖回顾） | 🟡 约 30% | 日记 + 里程碑预览、周/月聚合 service | 缺汇总卡（N 句/M 场景/D 天）、场景覆盖进度 |
| **Growth V2**（微信读书式多维度） | ✅ 完成 | `GrowthPeriod{week,month,year}`、`GrowthBarBucket`、`GrowthInsightsPanel`、`growth_insights_notifier.dart` | 无 |
| **组件规格**（13 共享组件） | 🟢 大体闭环 | `app/widgets/` 已沉淀 13+ 共享组件，按钮身份收敛到 `app_theme`，私有重复 widget 已清除 | 仅剩少量结构性规范待统一，不是功能缺口 |
| **跨页一致性审查** | 🟡 部分 | `BabyTalkColors` token 体系 | 审查清单中的按钮高/阴影/pill 高未统一收敛 |

## 二、缺口按优先级

### 🔴 高
- 无：审计里标成高优先的功能缺口，当前已全部闭环。

### 🟡 中
- 无：Discover 的“换一批”、Auth、Garden V2、Growth V1/V2 的核心功能都已在代码中实现或被设计替代。

### 🟢 低
- Onboarding：独立场景选择页与完成页拆分。
- Discover/Garden 的展示层结构仍可继续下沉为更独立的 feature/data 边界。
- 跨页样式收敛（按钮高、阴影色、pill 高）。

## 三、已完成的结构性结论

- **核心骨架已落地、可运行**：Shell V2、架构分层、Home B、Practice、Discover、Auth 框架、Garden/Growth 合并页均已实现。
- **`session_bootstrap.dart` 删除合理**：职责迁移到 [app.dart](../../../mobile/lib/app/app.dart) 的 `AppBootState`，`main.dart` 改为先 `AppBootState.load()` 再进 `ProviderScope`，架构 spec 不再引用它。
- **对应特性提交**：`a849df0`（Settings + Shell V2）、`86df8da`（Onboarding V21 + Home B + Practice）、`d37588c`（Discover V1 + Auth V11）、`a44bb78`（+51 测试 + CI/CD）、`1c59637`（路由修复）。
- **InputField 规范核对**：`AppLayoutConstants.smallRadius` 已存在，`components-spec` 里 InputField 的前置常量阻断已不成立；当前剩余的是文档快照陈旧，不是代码缺口。

## 四、备注

- 仓库根级未跟踪的 `lib/main.dart`（373 字节）与 `android/` 为 worktree 根目录意外生成的 Flutter 脚手架产物，与本次迭代无关，建议清理或忽略。
- 临时文件 `tmp_test_out.txt` 不应纳入版本控制。
