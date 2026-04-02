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

| Component | Usage | Key tokens |
|-----------|-------|-----------|
| PhraseCard | 英文短语展示卡 | Fraunces font, --english color, --radius-md, --shadow-md |
| PlayButton | 发音播放按钮 | --accent, 56-72px, circular, --shadow-md with accent tint |
| SceneTag | 场景标签 | --accent-light bg, --accent text, --radius-full |
| CoachTip | 教练提示条 | --accent-light bg, --text-secondary, --radius-sm |
| ReactionChip | 宝宝反应按钮 | --border stroke, --radius-full, active: --accent-light |
| SceneListItem | 场景列表项 | --bg-surface, --radius-md, full-width |
| ProgressBar | 短语进度条 | 4px height, --border track, --accent fill |
| AlertBanner | 提示/错误横幅 | semantic color soft bg, --radius-sm |
| BottomNav | 底部导航栏 | 4 tabs (首页/发现/笔记/我的), --bg-surface |

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
