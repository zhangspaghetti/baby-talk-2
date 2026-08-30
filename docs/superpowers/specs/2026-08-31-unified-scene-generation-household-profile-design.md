# 统一场景生成、家庭共享档案与预置内容发布设计

## 1. 背景

当前系统存在两条不同的练习内容路径：

- 自定义场景由用户输入文案，经过服务端证据检索、AI 生成、结构校验、修复、持久化和权限控制，产出一条 starter 与五条 reaction support。
- 预置场景直接读取移动端 `seed_content.json` 中的静态短语，不经过上述生成流程，也不会使用宝宝档案、家庭身份或近期练习上下文。

同时，次照护者没有自有宝宝档案时，自定义场景曾显示“宝宝档案未准备好”。最新修复通过隐藏次照护者入口避免误提示，但也阻止了次照护者使用家庭共享宝宝档案生成内容。

本设计解决三个相互关联的问题：

1. 次照护者必须能基于 household 的共享宝宝档案生成和使用家庭场景。
2. 预置场景与自定义场景必须进入同一套生成流程，差别只在输入来源。
3. 预置场景定义必须能在管理后台编辑，并通过草稿、发布版本和回滚进行治理。

## 2. 目标

- 建立一条统一场景生成管线，支持 `custom` 与 `preset` 两种严格区分的输入来源。
- 由服务端根据登录会话解析宝宝档案和家庭权限；客户端不得传入档案 ID、年龄段或照护目标。
- 次照护者始终使用所属 active household 的主照护者宝宝档案，即使次照护者账号历史上存在自有档案。
- 生成内容归家庭宝宝档案所有，active household 成员共享；练习互动仍归实际操作者。
- 预置场景首次打开时生成，按家庭档案、发布版本和每周家庭上下文缓存。
- 预置生成失败或离线时，可以使用 bundled 精选短语继续练习。
- 管理后台支持预置场景草稿、不可变发布版本、停用、版本历史和回滚。
- “我”页直接显示主照护者、次照护者或家庭同步状态。

## 3. 非目标

- 不兼容旧版自定义场景生成请求；改造完成后使用新版客户端。
- 不允许客户端提交或覆盖预置场景的生成文案。
- 不在本阶段通过管理后台维护离线短语或音频资源。
- 不在登录前或宝宝档案建立前强制调用 AI；注册和引导阶段继续使用精选静态预览。
- 不把手机号、账号标识、原始互动文本或完整家庭历史加入模型上下文。
- 不批量预生成全部预置场景。
- 不为生成记录新增“生成者账号”字段；练习事件继续承担实际操作者归因。

## 4. 核心领域模型

### 4.1 统一生成命令

新增统一的 `SceneGenerationCommand`。输入来源为严格 tagged union：

- `CustomSceneSource(text)`：用户输入的文案。
- `PresetSceneSource(presetSceneId)`：客户端只提供稳定场景 ID，服务端读取当前 published 版本。

命令还包含：

- `locale`
- `installationId`
- `clientRequestId`

命令不包含：

- `babyProfileId`
- `ageRange`
- `parentGoal`
- `babyName`
- `householdId`

`custom` source 只能出现 `type` 与 `text`；`preset` source 只能出现 `type` 与 `presetSceneId`。多余字段、混合字段和未知字段全部拒绝。

### 4.2 生成主体

`HouseholdBabyProfileAccessService` 根据已接受同意的登录会话解析 `GenerationSubject`：

- `actorAccountId`：当前登录账号，只用于权限判断和互动归因边界。
- `ownerAccountId`：宝宝档案所有者账号。
- `profileId` 与 `profileVersion`。
- `babyName`。
- `ageRange`。
- `parentGoal`。
- `householdId`，独立账号可为空。
- `actorRole`。

解析规则：

1. active membership 的角色为 `caregiver` 时，强制解析同一 active household 的 active `primary_caregiver` 所有档案。
2. `caregiver` 的历史自有档案不得参与选择。
3. 角色为 `primary_caregiver` 时使用自有档案。
4. 没有 household membership 但有自有档案时，按独立主照护者处理。
5. active membership 存在但角色未知时拒绝访问。
6. 次照护者家庭档案不存在时返回 `shared_profile_unavailable`。
7. 主照护者或独立账号档案不存在时返回 `profile_unavailable`。

### 4.3 个性化上下文

`PersonalizationContextBuilder` 只构造结构化信息：

- 宝宝姓名
- 年龄段
- 照护目标
- 语言偏好
- 当前照护者角色
- 近期练习聚合摘要
- 近期反应聚合摘要
- UTC 周窗口标识

不包含手机号、账号 ID、安装 ID、原始互动文本或用户隐私备注。近期摘要不可用时，生成仍使用核心宝宝档案继续执行。

宝宝姓名可以进入提示词和家庭共享生成结果。模型调用日志、错误详情和普通审计日志不得记录宝宝姓名或完整提示词。

## 5. 统一生成架构

### 5.1 服务边界

`SceneGenerationService` 负责完整编排：

1. 验证登录会话与客户端版本。
2. 解析 `GenerationSubject`。
3. 解析输入来源。
4. 构造个性化上下文。
5. 规范化并安全检查输入。
6. 构造缓存身份与幂等身份。
7. 执行证据检索。
8. 调用统一生成编排器。
9. 执行完整 bundle 校验、修复和质量判定。
10. 持久化生成记录与六条 utterance。
11. 返回统一响应。

现有 `CustomSceneGenerationOrchestrator` 的通用能力下沉或重命名为来源无关的 `SceneGenerationOrchestrator`。自定义与预置不得各自实现缓存、持久化、校验或权限分支。

### 5.2 输入解析

`SceneInputResolver` 有两个实现分支：

- 自定义输入：规范化用户文案，执行长度、敏感信息、欺骗字符、提示注入和内容政策检查。
- 预置输入：按 `presetSceneId` 读取当前 published 版本的 `generationBrief`；不存在、未发布或停用统一返回 `preset_scene_unavailable`。

预置文案虽然来自受控后台，仍执行结构与安全校验，防止错误模板进入模型。

### 5.3 输出合同

两类来源都必须产出相同 bundle：

- 一条 `starter`
- 五条 `reaction_support`
- 固定反应类型：`cooperating`、`hesitant`、`resisting`、`no_response`、`other`
- 场景元数据
- 每条 utterance 的 provider provenance
- `generatedContentId`
- 输入来源元数据

预置结果额外返回：

- `presetSceneId`
- `presetSceneVersion`

自定义结果不返回用户原始文案。

### 5.4 路由和统计身份

预置生成结果必须保留预置场景的稳定 `spaceId`、`activityId` 和 `presetSceneId`。模型不能修改这些路由身份。

因此：

- 预置个性化结果通过 `generatedContentId` 加载完整生成 bundle。
- 互动事件仍能归入原预置 activity 的进度、花园和成长统计。
- 预置生成结果不会被错误展示为独立“此刻照护”场景。
- 自定义生成结果继续使用独立生成场景身份。

## 6. API 设计

### 6.1 公开预置目录

`GET /api/v1/practice/preset-scenes`

只返回当前 published 且启用的场景：

- `presetSceneId`
- `publishedVersion`
- `spaceId`
- `title`
- `summary`
- `sceneTag`
- `coachTip`
- `sortOrder`

不得返回 `generationBrief`。

### 6.2 统一生成接口

`POST /api/v1/practice/scene-generations`

预置请求：

```json
{
  "source": {
    "type": "preset",
    "presetSceneId": "bath_time"
  },
  "locale": "zh-CN",
  "installationId": "installation_xxx",
  "clientRequestId": "request_xxx"
}
```

自定义请求：

```json
{
  "source": {
    "type": "custom",
    "text": "洗澡时宝宝不想碰水"
  },
  "locale": "zh-CN",
  "installationId": "installation_xxx",
  "clientRequestId": "request_xxx"
}
```

接口使用严格 JSON 合同。`babyProfileId`、`ageRange`、`parentGoal` 出现时直接拒绝。

旧 discovery 生成合同不保留兼容。服务端提高最低客户端版本；旧客户端返回 `426 app_version_required`。

### 6.3 管理接口

建议管理 API：

- `GET /api/admin/v1/practice/preset-scenes`
- `POST /api/admin/v1/practice/preset-scenes/{presetSceneId}/draft`
- `PUT /api/admin/v1/practice/preset-scenes/{presetSceneId}/draft`
- `GET /api/admin/v1/practice/preset-scenes/{presetSceneId}/versions`
- `POST /api/admin/v1/practice/preset-scenes/{presetSceneId}/publish`
- `POST /api/admin/v1/practice/preset-scenes/{presetSceneId}/rollback/{version}`

权限：

- `practice:read`
- `practice:write`
- `practice:publish`

## 7. 数据模型与发布治理

### 7.1 稳定身份

沿用 `practice_spaces` 与 `practice_activities`。`practice_activities.slug` 作为公开 `presetSceneId`，数据库内部继续使用数值主键和外键。

`practice_activities` 增加当前 published 版本引用。场景稳定身份不随标题、文案或版本变化。

### 7.2 版本表

新增 `practice_preset_scene_versions`，至少包含：

- 主键
- `activity_id`
- `version`：draft 时为空，发布事务中分配单调递增正整数
- `state`：`draft` 或 `published`
- `title_zh`
- `summary_zh`
- `scene_tag_en`
- `coach_tip_zh`
- `sort_order`
- `generation_brief`
- `enabled`
- `lock_version`
- `created_by_admin_id`
- `published_by_admin_id`
- `created_at`
- `updated_at`
- `published_at`

数据库约束：

- published 行的 `(activity_id, version)` 唯一。
- 每个 activity 最多一个 draft，使用 partial unique index。
- published 版本的必填展示字段和 `generation_brief` 非空。
- check constraint 要求 draft 的 `version` 为空、published 的 `version` 为正整数。
- 时间使用 `timestamp with time zone`。
- 外键和索引使用项目约定的稳定命名。

### 7.3 发布和回滚

发布操作在单一事务中：

1. 锁定 activity 与 draft。
2. 验证 optimistic lock。
3. 验证所有展示字段、长度、安全规则和生成文案。
4. 分配下一个单调版本号。
5. 把 draft 固化为 published。
6. 切换 `current_published_version_id`。
7. 写入发布审计。

published 行不可更新。回滚通过复制历史 published 内容、创建并发布新版本完成，不能把指针静默改回旧版本。

### 7.4 发布审计

新增发布审计表，记录：

- scene/activity 身份
- 操作：创建草稿、修改草稿、发布、停用、回滚
- 来源版本与目标版本
- admin principal
- 安全的字段变更摘要
- 时间

审计不保存模型个性化上下文。

### 7.5 生成记录扩展

`practice_generated_content` 增加或明确保存：

- `input_source`：`custom` 或 `preset`
- `preset_activity_id`，自定义为空
- `preset_scene_version_id`，自定义为空
- `profile_version`
- `household_context_version`

现有 owner 信息继续使用：

- `owner_scope = profile`
- `account_id = ownerAccountId`
- `profile_id = profileId`

不持久化原始家庭历史。自定义规范化文案继续按现有安全策略持久化；预置通过版本引用保证可复现性。

## 8. 缓存、幂等与限流

### 8.1 缓存身份

统一缓存身份包含：

- profile ID
- profile version
- 输入来源
- 自定义规范化文本哈希，或 preset activity ID + published version ID
- UTC 周窗口标识
- generation profile version
- prompt version
- rubric version
- evidence policy version
- content refresh epoch

同一家庭成员、同一预置场景、同一周和同一策略命中同一 bundle。

失效规则：

- 模板发布新版本：立即失效。
- 宝宝档案版本变化：立即失效。
- 生成、提示词、rubric 或证据策略变化：立即失效。
- 家庭近期上下文：每个 UTC 周窗口首次打开时刷新。
- 同一周新增互动不逐条使缓存失效。

### 8.2 幂等

`clientRequestId` 保留现有冲突、生成中和终态恢复语义。家庭成员可能同时打开同一预置场景；服务端应复用相同 owner/cache identity，只有一个生成占位成功，其余请求等待、重试或取得最终结果。

### 8.3 限流

profile-owned 内容按家庭 profile 共享限流预算，防止多个家庭成员绕过限流。自定义与预置可在相同 owner 下使用分来源计数和各自上限，但必须由同一限流组件执行。

## 9. 家庭权限

### 9.1 生成权限

- 主照护者或独立账号：使用自有档案。
- 次照护者：必须通过 active membership、active household 和 active primary membership 解析共享档案。
- 未知角色拒绝。
- 次照护者不能用客户端参数选择其他档案。

### 9.2 读取权限

所有消费者读取生成 bundle、utterance 和音频时统一使用同一访问谓词：

- 当前账号是生成内容档案所有者；或
- 当前账号是该档案所属 active household 的 active 成员。

不能只在首次生成时检查权限。membership 或 household 失效后，服务端后续读取立即拒绝。

离线设备无法即时感知远程撤销。下次会话或 household 同步时，移动端清除该家庭的生成内容缓存和恢复标记。

### 9.3 实际操作者归因

生成记录归 profile 所有，不新增生成者字段。练习互动、最近行为和家庭共享 actor 继续由提交互动事件时的登录账号决定。

## 10. 移动端体验

### 10.1 目录加载

目录读取顺序：

1. 远程 published 目录。
2. 上次成功持久化的目录快照。
3. bundled seed。

`generationBrief` 永不下发客户端。bundled seed 保留当前精选短语和音频，只用于注册/引导预览、首次离线和生成失败降级。

### 10.2 预置场景

首次点击未缓存场景：

1. 展示“正在为宝宝准备个性化练习…”。
2. 调用统一生成接口。
3. 成功后按 `generatedContentId` 进入练习。
4. 失败时显示“重试”和“使用通用内容”。
5. 选择通用内容时进入 bundled seed，并明确标记为通用内容。

命中服务端家庭缓存时直接进入生成内容。

登录后的“今天”“场景”和连续练习入口都使用统一生成。注册/引导阶段静态预览不调用生成。

### 10.3 自定义场景

自定义输入页继续接收用户文案，但提交改用统一 tagged request。客户端不再加载宝宝档案或 household 共享档案上下文。

生成失败时保留现有“查看已有场景”路径。自定义输入不能自动替换成某个预置输入。

### 10.4 错误恢复

- `shared_profile_unavailable`：显示“共享宝宝档案尚未准备好，请让主照护者先完成档案”，提供“查看家庭状态”。
- `household_access_required`：提供“查看家庭状态”。
- `profile_unavailable`：提供“完善宝宝档案”。
- `preset_scene_unavailable`：刷新目录；有对应 bundled scene 时允许使用通用内容。
- 超时、网络和生成中状态继续使用现有幂等恢复语义。

确定性档案或场景错误发生在生成占位创建前，客户端可以清除待提交草稿。未知结果必须保留恢复信息。

### 10.5 “我”页

用户信息卡直接显示：

- `主照护者`
- `次照护者`，并显示“使用家庭共享宝宝档案”
- household 加载中时显示“家庭身份同步中”
- 加载完成但无 membership 时显示“尚未加入共享家庭”

自定义入口不再按次照护者角色隐藏。共享档案缺失时保留入口，通过提交后的专用错误引导处理。

## 11. 管理后台体验

admin-web 新增“预置场景”页面：

- 场景列表与当前 published 版本状态
- 创建或继续编辑唯一 draft
- 编辑标题、摘要、标签、教练提示、排序、生成文案和启停状态
- optimistic lock 冲突提示
- 发布前校验摘要
- 版本历史
- 回滚操作

发布按钮要求 `practice:publish`；普通编辑要求 `practice:write`；只读查看要求 `practice:read`。

本阶段不提供音频上传、离线短语编辑或定时发布。

## 12. 错误合同

消费者错误：

- `invalid_scene_source`：400
- `invalid_custom_scene_text`：400
- `preset_scene_unavailable`：404
- `profile_unavailable`：404
- `shared_profile_unavailable`：404
- `household_access_required`：403
- `app_version_required`：426
- 现有 `generation_in_progress`、幂等冲突、终态、限流、超时和生成不可用错误继续保留

管理错误：

- `practice_draft_version_conflict`：409
- `practice_publish_validation_failed`：422
- `practice_preset_scene_not_found`：404
- 权限不足：403

消费者端对“不存在、未发布、已停用”统一返回 `preset_scene_unavailable`，避免泄漏内部内容状态。

## 13. 迁移与发布

1. 先执行项目要求的 Spring AI 2 平台门禁。
2. Flyway 新增版本表、审计表、约束、索引和生成记录扩展字段。
3. 把当前 bundled 五个场景迁移为 published v1，确保 `post_cry_soothing` 等移动端已有场景与服务端一致。
4. 部署 admin-api、admin-web 和 app-api 新能力。
5. 发布使用新合同的移动端，并提高最低客户端版本。
6. 不保留旧 discovery 生成合同；旧客户端收到升级要求。
7. 迁移完成后，现有 bundled 内容继续承担离线降级，不再作为在线目录真相源。

## 14. 测试策略

### 14.1 数据库与迁移

- Flyway migration smoke。
- 外键、check、唯一和 partial unique 约束。
- 每个场景最多一个 draft。
- published 版本不可通过服务更新。
- 并发发布只有一个成功，版本单调。
- 回滚生成新版本，不修改历史版本。
- 初始五个场景均存在 published v1。

### 14.2 app-api

- tagged request 精确字段校验。
- 三个客户端档案字段全部被拒绝。
- 次照护者无自有档案时生成成功。
- 次照护者有历史自有档案时仍强制使用家庭档案。
- 主照护者和独立账号使用自有档案。
- 未知角色、失效 membership、失效 household 和外部账号拒绝。
- 家庭档案缺失返回专用、不泄漏身份的错误。
- custom 与 preset 进入同一编排器和完整 bundle 校验。
- preset 只能读取当前 published 版本。
- 同家庭、同场景、同周复用；跨周、模板、档案或策略变化失效。
- active 家庭成员可读取 bundle 和音频；撤销后立即拒绝。
- 预置生成事件归入原 activity；自定义事件保持独立身份。
- 日志和错误不包含宝宝姓名或完整提示词。

### 14.3 admin-api 与 admin-web

- `practice:read/write/publish` 权限矩阵。
- 草稿创建、编辑、乐观锁冲突、发布、停用、历史和回滚。
- 发布校验失败不会切换当前版本。
- 目录只暴露当前 published 且启用版本。
- 页面 typecheck、build、关键组件测试和 Playwright E2E。

### 14.4 mobile

- 远程目录、持久化目录、bundled seed 的优先级。
- 预置首次点击显示生成进度，成功进入 generated route。
- 预置失败可重试或进入通用内容。
- custom request 不含档案字段。
- 幂等、超时和未知结果恢复。
- 预置生成事件计入原场景进度、花园和成长统计。
- 次照护者入口可见。
- 家庭状态错误 CTA。
- “我”页四种角色状态。
- membership 同步失效后清理家庭缓存。
- 语义标签、动态字体和按钮可达性。

### 14.5 完整验证

- `python3 tool/verify_spring_ai_2_backend_platform.py`
- `cd backend && bash mvnw clean test`
- admin-web typecheck、build 和 E2E
- Flutter analyze、定向 widget/unit 测试与相关回归测试

## 15. 成功标准

- 次照护者能够用家庭宝宝档案生成自定义和预置场景，不再看到误导性的自有档案错误。
- 自定义与预置只有输入来源不同，生成、校验、缓存、权限和持久化没有第二套编排。
- 在线预置内容由数据库 published 版本驱动，后台修改可审计、可回滚、可复现。
- 首次无缓存生成失败或离线时，用户仍能进入精选通用练习。
- 家庭成员共享生成 bundle，实际互动归因和权限撤销保持正确。
- “我”页无需打开抽屉即可识别当前家庭角色。
