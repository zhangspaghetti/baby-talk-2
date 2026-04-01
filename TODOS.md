# TODOS

## P1 — Blocks Production

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
