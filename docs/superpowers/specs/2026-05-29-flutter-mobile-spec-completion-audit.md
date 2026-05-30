# Flutter Mobile 设计规格实现完成度审计

> 审计日期：2026-05-29
> 审计范围：对照 [docs/superpowers/README.md](../README.md) 收录的页面 / 架构 / 组件设计规格，逐项核对 `mobile/lib` 中的实现是否完成。
> 方法：只读探查（不修改代码），按页面分组并行核对，记录文件证据与缺口。

> ⚠️ 2026-06 复盘更新（本审计快照已部分过时）：审计后多项缺口已闭环，下列结论以代码为准（只读核实）：
> - **Garden V2 🔴→✅**：肥料"待领取/领取/施肥"系统与 UI 已完整实现（`FertilizerStateEntity`/`garden_fertilizer_repository`/`GardenFertilizerNotifier`/`GardenFertilizerPanel`，接入 garden tab + Home 红点 + confetti 庆祝），garden 测试 21/21 绿。详见 specs/2026-06-01-garden-v2-fertilizer-implementation-plan.md。
> - **Growth V2 🔴→✅**：周/月/年多维度已实现（`GrowthPeriod{week,month,year}` + `GrowthBarBucket` 柱状图 + trend + streak + 场景覆盖推荐，`growth_insights_panel.dart`/`growth_insights_notifier.dart`，接入 garden_growth_combined_screen:475），含 `growth_insights_panel_test`/`growth_insights_notifier_test`。
> - **组件规格 🔴→🟢 大体闭环**：13 组件多数已抽到 `app/widgets/`（MentorBubble/EnglishPhrase/AudioButton/InputField/Toast/Card/ScenePill/SegmentTab 等）+ 按钮身份(色/高/圆角)集中到 `app_theme` 的 filled/outlined/text ButtonTheme；私有重复 widget 已清除。详见 /memories/repo/baby-talk-2-component-extraction.md。
> - **跨页一致性 🟡→改善**：圆角 token 化(shell/practice/mentor)、大屏限宽(me_screen + settings 系列 `ConstrainedBox(maxContentWidth=430)`) 已统一。


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
| **Growth V2**（微信读书式多维度） | 🔴 缺失 | 仅 `GrowthTab{garden,growth}` | 周/月/年/历程 Tab、柱状图、历程时间线全缺 |
| **组件规格**（13 共享组件） | 🔴 缺失 | tokens 已定义；组件多为屏幕内私有 | PrimaryCTA/MentorAvatar/EnglishPhrase 等未抽到 `app/widgets/` |
| **跨页一致性审查** | 🟡 部分 | `BabyTalkColors` token 体系 | 审查清单中的按钮高/阴影/pill 高未统一收敛 |

## 二、缺口按优先级

### 🔴 高
- **Growth V2 多维度视图完全缺失**：无周/月/年/历程 Tab、无柱状图、无历程时间线。
- **13 个共享组件未抽取**：组件以屏幕内私有 widget 形式存在，未沉淀到 `app/widgets/`，影响一致性与可维护性。

### 🟡 中
- Discover / Home 的“换一批”随机推荐入口。
- Auth：密码登录、注册、重置密码页、CAPTCHA、渐进披露流程。
- Garden：肥料“待领取/领取/施肥”系统与练习痕迹列表。
- Growth：汇总卡（总句数/场景数/天数）与场景覆盖进度。

### 🟢 低
- Onboarding：独立场景选择页与完成页拆分。
- 跨页样式收敛（按钮高、阴影色、pill 高）。

## 三、已完成的结构性结论

- **核心骨架已落地、可运行**：Shell V2、架构分层、Home B、Practice、Discover、Auth 框架、Garden/Growth 合并页均已实现。
- **`session_bootstrap.dart` 删除合理**：职责迁移到 [app.dart](../../../mobile/lib/app/app.dart) 的 `AppBootState`，`main.dart` 改为先 `AppBootState.load()` 再进 `ProviderScope`，架构 spec 不再引用它。
- **对应特性提交**：`a849df0`（Settings + Shell V2）、`86df8da`（Onboarding V21 + Home B + Practice）、`d37588c`（Discover V1 + Auth V11）、`a44bb78`（+51 测试 + CI/CD）、`1c59637`（路由修复）。

## 四、备注

- 仓库根级未跟踪的 `lib/main.dart`（373 字节）与 `android/` 为 worktree 根目录意外生成的 Flutter 脚手架产物，与本次迭代无关，建议清理或忽略。
- 临时文件 `tmp_test_out.txt` 不应纳入版本控制。
