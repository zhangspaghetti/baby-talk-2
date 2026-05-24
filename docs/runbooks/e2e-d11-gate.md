# D11 Gate Runbook (Admin Web E2E)

## Owner
- QA/测试负责人

## Purpose
在 D11 决策会前，产出可机器检查、可追溯、可审计的 go/no-go 输入。

## Inputs
- 决策简报: docs/reviews/management-decision-brief-2026-05-24.md
- 全栈E2E报告: docs/e2e-full-test-report-2026-05-23.md

## Checklist
- [ ] 生成本次执行批次ID并写入报告。
- [ ] 执行高风险域测试集合并统计通过率（目标 >=95%）。
- [ ] 确认 P0/P1 未解决数 = 0（附缺陷系统快照）。
- [ ] 每个失败用例均有 trace + screenshot 或 video。
- [ ] stdout/stderr 已持久化并与 commit SHA 绑定。
- [ ] 文档结论可反查到工件路径与执行批次。
- [ ] 工程负责人、技术负责人、QA 完成签字。

## Artifact Layout
建议路径：artifacts/e2e/{date}/{commit}/{suite}/

## Decision Rule
- 任一清单项未满足：NO-GO
- 全项满足：进入 D11 评审并可提请解冻
