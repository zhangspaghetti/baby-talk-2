# Cross-Page Design Consistency Audit

日期：2026-05-28
状态：审计完成
审计范围：9 份设计规格 + 2 份 HTML 原型 + DESIGN.md

## 1. Summary

**Overall Consistency Score: B**

设计系统 "Warm Paper Kindness" 在所有页面间建立了清晰的色彩和字体语言，核心 token（#FFF8F0, #FF8C42, #3B8577, #D4E8E3）在规格文档中引用一致。但在组件细节层面存在若干分歧：导航结构（第 4 个 Tab 命名）、阴影层级、按钮高度、场景 pill 样式、宝宝反应选项在不同页面间不统一。HTML 原型与 DESIGN.md 的 token 定义也存在偏差。

大部分不一致源于页面设计迭代速度快于组件标准化速度——各页面独立演进但缺少统一的组件规范对齐环节。

---

## 2. Findings

### HIGH — 阻塞项

#### H1. 底部导航第 4 Tab 命名不一致
- **涉及页面：** Shell V2 vs Home V23 / Home A/B / Discover
- **问题：** Shell V2 明确定义底部 Tab 为「首页/发现/花园/**我**」，但 Home V23 第 9 节、Discover 第 4 节全局结构、Home A/B 原型的 `bottomNav()` 函数均写为「首页/发现/花园/**成长**」。
- **原因：** Shell V2 基于微信读书"我"页面迭代后将"成长"改为"我"，但其他规格未同步更新。
- **建议：** 统一为 Shell V2 的「我」。更新 Home V23 第 9 节、Discover 第 4 节和 Home A/B 原型中的底部导航文案。如果选择保留"成长"作为独立 Tab，则需回退 Shell V2。

#### H2. 底部导航栏高度不一致
- **涉及页面：** Shell V2 vs Home A/B 原型
- **问题：** Shell V2 指定底部导航栏高度为 82px，Home A/B 原型 CSS 变量 `--nav-height: 72px`。
- **影响：** 10px 差异会影响底部安全区计算和内容区域可用高度。
- **建议：** 确认最终规格，统一所有页面引用。

#### H3. 小禾 FAB 可见性规则未在所有页面对齐
- **涉及页面：** Shell V2 vs Home V23 / Practice
- **问题：** Shell V2 定义「首页使用内联按钮不显示 FAB，花园页隐藏 FAB」。但 Home V23 第 8 节描述首页有内联 `问小禾` 按钮，Practice 也有「低干扰小禾浮动入口」。这两处的 FAB/浮动入口规格（尺寸、阴影、位置）未明确引用 Shell V2 的 56x56px / --shadow-md 规格。
- **建议：** 在 Home V23 和 Practice 中明确引用 Shell V2 的 FAB 规格，或在 Shell V2 中补充内联入口的规格。

---

### MEDIUM — 建议项

#### M1. 英文短语字号跨页面不统一
- **涉及页面：** Onboarding V21 vs Home A/B 原型 vs DESIGN.md
- **问题：**
  - DESIGN.md Type Scale: Hero 32px (Fraunces, 最大英文短语字号)
  - Onboarding V21 规格: 44px
  - Onboarding V21 原型 CSS: `.english { font-size: 44px }`
  - Home A/B 原型: Variant A 30px, Variant B 30px
  - Practice 规格: 未明确指定字号，仅说"英文主句"
- **原因：** Onboarding V21 为了强调首句体验放大了字号，但未回溯更新 DESIGN.md Type Scale。
- **建议：** 确认 Onboarding 的 44px 是否为有意的例外（首句强调），并更新 DESIGN.md 增加 "Display/Onboarding" 层级，或统一为 32px。

#### M2. 圆角值不一致
- **涉及页面：** Onboarding V21 vs Home A/B 原型 vs DESIGN.md
- **问题：**
  - DESIGN.md: --radius-sm 8px, --radius-md 16px, --radius-lg 24px, --radius-full 9999px
  - Onboarding V21 原型: `.scene { --radius: 20px }`（介于 md 和 lg 之间，未使用 token）
  - Onboarding V21 原型: `.end-card { border-radius: 26px }`（非标准值）
  - Home A/B 原型: `.sheet { border-radius: 24px }`（= --radius-lg），`.ctaBtn { border-radius: 16px }`（= --radius-md）
  - Home A/B 原型: `.phone { border-radius: 32px }`（非标准值，但这是设备外壳，可接受）
- **建议：** 场景按钮圆角统一为 16px（--radius-md）或 24px（--radius-lg），结束卡片圆角统一为 24px（--radius-lg）。避免出现 20px、26px 等非 token 值。

#### M3. 阴影层级不统一
- **涉及页面：** Onboarding V21 原型 vs Home A/B 原型 vs DESIGN.md
- **问题：**
  - DESIGN.md: --shadow-sm (0 1px 3px), --shadow-md (0 2px 12px), --shadow-lg (0 8px 24px)
  - Onboarding V21 原型: `--shadow: 0 24px 70px rgba(80,57,35,.12)` — 远超 --shadow-lg，接近 DESIGN.md 定义的 3 倍
  - Home A/B 原型: `--shadow: 0 8px 24px rgba(45,41,38,.12)`（= --shadow-lg），`--soft-shadow: 0 2px 12px rgba(45,41,38,.08)`（= --shadow-md）
  - 阴影颜色：Onboarding 用 `rgba(80,57,35)`，Home A/B 和 DESIGN.md 用 `rgba(45,41,38)`
- **建议：** 统一阴影颜色为 DESIGN.md 的 `rgba(45,41,38)`。Onboarding 原型的 70px 大阴影可以作为 phone 容器装饰保留，但内部组件应引用 --shadow-sm/md/lg。

#### M4. 场景选择交互模式不一致
- **涉及页面：** Onboarding V21 vs Discover vs Home A/B
- **问题：**
  - Onboarding V21: 纵向大按钮列表（≥48px 高），选中后自动进入练习页
  - Discover: 横滑 pill 筛选条，选中态使用 --accent 高亮
  - Home A/B: 场景以文本入口或快速救援行 chip 形式出现
- **原因：** 这三个页面的场景选择目的不同（Onboarding = 选今天场景, Discover = 筛选短语库, Home = 快捷入口），交互模式差异可以理解。
- **建议：** 虽然交互模式可以不同，但场景 pill 的视觉样式应统一。建议定义一个 `ScenePill` 组件规格，包含：选中态颜色、未选中态颜色、圆角、高度、字体大小。各页面引用同一规格。

#### M5. 宝宝反应选项跨页面不一致
- **涉及页面：** Onboarding V21 vs Practice
- **问题：**
  - Onboarding V21: 固定三个选项 —— 「有回应」「安静了」「没反应」
  - Practice: 按场景变化 —— 喂饭时「有回应/吃了一口/没反应」，睡前时「有回应/安静了/没反应」等
- **原因：** Practice 做了更细粒度的场景适配，Onboarding 保持简单。
- **建议：** 两套方案各有道理。建议统一策略：Onboarding 使用固定三项（降低决策成本），Practice 使用场景化选项（增加真实感）。但需要在两份规格中明确标注这一差异是有意设计，避免实现时混淆。

#### M6. "听小禾读"按钮样式不一致
- **涉及页面：** Onboarding V21 原型 vs Home A/B 原型
- **问题：**
  - Onboarding V21 原型: `.audio-btn { min-height: 40px, border-radius: 14px, background: var(--sage-soft), padding: 0 14px }` — 小图标按钮
  - Home A/B 原型: `.listenBtn { min-height: 46px, border-radius: 16px, background: rgba(255,252,247,.7) }` — 较大按钮
- **建议：** 统一为一个 `ListenButton` 组件规格。Onboarding V21 的设计意图是"小图标，不与主 CTA 竞争"，建议所有页面采用较小尺寸（min-height 40-42px），保持辅助动作的视觉定位。

#### M7. Primary CTA 按钮高度不一致
- **涉及页面：** Onboarding V21 vs Home A/B 原型
- **问题：**
  - Onboarding V21 规格: min-height 56px
  - Onboarding V21 原型: `.primary { min-height: 56px }`
  - Home A/B 原型: `.ctaBtn { min-height: 48px }`
  - DESIGN.md: Play button 56-72px
- **建议：** Primary CTA 统一为 min-height 56px（与 Onboarding 一致，且符合 DESIGN.md 的大触摸目标建议）。Home A/B 的 48px 偏小。

#### M8. Pill 组件高度不一致
- **涉及页面：** Onboarding V21 原型 vs Home A/B 原型
- **问题：**
  - Onboarding V21 原型: `.pill { min-height: 32px }`
  - Home A/B 原型: `.pill { min-height: 28px }`
- **建议：** 统一为 min-height 32px（更符合 44px 触摸目标的视觉比例）。

#### M9. 背景处理不一致
- **涉及页面：** Onboarding V21 原型 vs Home A/B 原型
- **问题：**
  - Onboarding V21 body: `background: linear-gradient(135deg, #fffaf3 0%, #FFF8F0 50%, #eef5f0 100%)` — 多色渐变
  - Home A/B body: `background: #F0EBE5` — 纯色（且不是 #FFF8F0）
  - DESIGN.md: `--bg-base: #FFF8F0` — 奶油纸纯色
- **建议：** Onboarding 原型的多色渐变作为设备外壳装饰可接受，但 app 内部背景应使用 #FFF8F0。Home A/B 的 body 背景 #F0EBE5 不是 DESIGN.md token，应改为 #FFF8F0 或 --bg-sunken。

#### M10. 场景按钮选中态样式不一致
- **涉及页面：** Onboarding V21 vs Discover
- **问题：**
  - Onboarding V21: 选中态使用暖色渐变 `linear-gradient(135deg, #8b6248, #bd8c67)` + 白色文字
  - Discover: 选中态使用 `--accent` 高亮（规格描述），需确认实现时是否也用渐变
- **建议：** 统一选中态为 DESIGN.md token 驱动：`background: var(--accent)` + `color: var(--text-on-accent)`，避免使用非 token 的渐变色。

---

### POLISH — 小改进

#### P1. Home A/B 原型底部导航 active 态使用 --sage-soft 而非 --accent
- **问题：** Home A/B `.navItem.active { background: var(--sage-soft); color: var(--sage-2) }` — 选中态为青绿色
- **建议：** 底部导航 active 态通常使用品牌主色（--accent）。确认设计意图：如果青绿色是导航的有意选择（与英文高亮色呼应），则需在 DESIGN.md 中记录这一决策。

#### P2. 小禾头像/标记样式不一致
- **涉及页面：** Onboarding V21 原型 vs Home A/B 原型
- **问题：**
  - Onboarding V21: `.avatar { width: 40px, border-radius: 16px, background: linear-gradient(145deg, #ead0b6, #f8e7d4) }` — 40px 方圆角头像
  - Home A/B: `.mentorMark { width: 28px, border-radius: 12px, background: var(--sage-soft) }` — 28px 小标记
- **建议：** 定义统一的 `MentorAvatar` 组件：大小（40px 用于头部展示，28px 用于内联引用）、圆角、背景色。两处引用同一规格。

#### P3. 场景名称列表在所有页面保持一致
- **检查结果：** 喂饭/喝水/换尿布/洗澡/睡前/出门 — 在 Onboarding V21、Discover、Growth V2、Home V23 中一致。
- **状态：** 通过。

#### P4. 触控目标一致性
- **检查结果：** 所有规格均标注 ≥44px，推荐 48px。HTML 原型中主要按钮均满足。
- **状态：** 通过。个别辅助按钮（如 Onboarding 的发音按钮 40px）略小，但作为辅助动作可接受。

#### P5. "说完了"按钮文案一致性
- **检查结果：** Onboarding V21 和 Practice 均使用「说完了」，Home A/B 原型中 Variant A 使用「说完了」，Variant B 也使用「说完了」。
- **状态：** 通过。

#### P6. prefers-reduced-motion 支持
- **检查结果：** Onboarding V21 原型、Home A/B 原型均实现了 `@media(prefers-reduced-motion:reduce)` 规则。各规格文档也提到支持减少动效。
- **状态：** 通过。

#### P7. DESIGN.md 组件规格与 Shell V2 不完全对齐
- **问题：** DESIGN.md 的 Drawer 组件描述为"右侧抽屉菜单"，但 Shell V2 已将设置改为独立页面（齿轮图标进入），不再是 Drawer。DESIGN.md 未更新。
- **建议：** 更新 DESIGN.md 导航组件部分，移除 Drawer，增加"我"页面和设置页面描述。

---

## 3. Quick Wins — Top 3 Fixes

### 1. 统一底部导航 Tab 命名（5 分钟）
更新 Home V23、Discover、Home A/B 原型中的「成长」→「我」，与 Shell V2 对齐。这是用户可见的一致性问题，直接影响导航体验。

### 2. 统一 Primary CTA 按钮高度为 56px（10 分钟）
Home A/B 原型中 `.ctaBtn { min-height: 48px }` 改为 `min-height: 56px`，与 Onboarding V21 一致。同时在 DESIGN.md Component Vocabulary 中补充 Primary CTA 的标准高度。

### 3. 统一阴影颜色为 rgba(45,41,38)（10 分钟）
Onboarding V21 原型中的 `rgba(80,57,35)` 统一改为 DESIGN.md 的 `rgba(45,41,38)`。阴影颜色不统一会导致不同页面的"深度感"不一致。

---

## 4. Component Inventory

| 组件 | Onboarding V21 | Home V23 | Practice | Discover | Garden V2 | Growth V2 | Shell V2 | Auth | Home A/B | 状态 |
|------|---------------|----------|----------|----------|-----------|-----------|----------|------|----------|------|
| **场景 Pill** | sage-soft bg, sage text, 32px | 引用 DESIGN.md | 引用 DESIGN.md | --accent 高亮, --bg-sunken 未选中 | - | - | - | - | honey-soft bg variant | INCONSISTENT |
| **Primary CTA** | 56px, gradient #FF8C42 | 引用 DESIGN.md | 引用 DESIGN.md | 引用 DESIGN.md | "去说一句" 按钮 | "去说一句" 按钮 | - | 渐变 CTA | 48px, flat #FF8C42 | INCONSISTENT |
| **Secondary Button** | 50px, border, sage text | 引用 DESIGN.md | 引用 DESIGN.md | 引用 DESIGN.md | - | - | - | border button | 44px, border, sage text | CONSISTENT |
| **小禾 Avatar/Mark** | 40px, warm gradient | 引用 DESIGN.md | 引用 DESIGN.md | - | - | - | 56x56 FAB | - | 28px, sage-soft | INCONSISTENT |
| **小禾 Bubble** | surface bg, 18px radius, 7px tail | 内联引用 | 内联引用 | - | - | - | - | - | sage bg, 16px radius | INCONSISTENT |
| **English Phrase** | 44px Fraunces | 引用 DESIGN.md | 引用 DESIGN.md | Fraunces, --english | - | - | - | - | 30px Fraunces | INCONSISTENT |
| **底部导航** | - | 4-tab "成长" | - | 4-tab "成长" | - | - | 4-tab "我", 82px | - | 4-tab "成长", 72px | INCONSISTENT |
| **Xiaohe FAB** | - | 内联入口 | 低干扰入口 | FAB | 隐藏 | FAB | 56x56, --shadow-md | - | - | INCONSISTENT |
| **宝宝反应** | 3 固定项 + icons | - | 按场景变化 | - | - | - | - | - | - | INTENTIONAL DIFF |
| **搜索栏** | - | - | - | --bg-sunken, --radius-sm | - | - | - | 输入框 | - | CONSISTENT |
| **卡片容器** | transparent (borderless) | --shadow-md | transparent (borderless) | --bg-surface, --shadow-sm | - | - | - | - | --surface, --soft-shadow | INCONSISTENT |
| **Toast** | - | 轻 toast 1.5-3s | - | - | - | - | - | - | sage-soft bg toast | CONSISTENT |

---

## 5. Recommendations for Next Steps

1. **创建统一的 Component Spec 文档** — 将上述 INCONSISTENT 组件逐个定义标准规格，各页面引用而非重新定义。
2. **同步 Shell V2 的导航变更** — 将「我」Tab 的变更同步到所有引用底部导航的页面。
3. **HTML 原型对齐 DESIGN.md token** — 优先修复阴影颜色、CTA 高度、pill 高度三处偏差。
4. **定义场景 pill 的选中态规范** — 统一为 token 驱动，避免非标准渐变。
5. **更新 DESIGN.md** — 移除 Drawer 组件描述，增加"我"页面、设置页面、Garden V2 单株成长模型的组件描述。
