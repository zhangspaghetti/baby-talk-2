# BabyTalk Flutter Mobile — Unified Component Specification

日期：2026-05-28（2026-05-29 按技术审核修订）
状态：有条件通过修订版（已对齐 `app_theme.dart` / `AppLayoutConstants` 实际实现）
审计来源：9 份页面设计规格 + 2 份 HTML 原型 + DESIGN.md
目标：统一所有跨页面共享组件的 token 驱动规格，消除不一致
配套审核：`2026-05-29-component-spec-tech-review.md`

> **实现对齐说明**：本规范的 `--*` token 命名沿用 DESIGN.md / HTML 原型的 CSS 习惯，Flutter 侧实际由 `BabyTalkColors`（颜色/阴影）与 `AppLayoutConstants`（间距/圆角）承载。凡 Flutter 与 CSS 取值不一致处，**以 Flutter 实现为准**，下文已逐项标注。

---

## 0. Design Token Reference

本规格所有值引用 DESIGN.md 的 Warm Paper Kindness token 系统。实现时通过 Flutter theme data 或 CSS custom properties 统一管理。

### 颜色 Token

| Token | Hex | 用途 |
|-------|-----|------|
| `--bg-base` | #FFF8F0 | 主背景（奶油纸） |
| `--bg-surface` | #FFFFFF | 卡片表面 |
| `--bg-sunken` | #F5F0EB | 下沉区域、pill 未选中态 |
| `--bg-accent-soft` | #FFF0E5 | 强调淡底、标签背景 |
| `--accent` | #FF8C42 | 暖橙 — 主 CTA、品牌色 |
| `--accent-dark` | #E67A30 | 深橙 — hover、pressed |
| `--english` | #3B8577 | 青绿 — 英文短语标记 |
| `--english-soft` | #D4E8E3 | 淡青绿 — 英文背景 |
| `--text-primary` | #2D2926 | 正文 |
| `--text-secondary` | #6B5E57 | 次要文字 |
| `--text-muted` | #8A7D76 | 弱文字、占位符 |
| `--text-on-accent` | #FFFFFF | 强调色上的文字（Flutter 无独立命名 token，直接用 `Colors.white`） |
| `--success` | #6B8F5E | 完成、掌握 |
| `--warning` | #E6A817 | 提醒、中断 |
| `--error` | #D94B3C | 错误、失败 |
| `--border` | **#D8CFC8** | 边框线（Flutter token：`outlineSoft`。注：旧稿误写 #E8E0DA，以实现 #D8CFC8 为准） |

### 间距 Token

> **以 Flutter `AppLayoutConstants` 为准**（旧稿 CSS 阶梯 4/8/16/24/32 与实现不符，已弃用）。

| Flutter 常量 | Value | 旧 CSS token（仅历史参考） |
|-------------|-------|---------------------------|
| `spacingXxs` | 2px | — |
| `spacingXs` | 8px | `--space-sm` |
| `spacingSm` | 12px | — |
| `spacingMd` | 16px | `--space-md` |
| `spacingLg` | 20px | （≈`--space-lg`，实现为 20 非 24） |
| `spacingXl` | 24px | `--space-lg` |
| `spacing2xl` | 32px | `--space-xl` |

### 圆角 Token

| Token | Value | Flutter 常量 | 适用 |
|-------|-------|-------------|------|
| `--radius-sm` | 8px | **（缺）待补 `AppLayoutConstants.smallRadius`（InputField 抽取前置硬阻断）** | 按钮、输入框、标签 |
| `--radius-md` | 16px | `cardRadius` | 卡片、模块容器 |
| `--radius-lg` | 24px | `largeRadius` | 弹窗、底部抽屉、modal |
| `--radius-full` | 9999px | `pillRadius` | 圆形按钮、pill 标签 |

> **关于 20px 圆角**：实现中仍存在 `AppLayoutConstants.mediumRadius = 20` 常量定义。原 `home_b_mentor_bubble.dart` 的 20px 气泡圆角已随方案 B 收敛消失（该组件现为 `AppMentorBubble` 薄包装，走 `cardRadius=16`）。20px 归为**待清理项**——仅余 `mediumRadius` 常量本身待随后续抽取移除，期间允许存量保留。`--radius-sm 8px` 在 Flutter 侧尚无对应常量，**抽取 InputField 前须先补 `AppLayoutConstants.smallRadius = 8`（前置硬阻断，见配套技术评审第 4 节抽取顺序）**。

### 阴影 Token

| Token | Value | 适用 |
|-------|-------|------|
| `--shadow-sm` | 0 1px 3px rgba(45,41,38,0.06) | 静态卡片 |
| `--shadow-md` | 0 2px 12px rgba(45,41,38,0.08) | 浮起卡片、短语卡 |
| `--shadow-lg` | 0 8px 24px rgba(45,41,38,0.12) | 弹窗、浮层 |

**关键约束：** 阴影颜色统一使用 `rgba(45,41,38)`，禁止使用 `rgba(80,57,35)` 或其他变体。

### 排版 Token

| Level | Size | Weight | Font | 用途 |
|-------|------|--------|------|------|
| Hero | 32px | 500 | Fraunces | 英文短语大号显示 |
| Title 1 | 28px | 500 | Fraunces | 英文短语标准显示 |
| Title 2 | 24px | 500 | Fraunces | 英文短语最小号 |
| Heading | 20px | 700 | PingFang SC | 页面标题 |
| Subheading | 16px | 700 | PingFang SC | 章节标题 |
| Body | 15px | 400 | PingFang SC / DM Sans | 正文 |
| Caption | 13px | 400 | PingFang SC | 辅助说明 |
| Micro | 11px | 600 | PingFang SC | 标签、badge |
| Mono | 14px | 400 | JetBrains Mono | 音标 |

---

## 1. Component Inventory

| # | 组件名 | 用途 | 使用页面 | 审计状态 |
|---|--------|------|---------|---------|
| 1 | ScenePill | 场景筛选标签 | Discover, Home, Onboarding | 已统一 · **已抽取闭环**（`AppScenePill`，commit a36b25e）[^impl-scenepill] |
| 2 | PrimaryCTA | 主行动按钮 | 全部页面 | 已统一 · **已闭环**（`filledButtonTheme`，commit 63a9cb8）[^impl-primarycta] |
| 3 | SecondaryButton | 次要文字按钮 | Practice, Onboarding | 一致 · 待抽取（走 Flutter 原生 `OutlinedButton`/`TextButton` + theme，详见技术评审第 4 节）|
| 4 | MentorAvatar | 小禾头像 | Onboarding, Home, Practice | 已统一 |
| 5 | MentorBubble | 小禾对话气泡 | Onboarding, Home, Practice | 已统一 |
| 6 | EnglishPhrase | 英文短语展示 | 全部页面 | 已统一 |
| 7 | AudioButton | 听小禾读按钮 | Practice, Onboarding | 已收敛（`AppAudioButton`，外观层） |
| 8 | BabyReaction | 宝宝反应按钮 | Practice, Onboarding | 有意差异 |
| 9 | BottomNav | 底部导航栏 | Shell V2 | 已统一 |
| 10 | XiaoheFAB | 小禾全局悬浮按钮 | 除首页和花园外所有页面 | 已收敛（`XiaoheFab`） |
| 11 | Card | 卡片容器 | 全部页面 | 已统一 |
| 12 | Toast | 轻提示 | Practice, Home, Garden | 已收敛（`showAppToast`） |
| 13 | InputField | 输入框 | Auth, Discover | 一致 |

[^impl-scenepill]: 2026-05-30 抽取为公开 `mobile/lib/app/widgets/app_scene_pill.dart`，Discover 私有 `_ScenePill` 已删除并迁移；home_b 临时场景表（Material `Chip` 风格）与 Onboarding 大按钮按设计差异**不迁移**。
[^impl-primarycta]: 2026-05-30 给 `app_theme.dart` light+dark 补 `filledButtonTheme`（accent / 56 高 / 16 圆角 / DM Sans 16 w700）；`minimumSize` 用 `Size(64, 56)` 而非 `Size.fromHeight`，避免 Row 内紧凑 FilledButton 溢出，全宽由调用点 stretch/SizedBox 决定；auth_screen 两处内联 `styleFrom(minimumSize)` 补丁已清理。

---

## 2. Component Specifications

### 2.1 ScenePill（场景筛选标签）

场景筛选 pill 组件，用于 Discover、Home、Onboarding 中的场景选择。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 高度 | min-height: 32px | — |
| 水平内边距 | padding: 0 16px | `--space-md` |
| 垂直内边距 | padding: 6px 0 | — |
| 圆角 | 9999px | `--radius-full` |
| 字体大小 | 13px | Micro 级 |
| 字重 | 500 | — |
| 最小触控宽度 | 44px | iOS HIG |

#### 状态

| 状态 | 背景 | 文字色 | 边框 | 说明 |
|------|------|--------|------|------|
| 未选中 | `--bg-sunken` (#F5F0EB) | `--text-secondary` (#6B5E57) | 无 | 默认态 |
| 选中 | `--accent` (#FF8C42) | `--text-on-accent` (#FFFFFF) | 无 | 选中态 |
| 按下 | `--accent-dark` (#E67A30) | `--text-on-accent` (#FFFFFF) | 无 | scale(0.95) 150ms ease-out |

**设计约束：**
- 统一使用 token 驱动，禁止使用非 token 渐变色（如 `linear-gradient(135deg, #8b6248, #bd8c67)`）
- 选中态不能只依赖颜色，需要有语义状态（如边框或下划线）辅助可访问性
- 场景名称列表：喂饭 / 喝水 / 换尿布 / 洗澡 / 睡前 / 出门 — 全页面一致

#### 页面使用差异

| 页面 | 布局 | 说明 |
|------|------|------|
| Discover | 横滑 pill 筛选条 | 全部 + 6 场景，横滑可溢出 |
| Home | 单个 pill | 显示当前场景标签 |
| Onboarding | 纵向大按钮列表 | 不使用 pill，使用 ≥48px 高的大按钮 |

---

### 2.2 PrimaryCTA（主行动按钮）

全应用核心 CTA 按钮，所有页面共享同一规格。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 最小高度 | 56px | — |
| 水平内边距 | padding: 0 24px | `--space-lg` |
| 垂直内边距 | padding: 16px 0 | — |
| 圆角 | 16px | `--radius-md` |
| 字体大小 | 16px | Subheading 级 |
| 字重 | 600 | — |
| 最小触控宽度 | 44px | iOS HIG |
| 阴影 | 0 2px 12px rgba(45,41,38,0.08) | `--shadow-md` |

#### 状态

| 状态 | 背景 | 文字色 | 阴影 | 动画 |
|------|------|--------|------|------|
| 默认 | `--accent` (#FF8C42) | `--text-on-accent` (#FFFFFF) | `--shadow-md` | — |
| 按下 | `--accent-dark` (#E67A30) | `--text-on-accent` (#FFFFFF) | `--shadow-sm` | scale(0.97) 150ms ease-out |
| 禁用 | #CCCCCC | #FFFFFF | 无 | opacity 0.6 |

**设计约束：**
- 最小高度 56px，不是 48px。56px 符合 DESIGN.md 的 Play button 56-72px 建议，且更适合单手持宝宝时的拇指操作
- 禁止使用渐变背景，使用 `--accent` 纯色
- 固定底部时使用 SafeArea 处理底部安全区

#### 页面引用

| 页面 | 按钮文案 | 变体说明 |
|------|---------|---------|
| Onboarding 场景选择 | `开始一句` | (V21 UX 优化: removed, auto-enter on scene select) |
| Onboarding 练习页 | `说完了` | 标准规格，固定底部 |
| Onboarding 结束态 | `再来一句` | 标准规格 |
| Practice | `说完了` | 标准规格，固定底部 |
| Practice 结束态 | `再来一句` | 标准规格 |
| Home (Variant A) | `开始练一句` | 标准规格 |
| Home (Variant B) | `试着说这一句` | 标准规格 |
| Garden | `去说一句` | 标准规格，空态时显示 |
| Growth 空态 | `去说一句` | 标准规格 |
| Discover | `练这一句` | 标准规格，每张卡片内 |

---

### 2.3 SecondaryButton（次要按钮）

用于次要操作，不与 PrimaryCTA 竞争视觉权重。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 最小高度 | 44px | — |
| 水平内边距 | padding: 0 16px | `--space-md` |
| 垂直内边距 | padding: 10px 0 | — |
| 圆角 | 16px | `--radius-md` |
| 字体大小 | 15px | Body 级 |
| 字重 | 500 | — |
| 边框 | 1px solid `--border` (#D8CFC8) | — |
| 阴影 | `--shadow-md` | — |
| 位置 | 右下角，距边缘 16px | `--space-md` |

#### 变体

| 变体 | 背景 | 文字色 | 边框 | 用途 |
|------|------|--------|------|------|
| Ghost（文字按钮） | transparent | `--accent` (#FF8C42) | 无 | `换一句`、`结束`、`先到这里` |
| Outline（边框按钮） | transparent | `--text-secondary` | 1px `--border` | `直接给一句`、`先看看再说` |

#### 状态

| 状态 | 背景 | 文字色 |
|------|------|--------|
| 默认 | transparent | 对应变体色 |
| 按下 | `--bg-accent-soft` (#FFF0E5) | 对应变体色 |

---

### 2.4 MentorAvatar（小禾头像）

小禾老师的头像组件，有两个尺寸变体。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 圆角 | 16px | `--radius-md` |
| 背景 | 暖色渐变 `#EAD0B6 → #F8E7D4` | 品牌装饰色 |

> **实现现状（2026-05-29 方案 B 已收敛）**：`AppMentorBubble` 两变体的内联头像均已统一为**圆角矩形 r12 + 28×28 + 暖色渐变 `#EAD0B6 → #F8E7D4`**（Inline 变体），前景色统一 `accentDark`（满足 WCAG AA）。下表 Inline 行即为实现态。**Display 40px 圆角矩形**仍为非气泡场景（Onboarding 顶部 / “我”页）的**目标态**，尚未落地，抽取这些独立头像时再对齐。

#### 尺寸变体

| 变体 | 尺寸 | 圆角 | 用途 | 使用位置 |
|------|------|------|------|---------|
| Display | 40x40px | 16px | 头部展示 | Onboarding 顶部、"我"页面用户信息区 |
| Inline | 28x28px | 12px | 内联引用 | MentorBubble 内、Home 导师标记 |

**设计约束：**
- Display 变体用于需要强调小禾存在感的场景
- Inline 变体用于不需要抢视觉焦点的内联引用
- 装饰性头像应对屏幕阅读器隐藏（`Semantics(hidden: true)`）

---

### 2.5 MentorBubble（小禾对话气泡）

小禾老师的消息气泡，包含头像 + 气泡。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 背景 | `--bg-surface` (#FFFFFF) | — |
| 圆角 | 16px | `--radius-md` |
| 阴影 | `--shadow-sm` | — |
| 内边距 | 12px 16px | — |
| 头像尺寸 | 28x28px（Inline 变体） | MentorAvatar.Inline |
| 头像与气泡间距 | 8px | `--space-sm` |
| 最大宽度 | 屏幕宽度 - 80px | — |

> **实现现状（2026-05-29 方案 B 已收敛）**：`AppMentorBubble`（onboarding/home 两变体，统一替代原 `mentor_bubble.dart` 与 `home_b_mentor_bubble.dart`）已全量对齐上表目标态——**对称 r16 圆角 + `--shadow-sm`（`warmShadowSm`）+ 无边框 + padding 12/16 + 头像间距 8（`--space-sm`）**。原非对称尾角、20px 边框气泡、白色头像图标均已移除。视觉契约由 `mobile/test/widgets/mentor_bubble_form_test.dart` 锁定（4 项断言）。

#### 状态

| 状态 | 背景 | 说明 |
|------|------|------|
| 默认 | `--bg-surface` | 正常显示 |
| 场景动态 | `--bg-surface` | 文案随场景变化（Onboarding 练习页） |

**设计约束：**
- 小禾在 Onboarding 中是主要引导角色，气泡较大
- 小禾在 Practice 中只保留一行短提示，不进入连续聊天
- 气泡文案不超过 15 个字
- 不用"你"开头（避免指令感）

#### 页面使用

| 页面 | 使用方式 |
|------|---------|
| Onboarding 场景选择 | 顶部引导气泡：`选个正在发生的场景，小禾给你一句现在就能说的。` |
| Onboarding 练习页 | 场景动态文案，如 `喂饭时轻轻说，宝宝会听的。` |
| Onboarding 结束态 | 根据完成数量动态变化 |
| Home (Variant B) | 作为与当前时刻关联的小导师气泡 |
| Practice | 轻提示：`小禾：会说就直接说。` |

---

### 2.6 EnglishPhrase（英文短语展示）

英文短语是 BabyTalk 最核心的视觉元素。所有页面共享统一规格。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 字体 | Fraunces (variable, opsz 9-144, wght 300-700) | `font-family` |
| 字号 | **32px**（Hero 级） | Type Scale Hero |
| 字重 | 500 | — |
| 行高 | 1.2 | — |
| 颜色 | `--english` (#3B8577) | — |

#### 使用场景

| 场景 | 字号 | 说明 |
|------|------|------|
| 标准展示 | 32px | Home、Practice、Discover、Growth 旅程 |
| Onboarding 首句 | 32px | 统一为 32px，不使用 44px |

**设计约束：**
- Fraunces 只用于 24px 以上的英文短语显示，不用于 UI 文本
- 最小使用字号 24px（Title 2 级）
- 颜色统一使用 `--english` (#3B8577)，禁止使用其他绿色变体
- 不展示拼音或英文转写

#### 不同页面字号

| 页面 | 规格字号 | 审计结论 |
|------|---------|---------|
| DESIGN.md | 32px | 基线 |
| Onboarding V21 | 44px | **统一为 32px**（44px 是过度强调，违反 Type Scale） |
| Home A/B | 30px | **统一为 32px** |
| Practice | 未指定 | 引用 DESIGN.md 32px |
| Discover | Fraunces, --english | 引用 DESIGN.md 32px |

> **状态（2026-05-29 方案 B 全量统一 32px）：已收敛。**
> 新增共享组件 `AppEnglishPhrase`（`mobile/lib/app/widgets/app_english_phrase.dart`），
> 渲染规格 = 主题 `displayMedium`（Fraunces 32px / w500 / 行高 1.2）+ `colors.english`。
> 主显示调用点统一收敛：
> - `phrase_card.dart` 展开态英文（28→32）
> - `garden_hero_card.dart` `phraseTitle`（28→32）
> - `discover_screen.dart` `_PhraseCard` 标题（24→32）
> - `home_v23_phrase_hero.dart` 已是 32px（无变化）
>
> 紧凑预览 `mini_seed_card.dart` 保留规范允许的最小号 24px（Title 2），
> 不强制走本组件。小号强调标签 / pill / 进度条等 `colors.english` 用法不属本组件范畴。
> 规格由 `mobile/test/app/widgets/app_english_phrase_test.dart` 护栏锁定。
> 色值核对（2026-05-29）：light `colors.english` = `#3B8577`，与本规范一致；
> dark 模式 `english` = `#5AAFA0`，为 DESIGN.md 暗模式策略明文规定的「青绿提亮」
> （#3B8577 → #5AAFA0，提升暗背景对比度），非缺陷，不改。

---

### 2.7 AudioButton（听小禾读按钮）

发音播放辅助按钮，不是主路径。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 最小高度 | 40px | — |
| 最小宽度 | 40px | — |
| 圆角 | 14px | （注：14px 非任何圆角 token，属规范破例；抽取时应收敛到 `--radius-sm 8px` 或 `--radius-md 16px`） |
| 背景 | `--english-soft` (#D4E8E3) | — |
| 图标色 | `--english` (#3B8577) | — |
| 内边距 | 0 14px | — |
| 字体大小 | 13px | Caption 级 |
| 字重 | 500 | — |

#### 状态

| 状态 | 背景 | 图标/文字 | 说明 |
|------|------|----------|------|
| 未播放 | `--english-soft` | `听小禾读` | 默认态 |
| 准备中 | `--english-soft` | `小禾准备读` | loading 态 |
| 播放中 | `--english-soft` | `播放中` | 播放态 |
| 播放完成 | `--english-soft` | `再听一次` | 可重播 |
| 失败 | `--error-soft` (#FDE8E6) | `这句没读出来，点我重试` | 错误态 |

**设计约束：**
- 统一为较小尺寸（min-height 40px），保持辅助动作的视觉定位
- 不与主 CTA（56px）竞争视觉权重
- 用户不需要等待发音播放才能点击"说完了"
- 失败重试不得使用技术错误码

> **【已收敛 2026-05-29 / Step 5】** 已抽取外观层共享组件 `mobile/lib/app/widgets/app_audio_button.dart`，`phrase_card._buildPlayButton` 复用，护栏 `app_audio_button_test.dart`（3 项）。
> **实现现状与本节规格的已知差异（待后续设计对齐）**：现行实现走「无背景填充 + 9999 胶囊点击区 + 18px `--text-secondary` 图标 + `minTouchTarget` 最小触达」，而非本节描述的「`--english-soft` 背景 / 14px 圆角 / `--english` 图标」。本次仅做无视觉变化的抽取（保持现状外观），背景/圆角/图标色是否回归本节目标态留作独立设计决策；规范误写的 14px 已按实现澄清为非 token。状态机（TTS/播放/错误/可点性）保留在调用点，不耦合进共享组件。

---

### 2.8 BabyReaction（宝宝反应按钮）

记录宝宝反应的图标+文字按钮。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 最小高度 | 44px | iOS HIG |
| 最小宽度 | 44px | iOS HIG |
| 圆角 | 9999px | `--radius-full` |
| 内边距 | 8px 16px | `--space-sm` `--space-md` |
| 图标大小 | 20px | — |
| 字体大小 | 14px | Body 级偏小 |
| 字重 | 500 | — |

#### 变体（有意设计差异）

**Onboarding — 固定三项（降低决策成本）：**

| 反应 | 图标 | 背景色 | 文字色 |
|------|------|--------|--------|
| 有回应 | 😊 | `--success-soft` (#E8F0E5) | `--success` (#6B8F5E) |
| 安静了 | 😌 | `--english-soft` (#D4E8E3) | `--english` (#3B8577) |
| 没反应 | 😐 | `--bg-sunken` (#F5F0EB) | `--text-muted` (#8A7D76) |

**Practice — 按场景变化（增加真实感）：**

| 场景 | 选项 1 | 选项 2 | 选项 3 |
|------|--------|--------|--------|
| 喂饭 | 有回应 | 吃了一口 | 没反应 |
| 喝水 | 有回应 | 喝了一口 | 没反应 |
| 换尿布 | 有回应 | 配合了 | 没反应 |
| 洗澡 | 有回应 | 配合了 | 没反应 |
| 睡前 | 有回应 | 安静了 | 没反应 |
| 出门 | 有回应 | 配合了 | 没反应 |

**设计约束：**
- 反应按钮使用图标 + 文字，不依赖颜色作为唯一标识
- 选中后显示匹配的反馈文案，约 2.5-3 秒后自动进入下一句
- 自动跳转可取消，避免竞态
- 不选反应时，用户可点击"跳过，下一句"

---

### 2.9 BottomNav（底部导航栏）

Shell V2 定义的四 Tab 底部导航。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 高度 | **82px**（含安全区） | （仅 HTML 原型；Flutter 下 N/A——`NavigationBar` 自管高度，M3 默认 ≈80px） |
| 背景 | `--bg-surface` + 毛玻璃 | （`blur(8px)` 仅 HTML 原型；Flutter `NavigationBar` 默认不加毛玻璃，N/A） |
| 顶部分割线 | 1px solid `--border` | — |
| Tab 图标大小 | 24px | — |
| Tab 文字大小 | 11px | Micro 级 |
| Tab 文字字重 | 500 | — |
| Tab 间距 | 均分 | — |
| 内容区底部 padding | 82px + safe area | — |

#### Tab 配置

| 序号 | Tab 名称 | 图标 | 路由 |
|------|---------|------|------|
| 1 | 首页 | home | /home |
| 2 | 发现 | discover | /discover |
| 3 | 花园 | garden | /garden |
| 4 | **我** | person | /me |

**关键决策：** 第 4 Tab 统一为「我」，不是「成长」。成长数据通过"我"页面的入口块进入。

#### 状态

| 状态 | 图标色 | 文字色 | 背景 |
|------|--------|--------|------|
| 未选中 | `--text-muted` (#8A7D76) | `--text-muted` | transparent |
| 选中 | `--accent` (#FF8C42) | `--accent` | transparent |

**设计约束：**
- 高度统一为 82px，不是 72px。82px 包含底部安全区，提供更充裕的触控空间
- Tab 切换：页面内容区域滚动到顶部，visibility 切换
- 不使用复杂动画或转场效果
- 底部安全区需要正确处理（iOS 刘海屏、Android 导航栏）

---

### 2.10 XiaoheFAB（小禾全局悬浮按钮）

小禾老师的全局入口 FAB。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 尺寸 | 56x56px | — |
| 圆角 | 9999px | `--radius-full` |
| 背景 | `--bg-base` (#FFF8F0) + 细边框 | — |
| 边框 | 1px solid `--border` (#D8CFC8) | — |
| 阴影 | `--shadow-md` | — |
| 位置 | 右下角，距边缘 16px | `--space-md` |
| 图标 | 小禾头像缩略图 | — |

#### 可见性规则

| 页面 | 是否显示 | 说明 |
|------|---------|------|
| 首页 | **不显示** | 使用内联"问小禾"按钮替代 |
| 花园 | **不显示** | 花园有自己的施肥交互 |
| 发现 | 显示 | 右下角固定 |
| 我 | 显示 | 右下角固定 |
| 设置 | 显示 | 右下角固定 |
| Onboarding | 不显示 | 导师角色通过顶部气泡呈现 |
| Practice | 显示（低干扰变体） | 可选浮动入口 |

**设计约束：**
- 所有页面（除首页和花园）统一引用此规格
- Home V23 和 Practice 中的浮动入口需明确引用此 56x56px / `--shadow-md` 规格
- 点击后展开 MentorPanel（建议+聊天双模式面板）

> **【已收敛 2026-05-29 / Step 5】** 已抽取共享组件 `mobile/lib/app/widgets/xiaohe_fab.dart`（`XiaoheFab`），封装 `Icons.auto_awesome` 图标 + `mentorName` tooltip + 轻触 haptics + `openMentorPanelSheet`，外观沿用主题 `floatingActionButtonTheme`（accent/white/CircleBorder）。参数 `launcher`/`surface`/`small`，`key` 由调用方传入。两处收敛：`app_shell_screen.dart`（标准形态，**顺手补齐原先漏调的 haptics**）、`home_screen.dart`（`small` 形态）。护栏 `app_audio` 同级 `xiaohe_fab_test.dart`（2 项）。注：本节描述的「细边框 + bg-base 背景」是 Web 原型值，Flutter 走主题 accent 实心圆形 FAB，差异属平台落地，非缺陷。

---

### 2.11 Card（卡片容器）

通用卡片组件，用于承载内容块。

> **实现现状（2026-05-29 方案 B 已收敛）**：共享组件 `app_surface_card.dart`（`AppSurfaceCard`）已全量对齐下表目标态——**默认对称 r16（`cardRadius`）+ 无边框 + padding 20/24（`spacingLg`/`spacingXl`）+ 按 `AppSurfaceCardVariant`（`standard`→`--shadow-sm` / `elevated`→`--shadow-md` / `borderless`→无阴影）取阴影**。原 r24（`largeRadius`）默认 + 常驻 `outlineSoft` 边框已移除。裸参数（`borderRadius`/`borderColor`/`boxShadow`/`padding`）保留向后兼容，提供时覆盖变体默认值（practice 教练提示卡仍走显式覆盖，零视觉变化）。视觉契约由 `mobile/test/app/widgets/app_surface_card_test.dart` 锁定（4 项断言）。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 背景 | `--bg-surface` (#FFFFFF) | — |
| 圆角 | 16px | `--radius-md` |
| 阴影 | `--shadow-sm`（静态）或 `--shadow-md`（浮起） | — |
| 内边距 | 20px horizontal, 24px vertical | — |
| 边框 | 无（除非语义需要） | — |

#### 变体

| 变体 | 阴影 | 用途 | 示例 |
|------|------|------|------|
| Static | `--shadow-sm` | 列表项、信息卡片 | Discover 短语卡、Growth 场景卡 |
| Elevated | `--shadow-md` | 浮起内容、主卡片 | Home 今日短语卡 |
| Borderless | 无 | 内联内容、嵌套卡片 | Onboarding 句子展示区 |

#### 状态

| 状态 | 阴影 | 变换 | 说明 |
|------|------|------|------|
| 默认 | 对应变体 | — | — |
| 悬停/按压 | 升级一级阴影 | translateY(-2px) | Elevated 可升至 `--shadow-lg` |

**设计约束：**
- 卡片只在承载真实交互时使用，不做装饰性卡片
- 移除阴影后页面仍应有清晰层级
- 禁止使用非 token 圆角值（20px、26px 等）
- Card 与 Borderless 变体在 Onboarding 中替换为无边框设计

---

### 2.12 Toast（轻提示）

短暂提示组件。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 背景 | `--bg-surface` (#FFFFFF) 或语义色 soft | — |
| 圆角 | 16px | `--radius-md` |
| 阴影 | `--shadow-lg` | — |
| 内边距 | 12px 20px | — |
| 字体大小 | 14px | Body 级偏小 |
| 最大宽度 | 屏幕宽度 - 48px | — |
| 位置 | 底部居中，距底部 100px（避开 BottomNav） | — |
| 自动消失 | 1.5-3 秒 | — |

#### 变体

| 变体 | 背景 | 用途 |
|------|------|------|
| 默认 | `--bg-surface` | 一般提示 |
| 成功 | `--success-soft` (#E8F0E5) | 练习完成、保存成功 |
| 错误 | `--error-soft` (#FDE8E6) | 网络失败、操作失败 |
| 花园 | `--english-soft` (#D4E8E3) | 练习→花园因果反馈 |

#### 使用

| 页面 | 内容 | 时长 |
|------|------|------|
| Practice | `已保存本句` | 1.5s |
| Practice | 反应反馈文案（如 `记下来了，小禾给你下一句。`） | 2.5-3s |
| Home | 轻 toast 提示 | 1.5-3s |
| Garden | `你的🌱洗澡花刚发芽了!` + 花圃缩略图 | 3s |

**设计约束：**
- Toast 不得遮挡 BottomNav
- 花园 toast 包含花圃缩略图，作为因果反馈
- 不使用 emoji 作为设计元素（种子 emoji 🌱 仅在 Garden toast 中例外，后续替换为插画）

> **【已收敛 2026-05-29 / Step 5】** 外观已由主题 `snackBarTheme` 集中（bgSurface 背景 / `cardRadius`(16) 圆角 / `floating` 行为 / bodyMedium+textPrimary 文字）。新增薄 helper `mobile/lib/app/widgets/app_toast.dart` `showAppToast(context, message, {duration})`，调用点不再重复设置 shape/behavior。两处迁移：`home_screen.dart`（**消除原硬编码 r12 圆角覆写**，回归主题 r16）、`account_entry_screen.dart`（裸 SnackBar 走 helper，行为不变）。护栏 `app_toast_test.dart`（1 项：断言不覆写 shape/behavior + 主题圆角=cardRadius/floating）。注：本节的语义色 soft 背景与成功/错误/花园变体属未来增强；当前 helper 仅承载默认态文案 Toast，语义变体留作独立设计决策。

---

### 2.13 InputField（输入框）

用于 Auth 和 Discover 的文本输入。

#### Token 驱动规格

| 属性 | 值 | Token 引用 |
|------|-----|-----------|
| 高度 | 48px | — |
| 圆角 | 8px | `--radius-sm` |
| 背景 | `--bg-surface` (#FFFFFF) | — |
| 边框 | 1px solid `--border` (#D8CFC8) | — |
| 内边距 | 12px 16px | — |
| 字体大小 | 16px | Subheading 级 |
| 字重 | 400 | — |
| 占位符色 | `--text-muted` (#8A7D76) | — |

#### 状态

| 状态 | 边框 | 阴影 | 说明 |
|------|------|------|------|
| 默认 | `--border` | 无 | — |
| 聚焦 | `--accent` (#FF8C42) | 0 0 0 3px rgba(255,140,66,0.1) | — |
| 错误 | `--error` (#D94B3C) | 无 | 附带错误文案 |
| 禁用 | `--border` | 无 | opacity 0.6 |

#### 使用

| 页面 | 类型 | 说明 |
|------|------|------|
| Auth | phone / verification code / password | 标准规格 |
| Discover | search | 搜索栏，使用 `--bg-sunken` 背景变体 |

---

## 3. Cross-Page Reference Table

| 组件 | Onboarding | Home | Practice | Discover | Garden | Growth | 我 | Auth |
|------|-----------|------|----------|----------|--------|--------|-----|------|
| ScenePill | 大按钮列表 | 单 pill | — | 横滑筛选 | — | — | — | — |
| PrimaryCTA | 56px | 56px | 56px | 56px | 56px | 56px | — | 56px |
| SecondaryButton | Ghost | Ghost | Ghost | — | — | — | — | Outline |
| MentorAvatar | Display 40px | Inline 28px | Inline 28px | — | — | — | — | — |
| MentorBubble | 顶部引导 | 内联引用 | 轻提示 | — | — | — | — | — |
| EnglishPhrase | 32px Fraunces | 32px Fraunces | 32px Fraunces | 32px Fraunces | — | 32px Fraunces | — | — |
| AudioButton | 40px | — | 40px | — | — | — | — | — |
| BabyReaction | 固定3项 | — | 场景化 | — | — | — | — | — |
| BottomNav | — | 82px 4-tab | — | 82px 4-tab | 82px 4-tab | — | 82px 4-tab | — |
| XiaoheFAB | 不显示 | 不显示 | 低干扰 | 56px | 不显示 | — | 56px | — |
| Card | Borderless | Elevated | Borderless | Static | — | Static | Static | — |
| Toast | — | 默认 | 成功/花园 | — | 花园 | — | — | — |
| InputField | — | — | — | Search 变体 | — | — | — | 标准 |

> **现状对齐说明**：本表数值为 HTML 原型/目标态，部分与 Flutter 实现现状不一致，抽取时不得默认改动：
> - **MentorAvatar**：表中 `Display 40px` 为非气泡场景（Onboarding 顶部 /「我」页）的**目标态，尚未落地**；气泡内联头像现状已统一为 **28×28 圆角矩形 r12 + 暖色渐变**（`AppMentorBubble._avatar`，onboarding/home 两变体一致），**非圆形**（详见 2.4 节）。
> - **BottomNav**：表中 `82px` 仅适用于 HTML 原型；Flutter 下 `NavigationBar` 自管高度（M3 默认 ≈80px），该值 N/A（详见 2.9 节）。

---

## 4. Resolved Inconsistencies

以下是审计中发现的所有不一致项及其解决方案：

### HIGH（已解决）

| ID | 问题 | 解决方案 |
|----|------|---------|
| H1 | 底部导航第 4 Tab 命名 | 统一为「我」（Shell V2 标准） |
| H2 | 底部导航栏高度 | 统一为 82px（Shell V2 标准） |
| H3 | 小禾 FAB 可见性规则 | 明确定义：首页/花园不显示，其他页面显示 |

### MEDIUM（已解决）

| ID | 问题 | 解决方案 |
|----|------|---------|
| M1 | 英文短语字号 | 统一为 32px（Hero 级），Onboarding 44px 降为 32px |
| M2 | 圆角值 | 以 token 为准（8/16/24/9999px）；**20px 列为待清理项**（仅余 `mediumRadius=20` 常量定义；`home_b_mentor_bubble` 的 20px 已随方案 B 收敛消失），随抽取渐进移除，不一次性硬禁 |
| M3 | 阴影颜色 | 统一为 rgba(45,41,38)，禁止 rgba(80,57,35) |
| M4 | 场景 pill 样式 | 定义统一 ScenePill 组件，token 驱动选中态 |
| M5 | 宝宝反应选项 | **有意差异**：Onboarding 固定 3 项，Practice 场景化 |
| M6 | 音频按钮尺寸 | 统一为 min-height 40px |
| M7 | Primary CTA 高度 | 统一为 min-height 56px |
| M8 | Pill 高度 | 统一为 min-height 32px |
| M9 | 背景处理 | 统一使用 `--bg-base` (#FFF8F0)，禁止非 token 渐变 |
| M10 | 场景按钮选中态 | 统一为 `--accent` + `--text-on-accent`，禁止渐变 |

### POLISH（已解决）

| ID | 问题 | 解决方案 |
|----|------|---------|
| P1 | BottomNav active 态颜色 | 统一使用 `--accent` (#FF8C42) |
| P2 | 小禾头像/标记不一致 | 定义 MentorAvatar Display(40px) + Inline(28px) |
| P7 | DESIGN.md Drawer 描述过时 | 更新 DESIGN.md：移除 Drawer，增加"我"页面和设置页面 |

---

## 5. Implementation Notes

### 命名约定（抽取落地必遵）

- 所有抽取出的共享组件置于 `mobile/lib/app/widgets/`，文件名 `app_*.dart`、类名 `App*`（与现有 `AppSurfaceCard` / `AppPrimaryButton` 等一致）。
- 本规范逻辑名 → 代码类名映射：ScenePill→`AppScenePill`、PrimaryCTA→`AppPrimaryButton`（已存）、SecondaryButton→`AppSecondaryButton`、MentorAvatar→`AppMentorAvatar`、**Card→`AppSurfaceCard`（已存，复用）**、AudioButton→`AppAudioButton`、Toast→`AppToast`、InputField→`AppInputField`。
- `BabyTalkComponents` 仅为尺寸/圆角常量聚合点；颜色/阴影以 `context.appColors`（`BabyTalkColors`）为唯一来源，不得硬编码 hex。

### Flutter 实现

```dart
// Component registration pattern
class BabyTalkComponents {
  // ScenePill
  static const double scenePillHeight = 32;
  static const double scenePillRadius = 9999; // --radius-full

  // PrimaryCTA
  static const double primaryCtaMinHeight = 56;
  static const double primaryCtaRadius = 16; // --radius-md

  // SecondaryButton
  static const double secondaryBtnMinHeight = 44;
  static const double secondaryBtnRadius = 16; // --radius-md

  // MentorAvatar（气泡内联头像现为圆角矩形 r12/28；Display 40 为独立头像目标态，抽取时二次确认）
  static const double mentorAvatarDisplay = 40;
  static const double mentorAvatarInline = 28;

  // AudioButton（radius 14 为现状破例，抽取时收敛到 8/16）
  static const double audioBtnMinHeight = 40;
  static const double audioBtnRadius = 14;

  // BottomNav（Flutter NavigationBar 自管高度，82 仅 HTML 原型参考）
  static const double bottomNavHeight = 82;

  // XiaoheFAB
  static const double xiaoheFabSize = 56;
}
```

### CSS 实现（HTML 原型）

```css
:root {
  /* 所有值引用 DESIGN.md token */
  --component-scene-pill-height: 32px;
  --component-primary-cta-height: 56px;
  --component-secondary-btn-height: 44px;
  --component-mentor-avatar-display: 40px;
  --component-mentor-avatar-inline: 28px;
  --component-audio-btn-height: 40px;
  --component-bottom-nav-height: 82px;
  --component-xiaohe-fab-size: 56px;
}
```

### 测试验收清单

- [ ] **【InputField 抽取前置】补 `AppLayoutConstants.smallRadius = 8`（当前缺失，InputField 抽取的硬阻断任务）**
- [ ] 所有组件使用 DESIGN.md token，无硬编码值
- [ ] 阴影颜色统一为 rgba(45,41,38)
- [ ] PrimaryCTA 最小高度 56px
- [ ] BottomNav 高度 82px，第 4 Tab 为「我」
- [ ] 英文短语字号统一 32px（Fraunces）
- [ ] ScenePill 选中态使用 `--accent` 纯色
- [ ] 触控目标 ≥ 44px
- [ ] 支持 prefers-reduced-motion
- [ ] TalkBack/VoiceOver 基础路径测试通过

---

**Component Spec 版本：** 1.0
**创建日期：** 2026-05-28
**审计来源：** Cross-Page Design Consistency Audit (2026-05-28)
**下次审查：** 进入 Flutter 实现前
