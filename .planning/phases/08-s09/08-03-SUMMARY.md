---
phase: "08"
plan: "03"
---

# T03: Added repo-root admin demo/smoke front doors, truthful root docs, and a shared S13 verifier that keeps live-stack smoke non-destructive.

**Added repo-root admin demo/smoke front doors, truthful root docs, and a shared S13 verifier that keeps live-stack smoke non-destructive.**

## What Happened

我先查询了与 admin demo / smoke / README 相关的 memory，并加载了 docker-expert、karpathy-guidelines、write-docs 三个技能，确认 T03 的核心不是再补一个旧脚本，而是把 repo root 的 front door 收敛成真实的 split-stack admin demo / fast-smoke 合同。随后新增 `tool/verify_m006_s13_demo_path.dart` 作为共享 contract：它在 `verify` mode 下静态校验 README / CONTRIBUTING / mobile README / runbook 链接与 wrapper parity，在 `demo` mode 下执行 `preflight -> compose_boot -> runtime_truth` 并输出 `tthw_seconds` / `first_failure_stage` / `next_action`，在 `smoke` mode 下复用 live stack 调用 S12 auth + Overview freshness proof pack。四个 `.sh` / `.cmd` wrapper 只保留 repo-root 定位、Dart preflight 和 mode 委托，从而把 Windows / POSIX 的 stage vocabulary、failure guidance 和 observability 字段锁到同一份真相上。文档层面，我重写了根 `README.md`，新增 `CONTRIBUTING.md`，并替换 `mobile/README.md`，把 golden path / fast smoke 前门、full-stack / backend-only / admin-web-only quickstarts、copy-paste admin auth/API 示例、旧单体 -> 新 split-stack 迁移表和 runbook 深链都放到了 fresh-reader 能直接执行的位置。运行时验证中，我发现直接复用 S12 Playwright proof pack 会在 smoke 成功后通过 global teardown 顺手停掉 compose 栈，这与“复用 live stack 的 fast smoke”语义冲突；因此额外调整了 `admin-web/playwright.global-teardown.ts`，让 `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` 同时表示“不要 boot compose，也不要 teardown compose”，把 smoke 修成真正的 non-destructive front door。

## Verification

执行 `dart run tool/verify_m006_s13_demo_path.dart`，确认 front-door artifacts、docs truth、relative links 和 wrapper parity 全部通过。执行 `./scripts/dev-up-admin-demo.sh`，确认 compose 能在 `preflight -> compose_boot -> runtime_truth` 后输出 `demo_status=ready`、`tthw_seconds`、`first_failure_stage=none`、admin-web URL 与 demo account。执行 `./scripts/dev-verify-admin-demo.sh`，确认 fast smoke 在 live stack 上复用 S12 auth/Overview proof pack，11 个 Playwright 用例全部通过，且 global teardown 输出 preserve 提示而不再停掉 compose。最后执行 `docker compose ps --all && rg -n ... README.md && ! rg -n ... mobile/README.md`，确认 smoke 后五个运行服务仍健康、`db-migration` exited 0，README front door 关键词存在且 mobile README 不再包含 Flutter 模板文本。第一次 smoke 在 malformed summary proof 上出现过一次瞬时失败，但同一 live stack 上的立即重跑通过，未留下可复现阻塞。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `dart run tool/verify_m006_s13_demo_path.dart` | 0 | ✅ pass | 8000ms |
| 2 | `./scripts/dev-up-admin-demo.sh` | 0 | ✅ pass | 90500ms |
| 3 | `./scripts/dev-verify-admin-demo.sh` | 0 | ✅ pass | 46400ms |
| 4 | `docker compose ps --all && rg -n "dev-up-admin-demo|dev-verify-admin-demo|admin-web|admin-api|CONTRIBUTING" README.md && ! rg -n "A new Flutter project" mobile/README.md` | 0 | ✅ pass | 5100ms |

## Deviations

为使 fast smoke 真正成为“对 live stack 追加 proof”而不是“跑完顺手关栈”，额外修改了 `admin-web/playwright.global-teardown.ts`：当 `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` 时保留 compose 栈。这个调整没有出现在原始文件清单里，但属于完成 T03 runtime contract 所必需的本地适配。

## Known Issues

无阻塞问题。一次 smoke 曾在 `overview-control-plane.spec.ts` 的 malformed summary 场景瞬时未观察到 `overview-summary-error`，但同一 live stack 上立即重跑通过；如果后续再次出现，应按 S12 proof-pack 时序抖动排查，而不是按 T03 front-door 回归处理。

## Files Created/Modified

- `tool/verify_m006_s13_demo_path.dart`
- `scripts/dev-up-admin-demo.sh`
- `scripts/dev-up-admin-demo.cmd`
- `scripts/dev-verify-admin-demo.sh`
- `scripts/dev-verify-admin-demo.cmd`
- `README.md`
- `CONTRIBUTING.md`
- `mobile/README.md`
- `docs/runbooks/m006-s13-demo-path.md`
- `admin-web/playwright.global-teardown.ts`
