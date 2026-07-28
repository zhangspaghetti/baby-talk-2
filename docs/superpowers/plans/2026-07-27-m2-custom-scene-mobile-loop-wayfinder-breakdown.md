# M2 Custom Scene Mobile Loop — Wayfinder 工作拆解

- **Date:** 2026-07-27
- **Status:** Draft for implementation planning
- **Target repository:** `baby-talk-2`
- **Target branch:** `Develop`
- **Milestone:** M2 — Custom Scene Mobile Loop
- **Prerequisite:** M1 First Care-turn Onboarding 达到 `RELEASE READY`
- **Source of truth:** `docs/superpowers/specs/2026-07-23-duolingo-like-care-path-three-milestone-roadmap-design.md`

## 1. M2 结果定义

M2 不是“给 Scene 页面加一个输入框”。它必须交付一个可独立发布的完整纵向闭环：

```text
Today / Scene
→ 描述正在发生的照护时刻
→ 未登录时保存草稿并登录
→ 登录后 exactly-once 恢复提交
→ 后端返回已批准的 bounded care moment
→ 正式 Care Turn
→ 可播放生成音频
→ 我说了
→ canonical reaction
→ reaction-aware next support
→ 真实 Garden trace
→ Today continuity
```

Custom Scene 必须继续服从 Baby Talk 的核心产品合同：

```text
它是实时照护支持，不是聊天产品。
它返回完整可直接说的话，不是生成式文本编辑器。
它进入同一套 Care Path / event / Garden / Today 链路，不创建平行 session。
```

## 2. Wayfinder 首先发现的四个 P0 合同缺口

### Gap A — discovery `surface` 仍是 onboarding 语义

现有私有生成合同保留的已实现组合是：

```text
surface=onboarding
mode=catalog|custom_scene
```

M2 的入口是 Today 和 Scene。继续把请求伪装成 `surface=onboarding` 会污染：

- API 合同语义；
- 审计和指标；
- feature rollout；
- 后续兼容策略。

**锁定建议：** 后端新增、而不是替换：

```text
surface=care_path
mode=custom_scene
```

移动端本地保留：

```text
entrySource=today|scene
```

`entrySource` 只决定返回和 UI 上下文，不进入后端生成语义。

### Gap B — `clientTraceId` 不能替代业务幂等键

现有后端 exact reuse 主要基于 owner-scoped request fingerprint。它可以避免相同内容重复生成，但不能完整表达：

```text
“这是同一次用户点击产生的同一个业务请求”
```

仅依赖场景文本 fingerprint 会混淆：

- 同一用户有意再次提交完全相同场景；
- prompt/profile/refresh epoch 变化；
- 首次响应丢失后的明确 reconciliation；
- in-flight 与 terminal retry 的区别。

**锁定建议：** 新增随机、非敏感、稳定的：

```text
clientRequestId
```

要求：

- 一次用户生成意图生成一次；
- 登录往返、超时、响应丢失和进程恢复都保持不变；
- 后端按 `(owner scope, clientRequestId)` 唯一；
- 同 ID immutable request facts 不一致时 fail closed；
- 同 ID 已有 ACTIVE 结果时返回同一个 `generatedContentId`；
- `clientTraceId` 继续只做脱敏追踪，不承担幂等。

### Gap C — 当前 generated output 不足以完成 reaction loop

M2 明确禁止每次宝宝反应后再次开放式生成。一个 bounded care moment 必须在生成完成时已经包含或解析出：

```text
starter
+ cooperating support
+ hesitant support
+ resisting support
+ no_response support
+ other support
```

现有 private generation 的主要输出仍以单个 starter 为中心。

**锁定建议：** 一次 Generator/Judge 处理一个完整的 `GeneratedCareMomentBundle`。后端使用 additive migration 新增稳定 utterance 子实体，而不是把五个分支塞进临时 UI 字符串：

```text
practice_generated_content_utterances
- generated_content_id
- utterance_id
- role = starter | reaction_support
- reaction_type nullable
- english_text
- chinese_text
- pronunciation_hint
- tpr_action_zh
- delivery_guidance_zh
- display_order
- approval/status lineage
```

约束：

- 一个 ACTIVE generated content 必须恰好有一个 starter；
- 五种 canonical reaction 各有且仅有一个 approved support；
- 所有 utterance 有稳定 ID；
- bundle 作为整体通过 deterministic gate 和 application-computed Judge verdict；
- 不允许 reaction 时再次调用 Generator。

### Gap D — formal Practice path 目前只验证 seed phrase

现有 `PracticeRepository.recordReaction()` 会先通过 seed content 加载 activity，再验证 `phraseId`。旧的 dynamic path 使用时间戳 ID，并在失败时偷偷 fallback 到 seed，不能用于 M2：

```text
DynamicPracticeApiService
PracticeRepository.getActivitySnapshotDynamic()
```

问题：

- ID 不稳定；
- 不能 unknown-outcome reconciliation；
- 不能进程恢复；
- 不能可靠 Garden / Today hydrate；
- fallback 会掩盖 Custom Scene 失败。

**锁定建议：** 在 practice/care-path 基础层引入通用的 approved content resolver，而不是让 `custom_scene` 直接改写事件：

```text
PracticeContentResolver
├── SeedPracticeContentSource
└── GeneratedPracticeContentSource
      └── GeneratedCareMomentLocalStore
```

Custom Scene 成功后注册 approved bundle；之后仍调用正式：

```text
CarePathNotifier
→ CarePathRepository
→ PracticeRepository.recordReaction
→ InteractionEventPayload
→ Garden projection
→ Today continuity
```

旧 dynamic generate path 在 M2 中删除或明确 quarantine，不得复用。

## 3. M2 需锁定的跨端合同

### 3.1 Discovery request

建议的业务字段：

```text
surface = care_path
mode = custom_scene
clientRequestId
clientTraceId optional
babyProfileId
ageRange / parentGoal only when contract allows
locale = zh-CN
customSceneText
```

约束：

- `customSceneText` 只在首次提交前保存在本地 draft；
- 日志、analytics、trace 和 crash metadata 禁止记录原文；
- 客户端只做 trim、空值、长度和重复点击检查；
- safety/PII/quality 由后端 authoritative gate 处理。

### 3.2 Discovery response

Mobile mapper 必须保留：

```text
generatedContentId
spaceId / activityId
spaceSlug / activitySlug
spaceTitleZh / activityTitleZh
sceneTagEn
source = custom_scene
starter utterance
five reaction-support utterances
contentVersion
generationProfileVersion when public contract permits
voiceVersion / supportedAudioFormat
```

不得把 backend DTO 直接暴露给 UI。

### 3.3 TTS contract

推荐 endpoint：

```http
GET /api/v1/practice/generated-content/{generatedContentId}/utterances/{utteranceId}/audio
```

固定要求：

- authenticated；
- owner access checked；
- generated content 必须 ACTIVE；
- utterance 必须属于该 content 且 approved/playable；
- 只能根据服务器已批准英文合成，客户端不能提交任意文本；
- provider 通过 typed port 选择；
- 返回有上限的 audio bytes 与明确 MIME；
- `Cache-Control: private, no-store`；
- 不写数据库音频记录、不创建文件、不写对象存储；
- TTS 失败不改变 content approval，也不重跑 Generator。

### 3.4 Mobile audio contract

统一为 source-neutral：

```text
CareAudioSource
├── asset(assetPath)
└── generated(
      generatedContentId,
      utteranceId,
      voiceVersion,
      format
    )
```

禁止把原始英文或 scene text 放进 cache key。

## 4. 工作包与依赖图

```text
M2-00 Contract freeze
├── M2-01 Backend bounded moment bundle
├── M2-02 Backend idempotency/reconciliation
│
├── M2-03 Mobile domain/data foundation
│   ├── M2-04 Draft + auth continuation
│   └── M2-05 Submission state machine
│       └── M2-06 Today/Scene entry UI
│
├── M2-07 Generated content registry + formal Care Turn adapter
│   └── M2-08 Reaction/Garden/Today continuity
│
├── M2-09 Backend real-time TTS
│   └── M2-10 Mobile audio/cache/playback
│
├── M2-11 Privacy/lifecycle/architecture gates
└── M2-12 E2E + Android + release verification
```

Critical path：

```text
M1 RELEASE READY
→ M2-00
→ M2-01 + M2-02
→ M2-03
→ M2-05
→ M2-07
→ M2-08
→ M2-09/10
→ M2-12
```

## 5. 详细任务拆解

---

## M2-00 — Contract Freeze and Baseline Gate

**Priority:** P0  
**Type:** architecture / contract / verification

### Goal

在写 UI 前把 surface、idempotency、bundle、local registry、TTS 与版本边界锁定。

### Tasks

- 确认 M1 最终代码 SHA 已达到 `RELEASE READY`；
- 确认 private custom-scene backend 的最终 SHA 与完整 verification；
- 记录 V25/V26 是否已运行；M2 只允许 additive V27+；
- 冻结 `surface=care_path + mode=custom_scene`；
- 冻结 `clientRequestId` immutable-facts 规则；
- 冻结六 utterance bundle schema；
- 冻结 TTS route、MIME、最大 bytes、timeout、voiceVersion；
- 加 OpenAPI/controller fixture，确保旧 `onboarding/catalog|custom_scene` 合同不被破坏；
- 建立 M2 copy/privacy/architecture verifier skeleton。

### Acceptance

- 书面 contract 与 request/response fixture 被批准；
- 无需 UI 猜测 backend shape；
- 无数据库 migration 重写；
- M2 feature flag 默认关闭；
- R4 feature-boundary hard budget 仍为 30，无例外。

---

## M2-01 — Backend Bounded Generated Care Moment

**Priority:** P0  
**Depends on:** M2-00

### Goal

将现有单 starter private output 演进为一次生成、一次审批的 bounded care moment bundle。

### Suggested files

```text
backend/app-api/.../practice/discovery/PracticeDiscoveryResponse.java
backend/app-api/.../practice/generated/GeneratedCareMomentBundle.java
backend/app-api/.../practice/generated/GeneratedCareUtterance.java
backend/app-api/.../practice/generated/CustomSceneGenerator.java
backend/app-api/.../practice/generated/CustomSceneQualityJudge.java
backend/app-api/.../practice/generated/CustomSceneGenerationOrchestrator.java
backend/app-api/.../practice/generated/*Mapper*.xml
backend/db-migration/.../V27__add_generated_care_moment_utterances.sql
```

### Tasks

- 先写 migration negative tests；
- 新增 utterance child table 与唯一/shape constraints；
- Generator typed schema 返回 starter + five supports；
- deterministic gate 对每条 utterance 和 bundle 完整性校验；
- Judge rubric 增加 branch alignment、reaction support 与 bilingual consistency；
- Repair 仍是 bounded semantic attempt，不按 reaction 临时生成；
- ACTIVE transition 只有 bundle 全部通过才允许；
- response 保持既有 scene/moment/starter 字段，并 additive 返回 support branches；
- exact reuse hydrate 完整 bundle，不新增 provider call。

### Acceptance

- 一个 ACTIVE row 对应 6 个稳定 utterance；
- missing/duplicate reaction branch 数据库 fail closed；
- 第二次 exact request 返回同一个 content 与同一 utterance IDs；
- response 不泄露 provider/Judge internals；
- 旧 API regression 全绿。

---

## M2-02 — Explicit Request Idempotency and Unknown-result Reconciliation

**Priority:** P0  
**Depends on:** M2-00

### Goal

让“响应丢失”可以按同一业务请求确定性对账，而不是碰巧依赖文本 fingerprint。

### Tasks

- request 增加 `clientRequestId`；
- DB 增加 owner-scoped unique contract；
- 首次 reservation 绑定 immutable request fingerprint；
- 同 ID + same facts：返回已有 live/active 状态；
- 同 ID + conflicting facts：409/typed contract failure；
- live generating 请求：返回 typed in-progress/unknown reconciliation 结果，或同步等待既有执行的明确合同；
- terminal retry 必须生成新的 clientRequestId；
- `clientTraceId` 不参与业务幂等；
- Testcontainers 覆盖并发、响应丢失、重启和 owner isolation。

### Acceptance

- 两个并发同 ID 只进入一次 Generator；
- 写入成功但响应丢失后同 ID 返回原 `generatedContentId`；
- 不同账号同 ID 不关联；
- 日志不记录 scene 原文。

---

## M2-03 — Mobile `custom_scene` Domain and Data Boundary

**Priority:** P0  
**Depends on:** M2-01, M2-02

### Goal

建立严格 mobile-owned 语义层，UI 不接触 Dio 或 backend DTO。

### Suggested structure

```text
mobile/lib/features/custom_scene/
├── domain/
│   ├── custom_scene_draft.dart
│   ├── custom_scene_failure.dart
│   ├── generated_care_moment.dart
│   └── custom_scene_repository.dart
├── data/
│   ├── custom_scene_api.dart
│   ├── custom_scene_dtos.dart
│   ├── custom_scene_mapper.dart
│   └── custom_scene_repository_impl.dart
├── application/
└── presentation/
```

### Domain types

```text
CustomSceneEntrySource.today|scene
CustomSceneDraft
CustomSceneRequestIdentity
GeneratedCareMoment
GeneratedCareUtterance
GeneratedReactionSupportMap
CustomSceneFailureKind
```

### Tasks

- strict DTO parsing，missing/unknown/invalid enum fail closed；
- `AuthenticatedApiClient` 调用 canonical discovery endpoint；
- age/profile/locale 从 formal account/profile source 读取；
- mapper 保留所有稳定 IDs；
- backend error code 映射成安全 failure kind；
- 不把 raw exception、provider code 或 scene 原文带到 presentation message；
- provider graph 注入 repository；
- 增加 API/mapper/repository contract tests。

### Acceptance

- UI 无 Dio import；
- domain 无 backend DTO import；
- malformed response 不构造部分 `GeneratedCareMoment`；
- R4 budget 不增加。

---

## M2-04 — Draft Persistence and Reusable Authentication Continuation

**Priority:** P0  
**Depends on:** M2-03, M1 auth continuation foundation

### Goal

用户可先写场景，点击生成时才登录；登录后 exactly-once 恢复。

### Design

扩展：

```text
AuthContinuationIntent.generateCustomScene
```

Continuation 不直接复制 raw scene text，只保存：

```text
draftId
entrySource
clientRequestId
expectedAccountContext
createdAt / expiresAt
```

Raw text 存在独立 `CustomSceneDraftStore`。

### Tasks

- 原子 JSON/Isar draft store；
- 最小 snapshot：draftId、text、source、request ID、state、expiry；
- TTL 与 corrupt/ioFailure typed result；
- 登录返回时验证 expected account；
- auto-resume single-flight；
- success/cancel/logout/account-switch/expiry 清理；
- 登录失败保留 draft；
- 不自动再次进入登录；
- local-sensitive-data clearance registry 接入。

### Acceptance

- 登录往返不丢文字；
- 强杀一次后可恢复；
- 双击生成只创建一个 continuation；
- account switch 不会提交旧账号 draft；
- raw scene 不进 continuation log/analytics。

---

## M2-05 — Custom Scene Application State Machine

**Priority:** P0  
**Depends on:** M2-03, M2-04

### Goal

由 application controller 统一拥有提交、恢复、unknown outcome 和 handoff；Widget 不拼业务状态。

### State

```text
editing
needsAuthentication
restoring
submitting
unknownOutcome
generated
registeringCareMoment
readyForHandoff
recoverableError
```

### Tasks

- 所有 mutation 串行队列；
- submit single-flight；
- clientRequestId 在首次提交前持久化；
- network timeout/response loss 进入 `unknownOutcome`；
- retry/reconcile 复用同 ID；
- cancel 只停止 client waiting，不声称取消 server；
- successful response 先持久化 approved bundle，再清 draft/continuation；
- handoff navigation intent exactly once；
- typed safe copy mapping。

### Acceptance

- 快速点击无平行请求；
- 未保存 request ID 时不发网络副作用；
- response lost 后进程恢复仍使用同 ID；
- response 成功但 local registration 失败时可重试注册，不重跑生成。

---

## M2-06 — Today and Scene Entry + Input Surface

**Priority:** P1  
**Depends on:** M2-05

### Goal

在不抢占 preset scene 主路径的前提下开放两个入口。

### Entry rules

**Today：** 仅当当前推荐不匹配、用户跳过、path 空或无可用 moment 时显示安静入口。

```text
不是正在发生的事？
描述一下此刻
```

**Scene：** catalog 之后稳定提供。

```text
没找到正在发生的场景？
描述一下此刻
```

### Input surface

- 一个 multiline field；
- 简短隐私说明；
- 一个 primary CTA；
- preset fallback；
- calm inline waiting；
- 无百分比、无假步骤、无 provider/Judge/Repair 文案；
- 登录只在点击提交后发生；
- error 保留可编辑 draft。

### Tests

- Today priority condition；
- Scene entry positioning；
- 390×844、427×952、1.3x；
- keyboard/IME/back behavior；
- TalkBack field label、privacy copy、CTA、error/retry；
- banned-copy firewall。

### Acceptance

- Custom Scene 不替代 preset scenes；
- 一屏一个主动作；
- 无课程/任务/AI 内部术语；
- 返回来源稳定。

---

## M2-07 — Approved Generated Content Registry and Formal Care-turn Adapter

**Priority:** P0  
**Depends on:** M2-01, M2-03

### Goal

让 generated content 成为 Practice/Care Path 可解析的正式内容，而不是 UI-only strings 或假 activity。

### Suggested architecture

```text
PracticeContentResolver
├── SeedPracticeContentSource
└── GeneratedPracticeContentSource
      └── GeneratedCareMomentLocalStore
```

Cross-feature handoff 通过 app-level port/route contract；`custom_scene` 不直接 import Care Path screen/repository。

### Tasks

- 引入稳定 source enum：seed/generated；
- local store 持久化 approved bundle，不持久化 raw scene/audio；
- store 按 account scope 清理；
- `PracticeRepository.getActivitySnapshot()` 通过 resolver 支持 generated IDs；
- `recordReaction()` 对 generated phrase 正式验证；
- Care models 增加 source/audio reference，但不暴露 backend DTO；
- generated Care Turn route 只传 `generatedContentId` 或 typed app contract；
- 删除或 quarantine timestamp-ID dynamic path；
- 不新增 parallel event table。

### Acceptance

- generated phrase 能走同一个 `InteractionEventPayload`；
- process restart 后仍可 hydrate；
- fake/unknown generated ID fail closed；
- seed Care Turn 全部回归通过；
- R4 budget ≤30。

---

## M2-08 — Canonical Reaction, Garden, and Today Continuity

**Priority:** P0  
**Depends on:** M2-07

### Goal

证明 Custom Scene 最终进入正式产品闭环。

### Tasks

- reaction 只接受 canonical five values；
- next support 按 bundle reaction map 解析；
- stable localEventId 与 M1 reconciliation 复用；
- Garden projection 使用 generated content resolver；
- Today recent continuity 能展示 generated moment 和 next support；
- 不把 generated content 插入 preset catalog；
- 不建立 Custom Scene history UI；
- logout/account switch 后 private display content 不跨账号可见。

### Acceptance

```text
Custom Scene
→ 我说了
→ reaction
→ exactly one real event
→ correct support branch
→ real Garden trace
→ Today continuity
```

- unknown reaction wire value fail closed；
- event 写入成功但响应丢失仍 same-ID reconciliation；
- Garden 失败不回滚已确认 event。

---

## M2-09 — Backend Real-time TTS

**Priority:** P0  
**Depends on:** M2-01

### Goal

对已批准 utterance 提供 owner-checked、无持久化实时语音。

### Suggested components

```text
GeneratedUtteranceAudioController
GeneratedUtteranceAudioService
GeneratedSpeechSynthesisPort
ConfiguredGeneratedSpeechProvider
Disabled/Fake provider
GeneratedAudioResponse
```

### Tasks

- endpoint contract tests；
- authenticate + owner check；
- active content + utterance membership check；
- typed provider port 与配置 startup validation；
- provider timeout、MIME、byte size、empty body validation；
- bounded in-memory request handling；
- `no-store` headers；
- privacy/static verifier：禁止 DB/file/object-storage audio writes；
- TTS failure 不改 generated row state；
- fake provider 仅 test/dev。

### Acceptance

- 任意文本不能合成；
- 跨账号访问 404/403 按现有 privacy contract；
- inactive/rejected content 不可播放；
- zero audio persistence；
- Generator/Judge call count 不受 TTS 失败影响。

---

## M2-10 — Source-neutral Mobile Audio + Memory Cache

**Priority:** P0  
**Depends on:** M2-09, M2-07

### Goal

同一 Care Turn 控件同时播放 packaged asset 和 generated bytes。

### Suggested components

```text
CareAudioSource
CareAudioPlaybackController
GeneratedAudioApi
GeneratedAudioRepository
GeneratedAudioMemoryCache
GeneratedAudioCacheKey
```

### Cache rules

- item limit；
- total-byte limit；
- TTL；
- LRU；
- same-key single-flight；
- logout/account switch/consent withdrawal/account deletion 清空；
- process termination 自然清空；
- 空、超大、错误 MIME 拒绝；
- active utterance token 防止迟到响应自动播放。

### Tasks

- 扩展/替换 `PracticeAudioController.playAsset` 为 typed source；
- seed asset 行为保持不变；
- generated bytes 使用 authenticated client；
- cache 不落盘、不进 Isar/SharedPreferences；
- screen dispose / utterance change 取消 playback intent；
- audio failure 仍允许“我说了”。

### Acceptance

- asset 回归全绿；
- same-key 并发只发一个 HTTP；
- eviction/TTL/byte limit 可确定性测试；
- 切换 utterance 后旧响应不播放；
- Android 实机证明 bytes playback 可行；若不可行，停止并走新设计评审，不偷加临时文件缓存。

---

## M2-11 — Privacy, Lifecycle, Semantic Firewall, and Architecture Gates

**Priority:** P0  
**Depends on:** M2-03 through M2-10

### Goal

把私有场景、账号边界和非课程语义写进 CI，而不是只靠 review。

### Gates

- raw scene 禁止进入 analytics/log/crash metadata；
- owner HMAC 禁止进入 mobile DTO/model；
- generated audio 禁止持久化；
- draft、continuation、generated local registry、audio cache lifecycle 清理；
- fake provider 无 production routing；
- custom_scene UI 禁止：课程、练习、任务、正确、完成度、AI 思考中、Judge、Repair、provider；
- controllers/UI 不直接依赖 mapper/Dio；
- R4 hard budget ≤30；
- formatter baseline 不扩张。

### Acceptance

- static verifiers 有 fixture tests；
- logout/account switch integration 清理所有 M2 private local state；
- preset scene path 在 AI/TTS disabled 时仍可用。

---

## M2-12 — End-to-end and Release Verification

**Priority:** P0  
**Depends on:** all prior tasks

### Automated matrix

#### Backend

- discovery contract；
- bundle shape/state constraints；
- clientRequestId idempotency；
- exact reuse；
- owner isolation；
- TTS owner/content/utterance checks；
- no persistence privacy verifier；
- Testcontainers concurrency；
- full Maven test。

#### Mobile

- DTO/mapper/repository；
- draft/continuation；
- state machine；
- Today/Scene widgets；
- generated resolver；
- reaction/Garden/Today；
- audio cache/playback；
- lifecycle clearing；
- full Flutter test；
- analyze/format/R4/full CI。

### Required Android risk UAT

1. Today → custom scene → already signed in → generated Care Turn；
2. Scene → draft → login → exactly-once auto resume；
3. response written but lost → same request ID → same generated content；
4. app force-stop during login and submitting；
5. reaction write unknown outcome → exactly one event；
6. generated starter and five supports audio playback；
7. TTS failure still allows “我说了” and Garden；
8. leave page during audio fetch → no late playback；
9. logout/account switch clears draft/content/audio；
10. actual TalkBack order and return focus；
11. AI/TTS disabled → preset scenes remain usable。

### Release-ready statement allowed only when

```text
M1 regression: PASS
Backend full CI: PASS
Mobile full CI: PASS
R4 ≤ 30: PASS
Custom Scene exactly-once: PASS
Formal Care Turn handoff: PASS
Real event/Garden/Today: PASS
TTS zero persistence: PASS
Memory cache contract: PASS
Android risk UAT: PASS
Actual TalkBack: PASS
Clean worktree: PASS
```

## 6. Recommended PR / commit sequence

### PR A — M2 Contract Enablement

```text
M2-00
M2-01
M2-02
```

Feature remains disabled. Backend-only contract becomes stable and testable.

### PR B — Mobile Draft and Submission Foundation

```text
M2-03
M2-04
M2-05
```

No Today/Scene exposure yet. Use provider overrides and route harnesses.

### PR C — Formal Generated Care Turn

```text
M2-07
M2-08
```

Proves text-only generated loop, real event, Garden and Today before TTS complexity。

### PR D — Real-time Generated Audio

```text
M2-09
M2-10
```

Backend and mobile audio contract land together behind feature flag。

### PR E — Product Entry and Release Closure

```text
M2-06
M2-11
M2-12
```

Only after the formal loop and audio are proven does Today/Scene expose the feature。

## 7. Parallelization

Safe parallel lanes after M2-00：

```text
Lane A: M2-01 bounded bundle
Lane B: M2-02 request idempotency
Lane C: M2-03 mobile DTO/domain skeleton against frozen fixtures
Lane D: M2-09 TTS provider/endpoint contract against frozen utterance schema
```

Must remain sequential：

```text
M2-04 → M2-05 → M2-06
M2-07 → M2-08
M2-09 → M2-10
all → M2-12
```

Conflict hotspots：

- `repository_providers.dart`；
- `app_go_router.dart`；
- `care_path_models.dart`；
- `care_path_repository.dart`；
- `practice_repository.dart`；
- `practice_audio_controller.dart`；
- discovery response DTO/schema；
- generated-content migrations/mappers。

这些文件需要明确单一 owner，不能多 lane 同时修改。

## 8. 明确不进入 M2

- 自定义场景历史管理；
- 编辑已批准内容；
- 分享 generated content；
- 后台生成或 push；
- polling 作为正常路径；
- 每次 reaction 再调用模型；
- multi-turn chat；
- semantic reuse UI；
- public catalog promotion；
- 全局视觉重构；
- XP、金币、任务、连续打卡；
- 临时文件音频缓存；
- M3 全页面视觉/设备矩阵。

## 9. 第一批应立即写成实施计划的任务

不要一次把全部 M2 写成一个超长实现 diff。第一份 executable plan 建议只覆盖：

```text
M2-00 Contract Freeze
M2-01 Backend Bounded Generated Care Moment
M2-02 Explicit Request Idempotency
```

原因：这三项决定后续 mobile DTO、Care Turn adapter、TTS utterance identity 和 unknown-outcome 的全部形状。先锁 UI 或 audio 会导致返工。

该计划完成并 review 后，再分别编写：

```text
Plan B: M2-03/04/05 Mobile foundation
Plan C: M2-07/08 Formal generated Care Turn
Plan D: M2-09/10 Generated audio
Plan E: M2-06/11/12 Product exposure and release closure
```
