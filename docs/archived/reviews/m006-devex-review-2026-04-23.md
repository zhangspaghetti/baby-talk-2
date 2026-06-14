# M006 DevEx Review

> 审查时间: 2026-04-23
> 审查对象: M006 Admin 管理后台与后端多模块重构计划
> 审查模式: DX EXPANSION
> 主产品类型: Platform（API/Service 次属性）
> 目标开发者: 产品团队里的全栈工程师
> 当前 TTHW 估计: 10-15 分钟
> 目标 TTHW: Champion `<2 分钟`

---

## Verdict

本轮 DevEx review 结论为 `clean`。

M006 原计划的主要问题不是“技术方案不够多”，而是“开发者第一次进仓库时，要自己拼出上手路径”。这轮评审把开发者体验从隐含假设改成了显式合同：怎么启动、怎么验证、怎么失败、怎么迁移、怎么找到下一步，现在都进入了计划和验收标准。

结论上，M006 现在已经具备实现级别的 DX 约束，不再把 onboarding、文档和脚本质量当成上线后再补的附属工作。

---

## Persona Card

Who:
产品团队里的全栈工程师。

Context:
需要在同一个仓库里拉起 backend、admin-web、docker-compose、CI 链路，然后修改一个真实管理面能力。

Tolerance:
10 到 20 分钟内必须看到“系统能跑、下一步清楚”，否则会开始自己猜路径。

Expects:
根 README 是唯一可信入口，命令可复制即跑，失败后知道先修哪里。

---

## Scorecard

| Pass | Score | Notes |
|------|-------|-------|
| Getting Started | 9/10 | 单命令 demo、fast smoke、Champion TTHW 已进入计划 |
| API / Service DX | 8/10 | 增加 copy-paste auth/API examples，OpenAPI 不再是唯一入口 |
| Errors & Debugging | 9/10 | demo/smoke 失败输出必须解释失败步骤、原因、下一步 |
| Docs & Learning | 8/10 | 根 README 成唯一入口，禁止占位 README，允许深链文档 |
| Upgrade & Migration | 8/10 | 明确要求旧单体开发流 -> 新多模块开发流迁移表 |
| Dev Environment & Tooling | 9/10 | wrappers/scripts 优先，Windows parity 成为硬要求 |
| Community & Contribution | 7/10 | 增加最小 CONTRIBUTING / dev workflow 文档要求 |
| DX Measurement | 8/10 | 要求记录 TTHW、首次 smoke 通过率、首次失败热点 |

整体评分: 8/10

---

## Key Plan Changes

1. M006 以 Champion 档 developer TTHW 为目标，要求 `<2 分钟` 到达可操作 admin demo 状态。
2. 计划必须交付一条 golden path demo 命令，负责起栈、seed、打印 URL/账号、做最小健康校验。
3. 计划必须交付一条本地 fast smoke 命令，快速验证登录、首页和关键 admin API 活性。
4. worktree 根 README 成为开发者前 2 分钟的唯一入口，深水区内容通过明确链接下钻到 `docs/` 或模块文档。
5. 在 golden path 之后，补齐 full-stack、backend-only、admin-web-only 三条 role-based quickstarts。
6. 所有被根 README 链出的模块文档都必须支持真实任务，禁止默认模板或占位内容。
7. README 主命令优先走 repo-local wrappers/scripts，不再把全局工具版本当隐含前提。
8. 明确要求一张“旧单体开发流 -> 新多模块开发流”的迁移表。
9. demo/smoke 命令的失败输出必须可执行，至少说明失败步骤、最可能原因、下一步动作。
10. golden path 与 fast smoke 必须同时提供 `.cmd` 与 `.sh` 入口，Windows 不是二等平台。
11. 补齐 copy-paste 级 auth/API examples，至少覆盖 admin login、token refresh 和一个关键只读接口。
12. 补最小 CONTRIBUTING / dev workflow 文档，说明常见开发路径、提交流程、验证入口和目录职责。
13. 增加最小 DevEx measurement，记录 TTHW、首次 smoke 通过率和首次失败热点。

---

## Evidence Used

1. 根 README 已提供环境要求、Docker、本地运行说明，但当前多服务/多模块路径尚未收敛成一个黄金入口。
2. `mobile/README.md` 仍是默认 Flutter 模板，说明模块文档可信度不足。
3. 仓库里实际存在 `backend/mvnw`，但 README 当前仍提示“不包含 Maven Wrapper”，这会制造命令信任冲突。
4. 当前计划在功能层面完整，但在开发者路径上原本缺少单命令 demo、fast smoke、迁移表和 measurement。

---

## Residual Risk

1. 这份 review 使用了 fallback benchmark，而不是实时 WebSearch 竞争数据。结论方向仍然成立，但外部 benchmark 证据不算最强。
2. 当前改动是计划级约束，不是实现验证。真正的 DX 成败还要看 README、脚本、seed 数据和错误输出落地质量。

---

## Recommendation

下一步最值钱的动作不是继续抽象，而是把这轮新增的 DX 交付拆回 M006 切片，尤其是：

1. README / docs contract
2. demo + fast smoke scripts
3. Windows parity
4. copy-paste auth/API examples
5. migration table + CONTRIBUTING
6. DevEx measurement