# Design System — Baby Talk 2

## Product Context
- **What this is:** Flutter 原生 app，帮助中国父母在日常场景（换尿布、洗澡、喂奶、睡前）中用英语和 0-3 岁宝宝互动
- **Who it's for:** 25-40 岁、一二线城市、CET-4/6 英语水平的中国父母
- **Space/industry:** 亲子英语启蒙。竞品包括叽里呱啦、Duolingo ABC、Kinedu
- **Project type:** Mobile app (Flutter, Android + iOS)

## Aesthetic Direction
- **Direction:** 暖纸亲和 (Warm Paper Kindness)
- **Decoration level:** Intentional — 有节制的细节，不是全平也不是花哨
- **Mood:** 温暖、克制、亲切。像父母写给孩子的一封信，不是一个学习任务清单。打开 app 的 3 秒内应该感到：「我可以做到。」
- **Design camp:** 亲子指导派（Kinedu 路线），不是儿童教育派（叽里呱啦路线）。用户是父母，不是小孩
- **Reference sites:** kinedu.com (同赛道定位最接近), babysparks.com (亲子工具审美)
- **Anti-slop:** 禁止紫色渐变、三列图标网格、居中万物、统一圆角气泡、渐变按钮

## Typography

### Font Stack
- **Display/Hero (英文短语):** Fraunces (variable, opsz 9-144, wght 300-700)
  - 温暖的衬线体，读起来像绘本台词而不是闪卡。竞品全用无衬线体，这是差异化的核心
  - 只用于 24px 以上的英文短语显示，不用于 UI 文本
  - 小字号衬线体可读性下降，严格限制最小使用字号
- **Body (中文):** PingFang SC → Noto Sans SC → Microsoft YaHei → sans-serif
  - iOS 原生字体，零加载成本，渲染质量最好
  - Phase 2 可选升级到得意黑 (Smiley Sans)，需评估 CJK 字体包大小 (~5MB) 对首屏速度的影响
- **Body (英文 UI):** DM Sans (wght 400-700)
  - 干净的几何无衬线体，支持 tabular-nums
  - 和 Fraunces 形成清晰层级：Fraunces = 你说出口的话，DM Sans = app 的界面
- **Data/Tables:** DM Sans (tabular-nums feature)
- **Code/Phonetics:** JetBrains Mono (wght 400-500)
  - 用于 IPA 音标和发音指南，等宽字体创造「技术辅助」的视觉分隔

### Loading
- **Flutter APK/IPA 内置字体** — 不使用 Google Fonts CDN（中国大陆不可用）
- Fraunces (variable, opsz 9-144, wght 300-700) → `pubspec.yaml` assets 打包
- DM Sans (wght 400-700) → `pubspec.yaml` assets 打包
- JetBrains Mono (wght 400-500) → `pubspec.yaml` assets 打包
- 预计增加 APK 大小 ~500KB
- 不使用 `google_fonts` package，直接用 `TextStyle(fontFamily: 'Fraunces')` 引用

### Type Scale
| Level | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| Hero | 32px | 500 | 1.2 | 英文短语大号显示 (Fraunces) |
| Title 1 | 28px | 500 | 1.3 | 英文短语标准显示 (Fraunces) |
| Title 2 | 24px | 500 | 1.3 | 英文短语最小号 (Fraunces) |
| Heading | 20px | 700 | 1.4 | 页面标题 (PingFang SC) |
| Subheading | 16px | 700 | 1.4 | 章节标题 (PingFang SC) |
| Body | 15px | 400 | 1.6 | 正文 (PingFang SC / DM Sans) |
| Caption | 13px | 400 | 1.5 | 辅助说明 |
| Micro | 11px | 600 | 1.4 | 标签、badge |
| Mono | 14px | 400 | 1.5 | 音标 (JetBrains Mono) |

## Color

### Approach: Restrained
一个暖色强调 + 一个功能色 + 中性暖灰。颜色是稀缺的、有意义的。

### Core Palette
| Token | Hex | Usage |
|-------|-----|-------|
| `--bg-base` | #FFF8F0 | 奶油纸 — 主背景 |
| `--bg-surface` | #FFFFFF | 卡片表面 |
| `--bg-sunken` | #F5F0EB | 下沉区域、页面底色 |
| `--bg-accent-soft` | #FFF0E5 | 强调淡底、标签背景 |
| `--accent` | #FF8C42 | 暖橙 — 主 CTA、品牌色 |
| `--accent-dark` | #E67A30 | 深橙 — hover、对比度修复 |
| `--accent-light` | #FFF0E5 | 淡橙底 |

### English Highlight
| Token | Hex | Usage |
|-------|-----|-------|
| `--english` | #3B8577 | 青绿 — 英文短语标记 |
| `--english-soft` | #D4E8E3 | 淡青绿 — 英文背景 |

设计决策：从蓝色 #2563EB 改为青绿 #3B8577。蓝色传达「英语是外语」，青绿传达「英语是生活中自然生长的东西」。与暖色调更和谐。

### Text Colors
| Token | Hex | Contrast on #FFF8F0 | Usage |
|-------|-----|---------------------|-------|
| `--text-primary` | #2D2926 | 14.2:1 AA✓ AAA✓ | 正文 |
| `--text-secondary` | #6B5E57 | 7.1:1 AA✓ AAA✓ | 次要文字 |
| `--text-muted` | #8A7D76 | 4.5:1 AA✓ | 弱文字、占位符 |
| `--text-on-accent` | #FFFFFF | — | 强调色上的文字 |

### Semantic Colors
| Token | Hex | Soft Variant | Usage |
|-------|-----|--------------|-------|
| `--success` | #6B8F5E | #E8F0E5 | 苔藓绿 — 完成、掌握 |
| `--warning` | #E6A817 | #FFF5D9 | 琥珀 — 提醒、中断 |
| `--error` | #D94B3C | #FDE8E6 | 红 — 错误、失败 |
| `--info` | #3B8577 | #D4E8E3 | 青绿 — 教练提示 |

### Dark Mode Strategy
- 背景从奶油纸翻转到暖深色 #1C1816
- 卡片表面 #2A2420，保持暖色调
- 强调色微调亮度 #FF8C42 → #FF9E5C
- 英文青绿提亮 #3B8577 → #5AAFA0
- 文字色反转但保持暖色基底
- 阴影改用纯黑透明度

## Spacing
- **Base unit:** 8px
- **Density:** Comfortable — 移动端亲子 app 需要充裕的呼吸感，单手操作的触摸目标要大
- **Scale:**

| Token | Value | Usage |
|-------|-------|-------|
| `--space-2xs` | 2px | 极小间隙 |
| `--space-xs` | 4px | 紧凑间隙 |
| `--space-sm` | 8px | 元素内间距 |
| `--space-md` | 16px | 默认间距 |
| `--space-lg` | 24px | 区块间距 |
| `--space-xl` | 32px | 章节间距 |
| `--space-2xl` | 48px | 大区块间距 |
| `--space-3xl` | 64px | 页面级间距 |

- **Minimum touch target:** 44x44px (iOS HIG), 推荐 48x48px
- **Play button:** 56x56px minimum, 72px recommended (单手持宝宝时的拇指操作)

## Layout
- **Approach:** Grid-disciplined, 单列卡片流
- **Grid:** 单列全宽 (移动端), 最大宽度 430px (web landing page)
- **Max content width:** 430px (手机壳内容区)
- **Card padding:** 20px horizontal, 24px vertical
- **Page padding:** 16px-20px horizontal

### Border Radius (Hierarchical)
| Token | Value | Usage |
|-------|-------|-------|
| `--radius-sm` | 8px | 按钮、输入框、标签、小组件 |
| `--radius-md` | 16px | 卡片、模块容器 |
| `--radius-lg` | 24px | 弹窗、底部抽屉、modal |
| `--radius-full` | 9999px | 圆形按钮、pill 标签 |

不使用统一圆角。小元素更锐利，大容器更圆润，建立视觉层级。

### Shadows (Warm)
| Token | Value | Usage |
|-------|-------|-------|
| `--shadow-sm` | 0 1px 3px rgba(45,41,38,0.06) | 静态卡片 |
| `--shadow-md` | 0 2px 12px rgba(45,41,38,0.08) | 浮起卡片、短语卡 |
| `--shadow-lg` | 0 8px 24px rgba(45,41,38,0.12) | 弹窗、浮层 |

阴影颜色使用暖色 rgba(45,41,38)，不是冷灰 rgba(0,0,0)。和奶油色背景自然融合。

## Motion
- **Approach:** Minimal-functional — 只做辅助理解的状态过渡，不做装饰动画
- **Exception:** 庆祝屏 (宝宝第一个英文词) 可以使用表现力更强的动画

### Easing
| Type | Curve | Usage |
|------|-------|-------|
| Enter | ease-out / cubic-bezier(0, 0, 0.2, 1) | 元素进入视口 |
| Exit | ease-in / cubic-bezier(0.4, 0, 1, 1) | 元素离开视口 |
| Move | ease-in-out / cubic-bezier(0.4, 0, 0.2, 1) | 位置变化 |

### Duration
| Type | Range | Usage |
|------|-------|-------|
| Micro | 50-100ms | 按钮点击反馈、toggle |
| Short | 150-250ms | 卡片展开、页面过渡 |
| Medium | 250-400ms | 底部抽屉弹出、modal |
| Long | 400-700ms | 庆祝动画、里程碑 |

## Design Tokens (CSS Custom Properties)

完整的 CSS token 定义见预览文件：
`./doc/designs/design-system-20260402/tokens.css`

## Component Vocabulary (Flutter)

### 核心组件

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| PhraseCard | 英文短语展示卡 (激活框模式下可展开/收缩) | Fraunces font, --english color, --radius-md, --shadow-md |
| PlayButton | 发音播放按钮 | --accent, 56-72px, circular, --shadow-md with accent tint |
| SceneTag | 场景/空间标签 | --accent-light bg, --accent text, --radius-full |
| CoachTip | 教练提示条 | --accent-light bg, --text-secondary, --radius-sm |
| ReactionChip | 宝宝反应按钮 | --border stroke, --radius-full, active: --accent-light, min 48x48px 触摸目标 |
| ProgressBar | 短语进度条 | 4px height, --border track, --accent fill |
| AlertBanner | 提示/错误横幅 | semantic color soft bg, --radius-sm |

### 导航组件 (Design Review v3 更新)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| BottomNav | 底部导航栏 | 4 tabs (首页/发现/花园/成长), --bg-surface |
| Drawer | 右侧抽屉菜单 (首页左上角头像/汉堡触发) | --bg-surface, --shadow-lg, --radius-lg (左侧圆角), 310px 宽 |
| MentorFAB | 小禾老师全局悬浮按钮 (所有页面) | --accent, 56px, circular, --shadow-lg, 右下角固定 |
| MentorPanel | 小禾老师双模式面板 (建议+聊天) | --bg-surface, --radius-lg (顶部圆角), 60%屏高, backdrop-filter: blur(8px) |

### 花园组件 (Design Review v3 新增)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| GardenMap | 可拖动花圃地图画布 | --bg-paper + 极淡绿色渐变, 760x760px 画布 |
| FlowerPatch | 花圃组件 (空间级别) | 圆形卡片 + SVG 进度环, --radius-full |
| FlowerBud | 花朵组件 (活动级别) | 5 阶段: 种子→发芽→生长→开花→盛放, SVG/Lottie 动画 |
| WaterButton | 浇水按钮 (底部浮层) | --accent, --radius-full, 触觉反馈 |
| GardenToast | 练习→花园因果反馈 toast | --success-soft bg, 花圃缩略图, 3s 自动消失 |

### 场景练习组件 (Design Review v3 更新)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| ActivationFrame | 屏幕中部激活区域 | --english-soft border, 标记当前练习的卡片 |
| CardSummary | 收缩态短语卡 | 步骤号圆点 + 标题 + 短语preview + 完成badge, --bg-sunken |
| CardExpanded | 展开态短语卡 | Fraunces 大号 + IPA(JetBrains Mono) + 播放 + 速度 + 反应chips |
| StepProgressBar | 步骤进度条 (固定顶部) | --accent fill, 步数计数器 |
| DifficultyPill | 难度选择 pill | --radius-full, 初级/中级/高级, 锁定态用 --text-muted + 🔒 |

### 成长组件 (Design Review v3 新增)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| DiaryCard | 自动日记卡片 | --bg-surface, --radius-md, 左边框颜色分类 (练习=teal, 里程碑=orange) |
| ManualNoteCard | 手动笔记卡片 | --bg-surface, --radius-md, 用户文字 + 时间戳 |
| StageProgressBar | 阶段总进度条 | --accent fill, 阶段标签 + 百分比 |
| SceneProgressCard | 空间进度卡片 | --bg-surface, --radius-md, 条形图 + 练习次数 + 宝宝回应次数 |
| MilestoneItem | 里程碑条目 | ✅/⬜ 图标, 时间戳, --success or --text-muted |

### Onboarding 组件 (Design Review v3 更新)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| MentorBubble | 小禾老师对话气泡 | --bg-surface, --shadow-sm, 左对齐 + 头像 |
| UserBubble | 用户对话气泡 | --accent bg, --text-on-accent, 右对齐 |
| QuickSelectCard | 月龄快速选择 (4格) | --bg-surface, --radius-md, active: --accent border |
| MiniSceneCard | 迷你场景体验卡 | --english-soft bg, Fraunces 短语, 播放按钮 |

### 首页组件 (Design Review v3 更新)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| BabyStatusBar | 宝宝状态条 (天气=情绪映射) | --bg-sunken, emoji天气图标, --text-secondary |
| TodaySceneCard | 今日场景大卡片 (核心 CTA) | --bg-surface, --shadow-md, --radius-lg, 播放按钮 |
| GardenMiniEntry | 花园迷你入口 | --success-soft bg, 花圃缩略图, "查看花园→" |
| WeekStats | 本周统计条 | --bg-sunken, 短语数 + 连续天数 |

### 发现组件 (Design Review v3 更新)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| DualTabBar | 双维度 Tab (按活动/按空间) | --bg-sunken tab bar, --accent active indicator |
| SearchBar | 搜索框 (与标题同行) | --bg-sunken, --radius-sm, 16px 搜索图标 |
| StageFilterStrip | 阶段筛选横滑条 | --radius-full pills, --accent active, 默认匹配当前阶段 |
| ActivityCard | 活动卡片 (按活动视图) | --bg-surface, 左侧彩色条纹, 英文预览 + 进度条 |
| SpaceGridItem | 空间宫格项 (按空间视图) | 2x3 grid, 渐变色背景 + 进度 |

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-02 | Initial design system created | Created by /design-consultation based on competitive research (叽里呱啦, Duolingo ABC, Kinedu, PalFish) + Claude subagent independent proposal |
| 2026-04-02 | English phrases use Fraunces serif | RISK: differentiation from flashcard-style sans-serif. Every competitor uses sans-serif for English display. Fraunces adds storybook warmth. Min size 24px. |
| 2026-04-02 | English highlight color changed from blue to teal | RISK: #2563EB → #3B8577. Blue signals "foreign language", teal signals "naturally growing in your home". Better harmony with warm palette. |
| 2026-04-02 | Keep PingFang SC for Chinese (defer 得意黑) | SAFE: zero loading cost, best rendering on iOS. Smiley Sans is Phase 2 upgrade candidate, pending font file size evaluation. |
| 2026-04-02 | Keep #FFF8F0 + #FF8C42 core palette | SAFE: validated across 12 existing HTML mockups. Changing would require redoing all mockups. |
| 2026-04-02 | Hierarchical border radius 8/16/24/full | Replaces flat 16px everywhere. Small elements sharper, large containers softer. |
| 2026-04-02 | Warm shadows rgba(45,41,38) instead of cool gray | Blends naturally with cream background. Subtle but noticeable difference. |
| 2026-04-02 | ~~Navigation: 4-tab+FAB → 5-tab with center Coach icon~~ | ~~Design Review v2~~ **SUPERSEDED by Design Review v3** |
| 2026-04-02 | Dark Mode: follow system setting | Design Review v2. 跟随系统设置，使用 DESIGN.md dark mode token 策略。|
| 2026-04-02 | Screen orientation: portrait lock | Design Review v2. Phase 1 锁定竖屏，简化布局开发。|
| 2026-04-04 | Navigation: 5-tab → 4-tab + Drawer + Mentor FAB | Design Review v3. 4 tabs (首页/发现/花园/成长)。"我的"取消，改为头像/汉堡→右侧抽屉。AI Coach 改为全局小禾老师 FAB。|
| 2026-04-04 | 花园系统 Phase 1 完整版 | Design Review v3. 可拖动花圃地图 + 生长点系统 + 播种仪式。不简化。|
| 2026-04-04 | 3 层内容模型: 空间→活动→短语 | Design Review v3. 替代 6 扁平场景。空间=花圃，活动=花朵，短语=练习。|
| 2026-04-04 | 全局小禾老师 Mentor FAB | Design Review v3 + Design Shotgun. 双模式面板(建议+聊天)，替代独立 Coach tab。离线时显示本地预设建议。|
| 2026-04-04 | 对话式 Onboarding (小禾老师导师) | Design Shotgun. 导师角色贯穿 + 月龄快选 + 迷你场景体验30s + 注册。|
| 2026-04-04 | 场景练习: C3 激活框 scroll 模式 | Design Shotgun. 卡片滚过激活框时展开，离开时收缩。步骤引导流。|
| 2026-04-04 | 成长 tab 默认日记视图 | Design Review v3. 日记 > 场景进展 > 里程碑。自动生成 + 手动添加。|
| 2026-04-04 | 练习→花园因果 toast | Design Review v3. 完成练习后底部 toast: "你的🌱洗澡花刚发芽了!" + 缩略图。|
| 2026-04-04 | 家长圈社交 → Phase 2 | Design Review v3. 10 人规模社交内容密度不够。|
| 2026-04-04 | 笔记/语音备忘 → 分散到成长+FAB | Design Review v3. 日记在成长tab，语音输入在 FAB。不单独做。|
| 2026-04-04 | Emoji → 插画/SVG 替换 | Design Shotgun 确认。实现时所有 emoji 占位替换为精美插画/图标/Lottie。|
| 2026-04-02 | Discovery: single-column variable-height cards | Design Review v2. Anti-slop: 不用 2x3 网格，改用单列不等高卡片流。|
| 2026-04-02 | Notes tab active in Phase 1 as Voice Memo | Design Review v2. 语音备忘录功能提前到 Phase 1，本地 Isar 存储，不需要 OSS。|
| 2026-04-02 | Mockup audit: 5-tab nav synced to all pages | 审计修复。所有 mockup HTML 从 4-tab+FAB 更新为 5-tab（首页/发现/教练/笔记/我的），中央教练图标突出。|
| 2026-04-02 | Mockup audit: dark mode CSS tokens added | 审计修复。tokens.css 增加 @media (prefers-color-scheme: dark) 完整 token 集。|
| 2026-04-02 | Mockup audit: --shadow-accent token added | 审计修复。play button hover 阴影从 hardcoded 改为 CSS custom property。|
| 2026-04-02 | Mockup audit: scene-icon semantic classes | 审计修复。discovery.html 场景图标背景色从 inline style 改为语义类（.bath/.diaper/.feeding 等）。|
| 2026-04-02 | Mockup audit: tabular-nums enabled | 审计修复。所有数字显示加 font-variant-numeric: tabular-nums，保证数据对齐。|
| 2026-04-02 | Mockup audit: Fraunces min 24px enforced | 审计修复。ai-coach.html .phrase-highlight 从 20px 修正为 24px。|
