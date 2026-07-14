Baby Talk 2 – Final Design Brief

## Active mobile strategic supersession

As of 2026-06-29, the active mobile strategic supersession reference is:

`docs/design-spec/BabyTalk_Mobile_Duolingo-like_Care_Path_Design_Contract.md`

Engineering architecture for this supersession:

`docs/design-spec/BabyTalk_Mobile_Care_Path_Engineering_Architecture.md`

Future mobile page planning must read that contract before using the older page specs in this folder. It supersedes conflicting mobile / mobile_v2 / Practice / Discover / Garden / Growth / Ritual Room direction, including navigation, user-facing framing, the status of `mobile_v2 Ritual Room`, Garden/Growth semantics, and the next approved implementation slice.

Older documents in `docs/design-spec/`, `DESIGN.md`, and mobile_v2 planning records remain useful as historical references and for non-conflicting details. When they conflict with the care path contract, the contract is the source of truth.

Project overview
Design a mobile app called “Baby Talk 2” — a warm, supportive companion that helps Chinese parents (age 25–40, can read English but struggle to speak) naturally say a few simple English phrases to their 0–3 year old baby during a specific care moment. The app does not teach English; it gives parents a small, manageable set of things they can say right now while feeding, bathing, changing or putting baby to sleep. The emotional promise: “You’re not learning English. You’re talking to your baby.”

Design DNA: “Warm Paper Kindness”
The app should feel like a handwritten note from parent to child — warm, restrained, intentional. The parent is the user, never the child. No cartoon, no gamification, no childish interfaces. Think Kinedu’s parent-facing warmth, not Duolingo or 叽里呱啦. A single warm accent colour carries meaning; in any one screen the accent colour should appear on no more than two elements. The visual weight of every screen is carried by typography and whitespace, never by decorative elements. Absolutely avoid purple gradients, 3-column icon grids, centred-everything layouts, generic gradient buttons and decorative blobs.

Core emotional rules (bake these into every interaction)

· Never judge. No pronunciation scores, no failures — only “I said it” and “baby reacted”.
· Use the child’s name wherever possible (“小明 is waiting to hear you” rather than “Start practice”).
· Celebrate with micro-animations over numbers (pressing “I said it” creates star particles, not “+1 points”).
· Progress is told through warm narratives (“You shared 5 feeding phrases with 小明 this evening”), never cold percentages alone.
· Each English phrase is presented as a small, precious gift, never as a task or test item. The typography must make each phrase feel cherished and easy to read aloud.
· Silence is met with gentleness. When a parent hasn’t practiced for a while, the system never says “You missed a day.” Instead it says something like “小明的花园今天在安静等待，随时可以来。”

Colour & material feeling

· Background: warm cream/paper tones, soft and tactile, never pure white or cold grey.
· Primary accent: a restrained warm orange, used extremely sparingly — for the main call-to-action and one other small key element at most.
· English phrase highlight: a muted, natural teal that feels kind and calm. This teal must only be used for the English phrase text itself, never as a large background area or card fill, to keep the overall temperature warm.
· Success/growth: soft botanical green.
· Warning/hint: a gentle honey-amber, never a sharp alert yellow. No red error colour anywhere — if a system-level error must exist, use a subdued warm tone and never display it as a judgement on the user.
· Text colours all carry a warm undertone; pure black (#000000) is never used.
· Shadows: warm-toned, never cold black.
· Dark mode: warm dark browns as base, with surfaces feeling like a soft warm textile rather than a cool dashboard; the accent softens to a warmer orange.

Typography direction

· English phrases: a warm, slightly condensed serif with storybook character. Preferred typeface: Fraunces. Fallback order if Fraunces not available: Lora → Georgia → system serif. Weight always stays between 400 and 600 — never bold or heavy. The English phrase is the single largest text on any screen.
· Chinese body text: native system font (PingFang SC), clean and readable.
· UI labels: a friendly geometric sans-serif (like DM Sans). If unavailable, fall back to system sans-serif.
· Phonetic helpers: monospace, modestly sized.
· Hierarchy through size and weight only, never through competing colours or decorations.
· Size references: Hero English phrase 30–36px; Chinese translation 14–15px; scene labels and pills 12–13px; body UI labels 14–16px. No other text may approach the size of the English phrase.
· Line-height for English phrases and their translations should be generous (1.5–1.6), giving the feeling that the phrase has been carefully placed on paper with room to breathe.
· When English and Chinese appear together, the English phrase is always the visual lead; the Chinese translation steps back through regular weight and muted colour.

What the app needs to do (functional skeleton — free to reimagine layout)
The app is structured around a 4-tab bottom bar: Home / Discover / Garden & Growth / Me, plus a discreet hamburger drawer for settings and profiles. A global floating mentor button (小禾老师) gives access to AI suggestions and chat, and may be hidden on Home and Garden where inline entries already exist.

· Home — “This moment’s phrases”
  The first thing a parent sees. It presents a small, lovingly curated set of phrases for the recommended care scene right now (e.g. feeding, bath, bedtime). This set must never feel like a checklist or numbered task list. It should feel like a friend gently suggesting, “You could try saying this, or this, or this” — imagine three or four smooth little stones resting on a soft cloth, each holding a phrase. Must include: a warm personalised greeting using the parent’s name; an intelligent scene recommendation based on time of day; the gentle display of 3–5 short, natural phrases with Chinese translations and optional audio; a primary action that invites the parent to begin (“和宝宝说说这几句” or “开始这段小时光”); a kind tip from 小禾 about why these phrases suit the moment; a low-pressure way to switch to a different scene; and a subtle glimpse of the child’s garden growth. After practicing, the Home card shows how many phrases were shared and offers a “Do it again” or “Next moment” path.
· Practice — “Say a few things during this care moment”
  A focused, warm screen that gently walks the parent through a handful of phrases. The experience should feel like turning the soft pages of a small pocketbook, not swiping through flashcards. The current English phrase is the absolute visual centre, but the parent can always sense there are more to come through a soft progress indication (“2 of 4”). 小禾 offers one scene-specific tip that applies to the whole moment. A fixed, easy-to-reach action bar lets the parent say “I said it” after each phrase — this button is a servant, not a commander; it simply says “You’ve spoken, tell me,” never conveying hurry. Immediately after, optional baby-reaction buttons appear (e.g. 😊 responded, 🍚 took a bite, 😐 no reaction). These reactions are entirely optional; the parent can tap one or do nothing, and after 3 seconds the app gently moves to the next phrase. No reaction is ever treated as a wrong answer. Transitions between phrases feel like softly turning a page of warm paper, never a hard cut or clinical slide. At the end of the set, a warm narrative summary appears (“You and 小明 shared 4 bath-time phrases 🌊”), followed by a quiet garden update.
· Discover — Browse phrases & scenes
  When parents want to explore beyond the moment’s recommendation. The atmosphere should feel like a quiet little library or bookshelf, inviting the parent to browse slowly, never like a search engine. Needs a lightweight search and horizontally scrollable scene filter chips. Scene pills: only the selected pill carries the warm orange fill; all unselected pills remain in paper or warm light grey, ensuring only the current focus point has colour. Cards can represent whole scenes or individual phrases, always showing the English text in teal serif and a gentle entry to practice. A refresh offers new curated sets.
· Garden & Growth — a living record of shared moments
  One screen with a gentle segment toggle: 花园 / 成长. The garden is not a reward system or gamified progress bar — it is a visual diary of presence. Every phrase said leaves a trace; those traces collectively make something grow. Avoid transactional language like “collect,” “redeem,” or “balance.” Claiming a trace feels like quietly receiving today’s small gift, not collecting points.
  Garden side:
  A main flower visualisation that grows through gentle stages (种子 → 发芽 → 生长 → 开花 → 盛放). Growth is fed by practice traces — recent phrases the parent has said. Claiming a trace is a quiet act of receiving (“收下今天的美好”); when enough traces gather, the flower stages up with a small confetti moment and a warm message. A hero card tells the story of what just happened in the garden through a warm narrative headline, never stats. If no recent practice, the card reassures quietly. A gentle nudge card suggests the next scene to revisit, with a clear path to practice. A vertical list of flower patch cards represents care spaces, each with an emotional stage label: 安静等待, 刚被照料, 正在扎根, 温柔发亮 (where 温柔发亮 means the patch is already active and softly radiating energy). Each patch shows its sub-activities and a kind one-line summary. Patches feel like small, tended garden beds with subtle borders and soft shadows. A shared caregiving card shows what a co-caregiver has practiced, and a gentle prompt to share progress. Empty state: “第一句开口就会让花圃醒来.”
  Growth side:
  A warm narrative record of the journey. A hero card frames the most recent practice as a story. An auto-generated diary section groups warm entries by date, crafted from practice events, garden changes and milestones — never raw logs. Parents can add their own notes. A milestones section shows achievements both earned and yet-to-be-reached, all visible as gentle motivation. A growth insights panel with a period selector (本周/本月/今年) shows: streak, total phrases, active days, scenes covered, and a simple trend chart. The chart is low-contrast, warm-toned, with a hand-drawn feel — as if sketched in the margin of a diary, never a dashboard widget. Instead of cold delta numbers, a warm phrase appears (“这周比上周说了更多 ✨”). A next-step suggestion offers an uncovered scene and a concrete phrase. Empty state: “和小明说第一句英语，就会留下第一条记录,” with a gentle nudge to Home.
· Me — profile & settings
  Contains parent/baby identity, quick garden summary cards, and a clean grid of functional entries. Even in this utilitarian screen, the paper-like warmth remains: cards sit on warm backgrounds, icons use line style rather than solid fills, and hard dividers between list items are avoided. The garden summary card acts as the emotional anchor, quietly reminding the parent: “This is not a settings screen — this is your corner with your baby.”
· Onboarding — first scene, first conversation
  A gentle, conversational flow led by 小禾. Step 1: pick a scene (smart default based on time), with the option “直接给我几句话” as a shortcut. Step 2: receive a small, handpicked set of 3–4 phrases for that scene, practice them one by one with reaction buttons and 小禾’s encouragement. Step 3: seed-sprouting animation and a warm welcome to the garden, then transition to Home. If the parent wants to leave onboarding early, the exit button never says “Skip”; it says “稍后再来,” and 小禾 replies, “好的，小明的花园等你,” without guilt.
· Mentor 小禾 (AI coach)
  A bottom sheet with two tabs: context-aware suggestion cards and a chat interface. 小禾’s language is always soft and never prescriptive: it never says “你应该” or “你最好”; instead it says “可以试试,” “有妈妈发现,” or “宝宝可能会喜欢.” English phrases within 小禾’s messages are highlighted in the same muted teal. Suggestion cards use “去和宝宝说说看 →” as their action, not “去练习.” Offline, suggestions use local presets and chat gently indicates the need for internet.

Technical & layout constraints

· Portrait only, phone-optimised (max viewport width 430px).
· Spacious rhythm, touch targets ≥44px.
· Soft border radius (cards ~16px, pills fully rounded).
· All transitions feel considerate and unhurried; nothing jerks or rushes.


## 可自由重设计的部分

原始 UI 规定过细。后续重设计可以丢弃固定元素顺序、精确按钮位置和旧卡片布局，但必须保留每个页面的目的和情绪基调。页面要像一个家长身边的陪伴工具，温柔邀请家长在已经存在的照护时刻里说几句英语。主要视觉重量由排版、留白和克制的暖意承担。

## 文档语言规则

`docs/design-spec/` 下的页面设计规格默认使用中文编写。

允许保留英文的情况：
- 产品名、技术字段名、API 字段名；
- UI 上必须出现的英文短语；
- JSON 示例中的字段名；
- 历史原型图文件名。

禁止在页面规格里混用大段英文说明。历史英文 brief 可保留作为来源材料，但新增或重写的页面规格必须使用中文。

## 2026-06-10 已批准产品模型覆盖说明

本节覆盖早期 brief 中把 Home 或 Onboarding 描述成固定 3-5 句短语组的旧说法。

已批准模型：
- Home 是当前时刻的对话入口页，不是短语卡片页。
- Home 固定展示 4 个直接开始的照护对话入口，并可显示继续入口、宝宝信号入口和自定义当前情况入口。
- Home 不展示英语短语卡、不提供发音、不出现 `说这一句`，也不持有固定短语组。
- Practice 负责展示英语短语、标准发音、`我说了`、可选宝宝反应，以及根据上下文生成每一句下一句。
- Onboarding 必须教会用户逐轮对话循环：选择/开始情境，听第一句，对宝宝说，可选宝宝信号，收到上下文生成的下一句，并在合适时温柔结束。
- 后端可以逐句连续生成。规格不得要求默认 3 句组，除非某个离线降级状态明确说明使用本地安全短句。

## 2026-06-11 Practice V2 覆盖说明

Practice 使用“共同注意力回合台”模型。

已批准模型：
- Practice 不使用固定 3 句组、`2 of 4` 步骤进度、难度选择或 flashcard 任务。
- Practice 每轮只展示 1 条当前可说的英文短句，英文短句必须是页面最大文字。
- 标准发音只使用扬声器/播放图标和 `听标准发音` 文案，禁止麦克风、录音、波形和发音评分。
- `我说了` 是每轮唯一主动作，按钮不带图标。
- 宝宝信号只在用户点击 `我说了` 后出现，不和 `我说了` 同时争夺主操作。
- 宝宝信号可不选；不选时 4 秒后使用 `babySignal = unspecified` 继续请求下一句。
- `宝宝说了...` 使用轻文本输入，不请求录音权限，不做语音转文字。
- 下一句必须根据当前场景、上一句、宝宝信号或宝宝文本反馈生成。
- 用户可以一直说下去；结束入口是 `今天先到这里`，结束后显示暖叙事和花园痕迹。

详细规格见 `docs/design-spec/07_Practice_Screen.md`。

建立一个目录：

```markdown
/Design

01_Product_Vision.md

02_Design_System.md

03_User_Persona.md

04_User_Journey.md

05_Information_Architecture.md

06_Home_Screen.md

07_Practice_Screen.md

08_Discover_Screen.md

09_Garden_Screen.md

10_Growth_Screen.md

11_Profile_Screen.md

12_Onboarding_Screen.md

13_Xiaohe_Chat.md
```

## 推荐的设计材料结构

以后每个页面都按照下面格式整理。

### 1. 页面目标（Goal）

例如 Home 页面：

```markdown
# Home 页面

## 页面目标

让家长在3秒内知道：

1. 现在适合什么场景
2. 可以对宝宝说什么
3. 一键开始说
```

---

### 2. 用户进入场景（Entry Context）

```markdown
## 用户进入时

时间：晚上8点

宝宝：2岁

最近练习：昨天完成睡前场景

当前推荐：
睡前场景
```

这样 GPT 才知道页面要突出什么。

---

### 3. 用户心理状态（Emotional State）

这是很多程序员不会写，但最重要的。

例如：

```markdown
## 用户心理

刚哄完宝宝

很累

没有时间学习英语

希望马上知道说什么
```

GPT 看到后会自动减少复杂操作。

---

### 4. 页面内容优先级（Content Priority）

例如：

```markdown
P0（最重要）

推荐场景
推荐短句
开始按钮

P1

小禾建议

P2

花园预览
```

这会直接决定排版层级。

---

### 5. 用户操作流程（User Flow）

例如：

```markdown
进入首页

↓
看到推荐场景

↓
点击开始

↓
进入 Practice

↓
完成练习

↓
返回 Home
```

GPT 能自动设计跳转逻辑。

---

### 6. 原型屏幕状态与跳转说明（Prototype Screen States）

每个页面如果有原型图，必须逐屏说明：

1. 这张屏幕是在什么条件下出现的
2. 用户做了什么操作会进入这张屏幕
3. 用户在这张屏幕上可以做什么
4. 每个关键操作会跳到哪一个屏幕或页面
5. 如果该屏幕是系统状态变化触发的，要说明触发条件

例如 Home 原型：

```markdown
## Screen 1：默认 Home / 当下对话入口

进入条件：
用户打开 App，系统根据时间和最近场景判断为睡前或安抚时间。

用户可操作：
- 点击「继续刚才的安抚对话」：进入 Practice 继续上一轮上下文。
- 点击「哄睡中」：进入 Practice，并用哄睡上下文请求第一句。
- 点击「宝宝刚刚说了什么 / 做了什么？」：进入 Screen 2 宝宝信号底部抽屉。
- 点击「描述现在的情况」：进入 Screen 3 当前情况底部抽屉。

跳转：
Screen 1 → Practice Resume
Screen 1 → Practice First Turn
Screen 1 → Screen 2
Screen 1 → Screen 3
```

这个部分是设计规格的必要内容，不能只贴原型图。

---

### 7. 页面组件清单（Components）

例如：

```markdown
Header

Greeting Card

Phrase Card

Mentor Tip Card

Garden Preview Card

Bottom Navigation
```

---

### 8. 图标与视觉资产清单（Icon & Asset Inventory）

每个页面规格必须列出该页面出现的所有图标、插画、SVG、Lottie、头像和装饰图案。原型 PNG 只能作为视觉参考，不能作为实现资产来源，禁止从原型图里裁切图标。

每个资产必须写清楚：

```markdown
| Asset ID | 用途/出现位置 | 类型 | 本地路径或实现来源 | 尺寸 | 颜色规则 | 状态 | 备注 |
|----------|---------------|------|--------------------|------|----------|------|------|
| icon.audio.speaker | 短语发音按钮 | Flutter IconData | Icons.volume_up_outlined | 24px | --text-primary | available | 不可用 microphone |
| illustration.xiaohe.avatar | 小禾头像 | SVG/PNG | assets/illustrations/xiaohe_teacher_avatar.svg | 40px | full color | missing | 必须补本地资产 |
```

状态只能使用：

- `available`：本地已有资产，或明确使用 Flutter 内置 `Icons.*`。
- `missing`：原型图里出现但本地没有，开发前必须补齐。
- `deferred`：本期不实现，页面规格必须说明替代显示。

#### 功能图标规则

- 功能图标优先使用 Flutter 内置 `Icons.*`，必须写出精确 IconData 名称。
- 同一个功能在所有页面使用同一个图标。
- 发音只允许 `Icons.volume_up_outlined`，禁止 microphone、record、waveform 图标。
- 返回使用 `Icons.arrow_back_ios_new`。
- 关闭使用 `Icons.close_rounded`。
- 下一步使用 `Icons.arrow_forward_rounded`。
- 选中使用 `Icons.check_rounded`。

#### 自定义视觉资产规则

以下内容不能只写“植物图案/头像/插画”，必须有本地资产或明确标记 `missing`：

- 小禾老师头像
- 花园嫩芽/种子/植物线稿
- 场景插画：睡前、喂奶、洗澡、换尿布、安抚、出门
- 宝宝反应图标
- 页面装饰性植物线稿

自定义 SVG 统一要求：

- 目录：`mobile/assets/illustrations/` 或 `mobile/assets/icons/`
- SVG viewport：`24x24`（功能图标）或规格中声明的固定尺寸（插画）
- 线宽：`1.75px`
- 线端：round cap / round join
- 默认颜色：使用 `currentColor`，由 Flutter 侧传入 token 色
- 禁止把颜色硬编码为纯黑 `#000000`

#### 缺失资产处理

如果资产状态是 `missing`：

1. 规格必须说明临时替代方案。
2. 临时替代方案只能用明确的 Flutter `Icons.*` 或隐藏该装饰。
3. 不能用 emoji 代替。
4. 不能临时手画风格不一致的 SVG。
5. 实现任务必须包含“补齐资产”或“确认 deferred”的子任务。

---

### 9. 每个组件详细说明

例如：

```markdown
## Phrase Card

目标：
展示一句当前推荐短句

内容：

英文
中文
播放按钮

交互：

点击播放
播放音频

长按
收藏
```

---

### 10. 空状态（Empty State）

```markdown
没有推荐内容时：

"小明今天想听你说第一句话。"
```

---

### 11. 错误状态（Error State）

```markdown
离线：

显示本地短句

不阻断练习
```

---

### 12. 实现偏差风险检查（Implementation Deviation Risks）

每个页面规格最后必须列出可能导致实现偏离原型的风险点，并给出固定处理方式。

必须检查：

1. 原型图里是否出现本地没有的图标、插画、SVG、Lottie。
2. 图标是否用了 emoji 或平台默认图标造成风格不一致。
3. 原型是否有图片里可见、但规格没写的交互入口。
4. 文案是否只在图里出现、规格没写。
5. 尺寸、颜色、圆角、阴影是否只靠视觉描述，没有 token 或数值。
6. 加载、失败、离线、超时状态是否没有对应屏幕说明。
7. 动效是否只写“轻柔/温暖”，没有时长和触发条件。
8. 后端返回结构是否没有字段契约。

格式：

```markdown
| Risk | Impact | Required Fix |
|------|--------|--------------|
| 小禾头像只在 PNG 原型中存在 | 开发会用随机头像或 emoji | 标记 missing，补 `xiaohe_teacher_avatar.svg`，未补前使用无头像布局 |
```

---

### 13. AI设计要求（最重要）

最后增加：

```markdown
请作为资深 UX Designer + Product Designer。

输出：

1. 页面布局结构图
2. Figma Wireframe
3. 组件层级
4. 页面跳转关系
5. 动效建议
6. 设计理由

要求：

不要输出代码
不要输出Flutter

输出接近Figma设计稿规格
```

---

### 14. 产品模型与状态机（Product Model / State Machine）

如果页面不是静态展示页，而是承载一个核心产品循环、状态机或业务模型，必须增加本章节。

适用页面：

- Home
- Practice
- Onboarding
- Garden & Growth
- 小禾页面
- 任何需要后端逐步生成、保存上下文或跨页恢复状态的页面

必须写清楚：

1. 页面采用什么产品模型。
2. 旧模型是否被覆盖。
3. 一次核心循环由哪些事件组成。
4. 哪些状态可以互相跳转。
5. 哪些状态是终止状态。
6. 哪些状态不能出现。

示例：

```markdown
## 产品模型

Practice 使用“共同注意力回合台”模型。

一个回合由 4 个事件组成：

当前句 ready
→ 家长点 我说了
→ 可选宝宝信号 / 宝宝说了轻文本
→ 请求下一句

回合可以无限继续。系统不得要求用户完成固定句数。
```

---

### 15. 数据契约与后端契约（Data Contract）

如果页面需要后端数据、保存本地状态、跨页传递 payload、请求 AI/LLM/agentic search 或恢复会话，必须增加本章节。

必须写清楚：

1. 进入页面需要哪些字段。
2. 页面向后端发送哪些请求。
3. 后端返回哪些字段。
4. 字段为空时如何处理。
5. 本地 fallback 如何标记。
6. 哪些字段不能由前端伪造。
7. 哪些值是枚举，枚举值有哪些。

JSON 示例必须使用真实字段名，不使用 `foo`、`bar`、`TBD`。

示例：

```json
{
  "entrySource": "home_route",
  "sceneType": "feeding",
  "babySignal": null,
  "babySignalText": null,
  "babyNickname": "宝宝",
  "babyAgeMonths": 18
}
```

如果页面隐藏 AI 机制，规格必须明确禁止这些 UI 文案：

- `AI生成`
- `LLM`
- `prompt`
- `模型`
- `置信度`
- `重新生成`
- `生成失败`

---

### 16. 视觉与动效要求（Visual & Motion Requirements）

如果原型图表达了视觉方向，页面规格必须把关键视觉和动效转成可实现规则，不能只写“温柔”“轻柔”“高级”。

必须写清楚：

1. 页面结构。
2. 主要区域占比。
3. 字体、字号、行高、字重。
4. 颜色 token。
5. 圆角、阴影、触摸目标。
6. 动效触发条件。
7. 动效时长。
8. 动效方向。
9. 禁止的动效。

示例：

```markdown
点击 我说了：
- CurrentPhrasePanel 在 180ms 内缩小 2% 并降透明度；
- SaidConfirmationPill 在 160ms 内淡入；
- BabySignalStrip 在 220ms 内从底部上移 12px 淡入。
```

---

### 17. 文案规则与禁用清单（Copy Rules）

如果页面承载情绪承诺、涉及错误/失败/用户行为反馈，必须增加本章节。

必须写清楚：

1. 允许出现的固定文案。
2. 禁止出现的文案。
3. 同一动作在不同状态下的文案。
4. 错误、离线、超时时的温柔替代表达。
5. 不同资料缺失时使用的默认称呼。

Baby Talk 2 默认禁止：

- `失败`
- `错误`
- `没听清`
- `请重说`
- `评分`
- `正确率`
- `任务`
- `挑战`
- `连续打卡`

示例：

```markdown
允许：
- 我说了
- 听标准发音
- 不选也可以

禁止：
- 请重说
- 发音失败
- 重新生成
```

---

### 18. 与其他页面的关系（Cross-screen Relationship）

如果页面会被其它页面进入，或会把状态传给其它页面，必须增加本章节。

必须写清楚：

1. 从哪些页面进入。
2. 进入时携带什么上下文。
3. 退出后回到哪里。
4. 哪些状态会写入 Garden/Growth。
5. 哪些页面不能承担本页面职责。
6. 与 Onboarding、Home、小禾页面是否复用同一循环。

示例：

```markdown
Home：
- Home 不展示英语短句。
- Home 点击入口后进入 Practice。
- Practice 负责首句、发音、宝宝信号和下一句。
```

---

### 19. 验收标准（Acceptance Criteria）

每个可实现页面必须增加验收标准。验收标准要能被设计、前端和 QA 逐条检查。

必须写清楚：

1. 入口是否正确。
2. 主流程是否正确。
3. 关键状态是否正确。
4. 空、慢、离线、错误状态是否正确。
5. 禁止项是否未出现。
6. 跨页跳转是否正确。
7. 数据 payload 是否正确。

格式：

```markdown
## 验收标准

1. 从 Home 点击 `正在喂奶` 后，Practice 不显示短语组列表，只显示一条当前句。
2. 当前句有 `听标准发音`，没有麦克风。
3. 点击 `我说了` 后才出现宝宝信号。
```

---

### 章节保留规则

如果某个页面规格已经包含 README 早期模板之外的重要产品约束，不能因为模板没有列出就删除。

保留条件：

1. 该内容定义了产品模型、状态机或业务循环。
2. 该内容定义了后端字段、payload、fallback 或本地状态。
3. 该内容防止实现偏离产品承诺。
4. 该内容能被设计、前端、后端或 QA 直接验证。
5. 该内容不和已有章节重复。

如果这类内容首次出现在某个页面规格中，应同步补充到本 README，让后续页面沿用同一标准。
