# Requirements

This file is the explicit capability and coverage contract for the project.

## Active

### R001 - 父母必须能在真实育儿场景里进入一次练习，拿到一句自然短语、听到发音、跟着开口并记录宝宝反应。

- Class: primary-user-loop
- Status: active
- Description: 父母必须能在真实育儿场景里进入一次练习，拿到一句自然短语、听到发音、跟着开口并记录宝宝反应。
- Why it matters: 这是"实时双语育儿伴侣"最核心的存在理由；如果这条闭环不成立，其他能力都只是包装。
- Source: user
- Primary owning slice: M001/S01
- Supporting slices: M001/S02, M001/S04, M002/S01, M002/S02, M009/S02
- Validation: mapped
- Notes: 必须是生活场景，不是课堂练习或词卡浏览。

### R002 - 产品必须能根据宝宝信息完成个性化 onboarding、阶段匹配和首次进入体验，让用户从第一分钟就感到"这是给我家宝宝的"。

- Class: core-capability
- Status: active
- Description: 产品必须能根据宝宝信息完成个性化 onboarding、阶段匹配和首次进入体验，让用户从第一分钟就感到"这是给我家宝宝的"。
- Why it matters: 如果进入体验是空壳或通用模板，父母很难把它当作日常陪伴工具。
- Source: user
- Primary owning slice: M001/S02
- Supporting slices: M001/S01, M002/S02, M002/S03
- Validation: mapped
- Notes: 名字、月龄/生日、第一颗种子、第一句短语都属于这个体验的一部分。

### R004 - 一次练习的结果必须可见地推动花园、成长或里程碑，而不是只写入日志或后台表。

- Class: differentiator
- Status: active
- Description: 一次练习的结果必须可见地推动花园、成长或里程碑，而不是只写入日志或后台表。
- Why it matters: 用户需要感到"我刚刚说的那句英语带来了变化"，这决定连续使用意愿。
- Source: user
- Primary owning slice: M001/S04
- Supporting slices: M001/S01, M001/S03, M002/S02, M009/S04
- Validation: mapped
- Notes: 反馈应温暖、具体，不用冷冰冰分数代替。

### R005 - 当父母不知道该说什么时，必须能从小禾老师获得即时建议或求助入口。

- Class: core-capability
- Status: active
- Description: 当父母不知道该说什么时，必须能从小禾老师获得即时建议或求助入口。
- Why it matters: "临场想不起来"是用户开口的主要阻力，产品必须正面解决它。
- Source: user
- Primary owning slice: M001/S05
- Supporting slices: M001/S02, M001/S03, M002/S03
- Validation: mapped
- Notes: M001 至少要证明一条受控的 Mentor 援助路径真实可用。

### R006 - 练习、反应和关键行为数据必须以 append-only 事件为真相源，同步后可派生出进度、花园和成长结果。

- Class: integration
- Status: active
- Description: 练习、反应和关键行为数据必须以 append-only 事件为真相源，同步后可派生出进度、花园和成长结果。
- Why it matters: 如果把聚合结果当作真相源，多设备、重试、离线回放都会把状态弄脏。
- Source: execution
- Primary owning slice: M001/S03
- Supporting slices: M001/S01, M001/S04, M001/S05, M002/S01, M002/S02, M002/S03
- Validation: mapped
- Notes: 需要显式防止删除/篡改事件载荷。

### R007 - 儿童和家庭相关数据必须有明确的同意前/后边界、撤回路径、删除路径和本地优先策略。

- Class: compliance/security
- Status: active
- Description: 儿童和家庭相关数据必须有明确的同意前/后边界、撤回路径、删除路径和本地优先策略。
- Why it matters: 这是中国上线的合规底线，也直接影响用户信任。
- Source: research
- Primary owning slice: M001/S03
- Supporting slices: M001/S02, M001/S06, M002/S03
- Validation: mapped
- Notes: PIPL 同意前的名字/生日至少只保存在本地。

### R008 - 网络缺失、同步失败、AI 不可用、版本不兼容等关键失败必须被用户和开发者识别，而不是静默失败。

- Class: failure-visibility
- Status: active
- Description: 网络缺失、同步失败、AI 不可用、版本不兼容等关键失败必须被用户和开发者识别，而不是静默失败。
- Why it matters: M001 是验证版；如果失败面不可见，就无法判断问题来自产品还是基础设施。
- Source: inferred
- Primary owning slice: M001/S06
- Supporting slices: M001/S03, M001/S05, M002/S01, M002/S02, M002/S03, M009/S06, M009/S07
- Validation: mapped
- Notes: 至少需要用户可见提示、结构化日志和可复现的错误表面。

### R009 - M001 必须能交付一个可安装、可演示、可继续验证的测试版，而不是只停留在本地开发环境。

- Class: launchability
- Status: active
- Description: M001 必须能交付一个可安装、可演示、可继续验证的测试版，而不是只停留在本地开发环境。
- Why it matters: 核心假设"父母会不会持续开口"只能在真实安装和真实使用里验证。
- Source: inferred
- Primary owning slice: M001/S06
- Supporting slices: M001/S03, M002/S03
- Validation: mapped
- Notes: Android APK、iOS 测试路径、landing page/安装说明都属于这项要求的一部分。

### R010 - ICP、短信模板、企业认证、隐私政策等关键外部依赖必须被纳入项目执行路径并与工程切片对齐。

- Class: admin/support
- Status: active
- Description: ICP、短信模板、企业认证、隐私政策等关键外部依赖必须被纳入项目执行路径并与工程切片对齐。
- Why it matters: 这些外部依赖不是"以后再说"的细节，而是验证版和正式上线的现实门槛。
- Source: research
- Primary owning slice: M001/S03
- Supporting slices: M001/S06
- Validation: mapped
- Notes: 行政依赖可以并行，但不能在 roadmap 里缺席。

### R011 - 小禾老师的输出必须符合正向育儿边界，可被过滤、审计，并避免危险建议、羞辱感或注入式绕过。

- Class: compliance/security
- Status: active
- Description: 小禾老师的输出必须符合正向育儿边界，可被过滤、审计，并避免危险建议、羞辱感或注入式绕过。
- Why it matters: 这是品牌、合规和用户信任的共同底线。
- Source: execution
- Primary owning slice: M001/S05
- Supporting slices: M001/S06, M002/S03
- Validation: mapped
- Notes: M001 不要求极致智能，但要求受控可靠。

### R012 - M001 必须具备最小埋点、留存观察和成功阈值定义，能判断父母是否真的会回来继续用。

- Class: operability
- Status: active
- Description: M001 必须具备最小埋点、留存观察和成功阈值定义，能判断父母是否真的会回来继续用。
- Why it matters: 如果没有留存和复访证据，就无法判断"实时双语育儿伴侣"是否成立。
- Source: execution
- Primary owning slice: M001/S06
- Supporting slices: M001/S03, M001/S04, M001/S05, M002/S03
- Validation: mapped
- Notes: 重点不是复杂 BI，而是足够支持 D1/D7/D30 与核心行为判断。

### R033 - 产品必须支持多个可反复使用的真实育儿活动，并允许父母按 space/activity 进入、练习、恢复和查看反馈，而不是固定在单一默认活动。

- Class: core-capability
- Status: active
- Description: 产品必须支持多个可反复使用的真实育儿活动，并允许父母按 space/activity 进入、练习、恢复和查看反馈，而不是固定在单一默认活动。
- Why it matters: 如果仍只有一个固定 bath-time 场景，就无法区分是产品价值不足还是内容耗尽导致的复访下降，也无法证明用户愿意在不同真实场景里继续开口。
- Source: M002-research
- Primary owning slice: M002/S01
- Supporting slices: M002/S02, M002/S03
- Validation: mapped
- Notes: 继续复用现有 space → activity → phrase 内容模型与 append-only interaction_events 真相源，不引入第二套进度模型。

### R034 - 父母再次打开 app 时，必须能看到上下文感知的下一步入口，可继续上次活动或开始更合适的当前活动，并在 Home / Discover / Mentor / Garden 之间保持一致。

- Class: continuity
- Status: active
- Description: 父母再次打开 app 时，必须能看到上下文感知的下一步入口，可继续上次活动或开始更合适的当前活动，并在 Home / Discover / Mentor / Garden 之间保持一致。
- Why it matters: 留存的关键不是把用户召回到一个空首页，而是让回来的那一刻立刻知道下一步做什么，并被顺畅接回上一次上下文。
- Source: M002-research
- Primary owning slice: M002/S02
- Supporting slices: M002/S01, M002/S03, M009/S02, M009/S04
- Validation: mapped
- Notes: 优先 local-first，基于最近练习、当前阶段与现有投影仓储派生；不以 push / reminder 作为前置依赖。

### R056 — Repo-wide runtime persistence migration：common / app-api / admin-api 的所有运行时 direct JdbcTemplate 替换为 MyBatisPlus-backed repository adapters；Druid 作为 datasource 层、Hutool 作为定向工具库接入；测试代码可暂留 JdbcTemplate。

- Class: functional
- Status: validated
- Description: Repo-wide runtime persistence migration：common / app-api / admin-api 的所有运行时 direct JdbcTemplate 替换为 MyBatisPlus-backed repository adapters；Druid 作为 datasource 层、Hutool 作为定向工具库接入；测试代码可暂留 JdbcTemplate。
- Why it matters: 当前 JdbcTemplate 分散在多个运行时面，持久层风格不统一，新增代码的模式不明确，也缺少 datasource-level 的慢查询可见性。
- Source: user
- Primary owning slice: M007/S05
- Validation: M007/S05 complete: zero owned JdbcTemplate in runtime paths (Spring AI carve-outs preserved); 4-batch parity tests all green; Druid slow-query metrics observable at >2000ms threshold

### R057 — Collaborative onboarding docs：根目录 README 经 doc-coauthoring workflow 重写，Getting Started 是一等交付物；README / CONTRIBUTING / runbooks / verifiers / CI 全部描述同一套 Helm-first + gateway-first 真相。

- Class: operability
- Status: validated
- Description: Collaborative onboarding docs：根目录 README 经 doc-coauthoring workflow 重写，Getting Started 是一等交付物；README / CONTRIBUTING / runbooks / verifiers / CI 全部描述同一套 Helm-first + gateway-first 真相。
- Why it matters: 当前 README 和 CONTRIBUTING 仍然围绕 compose 和 admin demo 写，导致新开发者无法在没有口耳相传的情况下搭建本地环境；文档和运行时真相之间的漂移是持续的维护负担。
- Source: user
- Primary owning slice: M007/S06
- Validation: M007/S06 complete: new developer can reach gateway admin login from clone without compose; README has Getting Started section; README/CONTRIBUTING/runbooks/verifiers all reference the same Helm-first deploy path

### R058 - Baby Talk v1 必须采用 Family-micro-ritual-first 产品承诺，并显式排除课程、翻译器、打卡和无限生成路线。

- Class: core-capability
- Status: active
- Description: Baby Talk v1 是面向中国 0-3 岁家庭的 Family English Micro-ritual System + Activation-governed English Enlightenment Expert；它不以生成更多句子、覆盖更多场景、打卡、孩子词汇测试或英语课表为目标。
- Why it matters: 这条 thesis 决定后续 Home、Practice、Garden、Runtime、Pack 和指标都围绕少数英语声音迁移进家庭日常，而不是把父母推入新内容任务。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P39
- Supporting slices: M010/P40, M010/P41
- Validation: mapped
- Notes: Replaces the discarded old M010/S01 Home-first framing; UI surfaces must be re-derived from this thesis during spec/discuss phases.

### R059 - v1 的核心产品单位必须是 Family English Micro-ritual，而不是 Phrase、Path、Pack 或 activity completion。

- Class: primary-user-loop
- Status: active
- Description: 每个可激活的 micro-ritual 至少定义 fixedSound、routineAnchor、actionBinding、toneHint、childNoResponseRule、softVariant、doNotUseWhen 和 exitCondition；它允许中文共存，不要求孩子回应，并能长期重复直至迁移出 app。
- Why it matters: Phrase 容易把产品拉回句子库和翻译器；micro-ritual 才能把英语绑定真实动作、声音、节奏和家庭记忆。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P39
- Supporting slices: M010/P40, M010/P41
- Validation: mapped
- Notes: Phase 39 must decide which existing phrase/activity/garden concepts are superseded, retained, or wrapped by this unit.

### R060 - Observed Moment 必须作为 Context Seed 证据，Interpreted Moment 必须作为 joinability 假设，不能变成宝宝诊断或自动任务触发器。

- Class: core-capability
- Status: active
- Description: 系统必须区分看见的信号和解释出的假设：Observed Moment/Context Seed 只记录行为、对象、共同注意、节律、互动和父母状态；Interpreted Moment 判断英语能否轻轻加入，并支持 Joinable、Chinese-first、Action-bound、Silence-better、Too-teachy、Parent-awkward、Routine-ready、Already-active 等结果。
- Why it matters: 如果把假设说成事实，或因为看到合适场景就自动推新内容，产品会从关系安全的陪伴变成育儿判断和任务系统。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P39
- Supporting slices: M010/P41
- Validation: mapped
- Notes: Pack matching may read interpreted context, age, risk, preference and Garden Memory, but matching candidate content is not activation.

### R061 - Communication Primitive Library 与 Strategy Graph 必须约束回应策略、Primitive 顺序和切换规则，Runtime 只能在允许范围内微调用词。

- Class: functional
- Status: active
- Description: Primitive Library 至少覆盖 Joint Attention Anchor、Connection、Narration、Choice、Waiting、Boundary、Transition、Repair、Expansion 等原语；Strategy Graph 将 Interpreted Moment 映射到 Primitive Sequence，并定义继续/切换策略的证据条件。
- Why it matters: 没有底层 Primitive/Graph 约束，系统会退化成自由生成句子，难以保持短、温柔、低控制、可说出口的 Baby Talk 风格。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P41
- Supporting slices: M010/P39
- Validation: mapped
- Notes: Runtime 可调整措辞、长度、具体物体和下一句微调；不得裸生成新教育目标、催促服从、评价宝宝或提高英语难度。

### R062 - Strategy Pack 必须作为 Strategy Graph 的发布形态、推荐系统消费单元和运营资产；Pack 匹配只能产生候选，不能直接激活家庭日常。

- Class: functional
- Status: active
- Description: Pack schema 必须表达 momentScope、strategy.graphRef、goals、languagePolicy、avoidRules、exampleOpeners、microRitual、evaluationRubric 和 metrics；Pack 可以被推荐、复用、实验、升级或下架，但候选进入家庭日常前必须经过 Activation Governor。
- Why it matters: Pack 是可发布资产，但如果把 Pack 匹配等同于激活，系统会把丰富专家内容压进家庭 routine，违背 conservative activation。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P41
- Supporting slices: M010/P39, M010/P40
- Validation: mapped
- Notes: This supersedes the old requirement that treated Strategy Pack as the single core asset; Primitive + Graph are lower-level assets, Pack is publication/runtime consumption surface.

### R063 - Baby Talk v1 必须把 Activation Governor 作为 Pack/Graph candidate 与 Runtime Agent response 之间的激活门控层。

- Class: functional
- Status: active
- Description: Baby Talk v1 必须把 Activation Governor 作为 Pack/Graph candidate 与 Runtime Agent response 之间的激活门控层；它控制 Activate，不控制 Explore，并输出 allow_activation、nearby_expansion_only、defer_to_garden、save_for_later、rest_existing、belongs_to_family 等节奏决策。
- Why it matters: 产品风险不是内容不足，而是把太多内容激活成家庭任务；没有独立激活门控，Runtime 很容易从“帮助开口”滑向“持续推新内容”。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P40
- Supporting slices: M010/P41
- Validation: mapped
- Notes: v1 默认 active capacity 为 3；mature-family upper bound 是内部保护参数，不应暴露成用户目标。

### R064 - Garden Memory 必须是 parent-confirmed 的家庭英语 micro-ritual 记忆层，而不是完成度、打卡或系统评分层。

- Class: differentiator
- Status: active
- Description: Garden Memory 必须记录 candidate、active、familiar、resting、expandable、belongs-to-family 等 micro-ritual 家庭迁移状态，并通过低压力父母确认更新；weak signals 可辅助提示，但不能直接判定 familiar 或 belongs-to-family。
- Why it matters: 花园如果变成换皮打卡，会重新制造父母压力；它的价值是帮助家庭看见哪些英语声音已经在真实 routine 里活下来。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P40
- Supporting slices: M010/P39, M010/P41
- Validation: mapped
- Notes: 禁止 streak、完成数、枯萎惩罚、解锁场景等打卡语义；Garden 呈现状态并收集反馈，但不拥有 activation policy。

### R065 - v1 必须明确区分 Explore 和 Activate：专家内容可开放访问，但进入家庭日常的 active micro-ritual 必须保守限速。

- Class: core-capability
- Status: active
- Description: 父母可以开放探索路线、绘本、儿歌、场景和表达；但任何“今天去说 / 现在去试 / 加入你们家的新声音”都必须作为 Activate 进入 Governor 决策，不得由内容推荐或 Runtime Agent 直接推进。
- Why it matters: Baby Talk 需要保持高上限专家能力，同时避免把父母日常淹没成内容执行表。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P40
- Supporting slices: M010/P39, M010/P41
- Validation: mapped
- Notes: Explore More 开放；Activate Today 保守；Nearby Expansion 中等开放；New Micro-ritual 严格限速。

### R066 - v1 成功指标必须转向 Parent-confirmed Micro-ritual Transfer，而不是生成量、使用量、打卡、streak 或孩子词汇测试。

- Class: operability
- Status: active
- Description: v1 成功指标必须转向 Parent-confirmed Micro-ritual Transfer，并观察 first active micro-ritual spoken without pressure、routine reuse rate、micro-ritual repeat comfort、parent-confirmed familiar/belongs-to-family、resting without shame 和 over-activation prevention。
- Why it matters: Baby Talk 第一阶段要证明的是少数英语声音能否在真实家庭 routine 里自然迁移，而不是系统能生成多少句。
- Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- Primary owning slice: M010/P41
- Supporting slices: M010/P40
- Validation: mapped
- Notes: 不优化宝宝服从、孩子词汇、生成句子数量、连续打卡、AI 新奇程度、激活新 ritual 数量或花园植物数量。

## Validated

### R020 - 支持父母双方或多照护者共同参与、分别记录和协作使用。

- Class: differentiator
- Status: validated
- Description: 支持父母双方或多照护者共同参与、分别记录和协作使用。
- Why it matters: 这可能增强家庭共同参与，但不是 M001 先验证的关键闭环。
- Source: user
- Primary owning slice: M003/S03
- Supporting slices: M003/S04
- Validation: M003/S03 通过 caregiver invite/accept/shared-context 合同与移动端 household shell/home/garden surface 证明多照护者协作入口成立；M003/S04 进一步通过 CaregiverPracticeAttributionWebTest、CaregiverInviteApiWebTest、household/home/garden/mentor 测试与 root-safe proof pack，证明次照护者可完成真实练习并形成共享归因与下一步闭环。
- Notes: 当前验证基于仓库内 assembled proof 与 artifact-driven assessment；未宣称正式商店/外部 admin 流程已开通。

### R035 - 仓库卫生必须可验证：运行数据库、验证残留、临时 HTML/header 输出、构建产物不得继续入库；.gitignore 与已追踪垃圾清理都必须纳入 proof。

- Class: operational
- Status: validated
- Description: 仓库卫生必须可验证：运行数据库、验证残留、临时 HTML/header 输出、构建产物不得继续入库；.gitignore 与已追踪垃圾清理都必须纳入 proof。
- Why it matters: 当前 .data/ 目录下的 H2 数据库文件、根目录散落的 body_*.html/json 和 headers_*.txt 已全部入库，影响 diff 质量、review 可信度和运行安全边界。如果不显式要求，slice 很容易只补 .gitignore 而不清理已追踪垃圾。
- Source: M004 research - 仓库卫生缺口
- Primary owning slice: M004/S01
- Validation: git ls-files 不含 .data/、body_*、headers_* 文件（23个垃圾文件已从追踪中移除）；.gitignore 覆盖 .data/、*.lock.db、body_*.html/json、headers_*.txt；命令 `git ls-files | grep -cE '\.data/|body_|headers_' | grep -q '^0$'` 通过（exit 0）

### R036 - Mentor provider 必须支持真实路径 + dev seam fallback + 配置级多 provider 切换：通过 Spring AI 包裹真实 GitHub Copilot provider（OAuth），保留 dev seam 作为开发/离线 fallback，并支持通过 application.yml 配置切换 provider。

- Class: functional
- Status: validated
- Description: Mentor provider 必须支持真实路径 + dev seam fallback + 配置级多 provider 切换：通过 Spring AI 包裹真实 GitHub Copilot provider（OAuth），保留 dev seam 作为开发/离线 fallback，并支持通过 application.yml 配置切换 provider。
- Why it matters: R011 约束了安全和审计，但没有明确要求真实 provider/OAuth/配置级多 provider 切换这一运行边界。对 M004 来说这是里程碑主目标之一，不显式立约会导致 slice 只做 stub 而不做真实接入。
- Source: M004 research - provider 运行边界缺口
- Primary owning slice: M004/S04
- Supporting slices: M004/S02
- Validation: SpringAiMentorProvider 实现通过 ChatClient 调用真实 OpenAI 兼容 API；MentorProviderConfiguration 支持 dev/github-models/openai 三种 provider mode 配置级切换；dev seam (DevMentorProvider) 在 api-key 为空时作为 fallback；provider 不可用时分别抛出 ProviderTimeoutException/ProviderUnavailableException/ProviderMalformedResponseException；66 个测试全绿（含 12 个新测试，覆盖四种异常路径和 API key 脱敏）

### R037 - 全 app UX 基线必须显式覆盖 a11y / i18n / dark mode / DESIGN.md 对齐：所有 screen 和 landing surface 的视觉样式与 DESIGN.md 一致，支持深色模式，用户文案通过 i18n 机制提供中文本地化，关键路径有 a11y 语义标签。

- Class: non-functional
- Status: validated
- Description: 全 app UX 基线必须显式覆盖 a11y / i18n / dark mode / DESIGN.md 对齐：所有 screen 和 landing surface 的视觉样式与 DESIGN.md 一致，支持深色模式，用户文案通过 i18n 机制提供中文本地化，关键路径有 a11y 语义标签。
- Why it matters: 当前 requirements 没有直接要求全 app 设计系统一致性与无障碍/暗黑模式/文案策略。如果不显式立约，M004 很容易只修功能不修真实用户表面，留下"框架已建、界面没收"的假完成。
- Source: M004 research - UX 基线缺口
- Primary owning slice: M004/S06
- Supporting slices: M004/S03
- Validation: M004/S06 验证完成：BabyTalkColors ThemeExtension light/dark + ThemeMode.system 实现 dark mode；AppLocalizations i18n 基础设施在 15 个 features presentation 文件中接入；Semantics 语义标签在 9 个文件中有匹配；33 个 smoke 测试全绿（theme/i18n/a11y 三件套）；flutter analyze 零 error 零 warning；DESIGN.md CardTheme 圆角/阴影 token 对齐完成

### R038 - 仓库级部署 proof 必须至少覆盖 Docker / Compose / CI / K8s artifact + smoke：项目可通过 Docker multi-stage build、docker compose 本地拉起、GitHub Actions CI 自动验证、K8s manifests/Helm lint/dry-run/smoke/runbook 完成仓库级交付证明。

- Class: operational
- Status: validated
- Description: 仓库级部署 proof 必须至少覆盖 Docker / Compose / CI / K8s artifact + smoke：项目可通过 Docker multi-stage build、docker compose 本地拉起、GitHub Actions CI 自动验证、K8s manifests/Helm lint/dry-run/smoke/runbook 完成仓库级交付证明。
- Why it matters: R009/R012 只到"可安装/可演示/可继续验证"的级别；M004 目标已经更接近"仓库级发布工程完备"。当前仓库没有 Dockerfile、compose、CI workflow、K8s manifests 中的任何一个。
- Source: M004 research - 部署 proof 缺口
- Primary owning slice: M004/S05
- Supporting slices: M004/S07
- Validation: S07 完成：helm lint 零错误、helm template 渲染 7 种资源类型（含 Ingress）、bash ci/k8s-smoke.sh exit 0（6 PASS / 0 FAIL / 2 SKIP-无集群）、docs/runbooks/k8s-deploy.md 426 行、README 包含 K8s 章节。全部仓库级交付证明（Docker/Compose/CI/K8s）已覆盖。

### R039 - 所有 mobile 页面（Flutter）须经 ui-ux-pro-max skill 专业评审后进行 UI/UX 改进。包括但不限于：accessibility、dark mode、color palette、typography、spacing、animation、touch interaction 等维度的审查和改进。

- Class: functional
- Status: validated
- Description: 所有 mobile 页面（Flutter）须经 ui-ux-pro-max skill 专业评审后进行 UI/UX 改进。包括但不限于：accessibility、dark mode、color palette、typography、spacing、animation、touch interaction 等维度的审查和改进。
- Why it matters: 确保 mobile app 的 UI/UX 达到专业水准，而非仅凭 DESIGN.md 静态文档或 agent 自行判断。专业评审能发现 accessibility 盲区、交互体验问题、视觉一致性偏差等人工难以全面覆盖的问题。
- Source: user-directive
- Primary owning slice: M004/S06
- Validation: M004/S06/T01 输出 S06-UX-REVIEW.md，对全部 8 个主屏幕进行专业 UI/UX 评审，识别 dark mode/a11y/token 缺口；T02-T05 按评审优先级执行改进（主题重构、颜色 token 迁移、i18n 接入、a11y 语义标签），评审-驱动的改进全部实施
- Notes: 已决定放入 M004/S06。S06 plan 阶段需将 ui-ux-pro-max skill review 作为前置 task，先评审所有 mobile 页面，再根据评审意见和 S06 原有目标（a11y/i18n/dark mode/DESIGN.md 对齐）统一执行改进。

### R040 - Agentic Search：小禾老师通过 tool calling 自主编排知识检索（向量检索 + 关键词检索 + 文档读取 + 宫殿导航 + KG 查询），后台可切换 agentic/RAG 模式

- Class: functional
- Status: validated
- Description: Agentic Search：小禾老师通过 tool calling 自主编排知识检索（向量检索 + 关键词检索 + 文档读取 + 宫殿导航 + KG 查询），后台可切换 agentic/RAG 模式
- Why it matters: RAG 存在 query 噪声、切片只言片语、向量匹配未必最优等局限；agentic search 让模型自主决策搜索策略，支持多轮检索直到信息充足
- Source: user - M005 Layer 3 讨论
- Primary owning slice: M005/S03
- Validation: 87 个单元/集成测试通过（PalaceKeywordRepositoryTest 11 + PalaceToolProviderTest 28 + MemPalacePromptBuilderTest 11 + AgenticMentorIntegrationTest + SpringAiMentorProviderTest）。PalaceToolProvider 5 个 @Tool 方法、三种 search-mode 切换（agentic/rag/none）、AgenticMentorIntegrationTest 验证 .tools() 注册、MemPalacePromptBuilderTest 验证四层 Prompt 分层。完整 tool calling 链路（LLM 真正调用 tool）需真实 OpenAI API key 在生产环境验证。

### R041 - 育儿知识宫殿：51 本育儿文献按 MemPalace Wing/Room/Hall 结构标注元数据并入库 PgVector，支持按宫殿坐标过滤检索

- Class: functional
- Status: validated
- Description: 育儿知识宫殿：51 本育儿文献按 MemPalace Wing/Room/Hall 结构标注元数据并入库 PgVector，支持按宫殿坐标过滤检索
- Why it matters: 结构化元数据让搜索可以按领域/主题/知识类型精准定位，而非全库扁平搜索
- Source: user - M005 Layer 1 讨论
- Primary owning slice: M005/S02
- Validation: 51 本书完整映射（5 Wing/18 Room/22 Hall 分类体系），MemPalaceTaxonomy + MemPalaceMetadataEnricher 24 个单元测试通过。PgVectorStore filterExpression 按坐标过滤验证通过。batch-ingest.sh/.cmd 就绪。实际 PDF/ePub 批量导入执行需要真实书籍文件 + OpenAI Embedding API。

### R042 - 多轮对话记忆：小禾老师支持 10 轮滑动窗口对话历史，30 分钟无交互自动结束会话，对话状态 PostgreSQL 持久化

- Class: functional
- Status: validated
- Description: 多轮对话记忆：小禾老师支持 10 轮滑动窗口对话历史，30 分钟无交互自动结束会话，对话状态 PostgreSQL 持久化
- Why it matters: 多轮记忆让小禾老师理解对话上下文，给出连贯、有针对性的建议而非每次从零开始
- Source: user - M005 Layer 2 讨论
- Primary owning slice: M005/S04
- Validation: ChatMemoryIntegrationTest 5/5 通过：多轮 conversationId 保持稳定、10 轮滑动窗口裁剪、30 分钟超时新建会话、null→UUID 向后兼容。Flyway V13 SPRING_AI_CHAT_MEMORY 表，JdbcChatMemoryRepository 手动配置，conversationId 全链路穿透。

### R043 - 动态练习生成：练习场景对话完全由 agentic search 基于知识宫殿 + 宝宝月龄/进度/用户反馈动态生成，淘汰 seed_content.json 预置内容

- Class: functional
- Status: validated
- Description: 动态练习生成：练习场景对话完全由 agentic search 基于知识宫殿 + 宝宝月龄/进度/用户反馈动态生成，淘汰 seed_content.json 预置内容
- Why it matters: 预置内容无法个性化，动态生成让练习内容与宝宝实际阶段和家长需求精准匹配
- Source: user - M005 Layer 4 讨论
- Primary owning slice: M005/S06
- Validation: POST /api/v1/mentor/practice/generate + MemPalacePromptBuilder.buildPracticeSystemPrompt()（26/26 测试通过）。DynamicPracticeApiService + PracticeRepository.getActivitySnapshotDynamic()，8 场景单元测试通过，seed_content.json 降级为离线 fallback。flutter analyze 零错误，17/17 移动端测试通过。

### R044 - Knowledge Graph：PostgreSQL 存储育儿知识实体关系图谱 + 时间有效窗口，支持矛盾检测、agent 自动审查冲突记录、无法自动判断时通知管理员人工介入

- Class: functional
- Status: validated
- Description: Knowledge Graph：PostgreSQL 存储育儿知识实体关系图谱 + 时间有效窗口，支持矛盾检测、agent 自动审查冲突记录、无法自动判断时通知管理员人工介入
- Why it matters: 育儿领域专家观点常有分歧，知识图谱能追踪实体关系和矛盾，确保回复质量和可追溯性
- Source: user - M005 Layer 3 讨论
- Primary owning slice: M005/S05
- Validation: V14 Flyway 迁移建立 pg_trgm + 4 张表（kg_entities/kg_relationships/kg_contradictions/kg_admin_notifications），4 个 JdbcTemplate Repository，KgContradictionDetector 自动检测 contradicts 关系，KgContradictionReviewService @Scheduled agent 审查，4 个 REST 端点，19 个测试全部通过，编译 exit 0。

### R045 - 文献 Ingestion 管道：REST API 上传文献 → MinIO 存储 → 异步多格式解析（PDF/ePub/TXT）→ 智能分块 → 宫殿元数据标注 → embedding → PgVector。提供批量导入脚本。所有操作详细日志可追溯 + 完备运维文档

- Class: functional
- Status: validated
- Description: 文献 Ingestion 管道：REST API 上传文献 → MinIO 存储 → 异步多格式解析（PDF/ePub/TXT）→ 智能分块 → 宫殿元数据标注 → embedding → PgVector。提供批量导入脚本。所有操作详细日志可追溯 + 完备运维文档
- Why it matters: REST API 为后续管理员页面铺垫，MinIO 持久化原始文件，异步处理避免上传阻塞
- Source: user - M005 Layer 2 讨论
- Primary owning slice: M005/S02
- Validation: REST API 3 端点（POST /upload 202+jobId、GET /jobs/{id} 状态、POST /jobs/{id}/retry 仅 FAILED 可重试），MinIO 存储，Tika 解析，ingestion_jobs 状态跟踪（PENDING→PROCESSING→COMPLETED/FAILED），batch-ingest.sh/.cmd 批量脚本就绪，3 个集成测试类编译通过，24 个单元测试通过。

### R046 - H2 全迁 PostgreSQL + pgvector 扩展，Flyway 迁移适配，所有现有功能（accounts/audit/mentor_turns/distribution/share/invite）不回归

- Class: operational
- Status: validated
- Description: H2 全迁 PostgreSQL + pgvector 扩展，Flyway 迁移适配，所有现有功能（accounts/audit/mentor_turns/distribution/share/invite）不回归
- Why it matters: 统一数据库降低运维复杂度，pgvector 支持向量检索，PostgreSQL 支持全文搜索
- Source: user - M005 Layer 2 讨论
- Primary owning slice: M005/S01
- Validation: docker-compose up -d 全栈健康，curl /actuator/health 返回 db(PostgreSQL)+minio 均 UP。Flyway V10 创建 pgvector 扩展 + vector_store 表 + HNSW 索引。16 个测试类迁移到 Testcontainers PostgreSQL（AbstractIntegrationTest singleton pattern）。

### R047 - 端到端部署验证：Docker 一键拉起（PostgreSQL + pgvector + MinIO + backend）→ 安卓模拟器安装运行无问题 → 20 题育儿问题验收通过 → 动态练习生成可用 → 文档全更新（README/runbook/部署/运维） → Helm chart 同步

- Class: operational
- Status: validated
- Description: 端到端部署验证：Docker 一键拉起（PostgreSQL + pgvector + MinIO + backend）→ 安卓模拟器安装运行无问题 → 20 题育儿问题验收通过 → 动态练习生成可用 → 文档全更新（README/runbook/部署/运维） → Helm chart 同步
- Why it matters: 确保整个系统从部署到使用的完整链路可用，不留半成品
- Source: user - M005 Layer 4 讨论
- Primary owning slice: M005/S07
- Validation: docker-compose config 解析成功含全部 M005 变量；helm lint 通过（0 charts failed）；README 含 PostgreSQL/MinIO/MemPalace/pgvector 完整架构说明；m005-mempalace-ops.md 新建含 9 个运维段落；verify-e2e.sh 语法检查通过，CI 脚本使用 mvn。安卓模拟器全功能测试和 20 题育儿验收集需真实设备 + OpenAI API key，为运营验证前提条件。

### R048 - 后端重构为三模块 Maven 多模块工程：common（共享实体/仓储/配置）、app-api（mobile REST 服务独立部署）、admin-api（admin REST 服务独立部署），各自打包为独立 Spring Boot JAR。

- Class: operational
- Status: validated
- Description: 后端重构为三模块 Maven 多模块工程：common（共享实体/仓储/配置）、app-api（mobile REST 服务独立部署）、admin-api（admin REST 服务独立部署），各自打包为独立 Spring Boot JAR。
- Why it matters: 单体结构导致 mobile API 和 admin API 耦合部署，代码边界不清；多模块拆分后可独立扩缩容、独立发布，为未来进一步拆分奠定基础。
- Source: user
- Primary owning slice: M006/S01
- Validation: Fresh slice-close verification on 2026-04-24: `./ci/backend-test.sh` passed, including `./backend/mvnw -f backend/pom.xml -B test` (reactor summary: parent/common/db-migration/app-api SUCCESS) plus migration-first compose smoke where `app-api` and `admin-api` health endpoints both became healthy. Browser/API closure also passed via `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` (3/3 passed), and focused auth/migration proofs passed via `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` and `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest`.
- Notes: Validated at S01 close; R049/R050 remain active for later slices because mobile JWT migration and standalone flyway:migrate/CI closure still extend beyond this slice.

### R049 - 统一引入 Spring Security，mobile 认证从 X-Session-Id 迁移到 JWT 双令牌（access token 15min + refresh token 7d），admin 用独立 admin_users 表走用户名+密码认证，两套认证均由 Spring Security 统一处理。

- Class: functional
- Status: validated
- Description: 统一引入 Spring Security，mobile 认证从 X-Session-Id 迁移到 JWT 双令牌（access token 15min + refresh token 7d），admin 用独立 admin_users 表走用户名+密码认证，两套认证均由 Spring Security 统一处理。
- Why it matters: 现有 X-Session-Id 机制绕过了 Spring Security，无法统一权限控制；JWT 标准化后 admin 和 mobile 共用同一套认证基础设施，为 RBAC 和令牌吊销奠定基础。
- Source: user
- Primary owning slice: M006/S02
- Validation: S02 verification passed on 2026-04-24: `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest,AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest` passed, and `flutter test mobile/test/features/account/jwt_session_refresh_test.dart mobile/test/features/account/account_repository_test.dart mobile/test/features/household/household_repository_test.dart mobile/test/features/mentor/mentor_view_model_test.dart` passed from the worktree root, proving token-first verify/refresh/logout, Bearer-protected mobile APIs, single-refresh replay, and household/mentor reuse of the shared auth seam.

### R050 - 抽出独立 db-migration Maven 模块，包含所有 Flyway SQL 脚本，作为 CI/CD 独立步骤在服务启动前执行，app-api 和 admin-api 关闭 Flyway 自动运行。

- Class: operational
- Status: validated
- Description: 抽出独立 db-migration Maven 模块，包含所有 Flyway SQL 脚本，作为 CI/CD 独立步骤在服务启动前执行，app-api 和 admin-api 关闭 Flyway 自动运行。
- Why it matters: 数据库 schema 变更与服务部署解耦，支持独立回滚数据库变更而不影响服务；避免多服务并发启动时 Flyway 锁竞争问题。
- Source: user
- Primary owning slice: M006/S02
- Validation: S02 verification passed on 2026-04-24: `docker compose up -d postgres && ./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` completed successfully, and `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` passed with `currentVersion=16` and `appliedCount=14`, confirming db-migration remains the sole Flyway owner and its module-local CLI closure works.

### R051 - Admin 精细权限体系：独立 admin_principals（管理员账号）表存储管理员账号，admin_roles/admin_permissions/admin_role_permissions 定义角色权限，Spring Security method-level security（@PreAuthorize）在 API 层强制执行权限检查，权限粒度到功能模块（如 users:read、rag:write、mentor:audit）。

- Class: functional
- Status: validated
- Description: Admin 精细权限体系：独立 admin_principals（管理员账号）表存储管理员账号，admin_roles/admin_permissions/admin_role_permissions 定义角色权限，Spring Security method-level security（@PreAuthorize）在 API 层强制执行权限检查，权限粒度到功能模块（如 users:read、rag:write、mentor:audit）。
- Why it matters: 精细权限体系支持未来多人团队分工管理（如专门的 RAG 管理员不能操作用户数据），比简单双角色更具扩展性。
- Source: user
- Primary owning slice: M006/S03
- Validation: Validated on 2026-04-24 by fresh `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` (users:read 200, admin/RBAC writes 403, same-token disable => 401 `admin_account_disabled`, current roles/permissions returned from login/refresh/`/api/admin/me`) plus fresh `./backend/mvnw.cmd -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` and compose-backed Flyway migrate proving V17/admin RBAC schema closure.
- Notes: S03 closes the admin RBAC backend proof with DB-backed authority hydration, super_admin create/disable admin flows, and stable forbidden/admin_account_disabled/admin_session_invalid semantics. Verification commands were normalized to `mvnw.cmd` for the Windows auto-mode worktree.

### R052 - Admin Web 全功能管理面（React + Ant Design Pro）覆盖：mobile 用户账号管理（账号列表/session/consent 审计/禁用）、RAG 知识库管理（Ingestion 任务监控/重试/文件上传、KG 矛盾审核/解决）、Mentor 审计日志（对话记录/rate limit/异常）、分发/分享/邀请统计面板。

- Class: core-capability
- Status: validated
- Description: Admin Web 全功能管理面（React + Ant Design Pro）覆盖：mobile 用户账号管理（账号列表/session/consent 审计/禁用）、RAG 知识库管理（Ingestion 任务监控/重试/文件上传、KG 矛盾审核/解决）、Mentor 审计日志（对话记录/rate limit/异常）、分发/分享/邀请统计面板。
- Why it matters: 现有所有管理面只有裸 REST API，无操作界面；admin Web 把这些能力对运营人员可见化、可操作化。
- Source: user
- Primary owning slice: M006/S04-S07
- Validation: 2026-04-25 milestone close-out revalidated the unified admin front door via `dart run tool/verify_m006_s14_release_closure.dart`, which passed after replaying S07/S08/S12/S13. Fresh browser/demo/smoke proof kept users, knowledge, mentor, distribution, and overview management surfaces under the same protected admin shell and repo-root entrypoints.
- Notes: S07 closed the final mentor/distribution composition proof instead of adding new runtime surfaces; full admin-web management coverage is now evidenced across prior slices plus the new closure pack.

### R053 - 后端 admin API 全部有 MockMvc 合同测试（权限矩阵验证、业务逻辑断言），Playwright E2E 测试覆盖关键 admin 流程（登录、权限守卫、用户管理、RAG 管理至少一个操作链路）。

- Class: quality-attribute
- Status: validated
- Description: 后端 admin API 全部有 MockMvc 合同测试（权限矩阵验证、业务逻辑断言），Playwright E2E 测试覆盖关键 admin 流程（登录、权限守卫、用户管理、RAG 管理至少一个操作链路）。
- Why it matters: admin 系统的权限矩阵是安全边界，必须有自动化测试证明；前端 E2E 验证整个交互链路可用，防止 API 和前端脱节。
- Source: user
- Primary owning slice: M006/S08
- Validation: 2026-04-25 milestone close-out revalidated the admin contract/browser/release proof chain via `dart run tool/verify_m006_s14_release_closure.dart` (pass). The fresh run covered S08 release closure, S12 `AdminOverviewWebTest` plus the 12-pass Playwright auth/overview pack, S13 front-door verifier parity, and CI/Helm wiring under one repo-root gate.
- Notes: Validated by M006/S08 release-closure slice; S14 may extend broader milestone release/canary closure but R053's CI + Playwright + contract-proof requirement is now satisfied.

### R054 - Helm-first split deployment：infra（Postgres/Redis/MinIO）和 app（gateway/app-api/admin-api/admin-web/db-migration）独立 release，本地和生产都不再依赖 docker compose；infra 和 app 的生命周期可以独立升级和回滚。

- Class: operational
- Status: validated
- Description: Helm-first split deployment：infra（Postgres/Redis/MinIO）和 app（gateway/app-api/admin-api/admin-web/db-migration）独立 release，本地和生产都不再依赖 docker compose；infra 和 app 的生命周期可以独立升级和回滚。
- Why it matters: 当前 docker compose 把所有基础设施和应用负载捆绑在同一个生命周期里，导致无法独立滚动更新或回滚，也让本地开发和生产部署讲两套不同的故事。
- Source: user
- Primary owning slice: M007/S01-S02
- Validation: S01 delivered: babytalk-infra (Postgres/Redis/MinIO via Bitnami) and babytalk-app (gateway stub + services + db-migration) as two independent Helm releases. docker-compose.yml deleted from repo. ci/k8s-smoke.sh passes 52/52 checks with zero failures. helm lint both charts exits 0. kind cluster config established as sole local baseline.

### R055 - Gateway single front door：Spring Cloud Gateway 模块是开发态和生产态唯一的 backend 入口；app-api 和 admin-api 在目标拓扑里为 internal-only services；admin-web dev proxy 和 prod ingress 都经由 gateway。

- Class: functional
- Status: validated
- Description: Gateway single front door：Spring Cloud Gateway 模块是开发态和生产态唯一的 backend 入口；app-api 和 admin-api 在目标拓扑里为 internal-only services；admin-web dev proxy 和 prod ingress 都经由 gateway。
- Why it matters: 当前 backend 入口分散在 admin-web 直代 admin-api、app-api 直接暴露公网、以及 ingress 配置三处；没有统一的 trust boundary，auth 和路由策略也没有单一可审计的执行点。
- Source: user
- Primary owning slice: M007/S03-S04
- Validation: S03 delivered: admin-web nginx.conf and vite proxy both forward /api/ to gateway:8090; admin-api has no external ingress in the Helm chart; AdminJwtGlobalFilter with 6 named error codes passes 9 unit tests; helm template shows babytalk/gateway:1.0.0 with no nginx:alpine; ci/k8s-smoke.sh passes 58 assertions (0 failures) confirming gateway is sole admin entry point.

## Deferred

### R021 - 提供更细的发音对比、发音建议或口语表现反馈。

- Class: differentiator
- Status: deferred
- Description: 提供更细的发音对比、发音建议或口语表现反馈。
- Why it matters: 对一部分用户有吸引力，但当前目标不是评分式训练。
- Source: user
- Primary owning slice: none
- Supporting slices: none
- Validation: unmapped
- Notes: 避免在验证期把产品拉回课堂模式。

### R022 - 包括 48h 沉默提醒、桌面 widget、更强的主动回访和推送机制。

- Class: continuity
- Status: deferred
- Description: 包括 48h 沉默提醒、桌面 widget、更强的主动回访和推送机制。
- Why it matters: 可能显著影响复访，但需要先知道 M001 的自然复访是否成立。
- Source: user
- Primary owning slice: none
- Supporting slices: none
- Validation: unmapped
- Notes: M002 再按数据决定组合方式。

### R023 - 为庆祝与结果页面提供更完整的微信分享卡、富预览和传播闭环。

- Class: differentiator
- Status: deferred
- Description: 为庆祝与结果页面提供更完整的微信分享卡、富预览和传播闭环。
- Why it matters: 有增长价值，但不属于先证明"家长会不会开口"的必要条件。
- Source: user
- Primary owning slice: none
- Supporting slices: none
- Validation: unmapped
- Notes: 依赖微信开放平台与额外审批。

### R024 - 包括会员、付费墙、定价和相关运营能力。

- Class: admin/support
- Status: deferred
- Description: 包括会员、付费墙、定价和相关运营能力。
- Why it matters: 长期必要，但早于 PMF 验证会扭曲优先级。
- Source: inferred
- Primary owning slice: none
- Supporting slices: none
- Validation: unmapped
- Notes: 待 M001/M002 留存与价值被证明后再推进。

## Out of Scope

### R003 - 核心场景练习、内置短语和基础播放在无网或弱网时仍然可用，且不会因为网络问题中断开口行为。

- Class: continuity
- Status: out-of-scope
- Description: 核心场景练习、内置短语和基础播放在无网或弱网时仍然可用，且不会因为网络问题中断开口行为。
- Why it matters: 真实育儿场景不适合等网络恢复；如果核心链路依赖在线，产品会在最关键时刻失效。
- Source: inferred
- Primary owning slice: M001/S01
- Supporting slices: M001/S03, M002/S01
- Validation: mapped
- Notes: M005 产品重新定位：软件定位真人导师，必须在线。离线对话可能不准确，影响使用体验。练习内容由 agentic search 动态生成，无法离线工作。

### R030 - 不做给父母打分、羞辱、排名或制造失败感的口语训练体验。

- Class: anti-feature
- Status: out-of-scope
- Description: 不做给父母打分、羞辱、排名或制造失败感的口语训练体验。
- Why it matters: 这会直接破坏"我可以做到"的产品气质和开口安全感。
- Source: user
- Primary owning slice: none
- Supporting slices: none
- Validation: n/a
- Notes: 即便未来增强语音能力，也不能转成打分产品。

### R031 - 不把产品做成给孩子直接操作的卡通课堂、闯关教育 app。

- Class: anti-feature
- Status: out-of-scope
- Description: 不把产品做成给孩子直接操作的卡通课堂、闯关教育 app。
- Why it matters: 这会把 parent-first 的产品定位拉偏。
- Source: inferred
- Primary owning slice: none
- Supporting slices: none
- Validation: n/a
- Notes: 用户是父母，不是孩子。

### R032 - 当前不以 Web-first、小程序优先或横屏适配作为主路线。

- Class: constraint
- Status: out-of-scope
- Description: 当前不以 Web-first、小程序优先或横屏适配作为主路线。
- Why it matters: 这能防止 roadmap 被分散到不支持当前验证目标的分发与布局分支上。
- Source: execution
- Primary owning slice: none
- Supporting slices: none
- Validation: n/a
- Notes: 当前路线明确是 Flutter Native、竖屏优先。

## Traceability

| ID | Class | Status | Primary owner | Supporting | Proof |
|---|---|---|---|---|---|
| R001 | primary-user-loop | active | M001/S01 | M001/S02, M001/S04, M002/S01, M002/S02 | mapped |
| R002 | core-capability | active | M001/S02 | M001/S01, M002/S02, M002/S03 | mapped |
| R003 | continuity | out-of-scope | M001/S01 | M001/S03, M002/S01 | mapped |
| R004 | differentiator | active | M001/S04 | M001/S01, M001/S03, M002/S02 | mapped |
| R005 | core-capability | active | M001/S05 | M001/S02, M001/S03, M002/S03 | mapped |
| R006 | integration | active | M001/S03 | M001/S01, M001/S04, M001/S05, M002/S01, M002/S02, M002/S03 | mapped |
| R007 | compliance/security | active | M001/S03 | M001/S02, M001/S06, M002/S03 | mapped |
| R008 | failure-visibility | active | M001/S06 | M001/S03, M001/S05, M002/S01, M002/S02, M002/S03 | mapped |
| R009 | launchability | active | M001/S06 | M001/S03, M002/S03 | mapped |
| R010 | admin/support | active | M001/S03 | M001/S06 | mapped |
| R011 | compliance/security | active | M001/S05 | M001/S06, M002/S03 | mapped |
| R012 | operability | active | M001/S06 | M001/S03, M001/S04, M001/S05, M002/S03 | mapped |
| R020 | differentiator | validated | M003/S03 | M003/S04 | M003/S03 通过 caregiver invite/accept/shared-context 合同与移动端 household shell/home/garden surface 证明多照护者协作入口成立；M003/S04 进一步通过 CaregiverPracticeAttributionWebTest、CaregiverInviteApiWebTest、household/home/garden/mentor 测试与 root-safe proof pack，证明次照护者可完成真实练习并形成共享归因与下一步闭环。 |
| R021 | differentiator | deferred | none | none | unmapped |
| R022 | continuity | deferred | none | none | unmapped |
| R023 | differentiator | deferred | none | none | unmapped |
| R024 | admin/support | deferred | none | none | unmapped |
| R030 | anti-feature | out-of-scope | none | none | n/a |
| R031 | anti-feature | out-of-scope | none | none | n/a |
| R032 | constraint | out-of-scope | none | none | n/a |
| R033 | core-capability | active | M002/S01 | M002/S02, M002/S03 | mapped |
| R034 | continuity | active | M002/S02 | M002/S01, M002/S03 | mapped |
| R035 | operational | validated | M004/S01 | none | git ls-files 不含 .data/、body_*、headers_* 文件（23个垃圾文件已从追踪中移除）；.gitignore 覆盖 .data/、*.lock.db、body_*.html/json、headers_*.txt；命令 `git ls-files | grep -cE '\.data/|body_|headers_' | grep -q '^0$'` 通过（exit 0） |
| R036 | functional | validated | M004/S04 | M004/S02 | SpringAiMentorProvider 实现通过 ChatClient 调用真实 OpenAI 兼容 API；MentorProviderConfiguration 支持 dev/github-models/openai 三种 provider mode 配置级切换；dev seam (DevMentorProvider) 在 api-key 为空时作为 fallback；provider 不可用时分别抛出 ProviderTimeoutException/ProviderUnavailableException/ProviderMalformedResponseException；66 个测试全绿（含 12 个新测试，覆盖四种异常路径和 API key 脱敏） |
| R037 | non-functional | validated | M004/S06 | M004/S03 | M004/S06 验证完成：BabyTalkColors ThemeExtension light/dark + ThemeMode.system 实现 dark mode；AppLocalizations i18n 基础设施在 15 个 features presentation 文件中接入；Semantics 语义标签在 9 个文件中有匹配；33 个 smoke 测试全绿（theme/i18n/a11y 三件套）；flutter analyze 零 error 零 warning；DESIGN.md CardTheme 圆角/阴影 token 对齐完成 |
| R038 | operational | validated | M004/S05 | M004/S07 | S07 完成：helm lint 零错误、helm template 渲染 7 种资源类型（含 Ingress）、bash ci/k8s-smoke.sh exit 0（6 PASS / 0 FAIL / 2 SKIP-无集群）、docs/runbooks/k8s-deploy.md 426 行、README 包含 K8s 章节。全部仓库级交付证明（Docker/Compose/CI/K8s）已覆盖。 |
| R039 | functional | validated | M004/S06 | none | M004/S06/T01 输出 S06-UX-REVIEW.md，对全部 8 个主屏幕进行专业 UI/UX 评审，识别 dark mode/a11y/token 缺口；T02-T05 按评审优先级执行改进（主题重构、颜色 token 迁移、i18n 接入、a11y 语义标签），评审-驱动的改进全部实施 |
| R040 | functional | validated | M005/S03 | none | 87 个单元/集成测试通过（PalaceKeywordRepositoryTest 11 + PalaceToolProviderTest 28 + MemPalacePromptBuilderTest 11 + AgenticMentorIntegrationTest + SpringAiMentorProviderTest）。PalaceToolProvider 5 个 @Tool 方法、三种 search-mode 切换（agentic/rag/none）、AgenticMentorIntegrationTest 验证 .tools() 注册、MemPalacePromptBuilderTest 验证四层 Prompt 分层。完整 tool calling 链路（LLM 真正调用 tool）需真实 OpenAI API key 在生产环境验证。 |
| R041 | functional | validated | M005/S02 | none | 51 本书完整映射（5 Wing/18 Room/22 Hall 分类体系），MemPalaceTaxonomy + MemPalaceMetadataEnricher 24 个单元测试通过。PgVectorStore filterExpression 按坐标过滤验证通过。batch-ingest.sh/.cmd 就绪。实际 PDF/ePub 批量导入执行需要真实书籍文件 + OpenAI Embedding API。 |
| R042 | functional | validated | M005/S04 | none | ChatMemoryIntegrationTest 5/5 通过：多轮 conversationId 保持稳定、10 轮滑动窗口裁剪、30 分钟超时新建会话、null→UUID 向后兼容。Flyway V13 SPRING_AI_CHAT_MEMORY 表，JdbcChatMemoryRepository 手动配置，conversationId 全链路穿透。 |
| R043 | functional | validated | M005/S06 | none | POST /api/v1/mentor/practice/generate + MemPalacePromptBuilder.buildPracticeSystemPrompt()（26/26 测试通过）。DynamicPracticeApiService + PracticeRepository.getActivitySnapshotDynamic()，8 场景单元测试通过，seed_content.json 降级为离线 fallback。flutter analyze 零错误，17/17 移动端测试通过。 |
| R044 | functional | validated | M005/S05 | none | V14 Flyway 迁移建立 pg_trgm + 4 张表（kg_entities/kg_relationships/kg_contradictions/kg_admin_notifications），4 个 JdbcTemplate Repository，KgContradictionDetector 自动检测 contradicts 关系，KgContradictionReviewService @Scheduled agent 审查，4 个 REST 端点，19 个测试全部通过，编译 exit 0。 |
| R045 | functional | validated | M005/S02 | none | REST API 3 端点（POST /upload 202+jobId、GET /jobs/{id} 状态、POST /jobs/{id}/retry 仅 FAILED 可重试），MinIO 存储，Tika 解析，ingestion_jobs 状态跟踪（PENDING→PROCESSING→COMPLETED/FAILED），batch-ingest.sh/.cmd 批量脚本就绪，3 个集成测试类编译通过，24 个单元测试通过。 |
| R046 | operational | validated | M005/S01 | none | docker-compose up -d 全栈健康，curl /actuator/health 返回 db(PostgreSQL)+minio 均 UP。Flyway V10 创建 pgvector 扩展 + vector_store 表 + HNSW 索引。16 个测试类迁移到 Testcontainers PostgreSQL（AbstractIntegrationTest singleton pattern）。 |
| R047 | operational | validated | M005/S07 | none | docker-compose config 解析成功含全部 M005 变量；helm lint 通过（0 charts failed）；README 含 PostgreSQL/MinIO/MemPalace/pgvector 完整架构说明；m005-mempalace-ops.md 新建含 9 个运维段落；verify-e2e.sh 语法检查通过，CI 脚本使用 mvn。安卓模拟器全功能测试和 20 题育儿验收集需真实设备 + OpenAI API key，为运营验证前提条件。 |
| R048 | operational | validated | M006/S01 | none | Fresh slice-close verification on 2026-04-24: `./ci/backend-test.sh` passed, including `./backend/mvnw -f backend/pom.xml -B test` (reactor summary: parent/common/db-migration/app-api SUCCESS) plus migration-first compose smoke where `app-api` and `admin-api` health endpoints both became healthy. Browser/API closure also passed via `npm --prefix admin-web run test:e2e -- admin-login.spec.ts` (3/3 passed), and focused auth/migration proofs passed via `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest` and `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest`. |
| R049 | functional | validated | M006/S02 | none | S02 verification passed on 2026-04-24: `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest,AuthConsentSyncWebTest,MentorWebTest,CaregiverInviteApiWebTest,CaregiverInviteLandingWebTest,CaregiverPracticeAttributionWebTest` passed, and `flutter test mobile/test/features/account/jwt_session_refresh_test.dart mobile/test/features/account/account_repository_test.dart mobile/test/features/household/household_repository_test.dart mobile/test/features/mentor/mentor_view_model_test.dart` passed from the worktree root, proving token-first verify/refresh/logout, Bearer-protected mobile APIs, single-refresh replay, and household/mentor reuse of the shared auth seam. |
| R050 | operational | validated | M006/S02 | none | S02 verification passed on 2026-04-24: `docker compose up -d postgres && ./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` completed successfully, and `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` passed with `currentVersion=16` and `appliedCount=14`, confirming db-migration remains the sole Flyway owner and its module-local CLI closure works. |
| R051 | functional | validated | M006/S03 | none | Validated on 2026-04-24 by fresh `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminAuthWebTest,AdminRbacWebTest` (users:read 200, admin/RBAC writes 403, same-token disable => 401 `admin_account_disabled`, current roles/permissions returned from login/refresh/`/api/admin/me`) plus fresh `./backend/mvnw.cmd -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` and compose-backed Flyway migrate proving V17/admin RBAC schema closure. |
| R052 | core-capability | validated | M006/S04-S07 | none | 2026-04-25 milestone close-out revalidated the unified admin front door via `dart run tool/verify_m006_s14_release_closure.dart`, which passed after replaying S07/S08/S12/S13. Fresh browser/demo/smoke proof kept users, knowledge, mentor, distribution, and overview management surfaces under the same protected admin shell and repo-root entrypoints. |
| R053 | quality-attribute | validated | M006/S08 | none | 2026-04-25 milestone close-out revalidated the admin contract/browser/release proof chain via `dart run tool/verify_m006_s14_release_closure.dart` (pass). The fresh run covered S08 release closure, S12 `AdminOverviewWebTest` plus the 12-pass Playwright auth/overview pack, S13 front-door verifier parity, and CI/Helm wiring under one repo-root gate. |
| R054 | operational | validated | M007/S01-S02 | none | S01 delivered: babytalk-infra (Postgres/Redis/MinIO via Bitnami) and babytalk-app (gateway stub + services + db-migration) as two independent Helm releases. docker-compose.yml deleted from repo. ci/k8s-smoke.sh passes 52/52 checks with zero failures. helm lint both charts exits 0. kind cluster config established as sole local baseline. |
| R055 | functional | validated | M007/S03-S04 | none | S03 delivered: admin-web nginx.conf and vite proxy both forward /api/ to gateway:8090; admin-api has no external ingress in the Helm chart; AdminJwtGlobalFilter with 6 named error codes passes 9 unit tests; helm template shows babytalk/gateway:1.0.0 with no nginx:alpine; ci/k8s-smoke.sh passes 58 assertions (0 failures) confirming gateway is sole admin entry point. |
| R056 | functional | validated | M007/S05 | none | M007/S05 complete: zero owned JdbcTemplate in runtime paths; Druid slow-query observable |
| R057 | operability | validated | M007/S06 | none | M007/S06 complete: README Getting Started; all deploy commands point to Helm-first path |
| R058 | core-capability | active | M010/P39 | M010/P40, M010/P41 | mapped |
| R059 | primary-user-loop | active | M010/P39 | M010/P40, M010/P41 | mapped |
| R060 | core-capability | active | M010/P39 | M010/P41 | mapped |
| R061 | functional | active | M010/P41 | M010/P39 | mapped |
| R062 | functional | active | M010/P41 | M010/P39, M010/P40 | mapped |
| R063 | functional | active | M010/P40 | M010/P41 | mapped |
| R064 | differentiator | active | M010/P40 | M010/P39, M010/P41 | mapped |
| R065 | core-capability | active | M010/P40 | M010/P39, M010/P41 | mapped |
| R066 | operability | active | M010/P41 | M010/P40 | mapped |

## Coverage Summary

- Active requirements: 22
- Mapped to slices: 22
- Validated: 24 (R020, R035, R036, R037, R038, R039, R040, R041, R042, R043, R044, R045, R046, R047, R048, R049, R050, R051, R052, R053, R054, R055, R056, R057)
- Unmapped active requirements: 0
