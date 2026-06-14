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

## 移动端产品一致性补充（2026-06-09）

本节是 Baby Talk 2 移动端原型一致性的基准。所有生成原型和 Flutter 页面都必须看起来属于同一个产品，并延续已批准的 onboarding 暖纸方向。

### 产品承诺
- App 不把英语当学科来教，而是帮助家长在真实照护时刻对宝宝说一句或几句简单英语。
- 核心承诺：`不是学英语，而是在和宝宝说话。`
- 用户永远是家长，不是孩子。避免儿童化卡通、游戏机制、分数反馈和课堂语言。

### Home 产品模型
- Home 不是固定短语模板页，而是**当前时刻的对话入口页**。
- 打开 Home 后 3 秒内应该回答：
  1. App 认为现在大概是什么照护时刻？
  2. 哪个可见入口可以马上开始一段照护对话？
  3. 如何继续刚才的对话，或描述当前特殊情况？
- Home 展示照护情境入口，不展示英语短语卡。家长选择入口后，英语短语才在 Practice 中出现。
- Home 的入口推荐可根据时间、最近场景、宝宝年龄/昵称、最近说过的话、进行中的对话和家长偏好动态准备。
- UI 必须隐藏 AI 机制。禁止显示 `AI生成`、`LLM`、`prompt`、`模型`、`置信度`、`重新生成`。
- 使用小禾语言：`小禾在看现在适合怎么开口`、`小禾正在换成更贴近现在的入口`、`告诉小禾一点点，下一句会更贴近`。

### 跨页面风格规则
- Onboarding、Home、Practice、Discover、Garden/Growth、Me 和小禾页面必须共享暖奶油纸背景、暖棕文字、英语短语青绿色、克制植物痕迹和同一套圆角节奏。
- 不为每个页面创建独立视觉语言。Home 应该像 onboarding 之后自然出现的页面，而不是仪表盘。
- 橙色很稀缺：每屏只用于一个主要动作，最多再用于一个小的选中状态。不要用橙色强调数字、tab 背景、分数或装饰。
- 青绿色只用于英语短语文字和少量发音相关强调。不要把青绿色做成大面积背景。
- 避免胶带、拼贴、渐变光斑、贴纸、大量卡片堆叠和仪表盘式统计模块。
- 底部导航保持安静：只使用线性图标和文字，不使用填充式选中背景，不显示 badge。页面规格允许时，选中 tab 可使用 `--accent-dark`。

### 交互边界
- Home 负责展示当前照护入口、可选继续入口、宝宝信号入口和自定义当前情况入口。
- Practice 负责展示英语短语、标准发音、`我说了`、可选宝宝反应，以及逐句生成下一句。
- Garden/Growth 负责长期记录和叙事反馈。
- 小禾可以解释为什么某个入口适合当下，但 Home 不应该像通用聊天机器人页面。
- 除非未来明确加入录音功能，否则不出现麦克风或录音暗示。发音支持只使用扬声器/播放。
- 不出现发音评分、失败状态、连续打卡压力、积分、排行榜或任务完成框架。

### 动态时刻状态
- **默认状态：** 当前推断时刻下显示 4 个直接开始的对话入口。
- **继续状态：** 仅当有 30 分钟内更新过的 open 对话时，显示 1 个继续入口。
- **宝宝信号：** 打开温柔底部抽屉，可选 `哭了`、`笑了`、`指东西`、`说了一个词` 或短文本。
- **自定义情况：** 打开底部抽屉处理 `不肯睡`、`要喝水`、`吃饭闹`、`要出门`、`刚洗完澡`、`想继续玩` 等例外情况。
- **入口准备中：** 小禾准备更贴近当前时刻的入口时，保留本地/缓存入口可用，不能清空页面。
- **离线：** 使用本地默认入口，文案为 `现在没联网，先用这几个常用入口。`
- **低置信度：** 保持 4 个入口可见，文案为 `现在可能适合先轻轻说几句。`，不要说识别失败。

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
| `--bg-surface` | #FFFCF7 | 温纸表面，移动端避免纯白 |
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
| `--error` | #B36B5E | #F6E7E1 | 暖陶土 — 系统问题提示，不用于评价用户 |
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
| BottomNav | 底部导航栏 | 4 tabs (首页/发现/花园&成长/我的), quiet line icons/text, no filled active background, --bg-surface |
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

### 场景练习组件 (Practice V2 共同注意力回合台)

本节覆盖旧的 `ActivationFrame`、`CardSummary`、`CardExpanded`、`StepProgressBar` 和 `DifficultyPill` 模型。Practice 不再使用固定步骤、难度选择或短语组进度。

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| PracticeContextHeader | 当前照护上下文 | 场景标题 + 1 行上下文，warm brown text，不显示进度 |
| CurrentPhrasePanel | 当前可说的一句 | Fraunces 大号英文, --english color, --bg-surface, --radius-md, warm shadow |
| StandardPronunciationControl | 标准发音播放 | 扬声器/播放图标 + `听标准发音`，禁止麦克风/录音/波形 |
| SaidItButton | `我说了` 主动作 | --accent, 56px height, no icon, bottom safe area |
| SaidConfirmationPill | 已经说出的轻确认 | soft green background, no reward language |
| BabySignalStrip | `我说了` 后的宝宝信号 | responsive chips, max 6 signals, no emoji grid, optional text entry |
| BabyWordsSheet | 宝宝说了轻文本输入 | bottom sheet, single-line input, no recording permission |
| NextPhraseLoadingPanel | 下一句准备中 | previous phrase dimmed, warm loading copy, no spinner-only blank screen |
| NextPhraseReadyPanel | 下一句已生成 | generated phrase + `继续说下去` / `今天先到这里` |
| PracticeSummaryPanel | 温柔复盘 | narrative count + garden trace, no score/accuracy |

### 成长组件 (Design Review v3 新增)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| DiaryCard | 自动日记卡片 | --bg-surface, --radius-md, 左边框颜色分类 (练习=teal, 里程碑=orange) |
| ManualNoteCard | 手动笔记卡片 | --bg-surface, --radius-md, 用户文字 + 时间戳 |
| StageProgressBar | 阶段总进度条 | --accent fill, 阶段标签 + 百分比 |
| SceneProgressCard | 空间进度卡片 | --bg-surface, --radius-md, 条形图 + 练习次数 + 宝宝回应次数 |
| MilestoneItem | 里程碑条目 | ✅/⬜ 图标, 时间戳, --success or --text-muted |

### Onboarding 组件 (Onboarding V4 连续生成体验)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| OnboardingTopBar | 小禾身份与首次问候 | 小禾头像/initials + 一句低压力说明 |
| OnboardingPromiseBlock | 产品承诺说明 | `不用学英语，只要对宝宝轻轻说一句。` |
| OnboardingRouteSelector | 首次当前情境选择 | 2x2 情境入口，固定显示 4 个 |
| OnboardingRouteTile | 单个照护情境入口 | line icon + title + subtitle, selected route uses scarce orange border |
| FirstPhraseLoadingState | 第一句准备中 | 暖纸 shimmer，不使用全屏 spinner |
| OnboardingPhrasePanel | 当前要说的一句 | Fraunces English phrase, Chinese translation, phonetic helper |
| StandardPronunciationControl | 标准发音播放 | 只用扬声器/播放，不用麦克风/录音/波形 |
| SaidItActionBar | `我说了` 底部动作 | 易触达底部动作，不带录音暗示 |
| BabySignalPanel | `我说了` 后的可选宝宝信号 | chips + optional text, auto-continue after 4s |
| NextPhraseLoadingState | 下一句上下文生成中 | `小禾正在接住刚才这一刻。` |
| NextPhraseReadyPanel | 下一句已生成 | Shows generated next phrase and `继续说下去` / `今天先到这里` |
| OnboardingGardenWelcome | 首句花园欢迎 | Skippable nickname field, no reward language |

### 首页组件 (Home V4 Context Launcher)

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| HomeTopBar | 小禾身份和问候 | 小禾头像/initials + `晚上好，妈妈`, menu icon |
| CurrentContextStatement | 当前时刻判断 | `现在可能是睡前或安抚时间。`, 3 quiet context pills |
| ContinueConversationStrip | 继续刚才的对话 | One slim warm row, visible only for open conversations updated within 30 minutes |
| ConversationRouteGrid | 4 个当下对话入口 | 2x2 情境入口，固定显示 4 个，不是三列图标网格 |
| ConversationRouteTile | 单个照护对话入口 | line icon + title + subtitle + chevron; whole tile is tappable |
| BabySignalEntry | 宝宝信号入口 | Full-width warm row, opens BabySignalSheet |
| CurrentSituationEntry | 自定义当前情况入口 | Full-width warm row, opens CurrentSituationSheet |
| BabySignalSheet | 宝宝反应/行为底部抽屉 | `宝宝刚刚怎么样？`, optional signal chips and text |
| CurrentSituationSheet | 当前情况底部抽屉 | `现在是什么情况？`, quick choices + required short text/choice |
| RoutePreparingHint | 动态入口准备状态 | Keeps current route entries visible, copy: `小禾正在换成更贴近现在的入口` |
| HomeGardenWhisper | 花园轻瞥 | One quiet line or tiny sprout only; never stats, never main narrative |

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
| 2026-06-09 | 增加移动端一致性补充和 Home V3 当前时刻入口模型 | Home 曾被定义为由后端动态准备的当前时刻语言入口，并隐藏 AI 机制。该模型已在 2026-06-10 被 Home V4 取代。 |
| 2026-06-09 | 用当前时刻入口组件替代 Home 仪表盘/统计组件 | 避免固定模板、周统计和任务产品感。该组件模型已被 Home V4 情境入口模型取代。 |
| 2026-06-10 | Home V4 当下对话入口模型批准 | Home 不再展示英语短语卡或固定 3 句短语组；改为 4 个直接开始的照护对话入口、可选继续入口、宝宝信号入口和自定义当前情况入口。Practice 负责短语生成和发音。 |
| 2026-06-10 | Onboarding V4 连续生成闭环批准 | Onboarding 不再教学固定短语组，而是教会用户：选择情境、听第一句、对宝宝说、可选宝宝信号、收到上下文生成的下一句，然后继续或温柔结束。 |
| 2026-06-09 | 移动端表面避免纯白，错误色避免红色评判感 | 保持暖纸材质一致，避免系统问题让用户感觉自己做错了。 |
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
