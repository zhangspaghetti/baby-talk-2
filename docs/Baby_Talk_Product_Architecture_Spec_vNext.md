# Baby Talk Product Architecture Spec vNext

## 架构总判断

Baby Talk v1 应采用：

```text
Family-micro-ritual-first
Open-exploration
Conservative-activation
Garden-remembered
Parent-confirmed
Pack / Graph-constrained
```

也就是：系统可以拥有丰富的英语启蒙专家能力，但不能把丰富内容直接压进家庭日常。父母可以自由探索路线、绘本、儿歌、场景和表达；真正进入家庭 routine 的英语声音必须经过节奏控制。

Baby Talk v1 的核心不是即时生成更多英语，而是帮助中国 0-3 岁家庭建立一组低压力、高重复、关系安全的 English micro-rituals。目标是让少数英语声音从 app 迁移到父母嘴边、动作里和家庭 routine 里。

这比“用户主动选择 Moment → 选择 Pack → Practice”更适合 Baby Talk v1。原因是家长真实场景中手忙、低耐心、容易把英语启蒙任务化。用户选择应该保留，但它主要是确认、整理和节奏调节信号，不是让系统不断激活新内容的理由。

### v1 Thesis

```text
Baby Talk v1 是一个带 Activation Governor 的家庭英语 micro-ritual 系统。
它通过 Garden 呈现低羞耻的家庭语言记忆，
默认只激活 3 个声音，
开放探索但保守激活，
目标不是生成更多英语，
而是让少数英语声音真正迁移进家庭日常。
```

### 非目标

Baby Talk v1 不是：

```text
一般育儿支持系统
英语学习 app
绘本课表
翻译器
早教打卡工具
无限场景句生成器
```

Baby Talk v1 不优化：

```text
新增内容数量
覆盖场景数量
孩子会说多少词
父母连续打卡天数
每日英语输入达标
AI 生成的新奇程度
```

---

## Phase 1｜最终系统层级

长期稳定结构应是：

```text
Context Seed / Observed Moment
↓
Joinability / Interpreted Moment
↓
Communication Primitive
↓
Strategy Graph
↓
Strategy Pack / Micro-ritual Candidate
↓
Activation Governor
↓
Runtime Agent / Runtime Response
↓
Garden Memory update
↓
Parent-confirmed Transfer State
```

v1 运行时的关键链路应是：

```text
Context Seed / Observed Moment
↓
Pack / Graph 产生内容和策略候选
↓
Activation Governor 读取 Garden Memory 与 activation policy，判断是否允许进入家庭日常
↓
Runtime Agent 按 activation decision 生成当下回应
↓
父母在 routine 中自然说出 / 收藏 / 休眠 / 扩展 / 退场
↓
Garden Memory 记录 parent-confirmed 迁移状态
```

Explore 和 Activate 必须分离：

```text
Explore = 父母可以自由了解更多内容、路线和策略
Activate = 某个声音进入家庭日常，成为正在种的 micro-ritual
```

默认原则：

```text
Conservative activation, open exploration.
```

| 层级 | 用户视角 | Agent 视角 | 运营视角 | 数据视角 |
|---|---|---|---|---|
| Context Seed / Observed Moment | 当前亲子日常片段 | 原始情境证据 | 训练场景识别 | 特征与事件 |
| Joinability / Interpreted Moment | 英语能否轻轻加入 | 低置信度假设 | 场景分类标准 | 标签与置信度 |
| Primitive | 不直接感知 | 最小沟通动作 | 可复用语言积木 | 策略原子 |
| Family English Micro-ritual | 家里正在种的一句声音 | 可迁移的 routine 单元 | v1 核心激活单元 | 家庭迁移状态 |
| Strategy Graph | 不直接感知 | 决策图谱 | 核心知识资产 | 转移关系 |
| Strategy Pack | 可被推荐/复用的一套说法 | 约束包 | 发布单元 | 推荐与实验单元 |
| Activation Governor | 不直接感知 | 激活门控 | 节奏治理资产 | 激活/延后/休眠决策 |
| Garden Memory | 家庭英语花园 | 家庭迁移记忆 | 留存与减压界面 | parent-confirmed 状态 |
| Runtime Response | 当前建议/解释/句子 | 当下输出 | 不作为资产 | 低层日志 |

最终判断：Primitive + Strategy Graph 是底层专家资产；Strategy Pack 是可发布资产；Activation Governor 是节奏治理核心；Garden Memory 是家庭语言记忆层；Runtime Response 是运行时产物。

---

## Phase 2｜Moment Taxonomy

### Observed Moment Taxonomy

Observed Moment 是“看见了什么”，不是解释。v1 中更准确地说，它是可触发英语共说的 Context Seed，而不是宝宝行为诊断入口。

典型维度：

```text
行为信号：摇头、推开、哭、笑、指、抓、扔、转身、看向某物
照护对象：勺子、奶瓶、水杯、尿布、浴巾、绘本、床、门口
共同注意：宝宝看哪里、手摸哪里、家长正在拿什么
时间节律：饭点、睡前、刚醒、出门前、洗澡后
互动信号：家长刚说了什么、宝宝是否回应、宝宝说了什么词
家长状态：赶时间、疲惫、不确定、想要更简单一句
```

v1 优先关注这些 context seeds：

```text
高频 routine：起床、穿衣、吃饭、洗手、出门、睡觉
动作绑定：抱起、穿鞋、洗手、递东西、打开、收起
共同注意：孩子指物、看动物、拿杯子、翻绘本
声音游戏：拟声词、重复节奏、动作节拍
关系安全：孩子已经用中文表达时，先承接中文，再轻轻加入英语
```

### Interpreted Moment Taxonomy

Interpreted Moment 是“可能发生了什么”。v1 中它不应主要追求育儿解释，而应判断 joinability：英语此刻能否以不测试、不替换、不破坏关系的方式加入。

核心类别：

```text
Refusal 拒绝
Autonomy Seeking 想自己来
Seeking Connection 寻求连接
Fatigue 疲劳
Overstimulation 过度刺激
Curiosity / Joint Attention Shift 注意力转移
Transition Difficulty 过渡困难
Discomfort / Need 不适或需求
Boundary Testing 边界测试
Engaged / Continue 已经投入，可继续
Repair Needed 需要修复
```

v1 需要额外识别：

```text
Joinable 英语可以轻轻加入
Chinese-first 孩子已经用中文进入关系，先承接中文
Action-bound 适合短句 + 动作绑定
Silence-better 此刻沉默/动作/中文优先
Too-teachy 当前表达容易滑向教学/测试
Parent-awkward 父母说出口会别扭，需要更短、更生活化
Routine-ready 适合作为 micro-ritual 候选
Already-active 应优先扩展旧声音，而不是激活新声音
```

### 推荐系统与 Pack 匹配

Observed signals 应成为推荐系统特征，因为它们细、实时、可更新。

Pack 匹配不应直接依赖单个 Observed signal，而应依赖：

```text
Interpreted Moment
+
Age Range
+
Care Context
+
Confidence
+
Risk Level
+
Parent Preference
+
Garden Memory
```

Pack matching 可以读取 Garden Memory 来提升候选相关性；activation policy 只由 Activation Governor 评估。Pack 匹配只是产生候选，不等于激活。候选内容如果要成为家庭日常中的新 micro-ritual，必须经过 Activation Governor。

例如：

```text
Observed:
推勺子 + 摇头 + 皱眉

Interpreted:
Refusal 0.72
Autonomy Seeking 0.31

Matched Strategy:
Connection + Choice + Waiting
```

关键规则：Observed Moment 是证据，Interpreted Moment 是假设，不能把假设说成事实。

v1 关键规则：Context Seed 是英语加入的入口，不是任务触发器。系统可以建议 `save_for_later` 或 `nearby_expansion_only`，不能因为有合适 Pack 就自动把新声音推入 Active Layer。

---

## Phase 3｜Communication Primitive Library

Primitive 是 Baby Talk 的最小沟通原语。它比 Pack 更底层、更长期稳定。

| Primitive | 定义 | 作用 | 风险 | 适用场景 | 典型表达 |
|---|---|---|---|---|---|
| Joint Attention Anchor 共同注意锚定 | 跟随宝宝正在看/摸/做的事 | 让英语贴近现实 | 错判注意对象会突兀 | 指物、看窗外、玩水 | `You see the dog.` |
| Connection 接住 | 承认宝宝状态或情绪 | 降低控制感 | 变成过度解读 | 哭、拒绝、摇头 | `You don't want it yet.` |
| Narration 旁白 | 描述正在发生的事实 | 提供自然语言输入 | 说太多会变唠叨 | 洗澡、换尿布、吃饭 | `The water is warm.` |
| Choice 选择 | 给宝宝一个小选择 | 支持自主感 | 选择过多会累 | 吃饭、穿衣、玩具 | `This one or that one?` |
| Waiting 留白 | 允许暂停和等待 | 保护互动节奏 | 太久会冷场 | 拒绝、疲劳、无回应 | `We can wait.` |
| Boundary 温柔边界 | 设定安全或照护边界 | 避免失控 | 容易变命令 | 打翻、危险、咬人 | `I won't let you throw it.` |
| Transition 过渡 | 预告下一步 | 降低切换阻力 | 太像任务通知 | 睡前、出门、收玩具 | `One more, then bath.` |
| Repair 修复 | 当互动紧张后重新连接 | 降低挫败 | 不能假装没事 | 哭闹升级、家长说重了 | `That was hard. I'm here.` |
| Expansion 扩展 | 接住宝宝的话并轻轻扩展 | 支持会说话宝宝 | 过度教学 | 18个月后有词语反馈 | `Ball. A red ball.` |

结论：Primitive 是语言积木；Family English Micro-ritual 是进入家庭动作记忆的最小单元；Pack 是可发布的策略套装；Runtime Response 是当下输出。

Pack 可以被替换、升级、下架。Primitive 会长期沉淀，并跨时刻复用。

### v1 核心单元：Family English Micro-ritual

v1 不应把 Phrase 当成核心单位。Phrase 太容易变成句子库、翻译器或无限生成器。v1 的核心单位应是 Family English Micro-ritual：

```text
一个高频 routine 中，
一句父母说得出口的英语声音，
绑定一个动作/声音/节奏，
允许中文共存，
不要求孩子回应，
可以长期重复，
并逐渐迁移出 app。
```

一个 micro-ritual 至少包含：

```text
fixedSound：稳定核心声音，例如 "Shoes on."
routineAnchor：发生在哪个 routine，例如出门穿鞋
actionBinding：配哪个动作，例如拿鞋、套脚、轻拍鞋
toneHint：怎么说得像照护语言，不像上课
childNoResponseRule：孩子没反应也没关系，继续动作即可
softVariant：一个轻微变体，例如 "One shoe. Two shoes."
doNotUseWhen：什么时候不要说，例如孩子已经强烈抗拒或父母说出口很别扭
exitCondition：什么时候从 app 提醒里退场
```

示例：

```text
Micro-ritual: Shoes on
固定声音: "Shoes on."
动作绑定: 帮孩子穿鞋时说
声音/节奏: "Tap tap."
轻微变体: "One shoe. Two shoes."
中文共存: 可以先说“穿鞋啦”，再轻轻加入 "Shoes on."
不测试: 不要求孩子跟读 shoe
退场: 父母不看 app 也会自然说时，进入 belongs-to-family
```

---

## Phase 4｜Strategy Graph

Strategy Graph 是：

```text
Interpreted Moment
↓
Primitive Sequence
↓
Strategy
```

核心映射：

| Interpreted Moment | 推荐 Primitive 组合 | Strategy |
|---|---|---|
| Refusal 拒绝 | Connection → Choice → Waiting | 先接住，再给一个小选择 |
| Crying 哭闹 | Connection → Waiting → Repair | 先稳住关系，不急着推进 |
| Autonomy Seeking 想自己来 | Joint Attention → Choice → Boundary | 看见自主，同时保留边界 |
| Boundary Testing 边界测试 | Connection → Boundary → Choice | 温柔限制，再给可行选择 |
| Fatigue 疲劳 | Connection → Transition → Waiting | 降低语言负担，慢慢收束 |
| Curiosity 注意力转移 | Joint Attention → Narration → Expansion | 跟随宝宝注意力说下去 |
| Overstimulation 过度刺激 | Connection → Waiting → Transition | 减少刺激，给出口 |
| Engaged 已投入 | Narration → Expansion → Choice | 延展互动，不抢节奏 |
| Repair Needed 需要修复 | Repair → Connection → Waiting | 先修复，再继续 |
| Discomfort / Need 不适 | Connection → Narration → Transition | 承认不适，说明下一步 |

v1 的 micro-ritual 图谱应优先服务高频家庭声音：

| Routine / Seed | 推荐 Primitive 组合 | Micro-ritual Strategy |
|---|---|---|
| 穿鞋出门 | Transition → Narration → Sound Play | 固定声音 `Shoes on.`，动作绑定，轻微节奏 |
| 洗手 | Narration → Sound Play → Waiting | `Wash wash wash.`，用重复节奏替代讲解 |
| 抱起 | Connection → Transition | `Up we go.`，绑定抱起动作，不要求回应 |
| 递东西 | Joint Attention → Narration | `Here you go.`，让英语跟随递给动作 |
| 完成/结束 | Transition → Repair / Waiting | `All done.`，降低结束时的控制感 |
| 摔落/打翻 | Joint Attention → Narration → Sound Play | `Uh-oh, it fell.`，先共同注意，不评价宝宝 |
| 睡前 | Transition → Connection → Sound Play | `Night night.`，稳定、低刺激、可重复 |
| 中文主动表达 | Connection → Joint Attention → Soft Expansion | 先承接中文，再轻轻加入英语，不替换、不测试 |

v1 的 Graph 不应追求覆盖所有场景，而应优先保护少数声音的可重复、可迁移和低压力。

### Conversation strategy switching

Conversation strategy switching 只管理当次回应中的 Primitive / wording / turn path，不决定一个 micro-ritual 是否进入家庭日常。进入、休眠、扩展、退场由 Activation Governor + Garden Memory 管理。

继续当前策略，当：

```text
Interpreted Moment 未变化
宝宝信号中性或正向
没有安全风险
当前回应仍然贴合 active micro-ritual 或 exploration intent
用户仍愿意继续当次互动
```

切换策略，当：

```text
新证据置信度超过当前解释
连续两轮无效或负向反应
宝宝说出新词改变共同注意对象
用户主动修正当前情况
出现安全/健康/强烈哭闹信号
```

### Micro-ritual activation state transition

Micro-ritual activation state transition 由 Activation Governor 决策，Garden Memory 只呈现状态并收集 parent-confirmed feedback。

典型状态流转：

```text
candidate → active：父母明确轻量激活，且当前 active 数量/状态允许
candidate → save_for_later：内容有价值，但今天不种
active → familiar：父母确认这句已经更顺口
active → resting：父母确认先放一边，不是失败
familiar → nearby_expansion_only：围绕旧声音给一个轻变体
familiar → belongs_to_family：父母确认已经属于家庭，不需要 app 提醒
```

Agent 可自由发挥的范围：

```text
允许：措辞、长度、具体物体、下一句微调
限制：Primitive 顺序、语气边界、禁止规则、安全边界
禁止：裸生成新教育目标、催促服从、评价宝宝、提高英语难度
```

---

## Phase 5｜Strategy Pack

Pack 不是最终资产本体，而是三者兼有：

```text
B. Strategy Graph 的发布形态
C. 推荐系统消费单元
A. 可运营的业务资产
```

但排序应是：

```text
Graph / Primitive 是底层资产
Pack 是发布资产
Activation Governor 是节奏治理资产
Garden Memory 是家庭迁移记忆
Runtime Response 是输出
```

### 最终 Schema

```json
{
  "packId": "routine_shoes_on_micro_ritual_v1",
  "version": 1,
  "status": "published",

  "momentScope": {
    "routine": "going_out",
    "contextSeeds": ["parent_holding_shoes", "child_near_door", "getting_ready_to_leave"],
    "joinabilityTargets": ["action_bound", "routine_ready"],
    "ageRangeMonths": [12, 24]
  },

  "strategy": {
    "graphRef": "routine_shoes_on_v1",
    "primaryPrimitives": ["Transition", "Narration", "Sound Play"],
    "fallbackPrimitives": ["Waiting", "Connection"],
    "switchRulesRef": "micro_ritual_pacing_v1"
  },

  "goals": {
    "parentGoal": "帮助家长在出门穿鞋时自然说出一个稳定英语声音",
    "communicationGoal": "让英语绑定真实动作，而不是变成教学提问",
    "notGoal": "教会宝宝说 shoe 或完成每日英语任务"
  },

  "languagePolicy": {
    "maxWordsPerPhrase": 4,
    "tone": "short_warm_action_bound",
    "englishLevel": "parent_speakable",
    "allowChineseHelper": true,
    "allowRepetition": true,
    "avoidTesting": true
  },

  "avoidRules": [
    "不要求宝宝跟读 shoe",
    "不问 What's this",
    "不把穿鞋变成课程",
    "不因孩子没反应而判定失败"
  ],

  "exampleOpeners": [
    "Shoes on.",
    "One shoe. Two shoes.",
    "Tap tap."
  ],

  "microRitual": {
    "fixedSound": "Shoes on.",
    "routineAnchor": "出门穿鞋",
    "actionBinding": "拿鞋、套脚、轻拍鞋",
    "softVariant": "One shoe. Two shoes.",
    "doNotUseWhen": ["parent_feels_awkward", "child_is_strongly_upset"],
    "exitCondition": "parent_confirms_belongs_to_family"
  },

  "evaluationRubric": {
    "parentSpeakability": true,
    "lowPressureTone": true,
    "ageAppropriate": true,
    "contextFit": true,
    "actionBound": true,
    "nonTesting": true
  },

  "metrics": {
    "northStarProxy": "parent_confirmed_micro_ritual_transfer",
    "guardrails": ["task_pressure_feedback", "awkwardness_feedback", "over_activation_rate"]
  }
}
```

---

## Phase 6｜Pack Factory

两条路线：

### 路线 A：专家设计 Pack

```text
专家提出 Moment
↓
设计 Strategy
↓
写 Pack
↓
审核上线
```

优势：安全、可控、品牌一致。
风险：慢，容易课程化，容易假设用户场景。
适合：MVP 冷启动、敏感场景、核心 Pack。

### 路线 B：真实对话发现 Pack

```text
真实用户对话
↓
发现高表现模式
↓
自动聚类
↓
形成候选 Pack
↓
人工审核
↓
发布新版本
```

优势：贴近真实复杂场景，能形成数据飞轮。
风险：数据噪声、隐私、偏见、局部最优。
适合：规模化、细分场景、个性化推荐。

最终选择：

```text
B 为长期主路线
A 为冷启动和治理层
```

也就是：

```text
Expert-seeded
Data-discovered
Human-governed
Agent-assisted
```

Baby Talk 不适合纯课程路线。课程路线会把产品带回“学习英语”。更接近 Spotify 路线：运营单元可被推荐、个性化、实验和淘汰。但必须加上 Headspace/Duolingo 式的安全与专家治理，因为这是亲子场景。

Pack Factory 只产生 Strategy Pack / Micro-ritual Candidate。候选内容是否进入家庭日常，必须由 Activation Governor 按 Garden Memory、activation policy 和父母确认状态决定。

---

## Phase 7｜Activation Governor & Garden Memory

Activation Governor 是 Baby Talk v1 的节奏治理层。它不负责生成内容，也不负责限制父母探索知识。它只负责判断：某个内容此刻是否应该被激活为家庭日常中的 micro-ritual。

核心原则：

```text
Conservative activation, open exploration.
```

也就是：

```text
Explore More：开放
Activate Today：保守
Nearby Expansion：中等开放
New Micro-ritual：严格限速
```

### Activation Governor 的权限边界

Activation Governor 控制 Activate，不控制 Explore。

父母可以随时问：

```text
2 岁以后怎么扩展？
绘本怎么选？
洗澡还能怎么说？
她开始说词了怎么办？
```

Expert Layer 可以回答这些问题，甚至可以给完整路线图。但当 Runtime Agent 试图把某个内容变成“今天去说 / 现在去试 / 加入你们家的新声音”时，Activation Governor 必须介入。

### v1 默认参数

```json
{
  "defaultActiveLimit": 3,
  "maxActiveLimit": 5,
  "nearbyExpansionLimit": 2,
  "newActivationRequiresParentConfirmedReadiness": true,
  "exposeMaxActiveLimitToUser": false
}
```

说明：

```text
defaultActiveLimit = 3 是 v1 的家庭激活带宽上限，不是 Baby Talk 的能力上限。
maxActiveLimit = 5 是成熟家庭的内部保护参数，不应作为用户目标暴露。
nearbyExpansionLimit = 2 表示可以围绕旧声音给少量轻扩展候选。
Explore Layer 不受这些数字限制。
```

### Activation Decision

Activation Governor 输出的不是“允许/拒绝”二元判断，而是节奏决策：

```text
allow_activation：允许激活一个新 micro-ritual
nearby_expansion_only：只扩展已有声音，不开新场景
defer_to_garden：Governor 决定先回到 Garden 整理当前声音
save_for_later：内容可以收藏，但今天不种
rest_existing：已有声音先休眠，不是失败
belongs_to_family：某句已经属于家庭，可以退出 app 提醒
```

Garden 只呈现状态并收集 parent-confirmed feedback；Activation Governor 拥有激活、延后、休眠和退场的决策权。

典型改写：

```text
用户：洗澡还能怎么说？

如果是 Explore：
可以给丰富方向、例句、未来扩展路径。

如果 Runtime 想 Activate：
Governor 检查当前 active 数、父母确认状态、任务化风险。

输出：
"可以先收藏这些洗澡表达。今天先不种新声音。你们家现在让 `Wash wash wash` 更顺口就够了。"
```

### Garden Memory

Garden Memory 是 Family English micro-ritual 的低羞耻记忆层。它不是 tracking system，不记录父母完成度，也不自动判断孩子学会了什么。

Garden 记录的是 micro-ritual 的家庭迁移状态：

```text
candidate：可能适合这个家庭
active：正在种
familiar：已经顺口
resting：先休眠
expandable：适合轻微扩展
belongs-to-family：已经属于家庭，不需要 app 提醒
```

状态更新应主要来自父母低压力确认：

```text
这句最近会自然冒出来吗？
还说得别扭吗？
要不要先放一边？
这句是不是已经属于你们家了？
```

系统可以使用 weak signals 辅助提示：

```text
反复打开某张声音卡
收藏或休眠
请求变体
在相同 routine 中回来
```

但 weak signals 不能直接判定 `familiar` 或 `belongs-to-family`。真正的迁移状态必须 parent-confirmed。

### Garden 不是换皮打卡

禁止的 Garden 语义：

```text
连续浇水 7 天
今天完成 3 句
没练习所以枯萎
再解锁 5 个场景
```

允许的 Garden 语义：

```text
这些声音正在你们家生长
这几句已经变成家庭声音
有些声音可以先休眠
你们现在只照顾 3 株就够了
忘几天也不会清零
```

Garden 的目标不是制造粘性，而是让父母看见：

```text
哪些英语声音已经在家里活了下来。
```

---

## Phase 8｜Runtime Agent Contract

运行链路：

```text
Observed Moment
↓
Interpreted Moment
↓
Strategy Pack Candidate
↓
Activation Governor
↓
Runtime Agent generates response by activation decision
↓
Parent says it
↓
Baby Response
↓
Garden Memory update
```

Runtime Agent 不能把匹配到的 Pack 直接变成家庭日常任务。任何 new activation 都必须先拿到 Activation Governor 的 decision。

### Agent 输入

Runtime Agent 输入的是 Activation Governor 已经做出的 activationDecision。Runtime Agent 不读取 activationPolicy 自行判断是否激活。

```json
{
  "childProfile": {
    "ageMonths": 18,
    "nickname": "宝宝",
    "languageStage": "single_words"
  },
  "parentProfile": {
    "englishComfort": "can_read_hard_to_speak",
    "preferredPhraseLength": "short"
  },
  "observationFrame": {
    "signals": ["parent_holding_shoes", "child_near_door"],
    "jointAttention": [
      { "object": "shoes", "weight": 0.74 },
      { "object": "door", "weight": 0.18 }
    ],
    "source": ["user_signal", "session_history"],
    "timestamp": "now"
  },
  "interpretationState": {
    "hypotheses": [
      { "moment": "routine_ready", "confidence": 0.76 },
      { "moment": "action_bound", "confidence": 0.64 }
    ]
  },
  "candidatePack": {
    "packId": "routine_shoes_on_micro_ritual_v1",
    "version": 1
  },
  "gardenState": {
    "activeMicroRituals": [
      { "ritualId": "shoes_on_v1", "state": "active" },
      { "ritualId": "wash_wash_wash_v1", "state": "familiar" }
    ],
    "activeCount": 2,
    "nearbyExpansionCount": 1
  },
  "activationDecision": {
    "decisionId": "act_20260614_001",
    "type": "allow_activation",
    "reason": "active_micro_ritual_capacity_available",
    "gardenAction": "set_active"
  },
  "conversationState": {
    "lastPhrase": null,
    "spokenTurns": 0,
    "babySignal": null,
    "babyWords": null
  }
}
```

### Agent 状态

```text
Active Interpretation
Candidate Pack
Active Primitive
Joint Attention Distribution
Runtime Response History
Baby Response History
Activation Decision
Garden Memory
Parent Language Confidence Estimate
Safety State
```

### Agent 输出

```json
{
  "phrase": "Shoes on.",
  "translation": "穿鞋啦。",
  "primitive": "Transition",
  "packId": "routine_shoes_on_micro_ritual_v1",
  "appliedActivationDecision": {
    "decisionId": "act_20260614_001",
    "type": "allow_activation",
    "applied": true
  },
  "stateUpdate": {
    "nextPrimitiveCandidates": ["Narration", "Sound Play"],
    "awaitingResponse": true
  },
  "safety": {
    "status": "ok"
  }
}
```

### 状态机

```text
Idle
→ Observe
→ Interpret
→ Match Pack
→ Activation Governor
→ Activation Decision
  ├─ allow_activation / nearby_expansion_only
  │  → Select Primitive
  │  → Generate Runtime Response / Phrase
  │  → Parent Spoken
  │  → Capture Baby Response
  │  → Update Interpretation
  │  → Update Garden Memory
  │  → Continue / Switch Strategy / End / Safety Stop
  └─ save_for_later / rest_existing / defer_to_garden / belongs_to_family
     → Generate Pacing / Garden Response
     → Collect parent-confirmed state if needed
     → Update Garden Memory
     → End / Explore
```

安全机制：

```text
不诊断
不医疗建议
不鼓励控制宝宝
不评价宝宝表现
不制造家长失败感
不默认录音
不把沉默视为失败
高风险内容转向停止与求助
```

---

## Phase 9｜Data Flywheel

Baby Talk v1 应优化：

```text
Parent-confirmed Micro-ritual Transfer
```

更具体地说：

```text
父母能否在不看 app、不像上课、不制造压力的情况下，
在真实 routine 里自然说出少数英语声音。
```

可操作北极星指标：

```text
Parent-confirmed Family English Sounds
=
父母确认已经从 app 迁移到家庭日常的 micro-ritual 数量与质量
```

核心指标：

```text
First active micro-ritual spoken without pressure
Routine reuse rate
Micro-ritual repeat comfort
Pack-to-activation conversion quality
Parent helpful rating
Regeneration rate
Early exit rate
Negative feedback rate
User correction rate
Parent-confirmed familiar rate
Parent-confirmed belongs-to-family rate
Active micro-ritual stability
Resting without shame rate
Over-activation prevention rate
```

不应优化：

```text
宝宝是否服从
宝宝是否吃下去
宝宝是否睡着
家长是否完成任务
说了多少句
连续打卡天数
英语难度提升
AI新奇程度
激活了多少新 ritual
花园里有多少植物
```

为什么 Micro-ritual Transfer 优于 Content Volume：

Content Volume 会把产品推向任务和表演：

```text
今天说满 20 句
再学 5 个场景
连续打卡 7 天
孩子掌握多少词
```

Micro-ritual Transfer 会把产品推向低压力、可重复、关系安全的家庭声音：

```text
Shoes on.
Wash wash wash.
Here you go.
Night night.
```

这决定 Baby Talk 是家庭英语语域养成系统，而不是英语任务执行系统。

数据飞轮：

```text
Context Seed 数据
↓
Joinability 判断更准
↓
Pack / Micro-ritual 候选更贴近家庭
↓
Activation Governor 更会控制节奏
↓
父母更容易自然说出口
↓
Parent-confirmed Garden 状态更准
↓
Strategy Graph / Pack Factory 调整
↓
更少内容负担，更多家庭迁移
```

---

## Phase 10｜Long-term Moat

如果未来所有大模型都能生成亲子英语，Baby Talk 仍然能存在，前提是护城河不在“生成一句话”，而在以下七层。

### 1. Strategy Graph

通用大模型能回答问题，但未必拥有：

```text
育儿时刻 → 解释假设 → Primitive组合 → 策略切换
```

的专用图谱。这个图谱越用越细，是 Baby Talk 的核心知识资产。

### 2. Primitive Library

“短、温柔、低控制、可说出口”的沟通原语库，会变成 Baby Talk 的语言风格底座。它不是 prompt，而是经过验证的亲子沟通语法。

### 3. Pack Factory

真正难的是持续生产、审核、实验、迭代 Pack。大模型能生成候选内容，但不能自动拥有一套可信的内容操作系统。

### 4. Activation Governor

Baby Talk 的差异化不只是知道很多，而是知道什么时候不该把更多内容激活成家庭任务。

```text
开放探索
保守激活
优先轻扩展
控制 active micro-ritual 数量
把更多内容转为收藏/稍后/休眠
```

这让 Baby Talk 成为节奏控制产品，而不是无限生成器。

### 5. Garden Memory

Garden Memory 记录的不是完成度，而是家庭语言记忆：

```text
哪些声音正在种
哪些已经顺口
哪些可以休眠
哪些适合轻扩展
哪些已经属于家庭
```

这个记忆必须 parent-confirmed，不能由使用次数自动推断。它是 Baby Talk 抵抗打卡化和任务化的重要资产。

### 6. Moment Understanding

Baby Talk 的上下文不是一段文字 prompt，而是长期家庭上下文：

```text
宝宝年龄
语言阶段
最近照护时刻
常见反应
家长英语舒适度
Pack 使用历史
Garden Memory
Activation History
共同注意线索
```

这让它比通用聊天更贴近真实现场。

### 7. Data Network Effects

每一次真实使用都会改进：

```text
哪些 Moment 常见
哪些 Observed signals 有预测力
哪些 Primitive 组合有效
哪些 Pack 形成 parent-confirmed transfer
哪些策略容易越界
```

这不是单个用户聊天数据，而是跨家庭、跨年龄、跨场景的策略表现网络。

---

## 最终架构一句话

Baby Talk 不是一个“生成英语句子”的产品。

它是一个：

```text
面向中国 0-3 岁家庭的
Family English Micro-ritual System
+
Activation-governed English Enlightenment Expert
```

其长期资产不是 Phrase，不是 Path，也不只是 Pack，而是：

```text
Context Seed / Joinability Understanding
+
Communication Primitive Library
+
Strategy Graph
+
Pack Factory
+
Activation Governor
+
Garden Memory
+
Parent-confirmed Micro-ritual Transfer Data Flywheel
```
