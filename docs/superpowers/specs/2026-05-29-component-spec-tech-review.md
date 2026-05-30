# 组件规范技术审核报告

**审核对象**：`docs/superpowers/specs/2026-05-28-component-spec.md`（Draft）
**审核日期**：2026-05-29
**审核人角色**：前端开发者技术专家
**审核基准**：实际代码（`mobile/lib`）+ `app_theme.dart` token 实现 + `2026-05-28-all-pages-design-decisions-summary.md`
**结论速览**：**有条件通过 → 已修订（2026-05-29）** —— 方向正确、颜色/阴影对齐度高；原存在的「规范引用了代码里不存在或不一致的 token」与「组件现状描述与实际实现冲突」已于 7 项必须修订项中全部修复，规范升级为「有条件通过修订版」，可进入抽取实施。

> **⏱ 收敛补注（评审后追加）**：本报告「一、逐组件审核表」「二、问题清单」中关于 **MentorAvatar（36×36 圆形）**、**MentorBubble（非对称尾角 + 无阴影）**、**HomeBMentorBubble（r20 + 边框）**、**`home_b_mentor_bubble.dart` 使用 `circular(20)`** 的现状描述，为 **2026-05-29 评审当时**对「方案 B 收敛前」代码的真实观测。该评审之后实施的**方案 B 收敛**已将两气泡内联头像统一为 **28×28 圆角矩形 r12 + 暖渐变**（`AppMentorBubble._avatar`），`home_b_mentor_bubble.dart` 降级为 `AppMentorBubble(variant: home)` 薄包装（走 `cardRadius=16`，20px 气泡圆角已消失，仅余 `AppLayoutConstants.mediumRadius=20` 常量待清理）。**本报告作为时间点审计快照保留原观测不改写**；组件现状以 `2026-05-28-component-spec.md`（已纠偏）与当前代码为准。

---

## 一、逐组件审核表

| 组件 | 规范状态 | 代码现状 | 一致性 | 抽取建议 + 理由 |
|------|---------|---------|--------|----------------|
| **ScenePill** | 已统一 | `_ScenePill` 私有类，仅 `discover_screen.dart` 1 处使用；Home 是「单 pill 标签」非交互筛选，Onboarding 是大按钮（非 pill） | ⚠️ 部分冲突：规范称三页使用，实际仅 1 处真实 pill | **延后**。真实复用点仅 1 个，抽取 ROI 低。代码 a11y 已优于规范（`Semantics(selected:true)` + 选中态加 1.5px `accentDark` 边框，已满足「不只靠颜色」） |
| **PrimaryCTA** | 已统一 | 无独立 widget，统一走 Material `FilledButton`/`ElevatedButton` + 主题 `buttonMinHeight=56` + 圆角 16 | ✅ 基本一致（已通过主题集中） | **延后**。主题已集中约束，新建 `AppPrimaryButton` 收益有限、需改 ~10 处调用，回归面大 |
| **SecondaryButton** | 一致 | 无共享 widget，Ghost/Outline 散落内联 | ⚠️ 缺失 | **延后/可做**。中等价值，建议与 PrimaryCTA 一并规划 |
| **MentorAvatar** | 已统一 | 无独立 widget；MentorBubble 内是 **36×36 圆形**，HomeBMentorBubble 内是 **28×28 圆形 + 图标** | ❌ 冲突：规范定义 40/28px **圆角矩形**(r16/r12)，实际是 36/28px **圆形** | **延后**，且规范须先修正：尺寸(36↔40)与形状(圆形↔圆角矩形)与代码不符 |
| **MentorBubble** | 已统一 | **真实共享组件**（`mentor_bubble.dart` 被 5 处 import），但放在 onboarding 目录；圆角非对称(12/24/24/24)、**无阴影**、padding 16/14 | ❌ 冲突：规范定 r16+`shadow-sm`+padding12/16，实际是非对称圆角+无阴影 | **做（最高优先）**：移到 `app/widgets/`。但规范须先按实际「气泡尾角」修正，否则会引入视觉回归 |
| **EnglishPhrase** | 已统一 | 无独立 widget，走主题 `displayMedium`(Fraunces 32/500/1.2) | ✅ 基线一致 | **可做（中）**：抽取薄封装统一字号并加语义，注意核对各调用点是否覆写为 44/30 |
| **AudioButton** | 已统一 | **已收敛**：抽取 `app/widgets/app_audio_button.dart`，phrase_card `_buildPlayButton` 复用（外观层）；状态逻辑留调用点 | ✅ 已收敛（见 §八） | **已做（薄封装）**。规范 r14px 非 token，按实现 9999 胶囊；详见 §八 |
| **BabyReaction** | 有意差异 | 无共享 widget（Onboarding 固定 3 项 / Practice 场景化） | ✅ 差异合理 | **不做共享 / 或仅薄配置层**。强行统一会破坏有意设计差异 |
| **BottomNav** | 已统一 | Material `NavigationBar`，4 Tab=首页/发现/花园/我，key 齐全（`app_shell_screen.dart`） | ✅ Tab 与顺序一致；⚠️ 规范的 82px 高/`blur(8px)` 是 Web 原型值，Flutter NavigationBar 自管高度、无毛玻璃 | **不抽取**（已天然集中）。规范须标注 82px/blur 为 N/A-for-Flutter |
| **XiaoheFAB** | 已统一 | **已收敛**：抽取 `app/widgets/xiaohe_fab.dart`，shell + home 两处复用 | ✅ 已收敛（见 §八） | **已做**：统一 icon/tooltip/haptics/openMentorPanelSheet，补齐 shell 漏调 haptics |
| **Card** | 已统一 | **已有共享 `AppSurfaceCard`**，默认圆角=`largeRadius`(**24**)+**始终带边框**+`shadow-sm` | ❌ 冲突：规范定 r16+**无边框**，与现有 AppSurfaceCard 默认相悖 | **做（高）但禁止新建**：必须复用/调和 AppSurfaceCard，不要再造一个「Card」 |
| **Toast** | 一致 | **已收敛**：抽取 `app/widgets/app_toast.dart` `showAppToast`，home + account_entry 两处复用；消除 home 硬编码 r12 覆写 | ✅ 已收敛（见 §八） | **已做（薄 helper）**：外观完全交主题 snackBarTheme（r16/floating） |
| **InputField** | 一致 | 走主题 `inputDecorationTheme` + `inputContentPadding` | ⚠️ 部分：规范 r8(`--radius-sm`)，但布局常量**无 8px 圆角 token** | **延后**。先补 token，再抽取 |

---

## 二、规范整体问题清单（按严重度）

### 🔴 HIGH（阻断 — 须修订规范后才能批准）

1. **`--border` token 值不存在/不符**：规范全篇用 `--border #E8E0DA`（SecondaryButton Outline、XiaoheFAB、InputField 等），但代码里边框色 token 是 `outlineSoft = #D8CFC8`，**没有 #E8E0DA 这个值**。「token 驱动」前提被打破。
2. **间距 token 阶梯与代码不一致**：规范 `--space-sm=8 / lg=24`，代码 `spacingXs=8 / spacingSm=12 / spacingLg=20 / spacingXl=24`。命名与数值双重错位（尤其 lg：规范 24 ↔ 代码 20）。按规范实施会和现有页面间距冲突。
3. **20px 圆角自相矛盾**：M2 明确「禁止 20px/26px」，但代码已定义 `mediumRadius=20` 且 `home_b_mentor_bubble.dart` 正在用 `BorderRadius.circular(20)`。规范须二选一：要么承认 20px 合法，要么列为待清理项并给迁移计划。

### 🟡 MEDIUM

4. **MentorAvatar 形状/尺寸与实现冲突**：规范 40/28px 圆角矩形 vs 实际 36/28px 圆形。
5. **Card 规范与既有 AppSurfaceCard 冲突**：r16+无边框 vs r24+恒边框；且命名「Card」与既有 `AppSurfaceCard` 冲突。
6. **命名/目录约定未遵循**：现有 9 个共享组件统一 `app_*.dart` + `App*` 类名（AppScaleButton/AppSurfaceCard…）。规范组件名全部**缺少 `App` 前缀**（ScenePill 而非 AppScenePill）。抽取前须明确命名映射。
7. **引用了不存在的 token**：`--text-on-accent`（代码直接用 `Colors.white`，无命名 token）、`--radius-sm 8px`（布局常量缺）、AudioButton `r14px`（非任何 token，规范自身破例）。
8. **MentorBubble 双实现/规格缺失**：规范未描述实际存在的「非对称气泡尾角」与「HomeBMentorBubble(r20+边框) 重复变体」，统一前须先决定保留哪种形态。
9. **BottomNav 含 Web-only 值**：82px 高度、`backdrop-filter: blur(8px)` 在 Flutter `NavigationBar` 下不适用/未实现，须标注 N/A 或给 Flutter 等价方案。

### 🟢 POLISH

10. **PingFang SC 未真正接线**：规范多处标 PingFang SC，但主题 `fontFamily` 基底是 `DM Sans`，标题级 TextStyle 未显式设 PingFang SC（中文走系统回退）。
11. **ScenePill 高度**：规范 min-height 32 与代码 44（触控目标）并存，代码做法更优，规范可直接采纳 44。

---

## 三、最终审批结论

### ⟢ 有条件通过（Conditional Pass）

规范**设计意图合理、跨页一致性方向正确**，颜色 token、阴影 token（`rgba(45,41,38)` 三级）、BottomNav Tab 配置与代码**高度对齐**，可作为实施蓝本。但作为「token 驱动 + 现状审计」文档，存在 **3 项 HIGH 级事实错误**（border 值、spacing 阶梯、20px 自相矛盾）和多项组件现状误述，若直接据此施工会引入回归。

**必须修改项（满足后即视为通过）：** ✅ 全部已于 2026-05-29 在 `2026-05-28-component-spec.md` 修订完成

- [x] 修正 `--border` → 对齐代码 `outlineSoft #D8CFC8`（并替换 SecondaryButton/XiaoheFAB/InputField 三处内联值）
- [x] 重写「间距 Token」表，与 `AppLayoutConstants` 实际阶梯（2/8/12/16/20/24/32）一一对应（附旧 CSS token 映射）
- [x] 解决 20px 圆角矛盾（列为「待清理项，随抽取渐进收敛」，M2 行同步改写）
- [x] 修正 MentorAvatar（形状=圆形、尺寸=36/28）与 Card（须复用 AppSurfaceCard，明确 r24+边框 现状）的现状描述
- [x] 补全命名映射：所有抽取组件加 `App` 前缀，遵循 `app_*.dart` 约定；「Card」改指 AppSurfaceCard（第 5 节新增）
- [x] 标注 `--text-on-accent`（用 Colors.white）/ `--radius-sm 8px`（Flutter 待补常量）/ AudioButton r14（破例待收敛）等缺失 token 的处理方式
- [x] BottomNav 82px/blur 标 N/A-for-Flutter

> **状态更新（2026-05-29）**：以上 7 项 HIGH/MEDIUM 修订已全部落地，规范状态升级为「有条件通过修订版」。剩余工作转入第四节抽取实施，视觉变更步骤仍需设计二次确认与 golden 测试兜底。

---

## 四、推荐抽取顺序与回归风险等级

| 步骤 | 抽取项 | 回归风险 | 理由 |
|------|--------|---------|------|
| 1 | **MentorBubble → `app/widgets/app_mentor_bubble.dart`**（先仅迁移位置，不改视觉） | 🟡 中 | 真实 5 处复用，纯移动 + 改 import 风险可控；视觉规格统一放第 2 步 |
| 2 | **统一 MentorBubble vs HomeBMentorBubble 形态**（合并为变体参数） | 🔴 高 | 涉及 7 处调用 + 真实视觉变化，必须先定规格、配 golden/widget 测试 |
| 3 | **Card 收敛到 AppSurfaceCard**（补 r16/无边框 变体参数） | 🟡 中 | 已有共享组件，加变体比新建安全 |
| 4 | **EnglishPhrase → AppEnglishPhrase**（薄封装 + 语义） | 🟢 低 | 走主题字号，封装即可，逐点替换 |
| 5 | **XiaoheFAB / AudioButton / Toast** 抽取 | 🟢 低–🟡 中 | 新增组件，对存量影响小，逐个上 |
| 6 | **PrimaryCTA / SecondaryButton** 封装 | 🟡 中 | 调用点多，建议放最后、靠 golden 测试兜底 |
| — | ScenePill / BabyReaction / BottomNav | — | **暂不抽取**（单点使用 / 有意差异 / 已天然集中） |

> 全程要求：每步先建 widget/golden 测试锁定现状，再改；视觉变更（步骤 2、3）需设计二次确认。

---

## 五、形态收敛设计决策清单（步骤 2 二次确认用）

> **进度（2026-05-29）**：步骤 2 已完成**结构合并**——两气泡合入单一 `AppMentorBubble`（`variant: onboarding | home`），`HomeBMentorBubble` 改为薄包装委托，**像素零改动**，由 `mobile/test/widgets/mentor_bubble_form_test.dart` 护栏锁定。
> 下方为**视觉收敛**（统一为单一外观）所需的设计决策，需设计确认后才能动像素。每项请勾选目标态并签字。

### 5.1 当前两变体差异对照

| 维度 | onboarding 变体（现状） | home 变体（现状） | 备注 |
|------|------------------------|-------------------|------|
| 头像形状/尺寸 | 圆形 36×36，`bgAccentSoft` 底 + 文字 caption | 圆形 28×28，`accentDark` 底 + `auto_awesome` 图标 | 底色/内容/尺寸均不同 |
| 气泡圆角 | 非对称尾角 12/24/24/24 | 对称 20px | — |
| 边框 | 无 | 有（`outlineSoft`） | — |
| 阴影 | 无 | 无 | 一致 |
| 内边距 | `fromLTRB(16,14,16,14)` | `symmetric(h16,v14)` | 等价 |
| 标题行 | 无（仅可选 caption） | 固定「小禾」labelSmall | — |
| 正文 | `bodyLarge`，不限行 | `bodyMedium` height1.5，2 行省略 | 字号/截断不同 |
| 交互 | 无（可选 trailing） | 可点击 + chevron | — |
| 语义 | `onboardingMentorMessageSemantics` | `小禾建议: …` | 文案不同 |

### 5.2 待决策项（裁定：方案 B 全对齐规范，2026-05-29）

- [x] **头像形状**：~~A) 统一圆形~~　**B) 统一圆角矩形(r12，对齐规范目标态)** ✅　~~C) 保留两形态~~
- [x] **头像尺寸**：~~A) 统一 36~~　**B) 统一 28** ✅　~~C) 按变体保留~~
- [x] **头像内容**：~~A) 统一文字~~　~~B) 统一图标~~　**C) 按变体保留**（onboarding 文字 caption / home `auto_awesome`）✅
- [x] **气泡圆角**：~~A) 非对称尾角~~　**B) 统一对称(r16，对齐规范)** ✅　~~C) 20px~~　~~D) 按变体保留~~
- [x] **边框**：**A) 全部无边框** ✅　~~B) 带 `outlineSoft`~~　~~C) 按变体保留~~
- [x] **阴影**：~~A) 全部无~~　**B) 全部加 `shadow-sm`(`warmShadowSm`，规范目标态)** ✅　~~C) 按变体保留~~
- [x] **正文字号**：~~A) 统一 `bodyLarge`~~　~~B) 统一 `bodyMedium`~~　**C) 按变体保留** ✅
- [x] **正文截断**：~~A) 统一不限行~~　~~B) 统一 2 行~~　**C) 按变体保留**（home 截断 2 行）✅
- [x] **标题行「小禾」**：~~A) 都显示~~　~~B) 都不显示~~　**C) 按变体保留** ✅
- [x] **可点击/chevron**：**A) 由 `onTap` 是否存在统一决定** ✅　~~B) 仅 home~~

> **A11y 补充裁定**：头像统一暖色渐变(`#EAD0B6→#F8E7D4`)后，home 变体原**白色** `auto_awesome` 图标在浅渐变上对比度不足 → 前景统一改为 **`accentDark`**，满足 WCAG AA。头像间距统一 `--space-sm`(8px)，内边距统一 12/16。

### 5.3 决策后的执行约束

- 任一像素改动前：先更新 `2026-05-28-component-spec.md` 对应小节为「目标态」，移除「现状/待清理」标注。
- 改动 `_buildOnboarding`/`_buildHome` 后：更新 `mentor_bubble_form_test.dart` 断言为新目标态（护栏需同步，否则视为回归）。
- 若决策为「按变体保留」全部维度 → 维持当前 `variant` 分支，无需进一步视觉改动。

| 决策人（设计） | 日期 | 结论摘要 |
|---------------|------|---------|
| 方案 B 全对齐规范（会话裁定） | 2026-05-29 | 两气泡视觉收敛至规范目标态：头像 28×28 圆角矩形 r12 + 暖色渐变（前景 `accentDark`）；气泡对称 r16 + `warmShadowSm` + 无边框 + padding 12/16 + 间距 8。内容（头像前景、标题行、字号、截断、chevron）按变体保留。已落地 `app_mentor_bubble.dart`，护栏 `mentor_bubble_form_test.dart` 同步更新为目标态（4 项通过），规范 2.4/2.5 脚注已翻转为已收敛。 |

---

## 六、Card 收敛设计决策清单（步骤 3 二次确认用）

> **测试底座（已就绪）**：`mobile/test/app/widgets/app_surface_card_test.dart`（REFACTOR-015）已锁定 `AppSurfaceCard` 现状默认值（r24 + `outlineSoft` 边框 + `warmShadowSm` + padding 20）。任何默认值改动会先触发该护栏，再据决策更新。

### 6.1 现状 vs 规范目标（§2.11）

| 维度 | `AppSurfaceCard` 现状 | 规范目标态 |
|------|----------------------|-----------|
| 圆角 | r24（`largeRadius`），参数可覆盖 | **r16**（`--radius-md`/`cardRadius`） |
| 边框 | **始终** `Border.all(outlineSoft)` | 无（除非语义需要） |
| 阴影 | `warmShadowSm`（固定，可覆盖） | 变体：Static=sm / Elevated=md / Borderless=无 |
| 内边距 | `EdgeInsets.all(20)` | 20 horizontal / 24 vertical |
| 变体模型 | 无显式变体，靠裸参数覆盖 | Static / Elevated / Borderless |

### 6.2 调用点 blast radius（6 处）

| 调用点 | 当前用法 | 方案 B 受影响 |
|--------|---------|--------------|
| `discover_activity_card.dart` | 全默认（r24+边框+sm） | ✅ r24→r16、去边框 |
| `discover_screen.dart` 短语卡 | 全默认 | ✅ 同上 |
| `share_callout_card.dart` | 全默认 | ✅ 同上 |
| `home_growth_summary_card.dart` | 全默认 | ✅ 同上 |
| `practice_session_screen.dart` 教练提示 | 已覆盖 r16/无边框/无阴影/padding0 | 不变（已接近目标） |

### 6.3 待决策项（裁定：方案 B 全对齐规范，2026-05-29）

- [x] **默认圆角**：~~A) 保持 r24~~　**B) 改 r16（对齐规范，4 站点变化）** ✅
- [x] **默认边框**：~~A) 保留 `outlineSoft`~~　**B) 默认无边框（`borderColor` opt-in）** ✅
- [x] **变体模型**：~~A) 维持裸参数~~　**B) 新增 `enum AppSurfaceCardVariant { standard, elevated, borderless }` 映射 sm/md/无阴影**（`static` 为 Dart 保留字，规范 Static 落为 `standard`）✅
- [x] **内边距**：~~A) 保持 `all(20)`~~　**B) 改 `symmetric(h20,v24)`（对齐规范）** ✅
- [x] **迁移策略**：**A) 仅改默认（隐式全量收敛）** ✅　~~B) 显式标 variant~~（4 站点均为 Static，隐式收敛即对齐目标态）

### 6.4 决策后的执行约束

- 改 `AppSurfaceCard` 默认值后：先更新 `app_surface_card_test.dart`（REFACTOR-015 断言）为新目标态，再跑 6 站点相关 widget 测试兜底。
- 引入 `variant` 枚举时：保留现有裸参数（`borderRadius`/`borderColor`/`boxShadow`）向后兼容，`practice` 教练提示无需改写。
- 任一像素改动前：先把 `2026-05-28-component-spec.md` §2.11 现状脚注翻转为「已收敛」。

| 决策人（设计） | 日期 | 结论摘要 |
|---------------|------|---------|
| 方案 B 全对齐规范（会话裁定） | 2026-05-29 | `AppSurfaceCard` 默认收敛至规范 §2.11 目标态：r16（`cardRadius`）+ 无边框 + padding 20/24 + `AppSurfaceCardVariant{standard→sm, elevated→md, borderless→无}`。4 处全默认调用点（discover activity / discover phrase / share callout / home growth summary）随默认隐式收敛为 Static 态；practice 教练提示卡走显式裸参数覆盖，零视觉变化。护栏 `app_surface_card_test.dart` 更新为目标态 + 变体 + 兼容断言（4 项通过，回归 34/34）。规范 §2.11 脚注已翻转为已收敛。 |

---

## 七、EnglishPhrase 收敛设计决策清单（步骤 4 二次确认用）

> **新增共享组件（已就绪）**：`mobile/lib/app/widgets/app_english_phrase.dart`，渲染规格 = 主题 `displayMedium`（Fraunces 32 / w500 / 行高 1.2）+ `colors.english`。护栏 `mobile/test/app/widgets/app_english_phrase_test.dart`（2 项：规格断言 + 透传断言）。

### 7.1 现状 vs 规范目标（§2.6）

| 调用点 | 现状字号/样式 | 方案 B 目标 |
|--------|--------------|-----------|
| `home_v23_phrase_hero.dart` | `displayMedium`(32) + english | 不变（已达标） |
| `phrase_card.dart` 展开态 | `headlineMedium`(28) + english | **32**（走 AppEnglishPhrase） |
| `garden_hero_card.dart` `phraseTitle` | `headlineMedium`(28) + english | **32**（走 AppEnglishPhrase） |
| `discover_screen.dart` `_PhraseCard` | `headlineSmall`(24) + english | **32**（走 AppEnglishPhrase） |
| `mini_seed_card.dart` 预览 | `displayMedium.copyWith(fontSize:24)` | 保留 24（规范允许最小 Title 2） |

### 7.2 blast radius / 非短语主显示（不动）

`colors.english` 还用于：onboarding 预览标签（labelMedium）、garden_patch_card stage pill（labelMedium）、discover 进度条颜色、share_callout 文字强调与按钮前景等。这些是小号标签 / pill / 进度 / 按钮，**不属英文短语主显示**，保持原样。

### 7.3 待决策项（裁定：方案 B 全量统一 32px，2026-05-29）

- [x] **主显示字号**：~~A) 按页面保留 28/24~~　**B) 全量统一 Hero 32px（走 AppEnglishPhrase）** ✅
- [x] **收敛方式**：**A) 抽取 `AppEnglishPhrase` 薄封装，主显示逐点替换** ✅　~~B) 仅各点改字号~~
- [x] **MiniSeedCard 预览**：**A) 保留 24px（规范允许最小 Title 2，紧凑预览）** ✅　~~B) 升 32~~（紧凑卡升 32 会撑破布局，24 为规范合法下限）
- [x] **小号 english 用法（标签/pill/进度/按钮）**：**A) 不动**（非短语主显示）✅

### 7.4 决策后的执行约束

- 主显示替换为 `AppEnglishPhrase` 后：跑 `app_english_phrase_test.dart` + a11y + practice feature 测试兜底（已 67/67 通过）。
- 紧凑预览 / 小号强调 `colors.english` 不强制走本组件。
- 规范 §2.6 脚注已翻转为「已收敛」。

| 决策人（设计） | 日期 | 结论摘要 |
|---------------|------|---------|
| 方案 B 全量统一 32px（会话裁定） | 2026-05-29 | 新增 `AppEnglishPhrase`（`displayMedium` 32/500/1.2 + english）。3 处主显示收敛至 32px：`phrase_card`(28→32)、`garden_hero_card`(28→32)、`discover_screen._PhraseCard`(24→32)；`home_v23_phrase_hero` 已 32 无变化；`mini_seed_card` 保留 24px（规范最小 Title 2）。小号标签/pill/进度/按钮的 `colors.english` 不动。护栏 `app_english_phrase_test.dart`（2 项）+ 回归 67/67 通过。规范 §2.6 脚注已翻转为已收敛。**色值核对**：light `colors.english`=`#3B8577` 与规范一致；dark=`#5AAFA0` 是 DESIGN.md 暗模式明文规定的青绿提亮（对比度策略），非缺陷，不改。 |

---

## 八、Step 5 收敛设计决策清单（XiaoheFAB / Toast / AudioButton，2026-05-29 二次确认）

> 三组件均经设计二次确认裁定后实施；遵循「代码 + 护栏测试 + 规范同步」的统一节奏。

### 8.1 XiaoheFAB（🟢 低风险，裁定：抽共享组件）

- **新增组件**：`mobile/lib/app/widgets/xiaohe_fab.dart` —— 封装 `Icons.auto_awesome` 图标、`mentorName` tooltip、点击轻触 haptics + `openMentorPanelSheet`。外观沿用主题 `floatingActionButtonTheme`（accent/white/CircleBorder）。
- **参数**：`launcher`（埋点入口）、`surface`（来源面）、`small`（紧凑形态）；`key` 由调用方经 `super.key` 传入保留语义标识。
- **收敛调用点**：
  - `app_shell_screen.dart`（标准形态，key=`shell-mentor-fab`，surface=`_surfaceForIndex`）—— **顺手修复**：原 shell FAB 漏调 `AppHaptics.lightTap()`，收敛后统一补齐。
  - `home_screen.dart`（`small` 形态，key=`home-mentor-fab`，surface=`standalone_home`）。
- **护栏**：`mobile/test/app/widgets/xiaohe_fab_test.dart`（2 项：标准形态 icon+tooltip+非 mini；small 形态 mini）。
- **副作用**：shell 移除不再使用的 `mentor_panel_sheet` import；两文件新增 `xiaohe_fab` import。

### 8.2 Toast（🟢 低风险，裁定：加 helper + 消除覆写）

- **新增 helper**：`mobile/lib/app/widgets/app_toast.dart` `showAppToast(context, message, {duration})` —— 外观完全交由主题 `snackBarTheme`（bgSurface / `cardRadius`(16) / floating），调用点不再重复设置 shape / behavior。
- **收敛调用点**：
  - `home_screen.dart`：原内联 SnackBar **硬编码圆角 r12**（与主题 r16 不一致）+ 冗余 floating —— 迁移后消除覆写，回归主题 r16。
  - `account_entry_screen.dart`：原裸 SnackBar 迁移到 helper（行为不变，纯走主题）。
- **护栏**：`mobile/test/app/widgets/app_toast_test.dart`（1 项：断言 SnackBar 不覆写 shape/behavior，主题圆角=cardRadius、behavior=floating）。

### 8.3 AudioButton（🟡 中风险，裁定：薄封装做成共享组件）

- **新增组件**：`mobile/lib/app/widgets/app_audio_button.dart` —— **仅外观层**：胶囊点击区（圆角 9999，对应实现而非规范误写的 r14px）、`minTouchTarget` 最小触达、18px 次要色图标、播放中文案。
- **参数**：`semanticsLabel`、`icon`、`buttonKey`（落在内部 InkWell 保持既有测试定位）、`onTap`、`isPlaying`、`playingLabel`。
- **设计取舍**：状态机（TTS/播放模式、playing/error、可点性、key 与回调选择、图标决策）**保留在调用点** `phrase_card._buildPlayButton`，不把播放状态耦合进共享组件 —— 在「做成共享组件」诉求与「单实例强耦合」风险之间取平衡。
- **护栏**：`mobile/test/app/widgets/app_audio_button_test.dart`（3 项：语义/图标/最小触达/buttonKey 可点；播放中文案；onTap=null 不可点）。

### 8.4 验证

- Step 5 全部新测试 + a11y + practice feature 回归：`flutter test`（xiaohe_fab + app_toast + app_audio_button + app_english_phrase + a11y_semantics + features/practice）→ **73/73 全绿**。
- 所有改动文件 `get_errors` 清洁。

| 决策人（设计） | 日期 | 结论摘要 |
|---------------|------|---------|
| Step 5 三组件抽取（会话裁定） | 2026-05-29 | XiaoheFAB=抽 `XiaoheFab`（补齐 shell haptics）；Toast=加 `showAppToast` 并消除 home r12 覆写；AudioButton=抽外观层 `AppAudioButton`（状态留调用点）。3 护栏测试 + 73/73 回归通过，审计表三行翻转为已收敛。 |
