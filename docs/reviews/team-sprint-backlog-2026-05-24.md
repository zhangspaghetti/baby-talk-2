# 2 周执行 Backlog（Sprint 排序版）

## 0. 先证据后决策：本轮已确认事实

1. 全栈 E2E 当次结果：Admin Web 失败，Mobile 通过，见 [docs/e2e-full-test-report-2026-05-23.md](docs/e2e-full-test-report-2026-05-23.md)
2. Admin Web 失败总数为 31，失败根因为浏览器可执行缺失，见 [docs/e2e-full-test-report-2026-05-23.md](docs/e2e-full-test-report-2026-05-23.md) 与 [admin-web/test-results/.last-run.json](admin-web/test-results/.last-run.json)
3. 失败模块分布已明确：auth-and-rbac(7)、overview-control-plane(5)、mentor-audit(4)、users-management(4) 等，见 [docs/e2e-full-test-report-2026-05-23.md](docs/e2e-full-test-report-2026-05-23.md)
4. 移动端集成流程在 emulator-5554 上已通过，且有 000 到 020 全流程截图，见 [docs/e2e-full-test-report-2026-05-23.md](docs/e2e-full-test-report-2026-05-23.md)
5. 当前证据缺口：逐用例失败截图、失败视频、持久化 stdout 或 stderr、HAR，见 [docs/e2e-full-test-report-2026-05-23.md](docs/e2e-full-test-report-2026-05-23.md)

## 1. Sprint 目标（2 周，Day1 到 Day10）

唯一核心目标：把可复现、可归因、可放行的 E2E 回归链路拉通，使 Admin Web 从基础设施阻断进入真实业务回归，同时保持移动端通过态不回退。

排序原则：
1. 先解除统一阻断（基础设施）
2. 再打通高风险业务回归（认证、RBAC、概览）
3. 并行保持移动端稳定推进
4. 用发布治理兜底，避免结果通过但证据不可审计

## 2. 执行 Backlog（按任务分组）

### A. 测试基础设施

| 任务 | 优先级 | Owner 建议 | 依赖 | 验收标准 | 风险 |
|---|---|---|---|---|---|
| A1. 修复 Playwright 浏览器可执行安装与发现路径（本地和 CI 一致） | P0 | QA 自动化负责人 + Admin Web 工程师 | 无 | 重新执行后不再出现 Executable 缺失；失败可进入业务断言层 | 环境差异导致本地好、CI坏 |
| A2. 增加 E2E 预检步骤（浏览器可执行、端口、依赖服务） | P0 | QA 自动化负责人 | A1 | 预检失败时在测试前快速失败并给出可执行错误信息 | 预检覆盖不全导致假阴性 |
| A3. 补齐工件策略：失败截图、视频、trace、stdout或stderr、HAR 持久化 | P1 | QA 自动化负责人 + DevOps | A1 | 任一失败用例均可定位到同名工件集合 | 工件增长带来存储成本 |
| A4. 增加失败聚类脚本（按 spec 和错误类型自动汇总） | P1 | QA 自动化负责人 | A3 | 每次失败后自动生成模块分布和根因 TopN 摘要 | 分类规则前期误判 |

### B. Admin Web 回归

| 任务 | 优先级 | Owner 建议 | 依赖 | 验收标准 | 风险 |
|---|---|---|---|---|---|
| B1. 第一波回归：登录、会话、Cookie 合约（最小放行链路） | P0 | Admin Web 负责人 + 后端认证接口 Owner | A1、A2 | [admin-web/tests/admin-login.spec.ts](admin-web/tests/admin-login.spec.ts)、[admin-web/tests/admin-cookie-contract.spec.ts](admin-web/tests/admin-cookie-contract.spec.ts) 通过；无新增阻断级错误 | 认证链路改动可能影响移动端会话 |
| B2. 第二波回归：auth-and-rbac（占比最高模块） | P0 | Admin Web 负责人 | B1 | [admin-web/tests/auth-and-rbac.spec.ts](admin-web/tests/auth-and-rbac.spec.ts) 关键场景通过；403和跳转行为符合预期 | 权限矩阵与后端返回不一致 |
| B3. 第三波回归：overview-control-plane | P1 | Admin Web 负责人 + 概览接口 Owner | B2 | [admin-web/tests/overview-control-plane.spec.ts](admin-web/tests/overview-control-plane.spec.ts) 通过，含轮询和异常态 | 实时与轮询切换抖动 |
| B4. 第四波回归：users 和 admin accounts | P1 | Admin Web 负责人 + Admin API Owner | B2 | [admin-web/tests/users-management.spec.ts](admin-web/tests/users-management.spec.ts)、[admin-web/tests/admin-accounts.spec.ts](admin-web/tests/admin-accounts.spec.ts) 通过 | 数据前置条件复杂 |
| B5. 第五波回归：mentor、distribution、knowledge | P2 | 对应模块前端 Owner | B3、B4 | [admin-web/tests/mentor-audit.spec.ts](admin-web/tests/mentor-audit.spec.ts)、[admin-web/tests/distribution-stats.spec.ts](admin-web/tests/distribution-stats.spec.ts)、[admin-web/tests/knowledge-ops.spec.ts](admin-web/tests/knowledge-ops.spec.ts)、[admin-web/tests/mentor-distribution-closure.spec.ts](admin-web/tests/mentor-distribution-closure.spec.ts) 按计划清零 | 模块共享壳导航串扰 |

### C. 移动端并行推进

| 任务 | 优先级 | Owner 建议 | 依赖 | 验收标准 | 风险 |
|---|---|---|---|---|---|
| C1. 固化已通过链路基线（截图索引和执行参数留档） | P1 | Mobile QA + Mobile 工程师 | 无 | 000 到 020 截图链路与执行环境说明可复用 | 基线未标准化导致后续对比困难 |
| C2. 建立移动端每日冒烟并行跑（不阻塞 Web 修复） | P1 | Mobile QA | C1 | 每日有明确 PASS 或 FAIL 记录与失败工件路径 | 模拟器资源争抢 |
| C3. 对齐账号和会话相关跨端契约检查清单 | P2 | Mobile 负责人 + 后端认证 Owner | B1 | 形成跨端契约检查项并在站会同步 | 契约边界不清 |

### D. 发布治理

| 任务 | 优先级 | Owner 建议 | 依赖 | 验收标准 | 风险 |
|---|---|---|---|---|---|
| D1. 定义本迭代放行门禁（证据门禁优先于口头结论） | P0 | Release Manager + QA Lead | A3、B1 | 放行条件文档化：结果状态、工件完整性、关键套件通过 | 门禁过宽导致带病发布 |
| D2. 建立失败豁免流程（时限、责任人、回补计划） | P1 | Release Manager | D1 | 每个豁免都含到期日、回补任务、验收人 | 豁免泛滥导致门禁失效 |
| D3. 发布前汇总模板（同一页面可审计） | P1 | QA Lead | D1 | 一页汇总包含失败数、根因、模块分布、工件链接、结论 | 信息分散导致决策延迟 |

## 3. Day1 到 Day10 执行节奏（建议）

| Day | 重点 | 当日输出 |
|---|---|---|
| Day1 | 锁定阻断根因与修复方案 | 完成 A1 方案评审，明确本地和 CI 一致安装路径 |
| Day2 | 落地基础设施修复 | A1 完成并复跑；确认不再出现浏览器缺失 |
| Day3 | 前置预检与快速失败 | A2 完成；预检日志可读、失败可定位 |
| Day4 | 证据工件补齐（第一阶段） | A3 完成截图、视频、trace、日志持久化 |
| Day5 | P0 回归波次 1 | B1 执行并出结论；同步跨端风险给 C3 |
| Day6 | P0 回归波次 2 | B2 执行，认证和 RBAC 高风险项清零或挂账 |
| Day7 | P1 回归波次 3 | B3 执行，概览异常态与恢复态验证完成 |
| Day8 | P1 回归波次 4 | B4 执行，用户和管理账号主流程验证完成 |
| Day9 | P2 回归波次 5 + 发布治理收口 | B5 执行；D1、D2、D3 文档定版 |
| Day10 | 迭代收官与复盘 | 输出可放行或不可放行结论、遗留风险与下 Sprint 输入 |

并行轨（Day1 到 Day10 持续）：
- C1、C2 每日执行，确保移动端通过态不回退
- A4 在 Day4 后插入，确保每天有自动失败聚类摘要

## 4. 站会关注指标（每日必看）

| 指标 | 口径定义 | 数据来源 |
|---|---|---|
| Admin Web failedTests | .last-run.json 中 failedTests 数值 | [admin-web/test-results/.last-run.json](admin-web/test-results/.last-run.json) |
| 阻断级基础设施错误数 | 未进入业务断言的环境错误数 | E2E 日志与 error-context |
| 模块失败分布 Top3 | 按 spec 聚合的失败数排名 | [admin-web/test-results](admin-web/test-results) + A4 汇总 |
| 关键套件通过率（P0） | B1、B2 对应用例通过占比 | [admin-web/tests](admin-web/tests) |
| 工件完整率 | 失败用例中具备截图、视频、trace、日志、HAR 的比例 | 工件目录与汇总页 |
| 移动端每日冒烟状态 | PASS 或 FAIL + 失败工件链接 | Mobile 集成测试产物与报告 |
| 发布门禁满足度 | D1 定义项中已满足条目数占比 | 发布汇总模板 |

## 5. Sprint 结束判定（建议）

满足以下条件才建议可放行：
1. A1、A2 完成，阻断级基础设施错误归零。
2. B1、B2 全通过；B3、B4 至少达到可接受风险状态并有明示挂账。
3. 移动端 Day1 到 Day10 冒烟记录连续可追溯，无未解释失败。
4. D1 门禁满足，且失败豁免项都有到期回补计划。
