# TODOS

## P0 — Architecture Decisions (Confirmed by Eng Review 2026-04-01)

### State Management: Provider + ChangeNotifier
**What:** Flutter 状态管理使用 Provider + ChangeNotifier。
**Why:** 官方推荐，对这个规模的应用刚好。不需要 Riverpod 的编译时安全，也不需要 BLoC 的严格单向流。
**Context:** Eng Review v3 (2026-04-01) 确认。

### Deployment: Docker Container
**What:** 后端使用 Docker 容器部署。本地开发跑 Docker，生产部署到阿里云 ECS。
**Why:** 最灵活的方案。Spring Boot 4 + JDK 21 的冷启动时间不适合 Serverless，Docker 常驻运行避免冷启动。
**Context:** Eng Review v3 (2026-04-01) 确认。原设计说"阿里云 FC"但 Java 冷启动 5-15s 不可接受。

### Authentication: JWT + Refresh Token
**What:** 用户认证使用 JWT (access token 15min) + Refresh Token (30天)。Hive 本地存储 token。
**Why:** 移动 app 标准做法，无状态服务器更简单，离线时仍可验证 access token。Spring Security 内置支持。
**Context:** Eng Review v3 (2026-04-01) 确认。API 端点已定义在 test-plan-v2.md。

### Ask Coach Latency Strategy: Text-First + Async TTS
**What:** Ask Coach 响应策略：LLM 文字返回后立即流式显示，TTS 音频异步生成。用户先看到短语文字（~2s），音频几秒后自动可播放。
**Why:** 全链路 worst case 8s（网络+RAG+LLM+TTS），文字先行可将感知延迟降到 2-3s。
**Context:** Eng Review v3 (2026-04-01) 确认。设计文档要求 <3s 文字显示。

## P1 — Blocks Production

### ~~Run /design-consultation to Generate DESIGN.md~~ ✅ DONE
**What:** 跑 /design-consultation 生成正式 DESIGN.md。
**Status:** 已完成 (2026-04-02)。DESIGN.md 已创建。计划文件内联 token 需要删除（见下方 P1 项）。

### ~~Update Design Docs for New Navigation Architecture~~ ✅ DONE → ⚠️ SUPERSEDED by Design Review v3
**What:** ~~导航架构从 4-tab+FAB 更新为 5-tab。~~ **Design Review v3 (2026-04-04) 再次变更: 5-tab → 4-tab (首页/发现/花园/成长) + Drawer + 全局小禾老师 Mentor FAB。**
**Status:** 计划文件已更新 (2026-04-04)。DESIGN.md 已更新。

### ~~Complete Onboarding Flow Mockup~~ ✅ DONE (Design Review v2)
**What:** 完整 Onboarding 流程 HTML mockup 已创建: 欢迎页 → 输入名字 → 输入生日 → 阶段匹配动画 → 过渡页 → 登录 → PIPL 隐私同意。
**Status:** 已完成 (2026-04-02)。见 docs/mockups/onboarding.html。

### Update Design Doc for Native Pivot
**What:** 将 `docs/designs/baby-talk-extended-mvp.md` 中所有 "Flutter Web first" 的引用更新为 "Flutter Native first"。移除所有 "hidden on Flutter Web" / "native-only" 的条件逻辑。更新 Build Order、Key Implementation Decisions、Known Risks 等章节。
**Why:** 现有设计文档和新的 CEO Plan (`ceo-plans/2026-04-01-native-app-pivot.md`) 矛盾。开发者会困惑。
**Context:** CEO Review (2026-04-01) 确认 Phase 1 改为 Flutter Native (Android APK + iOS i4Tools 自签名)。设计文档需要同步更新。
**Effort:** S (CC: ~15 分钟，批量替换)
**Depends on:** CEO Plan 已完成 ✅

### Alibaba Cloud ASR Flutter Integration Spike
**What:** 验证阿里云 ASR 的 Flutter 集成方式。是否有现成 Flutter plugin？还是需要 Platform Channel 桥接原生 SDK？
**Why:** 如果需要 Platform Channel，AI 教练语音输入的工时从 S 变成 M。影响 Sprint 3-4 排期。
**Context:** CEO Review (2026-04-01) 将 AI 教练语音输入提前到 Phase 1。Layer 0 tech spike 需要 Sprint 1 Day 1-2 完成。
**Effort:** S (CC: ~30 分钟研究 + 原型)
**Depends on:** Nothing. Start immediately.

### Pre-Launch Admin Dependencies (START IMMEDIATELY)
**What:** ICP filing + Alibaba Cloud SMS template approval + Alibaba Cloud enterprise certification. These are administrative processes that run in parallel with development.
**Why:** Without ICP filing, backend server domain cannot be accessed in China. Without SMS template approval, cannot send verification codes. Without enterprise certification, Alibaba Cloud API call limits are too low for production.
**Context:** Identified during eng review (2026-04-01). ICP filing takes 2-4 weeks. SMS template approval takes 1-3 business days. Enterprise certification takes 3-5 business days. All must be started before first line of code if you want to deploy when code is ready.
**Effort:** XL for admin (2-4 weeks calendar time), S for engineering (config)
**Depends on:** Chinese legal entity registration (same as PIPL)
**Blocked by:** Nothing. Start today.

### WeChat Share Card Enhancement
**What:** Custom OG meta tags for WeChat card preview when sharing celebration links. Currently shares as plain URL.
**Why:** Rich preview cards get significantly higher tap-through rates in WeChat groups. The celebration card is the primary viral growth mechanic.
**Context:** Phase 1 shares via plain URL (landing page link, not in-app). Custom OG card preview requires WeChat Open Platform app ID registration and server-side OG tag rendering endpoint. Architecture changed: now native app with web landing page, not Flutter Web. Phase 1 landing page 不含 OG 标签（需要微信平台注册审批时间）。Phase 2 加入 OG 标签支持。
**Effort:** M (human: ~1 week with registration / CC: ~30 min)
**Depends on:** WeChat Open Platform account registration

### PIPL Compliance Workstream
**What:** ICP filing, Chinese legal entity registration, data residency setup (Alibaba Cloud), user consent flow, privacy policy registration. Separate critical-path workstream running in parallel with development.
**Why:** Gates production launch. Without it, cannot legally operate in China or collect any user data. ICP filing alone takes 2-4 weeks minimum with a Chinese entity.
**Context:** Currently noted as a "known risk" in the CEO plan but needs its own timeline. Engineering work (consent flow UI) is S-effort. The bottleneck is legal/admin: entity registration, ICP filing, privacy policy drafting and registration. Start immediately, don't wait for code to be ready.
**Effort:** XL for admin/legal (2-4 weeks calendar time), S for engineering (consent flow UI)
**Depends on:** Chinese legal entity registration (if not already done)

### ~~Update Plan for Scope Reduction (12→6 features) + Native Pivot Sync~~ ✅ DONE
**What:** 更新 `baby-talk-extended-mvp.md`：(1) 范围从 12 缩减到 6 个核心功能，AI Coach 提到 Layer 1；(2) 同步所有 Flutter Web→Native 的引用；(3) 删除内联 Design Token Summary，改为引用 DESIGN.md；(4) 合并 Ask Coach 重复描述为单一来源；(5) 更新 Build Order 依赖图。
**Status:** 已完成 (2026-04-02)。合并计划 `2026-04-02-baby-talk-phase1-consolidated.md` 已创建。旧计划已标记 SUPERSEDED。
**Why:** Eng Review v2 (2026-04-02) + Outside Voice 确认：CET-4/6 用户需要 AI 教练作为核心价值，静态短语卡对他们吸引力低。12 个功能分散在 20+ 天里会导致半成品。6 个核心功能 + AI Coach 在 Layer 1 才是正确的验证组合。
**Context:** 保留的 6 功能：Core coaching + phrases、AI Coach (LLM+TTS)、Auth + Onboarding、Roadmap + Difficulty、Progress screen、Celebration screen。移到 Phase 2：情侣模式、语音备忘录、发音对比、48h 提醒、今日短语 widget、WeChat 分享。
**Effort:** S (CC: ~20 分钟)
**Depends on:** Nothing. Start immediately.

### ~~补充后端架构设计~~ ✅ DONE
**What:** 在计划中补充：(1) PostgreSQL + Redis schema 设计；(2) Spring Boot 服务分层图（Controller→Service→Repository）；(3) 阿里云服务连接图（TTS/ASR/SMS/OSS/LLM）；(4) CI/CD 管道（APK/IPA 构建）；(5) LLM system prompt 完整模板。
**Status:** 已完成 (2026-04-02)。合并计划中包含 PostgreSQL schema + Spring Boot 分层 + CI/CD + 阿里云连接图。LLM prompt 模板待创始人编写。
**Why:** Eng Review v2 (2026-04-02) 发现后端架构完全未定义。test-plan-v3 提到 PostgreSQL+pgvector+Redis 但计划文档没有指定。开发者不知道表怎么设计。
**Context:** 单体 Spring Boot 4 应用，PostgreSQL 主数据库 + Redis 缓存。CI/CD 用 GitHub Actions + flutter build apk。
**Effort:** M (CC: ~1 小时)
**Depends on:** Scope reduction decision (6 功能确认后再设计)

### 🔥 字体打包进 APK Assets
**What:** 将 Fraunces (variable)、DM Sans、JetBrains Mono 字体文件打包为 Flutter asset，不使用 google_fonts package 的 CDN 动态加载。
**Why:** Google Fonts CDN (fonts.googleapis.com) 在中国大陆不可用。中国用户首屏会卡在字体加载或回退系统字体，破坏"暖纸亲和"设计。
**Context:** Outside Voice (2026-04-02) 发现。约增加 ~500KB APK 大小。需同步更新 DESIGN.md 的 Loading 章节。
**Effort:** S (CC: ~10 分钟)
**Depends on:** Nothing.

### 🔥 Batch Event Insert 需要事务包裹
**What:** `POST /sync/events` 的批量 event 入库必须包裹在数据库事务中。部分失败时全部回滚。Progress 重算只在整个 batch 成功入库后执行一次。
**Why:** Eng Review v4 (2026-04-02) 发现的 critical gap。如果 1000 条 events 中第 500 条失败，前 499 条已入库，progress 重算基于不完整数据。用户的 mastery 数据会不准。
**Context:** SyncService 实现时用 `@Transactional` 注解包裹 batch insert。Progress recalculate 在事务提交后调用。
**Effort:** S (CC: ~5 分钟)
**Depends on:** 后端 SyncService 实现

### 🔥 里程碑检测幂等性
**What:** milestone 检测逻辑需要幂等性。同一个 phrase_id 的 first_babble 只触发一次 milestone 记录。防止并发上传或网络重试导致重复庆祝。
**Why:** Eng Review v4 (2026-04-02) 发现的 critical gap。两个设备同时上传 babble event，或网络重试导致重复 event，会创建重复 milestone，用户看到两次庆祝屏幕。
**Context:** ProgressService.checkMilestones() 实现时先查询已有 milestone（SELECT WHERE type='first_babble'），已存在则跳过。或用 UNIQUE 约束 (user_id, type, scene_id) 做数据库级幂等。
**Effort:** S (CC: ~10 分钟)
**Depends on:** 后端 ProgressService + milestones 表实现

### 🔥 数据埋点设计
**What:** 设计并实现 analytics 系统：screen view、session duration、feature usage 事件跟踪。本地收集 + 有网时上传。需覆盖 CEO Review Expansion events: auto_flow_started/completed/paused, smart_push_sent/tapped, demo_shown/skipped, bedtime_push_sent/tapped, celebration_shared, quick_ask_tapped。
**Why:** Phase 1 用 10-20 人验证假设。没有行为数据只能得到"挺好的"主观反馈。需要知道：哪个场景最常用、用户每次停留多久、AI Coach 使用频率、Auto-Flow vs 手动模式比例、推送打开率。
**Context:** Outside Voice (2026-04-02) + CEO Review Expansion (2026-04-02)。InteractionEvent 只记录短语反应，不记录页面访问和会话数据。可以扩展 InteractionEvent 模型或创建独立的 AnalyticsEvent 模型。
**Effort:** S (CC: ~15 分钟设计 + ~1 小时实现)
**Depends on:** 后端架构设计完成

### 同步策略改为 Event Sourcing
**What:** 明确 InteractionEvents 为单一真相来源。客户端上传 events，服务端根据 events 重新计算 progress（mastery counts、stage completion 等）。移除 last-write-wins 同步逻辑。
**Why:** Progress 是聚合数据。Last-write-wins 对聚合数据是灾难性的——旧设备的 mastery=5 会覆盖新设备的 mastery=8。
**Context:** Outside Voice (2026-04-02) 发现。计划已有 events 上传端点（POST /api/v1/sync/events），只需声明这是唯一真相源，progress 不再双向同步。
**Effort:** S (CC: ~15 分钟文档 + ~30 分钟实现调整)
**Depends on:** 后端架构设计完成

### API 版本协商 + 强制更新机制
**What:** 客户端每次请求带 `X-App-Version` 头。后端维护 minimum_supported_version 配置。低于最低版本的请求返回 426 Upgrade Required + 下载链接。
**Why:** Native app 不能强制同时更新。后端改了 API schema，旧版 APK 会崩溃。
**Context:** Outside Voice (2026-04-02) 发现。简单实现：Spring Boot interceptor 检查版本头，低于阈值返回 426。
**Effort:** S (CC: ~15 分钟)
**Depends on:** 后端架构设计完成

### LLM 后端输入/输出安全过滤
**What:** 后端 Ask Coach 端点加入：(1) 输入过滤（亵渎/注入检测），不依赖客户端；(2) 输出过滤（确保 LLM 响应符合正面育儿方法论）；(3) Admin 审核页使用独立认证（不共用用户 JWT）。
**Why:** 客户端过滤可被绕过（直接调 API）。用户可以让 LLM 生成不当内容。Admin 页共用用户 JWT 意味着任何用户都能访问。
**Context:** Eng Review v2 (2026-04-02) 发现。OWASP Top 10: A01 Broken Access Control + A03 Injection。
**Effort:** S (CC: ~30 分钟)
**Depends on:** 后端架构设计完成

### OSS 直传 STS Scope 设计
**What:** 定义 STS 临时凭证的 scope：只允许写入 `voice-memo/{user_id}/` 路径。后端 STS 端点按 user_id 生成限定 scope 的临时凭证。
**Why:** 如果 STS scope 不限制，任何用户拿到临时凭证可以覆盖其他用户的语音文件。基础安全设计。
**Context:** Outside Voice (2026-04-02) 发现。阿里云 STS AssumeRole 支持 Policy 参数限制资源路径。
**Effort:** S (CC: ~10 分钟)
**Depends on:** 阿里云 OSS bucket 创建

### ~~Voice Memo 本地录音实现~~ ❌ REMOVED (Design Review v3)
**What:** ~~实现笔记 tab 的语音备忘录功能。~~
**Status:** Design Review v3 (2026-04-04) 决定: 笔记 tab 移除，语音功能分散到成长日记 (手动文字记录) + Mentor FAB 语音输入。不再需要独立录音功能。

### 全局离线降级 UI (Design Review v2+v3 更新)
**What:** 实现全局离线 banner + 各功能离线状态处理。banner 用 --warning-soft 背景固定顶部, **Mentor FAB 建议 tab 仍可用(本地预设)**, 聊天 tab 灰掉, Scene Coaching 正常可用, 花园显示本地数据, 成长日记显示本地数据+未同步标签。
**Why:** Design Review v3 更新: Mentor FAB 离线时不灰掉，显示本地预设建议。
**Context:** 需要 connectivity_plus 插件监听网络状态。全局 ConnectivityProvider 控制 banner 显示和功能可用性。
**Effort:** S (CC: ~1 小时)
**Depends on:** 底部导航 + 基础路由

### Dark Mode 支持 (Design Review v2 新增)
**What:** 实现跟随系统设置的 Dark Mode。使用 DESIGN.md 中已定义的 dark mode token: 背景 #1C1816, 卡片 #2A2420, 强调色微调 #FF9E5C, 英文青绿提亮 #5AAFA0。
**Why:** Design Review v2 确认 Phase 1 跟随系统设置。DESIGN.md 已有完整 dark mode token 策略。
**Context:** Flutter ThemeData.dark() + 自定义 ColorScheme。需要确保所有组件引用 theme token 而非硬编码颜色。
**Effort:** M (CC: ~2 小时，需要确保所有屏幕适配)
**Depends on:** 所有屏幕 UI 基本完成后统一适配

### ReactionChip 触摸目标优化 (Design Review v2 新增)
**What:** 确保 ReactionChip 按钮满足 48x48px 最小触摸目标。当前 mockup 中尺寸偏小。增加 padding 或使用 InkWell 的 materialTapTargetSize。
**Why:** 父母单手抱宝宝操作，小按钮容易误触或触不到。DESIGN.md 要求 44px min, 推荐 48px。
**Context:** Design Review v2 Pass 6 发现。Flutter InkWell 默认 materialTapTargetSize.padded = 48px。
**Effort:** XS (CC: ~10 分钟)
**Depends on:** Scene Coaching 页实现

### 用户留存指标定义 + 埋点 (Eng Review v6 新增)
**What:** 定义并实现 D1/D7/D30 用户留存率指标。在后端基于 interaction_events 计算：D1 = 注册后第 2 天有 event 的用户比例，D7/D30 同理。前端增加首次打开 app_opened 事件上报。
**Why:** Phase 1 验证 10-20 人，没有留存数据意味着只能凭感觉判断产品是否有价值。D1 > 40% 才值得继续迭代。
**Context:** Eng Review v6 (2026-04-03) Outside Voice 建议。留存分析可以后端 SQL 查询，不需要第三方分析工具。
**Effort:** S (CC: ~30 分钟)
**Depends on:** 数据埋点设计 + 后端 interaction_events 表

### 🔥 花园系统实现 (Design Review v3 新增)
**What:** 实现完整花园系统: GardenMap 可拖动画布, FlowerPatch 花圃组件, 花朵成长 4 阶段 (种子→发芽→含苞→盛开), 生长点系统 (练习赚点+浇水消耗), 播种仪式空状态动画。
**Why:** Design Review v3 + Design Shotgun 确认花园为 Phase 1 完整版。花园是核心游戏化循环。
**Context:** Flutter CustomPainter 或 Stack+Positioned 实现地图。garden_flowers 表 + growth_points 字段。约增加 3 天工时。
**Effort:** M (CC: ~4 小时)
**Depends on:** PostgreSQL schema (spaces/activities/garden_flowers 表) + Isar 本地模型

### 🔥 3 层内容模型迁移 (Design Review v3 新增)
**What:** 6个扁平 scene → space→activity→phrase 三层模型。新增 spaces + activities 表, phrases 表加 space_id + activity_id。更新 Flyway 迁移。
**Why:** "换尿布和穿衣服不是独立场景，而是晨间护理下的活动"。3 层模型更符合真实生活。
**Effort:** S (CC: ~1 小时)
**Depends on:** Nothing. Layer 0 完成。

### 🔥 小禾老师 Mentor FAB 实现 (Design Review v3 新增)
**What:** 全局 FAB + BottomSheet 面板, 双 tab (建议+聊天)。离线时建议 tab 显示本地预设。
**Why:** 替代旧 AI Coach 独立 tab。任何页面可触达。
**Effort:** M (CC: ~3 小时, Layer 1 骨架 + Layer 3 AI)
**Depends on:** 底部导航 + 基础路由

### 🔥 C3 激活框场景练习 (Design Review v3 新增)
**What:** Scene Coaching C3 激活框 scroll 模式。卡片滚入中部 ActivationFrame 时展开, 滚出时收缩。
**Why:** Design Shotgun 确认。比左右滑动更适合单手操作。
**Effort:** M (CC: ~2 小时)
**Depends on:** PhraseCard 组件 + TTS 播放

### 🔥 成长 Tab (Design Review v3 新增)
**What:** 替代 Progress + Notes。3 sub-tab: 日记(默认)/场景进展/里程碑。日记自动生成+手动添加。
**Effort:** M (CC: ~2 小时)
**Depends on:** interaction_events 表 + diary_entries 表

### 🔥 对话式 Onboarding (Design Review v3 新增)
**What:** 小禾老师对话式 Onboarding: 欢迎→名字→月龄快选→阶段匹配→30s迷你体验→注册→PIPL→首页。
**Effort:** S-M (CC: ~1.5 小时)
**Depends on:** PhraseCard 组件 + 小禾老师角色

### Emoji→插画替换 (Design Review v3 新增)
**What:** 所有 emoji 占位替换为插画/SVG/Lottie。花朵成长、空间图标、导航图标。
**Effort:** M (需要插画 assets)
**Depends on:** DESIGN.md 视觉风格确认

### Mockup Token 漂移修复 (Design Review v3 发现)
**What:** 修复 home.html --radius-md: 12px→16px。清理旧版 garden.html/mentor-fab.html。
**Effort:** XS (CC: ~5 分钟)

### A11Y: 花园地图无障碍 (Design Review v3 新增)
**What:** 花园 Semantics 标注 + 拖动替代的列表模式。
**Effort:** S (CC: ~30 分钟)
**Depends on:** 花园系统实现

## P2 — Post-Validation

### Hive Data Migration Strategy
**What:** 定义 Hive schema 演进策略。当数据模型变更时（加字段、改类型），旧版 app 的本地数据如何迁移到新版。
**Why:** Native app 更新是覆盖安装，Hive 数据会保留。如果新版的数据模型不兼容旧数据，app 会 crash。
**Context:** Phase 1 用 Hive 做本地存储。第一次 APK 更新前必须有迁移策略。可以用 version 字段 + migration runner 模式。
**Effort:** S (CC: ~15 分钟，写一个 migration runner)
**Depends on:** Phase 1 数据模型确定

### JPush Vendor Channel Push Notifications
**What:** Replace flutter_local_notifications with JPush SDK + vendor-specific push channels (Huawei Push Kit, Xiaomi MiPush, OPPO Push, etc.) for reliable push delivery.
**Why:** Phase 1 uses local notifications (flutter_local_notifications + alarm_manager). Some Chinese Android ROMs kill background processes, making local notifications unreliable. JPush routes through system-level vendor channels that survive process killing.
**Context:** Phase 1 local notifications are sufficient for 10-20 test users. If user feedback shows missed notifications are a retention problem, upgrade to JPush. Each vendor channel requires separate developer account registration and approval (3-5 business days each).
**Effort:** M (human: ~1 week for vendor registrations + integration / CC: ~2 hours code)
**Depends on:** Phase 1 user feedback confirming notification delivery issues

### iOS TestFlight Distribution
**What:** Purchase Apple Developer Account ($99/year) and set up TestFlight for iOS beta distribution.
**Why:** Phase 1 uses i4Tools self-signing which expires every 7 days. Not suitable for distributing to non-technical test parents. TestFlight supports up to 10,000 testers with link-based installation.
**Context:** Phase 1 is Android APK + iOS self-sign for personal testing only. Once validation passes and more iOS users are needed, TestFlight is the path. Requires macOS for Xcode builds (GitHub Actions macOS runner or Codemagic).
**Effort:** S (human: ~1 hour setup + $99 / CC: ~15 min CI config)
**Depends on:** Phase 1 validation passing, decision to expand to iOS users

### Cross-Session Coaching Memory
**What:** Track state transitions across coaching sessions. If a baby is fussy 60% of the time during diaper change across last 3 sessions, pre-select gentler phrases for that scene.
**Why:** Currently the coaching state machine resets to 'calm' every session regardless of history. Cross-session memory enables better personalization.
**Context:** Requires InteractionEvent data accumulation (at least a week of data). Adds complexity to MasteryService and coaching entry point. Phase 1 validates 'do parents return?' not 'is the coaching smart?' — per-session state machine is sufficient for validation.
**Effort:** S (human: ~4 hours / CC: ~2 hours)
**Depends on:** 1+ week of InteractionEvent data from Phase 1 users

### Daddy/Mommy Speaking Toggle
**What:** Track which parent speaks more English. Gentle comparison, not competitive.
**Why:** Addresses the spouse factor (social awkwardness of speaking English with partner watching). If both parents use the app, the awkwardness dissolves.
**Context:** Couple Mode (#11) validates spouse participation first. If Couple Mode shows strong usage, promote this to track individual parent progress separately. Adds multi-user data model complexity (multiple users per child).
**Effort:** S (human: ~2 hours / CC: ~15 min)
**Depends on:** Phase 1 Couple Mode usage data confirming spouse dynamics matter

### Monetization Model Decision
**What:** Define freemium split, pricing, and which features are gated.
**Why:** Multiple features (voice memo, difficulty progression, growth profile) have monetization potential. Chinese ed-tech market has high willingness to pay but also high churn. Decision should be data-informed.
**Context:** No pricing model exists yet. Features are accumulating with monetization-shaped justifications but no monetization plan. Should be decided based on Phase 1 retention data and user willingness-to-pay interviews.
**Effort:** S (human: ~half day research / CC: market analysis)
**Depends on:** Phase 1 retention data (30+ days)

### Grandparent Mode
**What:** One-tap simplified UI for grandparents visiting. Bigger text, fewer options, pre-selected beginner phrases only. Chinese grandparents who babysit want to participate in the English immersion.
**Why:** In Chinese families, grandparents often provide primary daytime childcare while parents work. If grandparents use the app too, the child gets English input all day, not just evenings.
**Context:** Second persona's UX — validate primary user (parent) first. Add after Phase 1 retention is proven and user interviews confirm grandparent interest.
**Effort:** S (human: ~3 hours / CC: ~15 min)
**Depends on:** Phase 1 user feedback confirming grandparent interest

### Morning Routine Builder
**What:** Parent sequences their daily scenes (wake up → diaper → feeding → dressing). App pre-loads phrases in that order. One tap to start the chain.
**Why:** Daily routines are predictable. If the app knows the parent's routine, it can queue phrases automatically, reducing friction from "pick a scene" to "start my routine."
**Context:** Smart Home screen already does time-of-day scene recommendations. Custom routine builder adds UI complexity (drag-to-reorder, save/edit/delete). Build after Phase 1 usage data shows whether parents actually follow predictable scene sequences.
**Effort:** M (human: ~1 week / CC: ~30 min)
**Depends on:** Phase 1 usage data showing scene sequence patterns

### Refresh Token 吐销机制
**What:** 实现 refresh token 吐销能力。Redis 维护一个 token 黑名单（或 family ID 方案），支持强制下线。
**Why:** 当前 30 天 refresh token 存在 Hive 里无法吐销。手机丢失或账号被盗时无法使任何设备下线。
**Context:** Eng Review v2 (2026-04-02) + Outside Voice 发现。Phase 1 用户少风险低，但应在用户量增长前解决。实现可以用 Redis 存 token family ID，refresh 时检查黑名单。
**Effort:** S (CC: ~15 分钟)
**Depends on:** Phase 1 发布后

### Phase 2 功能回收（范围缩减移出的 6 个功能）
**What:** 将 Eng Review 范围缩减中移出的 6 个功能加回：(1) 情侣模式 (#11)；(2) 语音备忘录 (#6)；(3) 发音对比 (#2)；(4) 48h 沉默提醒 (#10)；(5) 今日短语 widget (#9)；(6) 庆祝屏 WeChat 分享。
**Why:** 这些功能不是没有价值，而是不应该在核心假设验证前分散精力。Phase 1 验证通过后按优先级加回。
**Context:** Eng Review v2 (2026-04-02) + Outside Voice 范围缩减决策。优先级建议：48h 提醒 > 情侣模式 > 今日短语 > 语音备忘录 > 发音对比 > WeChat 分享（按留存影响排序）。
**Effort:** M (总计，每个功能 S)
**Depends on:** Phase 1 核心假设验证通过 (30+ 天留存数据)

## P3 — Nice to Have

### Scene Photo Backgrounds
**What:** Let parents set a photo of their actual changing table/bathroom/nursery as the background for that scene's phrase cards.
**Why:** Personalization increases emotional attachment. When you see YOUR bathroom behind "Splash splash!", it clicks differently.
**Context:** Not core to validation loop. Add after retention is proven to enhance stickiness.
**Effort:** S (human: ~1 hour / CC: ~10 min)
**Depends on:** Phase 1 retention validated

### Scene-Appropriate Sound Effects
**What:** Subtle audio cues per scene: rubber duck squeak for Bath, lullaby hum for Bedtime, cheerful rattle for Play Time. Makes each scene feel distinct and alive.
**Why:** Product polish that increases emotional attachment to the app. Makes the coaching experience feel immersive rather than clinical.
**Context:** Deferred during CEO review expansion ceremony. Not core to validation. Needs audio asset sourcing (~1MB bundle increase).
**Effort:** S (human: ~2 hours sourcing / CC: ~10 min to integrate)
**Depends on:** Core scene coaching working

### 🔥 Redis 不可用降级策略
**What:** 当 Redis 宕机或网络不通时，SMS 验证码、TTS 缓存、速率限制全部失效。需要内存 fallback：限流用 ConcurrentHashMap（不精确但可用），SMS 拒绝发送（安全优先），TTS 跳过缓存直接生成。
**Why:** Redis 是单点。如果 Redis 挂了：(1) 速率限制失效 → Coach API 可被无限调用 → LLM 费用爆炸；(2) SMS 验证码无法存储 → 登录不可用；(3) TTS 缓存失效 → 每次生成新音频 → 延迟增加。
**Context:** Eng Review v5 (2026-04-02) 的 critical gap。Phase 1 单 ECS + Redis 在同一台机器上，实际风险低，但 Spring Boot 的 try-catch 包裹成本极低。
**Effort:** S (CC: ~15 分钟)
**Depends on:** 后端 Spring Boot 架构实现

### 🔥 E2E 测试框架选型
**What:** 确定 Flutter E2E 测试框架：Flutter integration_test（官方内置）、Patrol（社区增强版）、或 Maestro（声明式，YAML 驱动）。8 个 E2E 关键路径需要覆盖。
**Why:** Eng Review v5 (2026-04-02) 识别了 8 个 E2E-worthy 用户流。没有框架选型就无法在 Build Order 中安排 E2E 测试任务。
**Context:** Flutter integration_test 是 Layer 1 boring 选择。建议 integration_test + permission_handler mock。
**Effort:** S (CC: ~30 分钟 spike)
**Depends on:** Flutter 项目脚手架

### 🔥 Hive → Isar 迁移
**What:** 将计划中所有 Hive 引用替换为 Isar。本地存储、Token 存储、InteractionEvent 缓存全部改为 Isar。
**Why:** Eng Review v5 (2026-04-02) 确认 Hive 2.x 不再积极维护。现在换比 Phase 2 迁移成本低 10x。
**Context:** Isar 是 Hive 作者的新项目，API 兼容性好。需要更新 pubspec.yaml、数据模型注解、查询语法。
**Effort:** S (CC: ~15 分钟批量替换)
**Depends on:** Nothing. 在开始写代码前完成。
